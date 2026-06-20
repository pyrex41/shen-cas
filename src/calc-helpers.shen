\\ calc-helpers.shen - wired predicates + structural helpers for guarded
\\ calculus rules (SCUD 18c). Loaded BEFORE core.shen (so core's arithmetic /
\\ predicate hook can call calc-builtin) but AFTER match/store (uses content-eq,
\\ free-symbols-style walks, sym?/sym-name).
\\
\\ Wired predicates SameQ / UnsameQ / FreeQ / NumberQ reduce to [sym True] /
\\ [sym False]. free-of? is the structural walk underlying FreeQ.
\\
\\ These are kernel built-ins (not register-rule rules): the evaluator's
\\ try-builtin hook consults calc-builtin after num-builtin and before user
\\ DownValues, so guards in condition/ptest see them reduced.

\\ --- truth constructors (canonical interned exprs) ---
(define calc-true -> [sym (protect True)])
(define calc-false -> [sym (protect False)])

(define bool->expr
  true -> (calc-true)
  false -> (calc-false))

\\ --- structural independence: does Var (a [sym S]) occur free in E? ---
\\ free-of? E Var = true when Var does NOT appear anywhere in E.
(define occurs-in?
  Var Var -> true
  Var [sym S] -> false
  Var [int N] -> false
  Var [rat N D] -> false
  Var [H | Args] -> (if (occurs-in? Var H)
                        true
                        (occurs-in-list? Var Args))
  Var _ -> false)

(define occurs-in-list?
  Var [] -> false
  Var [X | Xs] -> (if (occurs-in? Var X) true (occurs-in-list? Var Xs)))

(define free-of?
  E Var -> (not (occurs-in? Var E)))

\\ --- NumberQ: integer or rational literal ---
(define number-expr?
  [int N] -> (number? N)
  [rat N D] -> (and (number? N) (number? D))
  _ -> false)

\\ --- calc-builtin: the evaluator hook ---
\\ Returns [some Result] / [none] so the evaluator can fall through to user
\\ rules. Dispatch on the head symbol NAME (str) so it is robust to interning.
(define calc-builtin
  [sym S] Args -> (calc-by-name (str S) Args)
  _ _ -> [none])

\\ --- Positive: positive numeric literal (after make-rat, rat denom is positive) ---
(define positive-expr?
  [int N] -> (> N 0) where (number? N)
  [rat N D] -> (> N 0) where (and (number? N) (number? D))
  _ -> false)

(define calc-by-name
  "SameQ"    [A B] -> [some (bool->expr (content-eq A B))]
  "UnsameQ"  [A B] -> [some (bool->expr (not (content-eq A B)))]
  "FreeQ"    [E V] -> [some (bool->expr (free-of? E V))]
  "NumberQ"  [E]   -> [some (bool->expr (number-expr? E))]
  "Positive" [E]   -> [some (bool->expr (positive-expr? E))]
  "And"      Args  -> [some (bool->expr (all-true? Args))]
  "Simplify" [E]   -> [some (collect-like-terms E)]
  \\ SCUD 17 Wave B: polynomial normal form + PolynomialQ (src/poly.shen).
  "Expand"      [E]   -> [some (poly-expand E)]
  "PolynomialQ" [E V] -> [some (bool->expr (polynomial-q? E V))]
  \\ SCUD 18 Wave C: univariate polynomial algebra over Q (src/polyalg.shen).
  \\ Each declines ([none]) -> the head stays inert -- when multivariate, not a
  \\ rational function, on int64 overflow, or if a self-check (divisibility /
  \\ Expand round-trip) fails. SOUND > COMPLETE.
  "PolynomialGCD" [A B] -> (poly-gcd-builtin A B)
  "Cancel"        [E]   -> (cancel-builtin E)
  "Together"      [E]   -> (together-builtin E)
  "Factor"        [P]   -> (factor-builtin P)
  \\ SCUD 19 Wave D: Solve polynomial equations in one variable over Q
  \\ (src/solve.shen). Declines ([none]) -> the head stays inert -- when
  \\ multivariate / symbolic-coefficient, the equation is identically zero, or a
  \\ root fails the substitute-back soundness gate. SOUND > COMPLETE.
  "Solve"         [E V] -> (solve-builtin E V)
  \\ SCUD 21: by-parts is consulted ONLY for the narrow product shape; it
  \\ declines ([none]) for everything else so the integration rule library and
  \\ the inert fall-through handle the rest. It runs before user rules but
  \\ ibp's whitelist guarantees it only ever fires on Times[poly, {Sin|Cos|Exp}].
  "Integrate" [Integrand V] -> (integrate-wired Integrand V)
  \\ SCUD 20 Wave E: Taylor Series + Limit (src/series.shen). Series accepts the
  \\ 3-arg (about 0) and 4-arg (about V0) forms; Limit is 3-arg. Each declines
  \\ ([none]) -> the head stays inert when a coefficient cannot be evaluated to a
  \\ number at the point, on int64 overflow, or when a limit is not justified by
  \\ substitution / terminating L'Hopital. SOUND > COMPLETE.
  "Series" Args -> (series-builtin Args)
  "Limit"  Args -> (limit-builtin Args)
  \\ Elementary & number-theory function layer (src/numfun.shen). Each declines
  \\ ([none]) -> the head stays inert when the argument is symbolic / outside the
  \\ exact numeric domain / on int64 overflow. SOUND > COMPLETE.
  "Abs"            [E]   -> (nf-abs E)
  "Sign"           [E]   -> (nf-sign E)
  "Floor"          [E]   -> (nf-floor E)
  "Ceiling"        [E]   -> (nf-ceiling E)
  "Round"          [E]   -> (nf-round E)
  "IntegerPart"    [E]   -> (nf-intpart E)
  "FractionalPart" [E]   -> (nf-fracpart E)
  "Mod"            [A B] -> (nf-mod A B)
  "Quotient"       [A B] -> (nf-quotient A B)
  "GCD"            Args  -> (nf-gcd Args)
  "LCM"            Args  -> (nf-lcm Args)
  "Factorial"      [E]   -> (nf-factorial E)
  "Binomial"       [A B] -> (nf-binomial A B)
  "Max"            Args  -> (nf-max Args)
  "Min"            Args  -> (nf-min Args)
  \\ Number theory (src/numfun.shen): decidable integer predicates + bounded
  \\ primality / sequences. Decline ([none]) -> inert outside the integer domain,
  \\ on int64 overflow, or beyond the trial bound. SOUND > COMPLETE.
  "EvenQ"     [E]     -> (nf-evenq E)
  "OddQ"      [E]     -> (nf-oddq E)
  "Divisible" [A B]   -> (nf-divisible A B)
  "CoprimeQ"  [A B]   -> (nf-coprimeq A B)
  "PrimeQ"    [E]     -> (nf-primeq E)
  "NextPrime" [E]     -> (nf-nextprime E)
  "Prime"     [E]     -> (nf-prime E)
  "Fibonacci" [E]     -> (nf-fibonacci E)
  "PowerMod"  [A B M] -> (nf-powermod A B M)
  _ _ -> [none])

