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
  "Apart"         [E]   -> (apart-builtin E)
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

\\ Unified post-table dispatch chain (Tier 2/3). Each stage is shape-specific and
\\ self-gated (declines to [none] outside its narrow sound shape), so order among
\\ them does not affect correctness; integrate-by-parts stays the final fallback.
\\   integrate-invfun    T2.4  ∫ArcTan[x], ∫ArcSin[x]
\\   integrate-log-parts T2.2  ∫Log[x], ∫x^n Log[x]
\\   integrate-cyclic    T3.3  ∫Exp[x] Sin[x], ∫Exp[x] Cos[x]
\\   integrate-trigpow   T3.2  ∫Cos[x]^2, ∫Sin[x]^2, ∫Sec[x]^2
(define integrate-after-table
  Integrand V -> (let NP (integrate-normalpdf Integrand V)
                      (if (= NP [none])
                          (integrate-after-normalpdf Integrand V)
                          NP)))

(define integrate-after-normalpdf
  Integrand V -> (let I (integrate-invfun Integrand V)
                      (if (= I [none])
                          (integrate-after-invfun Integrand V)
                          I)))

(define integrate-after-invfun
  Integrand V -> (let L (integrate-log-parts Integrand V)
                      (if (= L [none])
                          (integrate-after-log Integrand V)
                          L)))

(define integrate-after-log
  Integrand V -> (let C (integrate-cyclic Integrand V)
                      (if (= C [none])
                          (integrate-after-cyclic Integrand V)
                          C)))

(define integrate-after-cyclic
  Integrand V -> (let P (integrate-trigpow Integrand V)
                      (if (= P [none])
                          (integrate-after-trigpow Integrand V)
                          P)))

(define integrate-after-trigpow
  Integrand V -> (let S (integrate-sincos Integrand V)
                      (if (= S [none])
                          (integrate-after-sincos Integrand V)
                          S)))

(define integrate-after-sincos
  Integrand V -> (let P (integrate-powusub Integrand V)
                      (if (= P [none])
                          (integrate-after-powusub Integrand V)
                          P)))

(define integrate-after-powusub
  Integrand V -> (let A (integrate-arcsin Integrand V)
                      (if (= A [none])
                          (integrate-after-arcsin Integrand V)
                          A)))

(define integrate-after-arcsin
  Integrand V -> (let AP (integrate-apart Integrand V)
                      (if (= AP [none])
                          (integrate-after-apart Integrand V)
                          AP)))

(define integrate-after-apart
  Integrand V -> (let Q (integrate-arctan-shift Integrand V)
                      (if (= Q [none])
                          (integrate-by-parts Integrand V)
                          Q)))

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
  "Sin" Arg V -> (lusub-emit "Sin" Arg V)
  "Cos" Arg V -> (lusub-emit "Cos" Arg V)
  "Exp" Arg V -> (lusub-emit "Exp" Arg V)
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
  "Sin" Arg A -> [(ct-times) [int -1] [(ct-power) A [int -1]] [[sym (protect Cos)] Arg]]
  "Cos" Arg A -> [(ct-times) [(ct-power) A [int -1]] [[sym (protect Sin)] Arg]]
  "Exp" Arg A -> [(ct-times) [(ct-power) A [int -1]] [[sym (protect Exp)] Arg]])

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
  [H [HB B IE] E] -> (collect-like-terms [(ct-power) B (num-mul IE E)]) where (nested-power? H HB IE E)
  [H | Args] -> (collect-node H (map (/. A (collect-like-terms A)) Args))
  E -> E)

\\ Power[Power[b,p],q] -> Power[b,p*q] ONLY when the INNER exponent p is a non-
\\ integer rational (e.g. 1/2). Then b^p already presumes the principal-root domain
\\ b>=0, so (b^p)^q = b^(p*q) is exact. This folds (x^(1/2))^-1 -> x^(-1/2) so the
\\ differentiate-back of ∫1/Sqrt[x] and ∫1/Sqrt[1-x^2] closes. It deliberately does
\\ NOT fire for an integer inner exponent: (x^2)^(1/2) = |x| is branch-unsafe and
\\ must stay inert. Outer exponent q may be any numeric literal.
(define nested-power?
  H HB IE E -> (if (power-head? H)
                   (if (power-head? HB)
                       (if (rat-expr? IE) (number-expr? E) false)
                       false)
                   false))

