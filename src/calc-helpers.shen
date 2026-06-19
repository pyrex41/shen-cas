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
  _ _ -> [none])

\\ SCUD 21 wired Integrate dispatch: position-independent constant-factor
\\ pull-out FIRST (Times is Orderless, so a constant may sit anywhere after the
\\ canonical sort -- a positional rule cannot reliably catch it), then by-parts.
\\ Both decline ([none]) outside their narrow sound shapes -> rule library / inert.
(define integrate-wired
  Integrand V -> (let P (integrate-pullout Integrand V)
                      (if (= P [none])
                          (integrate-by-parts Integrand V)
                          P)))

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

(define plus-head?  [sym S] -> (= (str S) "Plus")  _ -> false)
(define times-head? [sym S] -> (= (str S) "Times") _ -> false)
(define power-head? [sym S] -> (= (str S) "Power") _ -> false)

\\ top-level dispatch: recurse into args, then collect at this node.
(define collect-like-terms
  [sym S] -> [sym S]
  [int N] -> [int N]
  [rat N D] -> [rat N D]
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
