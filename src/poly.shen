\\ poly.shen - canonical polynomial normal form (SCUD 17 Wave B)
\\
\\ Representation (the canonical normal form):
\\   GENERATOR : any expr that is NOT numeric and NOT a Plus/Times/integer-Power
\\               node -- an opaque indeterminate (e.g. [sym x], Sin[x], f[x,y]).
\\               Equal generators identified by content-eq / content-hash.
\\   MONOMIAL  : a canonical list of [Gen Exp] pairs, Exp a positive int, sorted
\\               by (content-hash Gen) ascending; [] is the constant monomial.
\\   TERM      : [Coeff Monomial], Coeff a NONZERO numeric ([int]/[rat]).
\\   POLY      : a list of Terms; no shared monomials, no zero coeffs, sorted
\\               degree-lex (higher total degree first; ties by generator-hash
\\               lexicographically). Equal polynomials => identical POLY structure.
\\
\\ Reuses src/num.shen for ALL coefficient arithmetic. shen-go portable (no bare
\\ higher-order application; nested ifs; int64 only).

\\ ============================================================================
\\ Head helpers (dispatch on str name, robust to interning)
\\ ============================================================================
(define poly-plus-head?  [sym S] -> (= (str S) "Plus")  _ -> false)
(define poly-times-head? [sym S] -> (= (str S) "Times") _ -> false)
(define poly-power-head? [sym S] -> (= (str S) "Power") _ -> false)

(define poly-ct-plus  -> [sym (protect Plus)])
(define poly-ct-times -> [sym (protect Times)])
(define poly-ct-power -> [sym (protect Power)])

\\ non-negative integer literal exponent?
(define nonneg-int-exp?
  [int N] -> (>= N 0)
  _ -> false)

\\ ============================================================================
\\ expr->poly : recursive descent into the canonical POLY form.
\\ ============================================================================
(define expr->poly
  E -> (if (numeric? E)
           (const-poly E)
           (poly-of-compound E)))

\\ a compound (or symbol generator): dispatch on head shape.
(define poly-of-compound
  [H | Args] -> (poly-of-head H Args)
  E -> (gen-poly E))   \\ atom symbol -> generator

(define poly-of-head
  H Args -> (if (poly-plus-head? H)
                (poly-sum-list Args)
                (if (poly-times-head? H)
                    (poly-prod-list Args)
                    (if (poly-power-head? H)
                        (poly-of-power Args [H | Args])
                        (gen-poly [H | Args])))))

\\ Power[base, [int n]] with n a non-negative integer -> poly-pow; else opaque.
(define poly-of-power
  [Base Exp] Whole -> (if (nonneg-int-exp? Exp)
                          (poly-pow (expr->poly Base) (hd (tl Exp)))
                          (gen-poly Whole))
  _ Whole -> (gen-poly Whole))

\\ Plus[..] -> sum of child polys.
(define poly-sum-list
  [] -> (zero-poly)
  [A | As] -> (poly-add (expr->poly A) (poly-sum-list As)))

\\ Times[..] -> product of child polys.
(define poly-prod-list
  [] -> (one-poly)
  [A | As] -> (poly-mul (expr->poly A) (poly-prod-list As)))

\\ ============================================================================
\\ POLY constructors
\\ ============================================================================
(define zero-poly -> [])

(define one-poly -> [[[int 1] []]])

\\ constant poly from a numeric expr (zero -> empty poly).
(define const-poly
  C -> (if (num-eq? C [int 0]) [] [[C []]]))

\\ single generator G -> coeff 1, monomial [[G 1]].
(define gen-poly
  G -> [[[int 1] [[G [int 1]]]]])

\\ ============================================================================
\\ Term accessors
\\ ============================================================================
(define term-coeff [C _] -> C)
(define term-mono  [_ M] -> M)