\\ SCUD 21 wired Integrate dispatch: position-independent constant-factor
\\ pull-out FIRST (Times is Orderless, so a constant may sit anywhere after the
\\ canonical sort -- a positional rule cannot reliably catch it), then by-parts.
\\ Both decline ([none]) outside their narrow sound shapes -> rule library / inert.
(define integrate-wired
  Integrand V -> (let P (integrate-pullout Integrand V)
                      (if (= P [none])
                          (integrate-after-pullout Integrand V)
                          P)))

(define integrate-after-pullout
  Integrand V -> (let U (integrate-linear-usub Integrand V)
                      (if (= U [none])
                          (integrate-after-usub Integrand V)
                          U)))

(define integrate-after-usub
  Integrand V -> (let T (integrate-table Integrand V)
                      (if (= T [none])
                          (integrate-after-table Integrand V)
                          T)))

(define integrate-after-table
  Integrand V -> (let R (integrate-rational Integrand V)
                      (if (= R [none])
                          (integrate-by-parts Integrand V)
                          R)))

\\ ============================================================================
\\ Rational-function integration (Wave 4). Two sound strategies for a Divide[N,D]
\\ integrand, consulted after the antiderivative table and before by-parts:
\\
\\   (1) Cancel-then-integrate: reduce N/D to lowest terms (polyalg Cancel) and,
\\       if it changed, integrate the simpler form through the full evaluator.
\\       Re-routes e.g. (x+1)/(x^2-1) -> 1/(x-1) -> Log[x-1]. Committed only when
\\       the re-integration fully resolves (no residual Integrate head).
\\
\\   (2) Quadratic denominator (deg_V D = 2, deg_V N <= 1):
\\        - discriminant < 0 (irreducible): complete the square ->
\\            (n1/2a) Log[D] + ((n0 - n1 b/2a)/(a k)) ArcTan[(x + b/2a)/k],  k=Sqrt[(4ac-b^2)/4a^2]
\\          (a standard exact identity; spot-checked by the test corpus).
\\        - two distinct rational roots: cover-up partial fractions ->
\\            A1 Log[x-r1] + A2 Log[x-r2],  Ai = N(ri)/D'(ri)
\\          VERIFIED un-foolably: N == a*(A1 (x-r2) + A2 (x-r1)) as polynomials.
\\
\\ Anything outside these shapes declines ([none]) -> by-parts / inert. Built on
\\ polyalg (expr->coeffs/vec-eval/vec-deriv/coeffs->expr/rational-roots, all live
\\ by reduce time) and the num tower.
\\ ============================================================================
(define ct-divide -> [sym (protect Divide)])
(define ct-log    -> [sym (protect Log)])
(define ct-arctan -> [sym (protect ArcTan)])
(define ct-sqrt   -> [sym (protect Sqrt)])

