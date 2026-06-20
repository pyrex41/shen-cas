\\ trace.shen - step-by-step derivation tracer (NON-INVASIVE).
\\
\\ The evaluator (src/core.shen) reaches a normal form by a fixed-point loop that
\\ applies eval-step until the expression stops changing. A "derivation" is just
\\ that reduction sequence made visible: each intermediate expression, plus the
\\ name of the rule / built-in that produced it.
\\
\\ This module adds that view WITHOUT touching the hot path. reduce/normal-form
\\ are unchanged; reduce-trace re-walks the SAME ordered sequence (args first,
\\ then this node: canonicalize -> built-in -> DownValues -> UpValues), but takes
\\ ONE rewrite at a time so every micro-step is recorded. The trace is layered:
\\   - the raw sequence of intermediate expressions, and
\\   - a human label for the rule/built-in that fired (the annotation layer).
\\
\\ Faithfulness: tr-step mirrors eval-step's applicative order (innermost-leftmost
\\ single step), so the final form of a trace equals (reduce E). A pure Orderless
\\ reordering / Flat-flatten is applied but suppressed from the printed steps (it
\\ is structural noise, not a derivation step). Bounded by *max-eval-steps*.
\\
\\ Loaded LAST (after core/print): uses canon-flat-orderless, try-builtin,
\\ rules-for-expr, up-candidates (core), match/substitute (match), rule accessors
\\ (rule), lhs-dispatch-pattern (rule), named?/blank? (pattern), print-expr (print).

\\ A step record is [Before After Why]: Before/After whole-expr snapshots, Why a
\\ string label. tr-step returns [none] | [some [After Why]].

