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
  "Simplify" [E]   -> [some (collect-like-terms E)]
  _ _ -> [none])

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
                    (collect-times Args)
                    [H | Args])))

\\ -------------------- Plus: group by base, sum coefficients --------------------
\\ Each addend -> [Coeff Base]; pure-numeric addends use the sentinel base
\\ [int 1] (so they fold together via Times[c,1] -> c on rebuild).
(define addend-coeff-base
  [int N] -> [[int N] [int 1]]
  [rat N D] -> [[rat N D] [int 1]]
  [H A B | Rest] -> (if (and (times-head? H) (number-expr? A))
                        [A (times-rest-as-expr [B | Rest])]
                        [[int 1] [H A B | Rest]])
  T -> [[int 1] T])

\\ rebuild the non-coefficient factor list as a single expr (Times[..] / single).
(define times-rest-as-expr
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

(define collect-plus
  Args -> (let Groups (plus-groups Args [])
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

(define collect-times
  Args -> (let Parts (split-num-factors Args [int 1] [])
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

(output "calc-helpers.shen loaded (SameQ/UnsameQ/FreeQ/NumberQ/Positive/Simplify + free-of? + collect-like-terms).~%")