(define integrate-rational
  [[sym S] N D] V -> (if (= (str S) "Divide") (irat-divide N D V) [none])
  _ _ -> [none])

(define irat-divide
  N D V -> (irat-try-cancel N D V (cancel-builtin [(ct-divide) N D])))

(define irat-try-cancel
  N D V [some Res] -> (if (content-eq Res [(ct-divide) N D])
                          (irat-quadratic N D V)
                          (irat-after-cancel Res N D V))
  N D V _ -> (irat-quadratic N D V))

(define irat-after-cancel
  Res N D V -> (let R (normal-form [[sym (protect Integrate)] Res V])
                   (if (has-integrate-head? R)
                       (irat-quadratic N D V)
                       [some R])))

\\ 0-indexed nth coeff (default [int 0] past the end).
(define irat-nth
  [] _ -> [int 0]
  [X | _] 0 -> X
  [_ | Xs] I -> (irat-nth Xs (- I 1)))

(define irat-neg? E -> (< (rat-num (as-rat E)) 0))

(define irat-quadratic
  N D V -> (irat-q1 N D V (expr->coeffs V D)))

(define irat-q1
  N D V [some Dv0] -> (irat-q2 N D V (trim-coeffs Dv0))
  N D V _ -> [none])

(define irat-q2
  N D V Dv -> (if (= (coeffs-deg Dv) 2) (irat-q3 N D V Dv (expr->coeffs V N)) [none]))

(define irat-q3
  N D V Dv [some Nv0] -> (irat-q4 D V Dv (trim-coeffs Nv0))
  N D V Dv _ -> [none])

(define irat-q4
  D V Dv Nv -> (if (> (coeffs-deg Nv) 1) [none] (irat-q5 D V Dv Nv)))

(define irat-q5
  D V Dv Nv -> (let A (irat-nth Dv 2)
                    B (irat-nth Dv 1)
                    C (irat-nth Dv 0)
                    Disc (num-sub (num-mul B B) (num-mul [int 4] (num-mul A C)))
                    (if (irat-neg? Disc)
                        (irat-arctan D V A B C Nv)
                        (irat-twolog D V Dv Nv))))

\\ --- irreducible quadratic -> Log + ArcTan (complete the square) ---
(define irat-arctan
  D V A B C Nv -> (let TwoA (num-mul [int 2] A)
                       N0 (irat-nth Nv 0)
                       N1 (irat-nth Nv 1)
                       H (num-div B TwoA)
                       LogCoeff (num-div N1 TwoA)
                       ArcRat (num-div (num-sub N0 (num-mul N1 H)) A)
                       MNum (num-sub (num-mul [int 4] (num-mul A C)) (num-mul B B))
                       MDen (num-mul [int 4] (num-mul A A))
                       M (num-div MNum MDen)
                       K [(ct-sqrt) M]
                       Kinv [(ct-power) K [int -1]]
                       Arg [(ct-times) [(ct-plus) V H] Kinv]
                       ArcTerm [(ct-times) ArcRat Kinv [(ct-arctan) Arg]]
                       LogTerm [(ct-times) LogCoeff [(ct-log) D]]
                       [some (normal-form [(ct-plus) LogTerm ArcTerm])]))

\\ --- two distinct rational roots -> cover-up partial fractions (2 logs) ---
(define irat-twolog
  D V Dv Nv -> (irat-twolog-r V Dv Nv (rational-roots Dv)))

(define irat-twolog-r
  V Dv Nv [R1 R2] -> (if (num-eq? R1 R2) [none] (irat-twolog-cv V Dv Nv R1 R2))
  V Dv Nv _ -> [none])

(define irat-twolog-cv
  V Dv Nv R1 R2 -> (let A (irat-nth Dv 2)
                        Dp (vec-deriv Dv)
                        A1 (num-div (vec-eval Nv R1) (vec-eval Dp R1))
                        A2 (num-div (vec-eval Nv R2) (vec-eval Dp R2))
                        Cand [(ct-plus) [(ct-times) A1 [(ct-log) (irat-linsub V R1)]]
                                        [(ct-times) A2 [(ct-log) (irat-linsub V R2)]]]
                        (if (irat-twolog-ok? Nv A A1 A2 R1 R2)
                            [some (normal-form Cand)]
                            [none])))

\\ (x - R) as an expr.
(define irat-linsub
  V R -> (coeffs->expr V [(num-mul [int -1] R) [int 1]]))