(define rat-expr?
  [rat N D] -> (and (number? N) (number? D))
  _ -> false)

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

\\ -------------------- Pythagorean fold: c*Sin[u]^2 + c*Cos[u]^2 -> c ----------
\\ Wired (the AC matcher cannot match the hash-sorted Plus). Operates on the
\\ collected addend list: when a Sin[u]^2 addend and a Cos[u]^2 addend share the
\\ SAME numeric coefficient c and the SAME u, replace the pair with the constant c
\\ and re-collect. The exact identity c(sin^2+cos^2)=c makes this always sound; it
\\ also closes the differentiate-back for ∫Sin^2/∫Cos^2 (T3.2). Terminates: each
\\ fold removes two trig-square addends and adds one numeric (never a trig square).
(define pyth-fold-addends
  Addends -> (let P (pyth-find-pair Addends Addends)
                  (if (= P [none])
                      Addends
                      (pyth-apply P Addends))))

\\ classify addend as c*Trig[u]^2 -> [some [c u]] / [none], via addend-coeff-base.
(define pyth-trig-term
  Name Addend -> (pyth-trig-cb Name (addend-coeff-base Addend)))

(define pyth-trig-cb
  Name [C [[sym P] [[sym F] U] E]] -> (pyth-trig-chk Name C U (str P) (str F) E)
  Name _ -> [none])

(define pyth-trig-chk
  Name C U PStr FStr E -> (if (= PStr "Power")
                              (if (= FStr Name)
                                  (if (number-expr? E)
                                      (if (num-eq? E [int 2]) [some [C U]] [none])
                                      [none])
                                  [none])
                              [none]))

(define pyth-find-pair
  [] _ -> [none]
  [A | As] All -> (pyth-find-pair-step (pyth-trig-term "Sin" A) As All))

(define pyth-find-pair-step
  [none] As All -> (pyth-find-pair As All)
  [some [C U]] As All -> (if (pyth-has-cos? C U All)
                             [some [C U]]
                             (pyth-find-pair As All)))

(define pyth-has-cos?
  C U [] -> false
  C U [A | As] -> (pyth-has-cos-step C U (pyth-trig-term "Cos" A) As))

(define pyth-has-cos-step
  C U [none] As -> (pyth-has-cos? C U As)
  C U [some [C2 U2]] As -> (if (num-eq? C C2)
                               (if (content-eq U U2) true (pyth-has-cos? C U As))
                               (pyth-has-cos? C U As)))

\\ Drop the matched pair, prepend the constant C, then RE-GROUP (so C folds with
\\ any sibling constant) and RE-FOLD (another u-pair may remain). Stays in the
\\ addend-list domain -- must return a list, not an expr.
(define pyth-apply
  [some [C U]] Addends -> (pyth-fold-addends
                            (drop-zeros
                              (map (/. G (group->addend G))
                                   (plus-groups [C | (pyth-drop "Cos" C U (pyth-drop "Sin" C U Addends))] [])))))

(define pyth-drop
  Name C U [] -> []
  Name C U [A | As] -> (pyth-drop-step Name C U A As (pyth-trig-term Name A)))

(define pyth-drop-step
  Name C U A As [none] -> [A | (pyth-drop Name C U As)]
  Name C U A As [some [C2 U2]] -> (if (num-eq? C C2)
                                      (if (content-eq U U2)
                                          As
                                          [A | (pyth-drop Name C U As)])
                                      [A | (pyth-drop Name C U As)]))

(define collect-plus
  Args0 -> (let Args (flatten-plus-args Args0)
                Groups (plus-groups Args [])
               Addends0 (drop-zeros (map (/. G (group->addend G)) Groups))
               Addends (pyth-fold-addends Addends0)
               (rat-zero-or (rebuild-nary (ct-plus) Addends [int 0]) Addends)))