\\ ---------------------------------------------------------------------------
\\ Single rewrite, innermost-leftmost (mirrors eval-step's applicative order).
\\ Atoms are inert (no built-in / rule applies), so only compounds can step.
\\ ---------------------------------------------------------------------------
(define tr-step
  Db E -> (if (expr-compound? E) (tr-step-compound Db E) [none]))

\\ Try to step a (non-held) argument first; only if no argument can step does the
\\ node itself rewrite -- exactly the order reduce-args-then-node uses.
(define tr-step-compound
  Db [H | Args] -> (let Sub (tr-step-args Db H Args)
                        (if (= Sub [none])
                            (tr-root Db [H | Args])
                            Sub)))

\\ Walk args left-to-right, honouring Hold attributes (a held position is skipped,
\\ matching reduce-args-compound). Rebuild the whole expr around the first arg that
\\ takes a step, carrying that sub-step's annotation up.
(define tr-step-args
  Db H Args -> (tr-args-walk Db H [] Args (eval-mask Db H Args)))

(define eval-mask
  Db H Args -> (if (sym? H)
                   (mask-for-head Db (sym-name H) Args)
                   (all-mask true Args)))

(define mask-for-head
  Db S Args -> (if (holds-all? Db S)
                   (all-mask false Args)
                   (if (holds-first? Db S)
                       [false | (all-mask true (tl Args))]
                       (if (holds-rest? Db S)
                           [true | (all-mask false (tl Args))]
                           (all-mask true Args)))))

(define all-mask
  _ [] -> []
  V [_ | Xs] -> [V | (all-mask V Xs)])

(define tr-args-walk
  Db H Prefix [] [] -> [none]
  Db H Prefix [A | As] [M | Ms] ->
    (if M
        (tr-args-dispatch Db H Prefix A As Ms (tr-step Db A))
        (tr-args-walk Db H [A | Prefix] As Ms))
  Db H Prefix _ _ -> [none])

(define tr-args-dispatch
  Db H Prefix A As Ms [none] -> (tr-args-walk Db H [A | Prefix] As Ms)
  Db H Prefix A As Ms [some [A2 Why]] ->
    [some [[H | (append (reverse Prefix) [A2 | As])] Why]])

\\ ---------------------------------------------------------------------------
\\ Node-level rewrite (args already inert). Same order as eval-step-compound:
\\ canonicalize (Flat/Orderless), then built-in (arithmetic / wired calculus),
\\ then DownValues, then UpValues. A canon-only change is applied but tagged with
\\ the canon sentinel so the driver can suppress it from the derivation.
\\ ---------------------------------------------------------------------------
(define tr-root
  Db E -> (let C (canon-flat-orderless Db E)
               B (try-builtin C)
               (if (not (content-eq B C))
                   [some [B (tr-builtin-label C)]]
                   (tr-root-rules Db E C))))

(define tr-root-rules
  Db E C -> (let DR (tr-first-rule C (rules-for-expr Db C))
                 (if (= DR [none])
                     (tr-root-up Db E C)
                     DR)))

(define tr-root-up
  Db E C -> (let UR (tr-first-rule C (up-candidates Db C))
                 (if (= UR [none])
                     (if (content-eq C E) [none] [some [C (canon-why)]])
                     UR)))

\\ first matching checked rule -> [some [Substituted Label]]
(define tr-first-rule
  E [] -> [none]
  E [R | Rest] -> (if (checked-rule? R)
                      (tr-first-rule-try E R Rest (match (rule-lhs R) E))
                      (tr-first-rule E Rest)))

(define tr-first-rule-try
  E R Rest M -> (if (match-some? M)
                    [some [(substitute (match-unwrap M) (rule-rhs R)) (rule-why R)]]
                    (tr-first-rule E Rest)))

\\ ---------------------------------------------------------------------------
\\ Trace driver: collect step records until inert (or fuel runs out).
\\ ---------------------------------------------------------------------------
(define reduce-trace
  E -> (reduce-trace-db (value *db*) E))

(define reduce-trace-db
  Db E -> (reverse (tr-loop Db E [] (value *max-eval-steps*))))

(define tr-loop
  Db E Acc 0 -> Acc
  Db E Acc N -> (tr-loop-dispatch Db E Acc N (tr-step Db E)))

(define tr-loop-dispatch
  Db E Acc N [none] -> Acc
  Db E Acc N [some [After Why]] ->
    (if (= Why (canon-why))
        (tr-loop Db After Acc (- N 1))                       \\ apply, do not record
        (tr-loop Db After [[E After Why] | Acc] (- N 1))))

\\ ---------------------------------------------------------------------------
\\ derive: print a readable step-by-step derivation, return the normal form.
\\ ---------------------------------------------------------------------------
(define derive
  E -> (let Steps (reduce-trace E)
            Final (reduce E)
            (do (output "~%Derivation of  ~A~%" (tr-show E))
                (tr-print-steps Steps 1)
                (output "  = ~A   (~A step(s))~%" (tr-show Final) (length Steps))
                Final)))

(define tr-print-steps
  [] _ -> true
  [[_ A W] | Rest] I -> (do (output "  ~A. ~A    [~A]~%" I (tr-show A) W)
                            (tr-print-steps Rest (+ I 1))))

(define tr-final
  E [] -> E
  E Steps -> (tr-step-after (tr-last Steps)))

(define tr-step-after [_ A _] -> A)

(define tr-last
  [S] -> S
  [_ | Rest] -> (tr-last Rest))

\\ print-expr is total over concrete exprs, but fall back to pretty-expr so a
\\ derivation never crashes on an unexpected shape.
(define tr-show
  E -> (trap-error (print-expr E) (/. Err (pretty-expr E))))

\\ ===========================================================================
\\ Annotation layer: name the rule / built-in that fired.
\\ ===========================================================================
(define canon-why -> "canonical reorder / flatten")

\\ --- built-ins: which hook fired on this (already canon) node ---
(define tr-builtin-label
  [H | Args] -> (if (= (num-builtin H Args) [none])
                    (calc-builtin-label H Args)
                    "arithmetic (numeric fold)")
  _ -> "built-in")

(define calc-builtin-label
  H Args -> (calc-label-name (tr-head-name H)))

(define calc-label-name
  "Simplify"      -> "Simplify (collect like terms)"
  "Expand"        -> "Expand (polynomial normal form)"
  "Integrate"     -> "Integrate (pull-out / u-sub / by-parts / table)"
  "Factor"        -> "Factor"
  "Cancel"        -> "Cancel"
  "Together"      -> "Together"
  "PolynomialGCD" -> "PolynomialGCD"
  "Solve"         -> "Solve"
  "Series"        -> "Series (Taylor)"
  "Limit"         -> "Limit"
  "SameQ"         -> "SameQ (predicate)"
  "UnsameQ"       -> "UnsameQ (predicate)"
  "FreeQ"         -> "FreeQ (predicate)"
  "NumberQ"       -> "NumberQ (predicate)"
  "Positive"      -> "Positive (predicate)"
  "PolynomialQ"   -> "PolynomialQ (predicate)"
  "And"           -> "And (predicate)"
  _               -> "built-in")

(define tr-head-name
  H -> (if (sym? H) (str (sym-name H)) ""))

\\ --- rules: classify by the (guard-peeled) LHS structure ---
(define rule-why
  R -> (rule-why-pattern (lhs-dispatch-pattern (rule-lhs R)) (rule-rhs R)))

(define rule-why-pattern
  [H | Args] RHS -> (if (sym? H)
                        (why-by-head (str (sym-name H)) Args RHS)
                        "rewrite rule")
  _ RHS -> "rewrite rule")

(define why-by-head
  "D" Args RHS -> (d-operand-label (tr-first-arg Args) RHS)
  "Integrate" Args RHS -> (i-operand-label (tr-first-arg Args) RHS)
  Name Args RHS -> (algebra-label Name))

(define tr-first-arg
  [A | _] -> A
  _ -> [none])

\\ identity / simplify rules from boot/arith + boot/simplify
(define algebra-label
  "Plus"  -> "Plus identity / fold"
  "Times" -> "Times identity / fold"
  "Power" -> "Power identity (x^1, x^0, ...)"
  Name    -> (@s Name (@s " " "rule")))

\\ --- differentiation rule labels ---
\\ A bare named/blank operand is the generic D[a,x] rule (identity vs constant,
\\ told apart by the RHS: 1 vs 0). A compound operand is classified by its head.
(define d-operand-label
  Operand RHS -> (if (tr-bare-operand? Operand)
                     (d-generic-label RHS)
                     (d-head-label (tr-operand-head Operand))))

(define tr-bare-operand?
  P -> (or (named? P) (blank? P)))

(define tr-operand-head
  [H | _] -> (if (sym? H) (str (sym-name H)) "")
  _ -> "")

(define d-generic-label
  [int 1] -> "variable rule: d/dx x = 1"
  [int 0] -> "constant rule: d/dx c = 0"
  _       -> "differentiation rule")

(define d-head-label
  "Plus"   -> "sum rule (linearity)"
  "Times"  -> "product rule"
  "Power"  -> "power rule (chain-aware)"
  "Divide" -> "quotient rule (via a*b^-1)"
  "Sin"    -> "chain rule: d/dx Sin = Cos . u'"
  "Cos"    -> "chain rule: d/dx Cos = -Sin . u'"
  "Tan"    -> "chain rule: d/dx Tan = Sec^2 . u'"
  "Sec"    -> "chain rule: d/dx Sec = Sec Tan . u'"
  "Exp"    -> "chain rule: d/dx Exp = Exp . u'"
  "Log"    -> "chain rule: d/dx Log = u'/u"
  "Sqrt"   -> "sqrt rule (via power rule)"
  "ArcTan" -> "inverse-trig rule: d/dx ArcTan"
  "ArcSin" -> "inverse-trig rule: d/dx ArcSin"
  "ArcCos" -> "inverse-trig rule: d/dx ArcCos"
  _        -> "differentiation rule")

\\ --- integration rule labels ---
(define i-operand-label
  Operand RHS -> (if (tr-bare-operand? Operand)
                     (i-generic-label RHS)
                     (i-head-label (tr-operand-head Operand) Operand)))

(define i-head-label
  "Power" Operand -> (if (tr-recip-power? Operand)
                         "log rule: int x^-1 dx = Log[x]"
                         "power rule: int x^n dx = x^(n+1)/(n+1)")
  "Plus"  Operand -> "linearity (integrate term by term)"
  "Times" Operand -> "constant-factor pull-out"
  "Sin"   Operand -> "antiderivative table: int Sin = -Cos"
  "Cos"   Operand -> "antiderivative table: int Cos = Sin"
  "Exp"   Operand -> "antiderivative table: int Exp = Exp"
  _       Operand -> "integration rule")

\\ Power operand with a literal -1 exponent -> the log rule (Power[u,-1]).
(define tr-recip-power?
  [_ _ [int -1]] -> true
  _ -> false)

(define i-generic-label
  RHS -> (if (tr-half-square? RHS)
             "base case: int x dx = x^2/2"
             "constant rule: int c dx = c*x"))

\\ recognise the x^2/2 RHS shape (Times[Power[x,2], 1/2], any factor order).
(define tr-half-square?
  [_ | Factors] -> (tr-has-rat-1-2? Factors)
  _ -> false)

(define tr-has-rat-1-2?
  [] -> false
  [[rat 1 2] | _] -> true
  [_ | Fs] -> (tr-has-rat-1-2? Fs))

(output "trace.shen loaded (reduce-trace / derive: step-by-step derivations).~%")