\\ un-foolable check: N == a*(A1 (x-R2) + A2 (x-R1)) as polynomials.
(define irat-twolog-ok?
  Nv A A1 A2 R1 R2 -> (let LV1 [(num-mul [int -1] R2) [int 1]]
                           LV2 [(num-mul [int -1] R1) [int 1]]
                           RHS (vec-scale A (vec-add (vec-scale A1 LV1) (vec-scale A2 LV2)))
                           (irat-vec-eq? (trim-coeffs RHS) (trim-coeffs Nv))))

(define irat-vec-eq?
  [] [] -> true
  [X | Xs] [Y | Ys] -> (if (num-eq? X Y) (irat-vec-eq? Xs Ys) false)
  _ _ -> false)

\\ Wired antiderivative table for forms a positional AC rule cannot match because
\\ of the orderless canonical ordering of the inner Plus. Detection via expr->coeffs
\\ (degree-indexed, order-independent). Differentiate-back verifies; declines -> [none].
\\   Integrate[1/(1+x^2), x] -> ArcTan[x]   (denominator coeff vector == [1,0,1])
(define integrate-table
  [[sym S] Num Den] V -> (itable-divide (str S) Num Den V)
  _ _ -> [none])

(define itable-divide
  "Divide" Num Den V -> (itable-on-divide Num Den V)
  _ _ _ _ -> [none])

\\ 1/Den: ArcTan if Den == 1+x^2, else (1/a)Log[Den] if Den is linear.
\\ Num/Den (general): c*Log[Den] when Num is a numeric multiple of Den' (u'/u form).
(define itable-on-divide
  [int 1] Den V -> (itable-recip Den V (expr->coeffs V Den))
  Num Den V -> (itable-logderiv Num Den V))

(define itable-recip
  Den V [some [B Z A]] -> (if (one-zero-one? B Z A)
                              [some [[sym (protect ArcTan)] V]]
                              [none])
  Den V [some [B A]] -> [some [(ct-times) [(ct-power) A [int -1]] [[sym (protect Log)] Den]]]
  Den V _ -> [none])

(define one-zero-one?
  B Z A -> (if (content-eq B [int 1])
               (if (content-eq Z [int 0]) (content-eq A [int 1]) false)
               false))

\\ log-derivative: Integrate[Num/Den, x] -> c*Log[Den] when Num == c*Den' (c numeric).
(define itable-logderiv
  Num Den V -> (itable-logderiv-2 Num Den V (expr->coeffs V Num)
                                  (expr->coeffs V (reduce [[sym (protect D)] Den V]))))

(define itable-logderiv-2
  Num Den V [some NV] [some DV] -> (itable-logderiv-3 Den (vec-ratio NV DV))
  Num Den V _ _ -> [none])

(define itable-logderiv-3
  Den [some C] -> [some [(ct-times) C [[sym (protect Log)] Den]]]
  Den _ -> [none])

\\ vec-ratio NumV DpV -> [some c] if NumV == c*DpV elementwise (c numeric), else [none].
\\ Trimmed coeff vectors have a nonzero leading entry, so same degree => same length.
(define vec-ratio
  NumV DpV -> (if (= (length NumV) (length DpV))
                  (vr-check-ratio NumV DpV (num-div (vr-last NumV) (vr-last DpV)))
                  [none]))

(define vr-last
  [X] -> X
  [_ | Xs] -> (vr-last Xs))

(define vr-check-ratio
  NumV DpV C -> (if (vr-elementwise? NumV DpV C) [some C] [none]))

(define vr-elementwise?
  [] [] _ -> true
  [N | Ns] [D | Ds] C -> (if (num-eq? N (num-mul C D)) (vr-elementwise? Ns Ds C) false)
  _ _ _ -> false)

\\ Linear-argument u-substitution for Sin/Cos/Exp: Integrate[g[a*x+b], x] where
\\ the argument is linear in V. The linear coeffs are read off via polyalg's
\\ expr->coeffs (so it is robust to the orderless canonical ordering of the inner
\\ Plus -- a positional AC rule cannot match the hash-sorted form). expr->coeffs
\\ declines (-> [none]) on any non-V generator, so symbolic coefficients stay
\\ inert. Sound: a,b are genuine numeric coeffs; differentiate-back verifies.
(define integrate-linear-usub
  [[sym S] Arg] V -> (lusub-by-name (str S) Arg V)
  _ _ -> [none])

(define lusub-by-name
  "Sin"  Arg V -> (lusub-emit "Sin" Arg V)
  "Cos"  Arg V -> (lusub-emit "Cos" Arg V)
  "Exp"  Arg V -> (lusub-emit "Exp" Arg V)
  "Sinh" Arg V -> (lusub-emit "Sinh" Arg V)
  "Cosh" Arg V -> (lusub-emit "Cosh" Arg V)
  _ _ _ -> [none])