\\ -------------------- rational zero-combine (diff-back closure) ---------------
\\ After like-term collection, if the rebuilt Plus still contains negative-power
\\ factors (rational structure) and is univariate, combine ALL addends over a
\\ common denominator (as coeff vectors) and -- ONLY IF the combined numerator is
\\ the zero polynomial -- return [int 0]. Otherwise return the rebuilt expr
\\ unchanged. Sound + monotonic: only a genuinely-zero rational sum is rewritten;
\\ every nonzero expression keeps its collected form. This is what lets the
\\ differentiate-back of partial-fraction / shifted-ArcTan integrals reduce to 0.
(define rat-zero-or
  Built Addends -> (if (rat-has-neg-power? Addends)
                       (rat-try-collapse Built Addends (dedup-syms (free-sym-names Built)))
                       Built))

(define rat-try-collapse
  Built Addends [Name] -> (rat-finish Built (rat-combine [sym Name] Addends))
  Built Addends _ -> Built)

(define rat-finish
  Built [some Num] -> (if (vec-zero? Num) [int 0] Built)
  Built [none] -> Built)

(define vec-zero?
  V -> (empty? (trim-coeffs V)))

\\ combine all addends into ONE fraction over a common denominator; return the
\\ numerator [some NumVec], or [none] if any addend is not univariate-rational.
(define rat-combine
  V Addends -> (rat-combine-loop V Addends [[int 0]] [[int 1]]))

(define rat-combine-loop
  V [] AccNum AccDen -> [some AccNum]
  V [A | As] AccNum AccDen -> (rat-combine-step V As AccNum AccDen (rat-addend->frac V A)))

(define rat-combine-step
  V As AccNum AccDen [some [TN TD]] -> (rat-combine-loop V As
                                          (vec-add (vec-mul AccNum TD) (vec-mul TN AccDen))
                                          (vec-mul AccDen TD))
  V As AccNum AccDen _ -> [none])