\\ ============================================================================
\\ Monomial multiply: merge two sorted [Gen Exp] lists, summing exponents of
\\ equal generators; result stays sorted by (content-hash Gen) ascending.
\\ ============================================================================
(define mono-mul
  [] M -> M
  M [] -> M
  [[G1 E1] | R1] [[G2 E2] | R2] ->
    (let H1 (unwrap-ch (content-hash G1))
         H2 (unwrap-ch (content-hash G2))
         (if (= H1 H2)
             [[G1 (num-add E1 E2)] | (mono-mul R1 R2)]
             (if (< H1 H2)
                 [[G1 E1] | (mono-mul R1 [[G2 E2] | R2])]
                 [[G2 E2] | (mono-mul [[G1 E1] | R1] R2)]))))

\\ ============================================================================
\\ poly-add : merge two canonical POLYs.
\\ Strategy: fold each term of B into A (insert-or-combine), then the result is
\\ re-sorted into degree-lex canonical order.
\\ ============================================================================
(define poly-add
  A B -> (canon-sort-poly (poly-add-raw A B)))

(define poly-add-raw
  A [] -> A
  A [T | Ts] -> (poly-add-raw (insert-term T A) Ts))

\\ insert a [Coeff Mono] term: combine with an equal-monomial term (summing
\\ coeffs, dropping if zero) or append.
(define insert-term
  [C M] [] -> (if (num-eq? C [int 0]) [] [[C M]])
  [C M] [[C2 M2] | Rest] ->
    (if (mono-eq? M M2)
        (let Sum (num-add C C2)
             (if (num-eq? Sum [int 0])
                 Rest
                 [[Sum M2] | Rest]))
        [[C2 M2] | (insert-term [C M] Rest)]))

\\ monomial equality: same generators with same exponents (both canonically
\\ sorted, so a positional walk suffices).
(define mono-eq?
  [] [] -> true
  [[G1 E1] | R1] [[G2 E2] | R2] ->
    (if (content-eq G1 G2)
        (if (num-eq? E1 E2) (mono-eq? R1 R2) false)
        false)
  _ _ -> false)

\\ ============================================================================
\\ poly-mul : distribute, accumulate.
\\ ============================================================================
(define poly-mul
  [] _ -> []
  _ [] -> []
  A B -> (canon-sort-poly (poly-mul-raw A B [])))

\\ for each term of A, multiply into all of B, accumulating into Acc.
(define poly-mul-raw
  [] _ Acc -> Acc
  [Ta | As] B Acc -> (poly-mul-raw As B (poly-add-raw Acc (term-times-poly Ta B))))

(define term-times-poly
  _ [] -> []
  [Ca Ma] [[Cb Mb] | Bs] ->
    [[(num-mul Ca Cb) (mono-mul Ma Mb)] | (term-times-poly [Ca Ma] Bs)])

\\ ============================================================================
\\ poly-pow : repeated multiplication. n is a non-negative integer literal.
\\ ============================================================================
(define poly-pow
  _ 0 -> (one-poly)
  P N -> (poly-mul P (poly-pow P (- N 1))))