(define lusub-emit
  Name Arg V -> (lusub-on-coeffs Name Arg (expr->coeffs V Arg)))

\\ fires ONLY for a degree-1 argument: coeff vector is exactly [b a] (a = leading,
\\ guaranteed nonzero). Degree 0 (constant arg) and degree >=2 -> decline.
(define lusub-on-coeffs
  Name Arg [some [B A]] -> [some (lusub-form Name Arg A)]
  Name Arg _ -> [none])

\\ (1/a) * G[arg], G the bare antiderivative: Sin->-Cos, Cos->Sin, Exp->Exp.
(define lusub-form
  "Sin"  Arg A -> [(ct-times) [int -1] [(ct-power) A [int -1]] [[sym (protect Cos)] Arg]]
  "Cos"  Arg A -> [(ct-times) [(ct-power) A [int -1]] [[sym (protect Sin)] Arg]]
  "Exp"  Arg A -> [(ct-times) [(ct-power) A [int -1]] [[sym (protect Exp)] Arg]]
  "Sinh" Arg A -> [(ct-times) [(ct-power) A [int -1]] [[sym (protect Cosh)] Arg]]
  "Cosh" Arg A -> [(ct-times) [(ct-power) A [int -1]] [[sym (protect Sinh)] Arg]])

\\ constant-factor pull-out: partition a Times integrand into the product of
\\ x-free factors (Const) and the x-dependent rest (Rest). Fires only when there
\\ is at least one x-free factor AND at least one x-dependent factor (so it makes
\\ progress and never loops). Sound: Const is genuinely free of V.
\\   Integrate[Times[..],V] -> Const * Integrate[Times[Rest..],V]
(define integrate-pullout
  [[sym S] | Factors] V -> (integrate-pullout-times (str S) Factors V)
  _ _ -> [none])

(define integrate-pullout-times
  "Times" Factors V -> (pullout-build (partition-free V Factors [] []) V)
  _ _ _ -> [none])

\\ partition-free V Factors FreeAcc DepAcc -> [FreeFactors DepFactors] (order kept)
(define partition-free
  V [] FreeAcc DepAcc -> [(reverse FreeAcc) (reverse DepAcc)]
  V [F | Fs] FreeAcc DepAcc -> (if (free-of? F V)
                                   (partition-free V Fs [F | FreeAcc] DepAcc)
                                   (partition-free V Fs FreeAcc [F | DepAcc])))

(define pullout-build
  [Free Dep] V -> (if (or (empty? Free) (empty? Dep))
                      [none]
                      [some [(ct-times) (ibp-times Free)
                              [[sym (protect Integrate)] (ibp-times Dep) V]]]))

\\ And: every argument must be the canonical True symbol (after arg eval).
(define true-expr?
  [sym S] -> (= S (protect True))
  _ -> false)

(define all-true?
  [] -> true
  [A | As] -> (if (true-expr? A) (all-true? As) false))

\\ ============================================================================
\\ SCUD 19: collect-like-terms - an AUDITED, NON-RULE, single-pass simplifier.
\\ Surfaced as the kernel-recognized Simplify head (wired here, NOT a register-
\\ rule), because like-term collection is not cleanly confluent as rewrite rules.
\\
\\ Plus:  group args by their non-coefficient part, SUMMING coefficients.
\\          Plus[Times[3,x],Times[2,x]] -> Times[5,x]
\\ Times: gather equal bases into Power, SUMMING exponents.
\\          Times[x,x] -> Power[x,2]
\\
\\ It recurses bottom-up (args first), so nested sub-expressions are collected
\\ before their parent. Numeric literals are folded via the Wave-1 num layer.
\\ ============================================================================

(define ct-plus -> [sym (protect Plus)])
(define ct-times -> [sym (protect Times)])
(define ct-power -> [sym (protect Power)])

(define plus-head?   [sym S] -> (= (str S) "Plus")   _ -> false)
(define times-head?  [sym S] -> (= (str S) "Times")  _ -> false)
(define power-head?  [sym S] -> (= (str S) "Power")  _ -> false)
(define divide-head? [sym S] -> (= (str S) "Divide") _ -> false)

\\ top-level dispatch: recurse into args, then collect at this node.
\\ Divide[a,b] is normalized to Times[a, Power[b,-1]] FIRST so that a rational
\\ written with the Divide head and the same quantity written as a negative power
\\ collapse together -- this is what lets differentiate-back verify integrals
\\ whose integrand is a Divide but whose D-image is a Power[.,-1] (e.g. ArcTan,
\\ Log). Scoped to Simplify; the global evaluator/printer keep the Divide head.
(define collect-like-terms
  [sym S] -> [sym S]
  [int N] -> [int N]
  [rat N D] -> [rat N D]
  [H A B] -> (collect-like-terms [(ct-times) A [(ct-power) B [int -1]]]) where (divide-head? H)
  [H | Args] -> (collect-node H (map (/. A (collect-like-terms A)) Args))
  E -> E)