\\ addend -> [some [NumVec DenVec]] (univariate rational in V) / [none].
\\ (Named rat-addend->frac to avoid colliding with polyalg's addend->frac.)
\\ flatten-times-arg fully flattens a (possibly nested) Times into its factor list.
(define rat-addend->frac
  V A -> (af-loop V (flatten-times-arg A) [[int 1]] [[int 1]]))

(define af-loop
  V [] Num Den -> [some [Num Den]]
  V [F | Fs] Num Den -> (af-step V Fs Num Den (af-classify V F)))

(define af-step
  V Fs Num Den [0 NV] -> (af-loop V Fs (vec-mul Num NV) Den)
  V Fs Num Den [1 DV] -> (af-loop V Fs Num (vec-mul Den DV))
  V Fs Num Den _ -> [none])

\\ classify a factor: Power[poly, negative-int] -> [1 DenVec]; numeric/polynomial
\\ (incl. positive powers) -> [0 NumVec]; anything else (e.g. fractional power,
\\ transcendental) -> [none] (so the whole addend declines).
(define af-classify
  V F -> (af-class V F (af-den-of V F)))

(define af-den-of
  V [H B E] -> (af-den-pow V B E) where (power-head? H)
  V _ -> [none])

(define af-den-pow
  V B [int N] -> (if (< N 0) (af-den-raise V B (- 0 N)) [none])
  V B _ -> [none])

(define af-den-raise
  V B K -> (af-den-raise-2 (expr->coeffs V B) K))

(define af-den-raise-2
  [some BV] K -> [some (vec-pow BV K)]
  _ K -> [none])

(define af-class
  V F [some DV] -> [1 DV]
  V F _ -> (af-class-num (expr->coeffs V F)))

(define af-class-num
  [some NV] -> [0 NV]
  _ -> [none])

(define vec-pow
  BV 1 -> BV
  BV K -> (vec-mul BV (vec-pow BV (- K 1))))

(define rat-has-neg-power?
  [] -> false
  [A | As] -> (if (expr-has-neg-power? A) true (rat-has-neg-power? As)))

(define expr-has-neg-power?
  [sym _] -> false
  [int _] -> false
  [rat _ _] -> false
  [H B E] -> (rat-np-power H B E) where (power-head? H)
  [_ | Args] -> (expr-any-neg-power? Args)
  _ -> false)

(define rat-np-power
  H B E -> (if (neg-num? E) true (if (expr-has-neg-power? B) true (expr-has-neg-power? E))))

(define expr-any-neg-power?
  [] -> false
  [A | As] -> (if (expr-has-neg-power? A) true (expr-any-neg-power? As)))

(define neg-num?
  [int N] -> (< N 0) where (number? N)
  [rat N D] -> (< N 0) where (and (number? N) (number? D))
  _ -> false)

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

\\ ============================================================================
\\ Tier 2/3 integration helpers. SHARED differentiate-back soundness gate mirrors
\\ the corpus oracle ext-integrates-back?: true iff reduce[Simplify[D[R,V] - F]]
\\ == [int 0]. Every helper below COMMITS [some R] only when this holds, so a
\\ wrong candidate can only ever stay INERT. SOUND > COMPLETE. Re-entrancy is
\\ safe: R is a closed antiderivative (no Integrate head), so the nested reduce
\\ cannot re-enter integrate-wired.
\\ ============================================================================
(define integ-diffback-ok?
  R Integrand V -> (content-eq
                     (reduce [[sym (protect Simplify)]
                               [(ct-plus) [[sym (protect D)] R V]
                                          [(ct-times) [int -1] Integrand]]])
                     [int 0]))

\\ ---- T2.4: inverse-function antiderivatives via by-parts closed forms --------
\\   ∫ArcTan[x] dx = x ArcTan[x] - (1/2) Log[1+x^2]
\\   ∫ArcSin[x] dx = x ArcSin[x] + (1-x^2)^(1/2)
\\ Fires only on Integrate[f[x],x] with f in {ArcTan,ArcSin} over the BARE var.
(define integrate-invfun
  [[sym S] Arg] V -> (iv-by-name (str S) Arg V)
  _ _ -> [none])

(define iv-by-name
  "ArcTan" Arg V -> (iv-commit (iv-candidate "ArcTan" V) [[sym (protect ArcTan)] Arg] V)
                    where (content-eq Arg V)
  "ArcSin" Arg V -> (iv-commit (iv-candidate "ArcSin" V) [[sym (protect ArcSin)] Arg] V)
                    where (content-eq Arg V)
  _ _ _ -> [none])

(define iv-candidate
  "ArcTan" V -> [(ct-plus)
                  [(ct-times) V [[sym (protect ArcTan)] V]]
                  [(ct-times) [rat -1 2]
                              [[sym (protect Log)]
                                [(ct-plus) [int 1] [(ct-power) V [int 2]]]]]]
  "ArcSin" V -> [(ct-plus)
                  [(ct-times) V [[sym (protect ArcSin)] V]]
                  [(ct-power)
                    [(ct-plus) [int 1] [(ct-times) [int -1] [(ct-power) V [int 2]]]]
                    [rat 1 2]]])

(define iv-commit
  Cand Integrand V -> (if (integ-diffback-ok? Cand Integrand V) [some Cand] [none]))

\\ ---- Gaussian Wave 1: Integrate[NormalPDF[x],x] -> NormalCDF[x] -------------
\\ The CDF is, by definition, the antiderivative of the PDF. This is DERIVED,
\\ not tabulated: it commits ONLY through the shared differentiate-back gate,
\\ which holds because the D[NormalCDF[u],x] -> NormalPDF[u] rule makes
\\ reduce[Simplify[D[NormalCDF[x],x] - NormalPDF[x]]] == 0. Fires only on a
\\ single-arg NormalPDF over the BARE variable (content-eq Arg V); any other
\\ integrand (e.g. Exp[x]*NormalPDF[x]) declines to [none] and stays INERT.
\\ The general (Integrand/V) gate means a Wave-2 complete-the-square pass that
\\ rewrites to NormalPDF over a shifted argument reuses this same machinery.
(define integrate-normalpdf
  [[sym S] Arg] V -> (inpdf-by-name (str S) Arg V)
  _ _ -> [none])

(define inpdf-by-name
  "NormalPDF" Arg V -> (iv-commit [[sym (protect NormalCDF)] V] [[sym (protect NormalPDF)] V] V)
                       where (content-eq Arg V)
  _ _ _ -> [none])

\\ ---- T2.2: ∫Log[x] and ∫x^n Log[x] via by-parts (u=Log, dv=x^n dx) ----------
\\   ∫x^n Log[x] dx = x^(n+1)/(n+1) Log[x] - x^(n+1)/(n+1)^2   (n numeric, n != -1)
(define integrate-log-parts
  Integrand V -> (if (ilog-log-of-var? V Integrand)
                     (ilog-emit V [int 0])
                     (ilog-on-form Integrand V)))

(define ilog-log-of-var?
  V [[sym S] Arg] -> (if (= (str S) "Log") (content-eq Arg V) false)
  V _ -> false)

(define ilog-on-form
  [[sym S] | Factors] V -> (ilog-on-times (str S) Factors V)
  _ _ -> [none])

(define ilog-on-times
  "Times" Factors V -> (ilog-find-log Factors V [])
  _ _ _ -> [none])

\\ find the unique Log[V] factor; the rest must be exactly V (n=1) or Power[V,n].
(define ilog-find-log
  [] _ _ -> [none]
  [F | Fs] V Seen -> (if (ilog-log-of-var? V F)
                         (ilog-rest-exp (append (reverse Seen) Fs) V)
                         (ilog-find-log Fs V [F | Seen])))

(define ilog-rest-exp
  [F] V -> (ilog-rest-exp-1 F V)
  _ _ -> [none])

(define ilog-rest-exp-1
  [[sym S] B E] V -> (ilog-rest-power (str S) B E V)
  F V -> (if (content-eq F V) (ilog-emit V [int 1]) [none]))

(define ilog-rest-power
  "Power" B E V -> (if (content-eq B V)
                       (if (number-expr? E) (ilog-emit V E) [none])
                       [none])
  _ _ _ _ -> [none])

\\ canonical integrand for exponent N: n=0 -> Log[V]; else V^n Log[V].
(define ilog-integrand
  V [int 0] -> [[sym (protect Log)] V]
  V N -> [(ct-times) [(ct-power) V N] [[sym (protect Log)] V]])

(define ilog-emit
  V N -> (ilog-build V N (num-add N [int 1])))

(define ilog-build
  V N NP1 -> (if (num-eq? NP1 [int 0])
                 [none]
                 (let R [(ct-plus)
                          [(ct-times) (num-div [int 1] NP1) [(ct-power) V NP1] [[sym (protect Log)] V]]
                          [(ct-times) [int -1] (num-div [int 1] (num-mul NP1 NP1)) [(ct-power) V NP1]]]
                      (if (integ-diffback-ok? R (ilog-integrand V N) V) [some R] [none]))))

\\ ---- T3.3: cyclic by-parts closed forms for Exp[x]*{Sin[x]|Cos[x]} ----------
\\   ∫Exp[x] Sin[x] dx = (1/2) Exp[x] (Sin[x] - Cos[x])
\\   ∫Exp[x] Cos[x] dx = (1/2) Exp[x] (Sin[x] + Cos[x])
\\ Order-robust: tries both factor assignments (Times is Orderless).
(define integrate-cyclic
  [[sym S] A B] V -> (icyc-times (str S) A B V)
  _ _ -> [none])

(define icyc-times
  "Times" A B V -> (icyc-pair A B V)
  _ _ _ _ -> [none])

(define icyc-pair
  A B V -> (if (icyc-exp? A V)
               (icyc-emit (icyc-trig-name B V) V B)
               (if (icyc-exp? B V)
                   (icyc-emit (icyc-trig-name A V) V A)
                   [none])))

(define icyc-exp?
  [[sym S] Arg] V -> (if (= (str S) "Exp") (content-eq Arg V) false)
  _ _ -> false)

(define icyc-trig-name
  [[sym S] Arg] V -> (icyc-trig-name-2 (str S) Arg V)
  _ _ -> "")

(define icyc-trig-name-2
  "Sin" Arg V -> (if (content-eq Arg V) "Sin" "")
  "Cos" Arg V -> (if (content-eq Arg V) "Cos" "")
  _ _ _ -> "")

(define icyc-emit
  "Sin" V Trig -> (icyc-gate [(ct-times) [rat 1 2] [[sym (protect Exp)] V]
                               [(ct-plus) [[sym (protect Sin)] V]
                                          [(ct-times) [int -1] [[sym (protect Cos)] V]]]]
                             [(ct-times) [[sym (protect Exp)] V] Trig] V)
  "Cos" V Trig -> (icyc-gate [(ct-times) [rat 1 2] [[sym (protect Exp)] V]
                               [(ct-plus) [[sym (protect Sin)] V] [[sym (protect Cos)] V]]]
                             [(ct-times) [[sym (protect Exp)] V] Trig] V)
  _ _ _ -> [none])

(define icyc-gate
  R Integrand V -> (if (integ-diffback-ok? R Integrand V) [some R] [none]))

\\ ---- T3.2: trig-power integrals over the bare variable -----------------------
\\   ∫Cos[x]^2 dx = x/2 + Sin[x]Cos[x]/2
\\   ∫Sin[x]^2 dx = x/2 - Sin[x]Cos[x]/2     (both close via the Pythagorean fold)
\\   ∫Sec[x]^2 dx = Tan[x]                    (closes directly via D[Tan]=Sec^2)
(define integrate-trigpow
  [[sym P] [[sym F] Arg] E] V -> (itp-power (str P) (str F) Arg E V)
  _ _ -> [none])

(define itp-power
  "Power" F Arg E V -> (if (content-eq Arg V)
                          (if (number-expr? E)
                              (if (num-eq? E [int 2]) (itp-emit F V) [none])
                              [none])
                          [none])
  _ _ _ _ _ -> [none])

(define itp-emit
  "Cos" V -> (itp-gate (itp-half-plus V [int 1]) [(ct-power) [[sym (protect Cos)] V] [int 2]] V)
  "Sin" V -> (itp-gate (itp-half-plus V [int -1]) [(ct-power) [[sym (protect Sin)] V] [int 2]] V)
  "Sec" V -> (itp-gate [[sym (protect Tan)] V] [(ct-power) [[sym (protect Sec)] V] [int 2]] V)
  _ _ -> [none])

\\ x/2 + S*(Sin[x] Cos[x])/2 ; S = +1 (Cos^2) or -1 (Sin^2).
(define itp-half-plus
  V S -> [(ct-plus)
           [(ct-times) [rat 1 2] V]
           [(ct-times) [rat 1 2] S [[sym (protect Sin)] V] [[sym (protect Cos)] V]]])

(define itp-gate
  R Integrand V -> (if (integ-diffback-ok? R Integrand V) [some R] [none]))

(define ct-divide -> [sym (protect Divide)])

\\ ---- sin-cos product: ∫Sin[x]Cos[x] dx = (1/2)Sin[x]^2 (order-robust) --------
(define integrate-sincos
  [[sym S] A B] V -> (isc-times (str S) A B V)
  _ _ -> [none])

(define isc-times
  "Times" A B V -> (isc-pair A B V)
  _ _ _ _ -> [none])

(define isc-pair
  A B V -> (if (isc-is? "Sin" A V)
               (if (isc-is? "Cos" B V) (isc-emit V) [none])
               (if (isc-is? "Cos" A V)
                   (if (isc-is? "Sin" B V) (isc-emit V) [none])
                   [none])))

(define isc-is?
  Name [[sym S] Arg] V -> (if (= (str S) Name) (content-eq Arg V) false)
  Name _ _ -> false)

(define isc-emit
  V -> (let R [(ct-times) [rat 1 2] [(ct-power) [[sym (protect Sin)] V] [int 2]]]
            F [(ct-times) [[sym (protect Sin)] V] [[sym (protect Cos)] V]]
            (if (integ-diffback-ok? R F V) [some R] [none])))

\\ ---- power of a linear arg: ∫(a x+b)^n dx = (a x+b)^(n+1)/(a(n+1)), n != -1 ---
\\ Also the reciprocal-radical form Divide[1, Power[a x+b, n]] (= exponent -n), so
\\ ∫1/Sqrt[x] = 2 Sqrt[x] and ∫Sqrt[1+x] = (2/3)(1+x)^(3/2). Self-gated; the
\\ reciprocal/radical diff-back closes via the nested-power flatten in Simplify.
(define integrate-powusub
  [[sym S] A B] V -> (ipow-by-head (str S) A B [[sym S] A B] V)
  _ _ -> [none])

(define ipow-by-head
  "Power"  Arg E Integrand V -> (if (number-expr? E)
                                    (ipow-on (expr->coeffs V Arg) E Arg Integrand V)
                                    [none])
  "Divide" Num Den Integrand V -> (ipow-div Num Den Integrand V)
  _ _ _ _ _ -> [none])

(define ipow-div
  [int 1] [[sym S] Arg E] Integrand V -> (ipow-div-2 (str S) Arg E Integrand V)
  _ _ _ _ -> [none])

(define ipow-div-2
  "Power" Arg E Integrand V -> (if (number-expr? E)
                                  (ipow-on (expr->coeffs V Arg) (num-mul [int -1] E) Arg Integrand V)
                                  [none])
  _ _ _ _ _ -> [none])

\\ degree-1 arg only: coeff vector [b a], a = leading (nonzero).
(define ipow-on
  [some [B A]] E Arg Integrand V -> (ipow-emit A E Arg Integrand V)
  _ _ _ _ _ -> [none])

(define ipow-emit
  A E Arg Integrand V -> (ipow-np1 A (num-add E [int 1]) Arg Integrand V))

(define ipow-np1
  A NP1 Arg Integrand V -> (if (num-eq? NP1 [int 0])
                              [none]
                              (ipow-gate [(ct-times) (num-div [int 1] (num-mul A NP1)) [(ct-power) Arg NP1]]
                                         Integrand V)))

(define ipow-gate
  R Integrand V -> (if (integ-diffback-ok? R Integrand V) [some R] [none]))

\\ ---- ∫1/Sqrt[1-x^2] dx = ArcSin[x] (denominator coeff vector == [1,0,-1]) -----
(define integrate-arcsin
  [[sym S] Num Den] V -> (iasin-div (str S) Num Den V)
  _ _ -> [none])

(define iasin-div
  "Divide" [int 1] Den V -> (iasin-den Den V)
  _ _ _ _ -> [none])

(define iasin-den
  [[sym S] Arg E] V -> (iasin-sqrt (str S) Arg E V)
  _ _ -> [none])

(define iasin-sqrt
  "Power" Arg [rat 1 2] V -> (iasin-on (expr->coeffs V Arg) Arg V)
  _ _ _ _ -> [none])

(define iasin-on
  [some [B Z A]] Arg V -> (if (one-minus-xsq? B Z A) (iasin-gate Arg V) [none])
  _ _ _ -> [none])

(define one-minus-xsq?
  B Z A -> (if (content-eq B [int 1])
               (if (content-eq Z [int 0]) (content-eq A [int -1]) false)
               false))

(define iasin-gate
  Arg V -> (let R [[sym (protect ArcSin)] V]
                F [(ct-divide) [int 1] [(ct-power) Arg [rat 1 2]]]
                (if (integ-diffback-ok? R F V) [some R] [none])))

\\ ---- partial-fraction integral: ∫P/Q = sum_i A_i Log[x-r_i] (distinct linear) -
\\ Reuses Apart's exact recombination gate to decompose, integrates each simple
\\ pole to a Log, and commits ONLY IF the whole differentiate-back reduces to 0
\\ (now possible thanks to the rational zero-combine in Simplify). Declines -> [none].
(define integrate-apart
  [[sym S] Num Den] V -> (iapart-divide (str S) Num Den V)
  _ _ -> [none])

(define iapart-divide
  "Divide" Num Den V -> (iapart-decomp Num Den V (apart-builtin [(ct-divide) Num Den]))
  _ _ _ _ -> [none])

(define iapart-decomp
  Num Den V [none] -> [none]
  Num Den V [some Decomp] -> (iapart-anti V [(ct-divide) Num Den] (iapart-logs (apart-plus-flatten Decomp))))

(define apart-plus-flatten
  [[sym S] | Args] -> Args where (plus-head? [sym S])
  T -> [T])

(define iapart-logs
  Terms -> (iapart-logs-loop Terms []))

(define iapart-logs-loop
  [] Acc -> [some (reverse Acc)]
  [T | Ts] Acc -> (iapart-logs-step Ts Acc (iapart-log-term T)))

(define iapart-logs-step
  Ts Acc [some L] -> (iapart-logs-loop Ts [L | Acc])
  Ts Acc _ -> [none])

\\ Apart term A*(x-r)^-1 (or bare (x-r)^-1) -> A*Log[(x-r)].
(define iapart-log-term
  [[sym P] Lin [int -1]] -> (iapart-mk [int 1] Lin) where (power-head? [sym P])
  [[sym T] A [[sym P] Lin [int -1]]] -> (iapart-mk A Lin) where (rat-apart-times? T P)
  _ -> [none])

(define rat-apart-times?
  T P -> (if (times-head? [sym T]) (power-head? [sym P]) false))

(define iapart-mk
  A Lin -> (if (num-eq? A [int 1])
               [some [[sym (protect Log)] Lin]]
               [some [(ct-times) A [[sym (protect Log)] Lin]]]))

(define iapart-anti
  V Integrand [none] -> [none]
  V Integrand [some Antis] -> (iapart-gate V Integrand (iapart-sum Antis)))

(define iapart-sum
  [A] -> A
  As -> [(ct-plus) | As])

(define iapart-gate
  V Integrand R -> (if (integ-diffback-ok? R Integrand V) [some R] [none]))

\\ ---- irreducible-quadratic reciprocal: ∫1/(a x^2+b x+c) = (1/(a k))ArcTan[(x+h)/k]
\\ via completing the square, where h=b/(2a) and k=Sqrt[c/a-(b/2a)^2]. Emits only
\\ when k is an exact rational (perfect-square completion) and k^2>0 (irreducible);
\\ diff-back-gated (closes via the rational zero-combine). Else INERT.
(define integrate-arctan-shift
  [[sym S] Num Den] V -> (iarc-divide (str S) Num Den V)
  _ _ -> [none])

(define iarc-divide
  "Divide" [int 1] Den V -> (iarc-on V Den (expr->coeffs V Den))
  _ _ _ _ -> [none])

(define iarc-on
  V Den [some [C B A]] -> (iarc-k V Den A
                                 (num-div B (num-mul [int 2] A))
                                 (num-sub (num-div C A)
                                          (num-div (num-mul B B) (num-mul [int 4] (num-mul A A)))))
  V Den _ -> [none])

(define iarc-k
  V Den A H K2 -> (if (positive-expr? K2)
                      (iarc-emit V Den A H (rat-sqrt K2))
                      [none]))

(define iarc-emit
  V Den A H [some K] -> (iarc-gate V Den (iarc-coeff (num-div [int 1] (num-mul A K))
                                                     [[sym (protect ArcTan)] (iarc-arg V H K)]))
  V Den A H _ -> [none])

\\ argument (x+H)/K, built clean (no Divide-by-1 / Plus-of-0 junk that fails to
\\ reduce and would break the diff-back match).
(define iarc-arg
  V H K -> (iarc-divK (iarc-plusH V H) K))

(define iarc-plusH
  V H -> (if (num-eq? H [int 0]) V [(ct-plus) V H]))

(define iarc-divK
  Base K -> (if (num-eq? K [int 1]) Base [(ct-divide) Base K]))

(define iarc-coeff
  C Atan -> (if (num-eq? C [int 1]) Atan [(ct-times) C Atan]))

(define iarc-gate
  V Den R -> (if (integ-diffback-ok? R [(ct-divide) [int 1] Den] V) [some R] [none]))

\\ exact rational square root: [some K] if K*K == Q exactly, else [none].
(define rat-sqrt
  [int N] -> (rat-sqrt-make (isqrt-exact N) [int 1])
  [rat N D] -> (rat-sqrt-rat (isqrt-exact N) (isqrt-exact D))
  _ -> [none])

(define rat-sqrt-rat
  [some SN] [some SD] -> [some (make-rat SN SD)]
  _ _ -> [none])

(define rat-sqrt-make
  [some SN] _ -> [some [int SN]]
  _ _ -> [none])

\\ exact integer sqrt: [some r] if r*r=N (N>=0), else [none]. Bounded loop.
(define isqrt-exact
  N -> (if (< N 0) [none] (isqrt-loop N 0)))

(define isqrt-loop
  N I -> (if (> (* I I) N)
             [none]
             (if (= (* I I) N) [some I] (isqrt-loop N (+ I 1)))))

(output "calc-helpers.shen loaded (SameQ/UnsameQ/FreeQ/NumberQ/Positive/And/Simplify + free-of? + collect-like-terms + integrate-by-parts).~%")