\\ ============================================================================
\\ Canonical ordering: degree-lex. Higher total degree first; ties broken by
\\ generator-hash lexicographically (the monomial's [Gen Exp] hash sequence).
\\ ============================================================================
(define canon-sort-poly
  P -> (sort-terms P))

(define sort-terms
  [] -> []
  [T | Ts] -> (insert-term-ordered T (sort-terms Ts)))

(define insert-term-ordered
  T [] -> [T]
  T [Y | Ys] -> (if (term-before? T Y)
                    [T Y | Ys]
                    [Y | (insert-term-ordered T Ys)]))

\\ total degree of a monomial (sum of exponents; exps are [int _]).
(define mono-degree
  [] -> 0
  [[_ [int E]] | R] -> (+ E (mono-degree R))
  [[_ E] | R] -> (mono-degree R))   \\ defensive: non-int exp contributes 0

\\ degree-lex: T strictly before Y?
(define term-before?
  [_ M1] [_ M2] -> (let D1 (mono-degree M1)
                        D2 (mono-degree M2)
                        (if (> D1 D2)
                            true
                            (if (< D1 D2)
                                false
                                (mono-lex-before? M1 M2)))))

\\ lexicographic tiebreak on the [Gen-hash, Exp] sequence.
(define mono-lex-before?
  [] [] -> false
  [] _ -> true
  _ [] -> false
  [[G1 E1] | R1] [[G2 E2] | R2] ->
    (let H1 (unwrap-ch (content-hash G1))
         H2 (unwrap-ch (content-hash G2))
         (if (< H1 H2)
             true
             (if (> H1 H2)
                 false
                 (let X1 (exp-int E1)
                      X2 (exp-int E2)
                      (if (< X1 X2)
                          true
                          (if (> X1 X2)
                              false
                              (mono-lex-before? R1 R2))))))))

(define exp-int
  [int N] -> N
  _ -> 0)

\\ ============================================================================
\\ poly->expr : canonical POLY back to an expr.
\\   zero poly -> [int 0]; constant poly -> its numeric coeff; else Plus of
\\   terms (single term: no Plus wrapper). Each term = Times of (coeff if not 1)
\\   and (gen^exp, exp 1 omitted). Ordering taken straight from the POLY.
\\ ============================================================================
(define poly->expr
  [] -> [int 0]
  Terms -> (terms->expr Terms))

(define terms->expr
  [T] -> (term->expr T)
  Terms -> [(poly-ct-plus) | (map (/. T (term->expr T)) Terms)])

\\ a term -> expr. Constant monomial -> the coeff. Else build the factor list.
(define term->expr
  [C []] -> C
  [C M] -> (let Factors (mono->factors M)
                (if (num-eq? C [int 1])
                    (factors->expr Factors)
                    (factors->expr [C | Factors]))))

\\ monomial -> list of factor exprs (gen if exp 1, else Power[gen,exp]).
(define mono->factors
  [] -> []
  [[G [int 1]] | R] -> [G | (mono->factors R)]
  [[G E] | R] -> [[(poly-ct-power) G E] | (mono->factors R)])

\\ build a single expr from a factor list: [] -> [int 1], single -> it, else Times.
(define factors->expr
  [] -> [int 1]
  [F] -> F
  Fs -> [(poly-ct-times) | Fs])

\\ ============================================================================
\\ Expand[E] = poly->expr(expr->poly(E))
\\ ============================================================================
(define poly-expand
  E -> (poly->expr (expr->poly E)))

\\ ============================================================================
\\ PolynomialQ[E, V] : is E a polynomial in V?
\\   numbers ok; V ok; other symbols/opaque-without-V ok (constants);
\\   Plus/Times of poly args ok; Power[p,n] ok iff n non-neg int literal AND p
\\   polynomial; any subexpression CONTAINING V not of these forms -> false.
\\ ============================================================================
(define polynomial-q?
  E V -> (if (numeric? E)
             true
             (poly-q-nonnum E V)))

(define poly-q-nonnum
  E V -> (if (content-eq E V)
             true
             (if (free-of? E V)
                 true
                 (poly-q-structural E V))))

\\ E contains V and is not numeric: only Plus/Times/Power-of-poly are admissible.
(define poly-q-structural
  [H | Args] V -> (poly-q-head H Args V)
  _ V -> false)

(define poly-q-head
  H Args V -> (if (or (poly-plus-head? H) (poly-times-head? H))
                  (poly-q-args Args V)
                  (if (poly-power-head? H)
                      (poly-q-power Args V)
                      false)))

(define poly-q-args
  [] V -> true
  [A | As] V -> (if (polynomial-q? A V) (poly-q-args As V) false))

(define poly-q-power
  [Base Exp] V -> (if (nonneg-int-exp? Exp)
                      (polynomial-q? Base V)
                      false)
  _ V -> false)

(output "poly.shen loaded (expr<->poly, Expand + PolynomialQ).~%")