(define collect-node
  H Args -> (if (plus-head? H)
                (collect-plus Args)
                (if (times-head? H)
                    (collect-times-node Args)
                    [H | Args])))

\\ Times node: if any factor is a Plus, DISTRIBUTE (expand the product of sums)
\\ and re-collect the resulting Plus -- so e.g. Times[-1, Plus[a,b]] -> Plus[-a,-b]
\\ and a difference D[R,x] - f collapses cleanly. Bounded (our exprs are small).
\\ Otherwise fall through to the plain like-base Times collection.
(define collect-times-node
  Args -> (if (any-plus-factor? Args)
              (collect-like-terms (expand-product Args))
              (collect-times Args)))

(define any-plus-factor?
  [] -> false
  [F | Fs] -> (if (plus-head? (head-of F)) true (any-plus-factor? Fs)))

(define head-of
  [H | _] -> H
  _ -> [none])

\\ expand-product: distribute a list of factors (some of which are Plus) into a
\\ single Plus of product-terms (cartesian over the Plus factors).
(define expand-product
  Factors -> (let Terms (expand-factors Factors [[]])
                  [(ct-plus) | (map (/. T (ibp-times T)) Terms)]))

\\ expand-factors Factors Acc -> list of factor-lists (each a product term).
\\ Acc is the accumulated list of partial product-term factor-lists.
(define expand-factors
  [] Acc -> (reverse-each Acc)
  [F | Fs] Acc -> (expand-factors Fs (expand-one F Acc)))

\\ multiply factor F into every partial term; a Plus factor branches each term
\\ into one per addend.
(define expand-one
  [H | Addends] Acc -> (cartesian-plus Addends Acc) where (plus-head? H)
  F Acc -> (map (/. T [F | T]) Acc))

(define cartesian-plus
  Addends Acc -> (cartesian-loop Addends Acc []))

(define cartesian-loop
  [] _ Out -> Out
  [A | As] Acc Out -> (cartesian-loop As Acc (append Out (map (/. T [A | T]) Acc))))

(define reverse-each
  [] -> []
  [T | Ts] -> [(reverse T) | (reverse-each Ts)])

\\ -------------------- Plus: group by base, sum coefficients --------------------
\\ Each addend -> [Coeff Base]; pure-numeric addends use the sentinel base
\\ [int 1] (so they fold together via Times[c,1] -> c on rebuild).
\\ split a Times addend into (numeric coeff, base) folding ALL numeric factors
\\ (robust to Orderless arg order: the constant need not be first).
(define addend-coeff-base
  [int N] -> [[int N] [int 1]]
  [rat N D] -> [[rat N D] [int 1]]
  [H | Factors] -> (acb-times Factors) where (times-head? H)
  T -> [[int 1] T])

(define acb-times
  Factors -> (let Parts (split-num-factors Factors [int 1] [])
                  Coeff (hd Parts)
                  Syms (hd (tl Parts))
                  [Coeff (times-rest-as-expr Syms)]))

\\ rebuild the non-coefficient factor list as a single expr (Times[..] / single).
(define times-rest-as-expr
  [] -> [int 1]
  [X] -> X
  Xs -> [(ct-times) | Xs])

\\ accumulate (base, summed-coeff) groups in order of first appearance.
(define plus-groups
  [] Acc -> Acc
  [T | Ts] Acc -> (plus-groups Ts (plus-add-group (addend-coeff-base T) Acc)))

(define plus-add-group
  [C B] [] -> [[C B]]
  [C B] [[C2 B2] | Rest] -> (if (content-eq B B2)
                                [[(num-sum-2 C C2) B2] | Rest]
                                [[C2 B2] | (plus-add-group [C B] Rest)]))

(define num-sum-2
  A B -> (num-add A B))

\\ rebuild each group into an addend, drop zero coefficients, re-Plus.
(define group->addend
  [C [int 1]] -> C
  [C B] -> (if (num-eq? C [int 0])
               [int 0]
               (if (num-eq? C [int 1])
                   B
                   [(ct-times) C B])))

(define zero-expr?
  A -> (if (number-expr? A) (num-eq? A [int 0]) false))

(define drop-zeros
  [] -> []
  [A | As] -> (if (zero-expr? A) (drop-zeros As) [A | (drop-zeros As)]))

\\ flatten nested Plus addends (Plus is Flat) before grouping, so a distributed
\\ sub-Plus (e.g. from expand-product) merges into the enclosing sum.
(define flatten-plus-args
  [] -> []
  [A | As] -> (append (flatten-plus-arg A) (flatten-plus-args As)))

(define flatten-plus-arg
  [H | Inner] -> (flatten-plus-args Inner) where (plus-head? H)
  A -> [A])

(define collect-plus
  Args0 -> (let Args (flatten-plus-args Args0)
                Groups (plus-groups Args [])
               Addends (drop-zeros (map (/. G (group->addend G)) Groups))
               (rebuild-nary (ct-plus) Addends [int 0])))

\\ -------------------- Times: gather equal bases into Power ---------------------
\\ Each factor -> [Base Exp]; a Power[b,e] factor contributes (b,e), else (f,1).
(define factor-base-exp
  [int N] -> [[int N] [int 1]]
  [rat N D] -> [[rat N D] [int 1]]
  [H B E] -> (if (and (power-head? H) (number-expr? E)) [B E] [[H B E] [int 1]])
  F -> [F [int 1]])

(define times-groups
  [] Acc -> Acc
  [F | Fs] Acc -> (times-groups Fs (times-add-group (factor-base-exp F) Acc)))

(define times-add-group
  [B E] [] -> [[B E]]
  [B E] [[B2 E2] | Rest] -> (if (content-eq B B2)
                                [[B2 (num-add E E2)] | Rest]
                                [[B2 E2] | (times-add-group [B E] Rest)]))

(define group->factor
  [B E] -> (if (num-eq? E [int 1]) B [(ct-power) B E]))

\\ partition factors into (numeric-product, symbolic-factor-list): pure numeric
\\ factors fold via num-prod (so literal 1s vanish and constants combine), the
\\ rest are grouped by base into Powers.
(define split-num-factors
  [] Acc Syms -> [Acc (reverse Syms)]
  [F | Fs] Acc Syms -> (if (number-expr? F)
                           (split-num-factors Fs (num-mul Acc F) Syms)
                           (split-num-factors Fs Acc [F | Syms])))

\\ flatten nested Times factors (Times is Flat) before grouping, so a nested
\\ product (e.g. from distribution) folds its numeric factors with the rest.
(define flatten-times-args
  [] -> []
  [A | As] -> (append (flatten-times-arg A) (flatten-times-args As)))

(define flatten-times-arg
  [H | Inner] -> (flatten-times-args Inner) where (times-head? H)
  A -> [A])

(define collect-times
  Args0 -> (let Args (flatten-times-args Args0)
               Parts (split-num-factors Args [int 1] [])
               Coeff (hd Parts)
               Syms (hd (tl Parts))
               Groups (times-groups Syms [])
               Factors (map (/. G (group->factor G)) Groups)
               (collect-times-rebuild Coeff Factors)))

\\ if coeff is 0 -> 0; if 1 -> just the symbolic factors; else prepend coeff.
(define collect-times-rebuild
  Coeff Factors -> (if (num-eq? Coeff [int 0])
                       [int 0]
                       (if (num-eq? Coeff [int 1])
                           (rebuild-nary (ct-times) Factors [int 1])
                           (rebuild-nary (ct-times) [Coeff | Factors] [int 1]))))

\\ rebuild an n-ary head: 0 args -> Identity, 1 arg -> the arg, else [H | args].
(define rebuild-nary
  H [] Identity -> Identity
  H [X] _ -> X
  H Args _ -> [H | Args])

\\ ============================================================================
\\ SCUD 21 Wave 5: integration-by-parts as a DEPTH-LIMITED wired helper.
\\
\\ Principle (sound or inert): integrate-by-parts is whitelisted to the narrow
\\ shape Integrate[Times[poly(x), g], x] where g is one of Sin[x] / Cos[x] /
\\ Exp[x] over the BARE variable x. It applies the by-parts identity
\\   ∫ u dv = u v - ∫ v du           (u = poly, dv = g dx)
\\ recursively (max depth ~3). It COMMITS the result ONLY IF the sub-integral
\\ ∫ v du fully resolves (the reduced form contains NO residual Integrate head);
\\ otherwise it returns [none] and the expression stays INERT. It never returns
\\ a wrong answer.
\\
\\ Wired (not register-rule) because the recursion + the "fully resolved" commit
\\ check are procedural. It is consulted from calc-by-name for the Integrate
\\ head, AFTER num/predicate builtins and only for this exact shape (declines to
\\ [none] for everything else so the rule library / inert path takes over).
\\ ============================================================================

(define ibp-max-depth -> 3)

\\ antiderivative (over var) of a bare elementary g[var]: returns [some V] / [none]
\\ (sound table only). g must be Sin/Cos/Exp applied to exactly the variable.
(define ibp-antideriv
  [sym S] V [Arg] -> (ibp-antideriv-by-name (str S) V Arg)
  _ _ _ -> [none])

(define ibp-antideriv-by-name
  "Sin" V Arg -> (if (content-eq Arg V)
                     [some [(ct-times) [int -1] [[sym (protect Cos)] Arg]]]
                     [none])
  "Cos" V Arg -> (if (content-eq Arg V) [some [[sym (protect Sin)] Arg]] [none])
  "Exp" V Arg -> (if (content-eq Arg V) [some [[sym (protect Exp)] Arg]] [none])
  _ _ _ -> [none])

\\ recognize a g-factor (Sin/Cos/Exp of bare var) inside a product: returns
\\ [some [Gfactor PolyFactors]] splitting the product, or [none].
(define ibp-split-product
  V Factors -> (ibp-split-loop V Factors []))

(define ibp-split-loop
  V [] _ -> [none]
  V [F | Fs] Seen -> (if (ibp-g-factor? V F)
                         [some [F (append (reverse Seen) Fs)]]
                         (ibp-split-loop V Fs [F | Seen])))

(define ibp-g-factor?
  V [[sym S] Arg] -> (and (ibp-table-name? (str S)) (content-eq Arg V))
  _ _ -> false)

(define ibp-table-name?
  "Sin" -> true
  "Cos" -> true
  "Exp" -> true
  _ -> false)

\\ poly-in-var? : whitelist the u-factor to a polynomial in V (so by-parts
\\ strictly lowers the polynomial degree and terminates): V itself, Power[V,k]
\\ with numeric k, numeric literal, or a Times/Plus of such.
(define poly-in-var?
  V V -> true
  V [int _] -> true
  V [rat _ _] -> true
  V [[sym S] B E] -> (and (power-head? [sym S])
                          (and (content-eq B V) (number-expr? E)))
                     where (= (str S) "Power")
  V [[sym S] | Args] -> (poly-args? V Args)
                        where (or (= (str S) "Times") (= (str S) "Plus"))
  V _ -> false)

(define poly-args?
  V [] -> true
  V [A | As] -> (if (poly-in-var? V A) (poly-args? V As) false))

\\ build a single Times-expr from a factor list (1 -> identity, [x] -> x).
(define ibp-times
  [] -> [int 1]
  [F] -> F
  Fs -> [(ct-times) | Fs])

\\ Integrate[E,V] constructor.
(define ibp-integrate
  E V -> [[sym (protect Integrate)] E V])

\\ does E (anywhere) contain an Integrate head? (residual = unresolved)
(define has-integrate-head?
  [sym S] -> false
  [int _] -> false
  [rat _ _] -> false
  [[sym S] | Args] -> (if (= (str S) "Integrate")
                          true
                          (has-integrate-list? Args))
  [H | Args] -> (if (has-integrate-head? H) true (has-integrate-list? Args))
  _ -> false)

(define has-integrate-list?
  [] -> false
  [X | Xs] -> (if (has-integrate-head? X) true (has-integrate-list? Xs)))

\\ Top entry: try by-parts on Integrate[Integrand, V]. [some R] / [none].
(define integrate-by-parts
  Integrand V -> (ibp-attempt Integrand V (ibp-max-depth)))

(define ibp-attempt
  Integrand V 0 -> [none]
  Integrand V Depth -> (ibp-on-form Integrand V Depth))

\\ only the product form Times[..] qualifies; split into (g-factor, poly-rest).
(define ibp-on-form
  [[sym S] | Factors] V Depth -> (ibp-with-split (str S) Factors V Depth)
  _ _ _ -> [none])

(define ibp-with-split
  "Times" Factors V Depth -> (ibp-dispatch-split (ibp-split-product V Factors) V Depth)
  _ _ _ _ -> [none])

(define ibp-dispatch-split
  [none] _ _ -> [none]
  [some [G PolyFactors]] V Depth ->
    (let U (ibp-times PolyFactors)
         (if (poly-in-var? V U)
             (ibp-go U G V Depth)
             [none])))

\\ u = U (poly), dv = G dx.  v = antideriv(G);  du-integrand = v * D[U,x].
\\ result = U*v - ∫(v * D[U,x]) dx ; recurse + require full resolution.
(define ibp-go
  U [GH GArg] V Depth ->
    (ibp-build U (ibp-antideriv GH V [GArg]) V Depth)
  _ _ _ _ -> [none])

(define ibp-build
  U [none] V Depth -> [none]
  U [some Vanti] V Depth ->
    (let DU [[sym (protect D)] U V]
         SubIntegrand [(ct-times) Vanti DU]
         \\ reduce the sub-integral through the full evaluator (D + integration
         \\ rules + by-parts recursion via the Integrate head).
         Sub (normal-form (ibp-integrate SubIntegrand V))
         (if (has-integrate-head? Sub)
             [none]
             [some (collect-like-terms
                     (normal-form
                       [(ct-plus) [(ct-times) U Vanti]
                                  [(ct-times) [int -1] Sub]]))])))

(output "calc-helpers.shen loaded (SameQ/UnsameQ/FreeQ/NumberQ/Positive/And/Simplify + free-of? + collect-like-terms + integrate-by-parts).~%")
