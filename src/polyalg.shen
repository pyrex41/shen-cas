\\ polyalg.shen - SCUD 18 Wave C: univariate polynomial algebra over Q.
\\
\\ Built on src/poly.shen (canonical POLY normal form) and src/num.shen (exact
\\ rational coefficient arithmetic). GUIDING PRINCIPLE: SOUND > COMPLETE.
\\ Univariate-over-Q is the guaranteed path; multivariate inputs, int64 overflow,
\\ or anything we cannot prove correct returns the input UNEVALUATED (inert).
\\ Every closed-form result passes its own self-check before being returned.
\\
\\ shen-go portable: no bare higher-order application, nested ifs (no and/or to
\\ guard partial accessors), int64 only (num.shen guards overflow & errors; we
\\ trap-error around risky arithmetic and decline to inert).

\\ ============================================================================
\\ Variable-set detection (which free symbols occur?).
\\ free-symbols (rule.shen) returns a list of BARE symbol names. We dedup them.
\\ ============================================================================
(define dedup-syms
  [] -> []
  [S | Ss] -> (if (element? S (dedup-syms Ss)) (dedup-syms Ss) [S | (dedup-syms Ss)]))

\\ list of distinct INDETERMINATE symbol NAMES in E. The kernel's free-symbols
\\ (rule.shen) also returns the HEAD symbols of compounds (Plus/Power/...), which
\\ are operators, not variables -- so we walk ourselves, collecting only symbols
\\ that occur in ARGUMENT position (never a compound's head). A bare-symbol expr
\\ (the variable itself) is collected directly.
(define indet-names
  [sym S] -> [S]
  [int _] -> []
  [rat _ _] -> []
  [_ | Args] -> (indet-names-list Args)   \\ skip the head; recurse into args only
  _ -> [])

(define indet-names-list
  [] -> []
  [A | As] -> (append (indet-names A) (indet-names-list As)))

(define free-sym-names
  E -> (dedup-syms (indet-names E)))

\\ the single free var [sym S] of E, or [none] if not exactly one.
(define single-var
  E -> (let Ns (free-sym-names E)
            (if (= (length Ns) 1) [some [sym (hd Ns)]] [none])))

\\ ============================================================================
\\ UNIVARIATE BRIDGE: POLY (in a single var V) <-> dense rational coeff vector
\\   [c0 c1 ... cn]  (c0 = constant term; ci numeric exprs; possibly trailing 0s
\\   trimmed). A monomial in a univariate poly is [] (constant) or [[V [int e]]].
\\ Returns [some Vec] / [none] (if any monomial is not pure-V, i.e. multivariate).
\\ ============================================================================

\\ exponent of V in a single TERM's monomial: 0 for [], the int exp for [[V e]],
\\ or [bad] if the monomial mentions any generator other than V.
(define term-exp-in
  V [_ []] -> 0
  V [_ [[G [int E]]]] -> (if (content-eq G V) E [bad])
  V _ -> [bad])

\\ poly -> [some Vec] / [none]. Build by placing each term's coeff at its degree.
(define poly->coeffs
  V P -> (let D (poly-max-deg V P)
              (if (= D [bad])
                  [none]
                  [some (coeffs-fill V P D)])))

\\ maximum exponent of V across terms, or [bad] if non-univariate monomial seen.
(define poly-max-deg
  V [] -> 0
  V [T | Ts] -> (let E (term-exp-in V T)
                     (if (= E [bad])
                         [bad]
                         (let Rest (poly-max-deg V Ts)
                              (if (= Rest [bad]) [bad] (max E Rest))))))

(define max
  A B -> (if (> A B) A B))

\\ build the dense vector [c0..cD]: for each degree i, sum the coeffs of terms
\\ whose V-exponent = i (canonical poly has at most one such term).
(define coeffs-fill
  V P D -> (coeffs-loop V P 0 D))

(define coeffs-loop
  V P I D -> (if (> I D)
                 []
                 [(coeff-at-deg V P I) | (coeffs-loop V P (+ I 1) D)]))

(define coeff-at-deg
  V [] _ -> [int 0]
  V [T | Ts] I -> (let E (term-exp-in V T)
                       (if (= E I)
                           (term-coeff T)
                           (coeff-at-deg V Ts I))))

\\ coeff vector -> POLY (in V). ci at index i -> term [ci [[V [int i]]]] (i>0),
\\ [ci []] for i=0; drop zero coeffs. Result re-canonicalized.
(define coeffs->poly
  V Vec -> (canon-sort-poly (coeffs->terms V Vec 0)))

(define coeffs->terms
  V [] _ -> []
  V [C | Cs] I -> (if (num-eq? C [int 0])
                      (coeffs->terms V Cs (+ I 1))
                      [(coeff->term V C I) | (coeffs->terms V Cs (+ I 1))]))

(define coeff->term
  V C 0 -> [C []]
  V C I -> [C [[V [int I]]]])

\\ trim trailing zero coeffs (high-degree). [int 0]-only vector -> [].
(define trim-coeffs
  Vec -> (reverse (drop-leading-zeros (reverse Vec))))

(define drop-leading-zeros
  [] -> []
  [C | Cs] -> (if (num-eq? C [int 0]) (drop-leading-zeros Cs) [C | Cs]))

\\ degree of a (trimmed) coeff vector = length-1; [] (zero poly) -> -1.
(define coeffs-deg
  Vec -> (let T (trim-coeffs Vec) (- (length T) 1)))

\\ leading coeff (highest degree) of a trimmed vector; [int 0] for zero.
(define coeffs-lead
  Vec -> (let T (trim-coeffs Vec)
              (if (empty? T) [int 0] (last-of T))))

(define last-of
  [X] -> X
  [_ | Xs] -> (last-of Xs))

\\ expr (univariate in V) -> [some Vec] / [none].
(define expr->coeffs
  V E -> (poly->coeffs V (expr->poly E)))

\\ ============================================================================
\\ Vector arithmetic over Q on dense coeff vectors (untrimmed lengths ok).
\\ ============================================================================
(define vec-add
  [] B -> B
  A [] -> A
  [A | As] [B | Bs] -> [(num-add A B) | (vec-add As Bs)])

(define vec-sub
  A B -> (vec-add A (vec-neg B)))

(define vec-neg
  [] -> []
  [A | As] -> [(num-mul [int -1] A) | (vec-neg As)])

\\ scale a vector by numeric S.
(define vec-scale
  S [] -> []
  S [A | As] -> [(num-mul S A) | (vec-scale S As)])

\\ shift (multiply by x^K): prepend K zeros.
(define vec-shift
  0 Vec -> Vec
  K Vec -> [[int 0] | (vec-shift (- K 1) Vec)])

\\ polynomial multiply on coeff vectors.
(define vec-mul
  [] _ -> []
  _ [] -> []
  A B -> (vec-mul-loop A B 0))

(define vec-mul-loop
  [] _ _ -> []
  [Ai | As] B K -> (vec-add (vec-shift K (vec-scale Ai B))
                            (vec-mul-loop As B (+ K 1))))

\\ ============================================================================
\\ uni-divmod : long division A / B over Q. Returns [Q R], deg R < deg B.
\\ Inputs and outputs are trimmed coeff vectors. B must be nonzero (deg>=0).
\\ ============================================================================
(define uni-divmod
  A B -> (let Bt (trim-coeffs B)
              (if (empty? Bt)
                  (error "uni-divmod: zero divisor")
                  (divmod-loop (trim-coeffs A) Bt []))))

\\ Q accumulated as a list of [Deg Coeff] (we build the quotient vector at end).
(define divmod-loop
  R B QAcc -> (let Rt (trim-coeffs R)
                   Dr (coeffs-deg Rt)
                   Db (coeffs-deg B)
                   (if (< Dr Db)
                       [(qacc->vec QAcc) Rt]
                       (let Lr (coeffs-lead Rt)
                            Lb (coeffs-lead B)
                            Co (num-div Lr Lb)
                            K (- Dr Db)
                            Sub (vec-shift K (vec-scale Co B))
                            R2 (vec-sub Rt Sub)
                            (divmod-loop R2 B [[K Co] | QAcc])))))

\\ build a dense quotient vector from [Deg Coeff] pairs.
(define qacc->vec
  [] -> []
  Pairs -> (qacc-fill Pairs (qacc-maxdeg Pairs 0) 0))

(define qacc-maxdeg
  [] Acc -> Acc
  [[D _] | Ps] Acc -> (qacc-maxdeg Ps (max D Acc)))

(define qacc-fill
  Pairs Max I -> (if (> I Max)
                     []
                     [(qacc-at Pairs I) | (qacc-fill Pairs Max (+ I 1))]))

(define qacc-at
  [] _ -> [int 0]
  [[D C] | Ps] I -> (if (= D I) C (qacc-at Ps I)))

\\ remainder of A divided by B (the R component).
(define uni-rem
  A B -> (hd (tl (uni-divmod A B))))

\\ is R the zero vector?
(define zero-vec?
  Vec -> (empty? (trim-coeffs Vec)))

\\ ============================================================================
\\ Euclidean GCD over Q, normalized MONIC. Returns a trimmed coeff vector.
\\ ============================================================================
(define uni-gcd
  A B -> (gcd-loop (trim-coeffs A) (trim-coeffs B)))

(define gcd-loop
  A [] -> (make-monic A)
  A B -> (gcd-loop B (uni-rem A B)))

\\ divide a vector by its leading coeff -> monic (leading coeff 1).
(define make-monic
  Vec -> (let T (trim-coeffs Vec)
              (if (empty? T)
                  []
                  (vec-scale (num-div [int 1] (coeffs-lead T)) T))))

\\ ============================================================================
\\ Derivative of a coeff vector: d/dx [c0 c1 c2 ..] = [c1 2c2 3c3 ..].
\\ ============================================================================
(define vec-deriv
  Vec -> (deriv-loop (trim-coeffs Vec) 1))

(define deriv-loop
  [] _ -> []
  [_] _ -> []                 \\ constant term has no derivative contribution... handled below
  [_ C1 | Cs] I -> (deriv-build [C1 | Cs] I))

(define deriv-build
  [] _ -> []
  [C | Cs] I -> [(num-mul [int I] C) | (deriv-build Cs (+ I 1))])

\\ ============================================================================
\\ Reconstruct an expr from a coeff vector in variable V (via poly->expr).
\\ ============================================================================
(define coeffs->expr
  V Vec -> (poly->expr (coeffs->poly V (trim-coeffs Vec))))

\\ ============================================================================
\\ Head / constructor helpers (str-name dispatch, robust to interning).
\\ ============================================================================
(define pa-divide-head? [sym S] -> (= (str S) "Divide") _ -> false)
(define pa-times-head?  [sym S] -> (= (str S) "Times")  _ -> false)
(define pa-plus-head?   [sym S] -> (= (str S) "Plus")   _ -> false)
(define pa-power-head?  [sym S] -> (= (str S) "Power")  _ -> false)

(define pa-divide -> [sym (protect Divide)])
(define pa-times  -> [sym (protect Times)])
(define pa-plus   -> [sym (protect Plus)])
(define pa-power  -> [sym (protect Power)])

\\ ============================================================================
\\ PolynomialGCD[A, B]: univariate Euclidean GCD over Q, monic.
\\ SELF-SOUND: result must divide BOTH A and B (uni-rem = zero).
\\ Inert if not univariate over a SINGLE shared variable, or on overflow.
\\ ============================================================================
(define poly-gcd-builtin
  A B -> (trap-error (poly-gcd-attempt A B) (/. E [none])))

(define poly-gcd-attempt
  A B -> (let V (gcd-shared-var A B)
              (if (= V [none])
                  [none]
                  (gcd-with-var (hd (tl V)) A B))))

\\ both A and B must be univariate (or constant) in ONE common variable.
\\ Allowed: each input has 0 or 1 free vars; the union has at most 1 distinct var.
(define gcd-shared-var
  A B -> (let Na (free-sym-names A)
              Nb (free-sym-names B)
              U (dedup-syms (append Na Nb))
              (if (> (length U) 1)
                  [none]
                  (if (empty? U)
                      [none]            \\ both constant: GCD ill-defined here, decline
                      [some [sym (hd U)]]))))

(define gcd-with-var
  V A B -> (let CA (expr->coeffs V A)
                CB (expr->coeffs V B)
                (if (or (= CA [none]) (= CB [none]))
                    [none]
                    (gcd-from-coeffs V (hd (tl CA)) (hd (tl CB))))))

(define gcd-from-coeffs
  V VA VB -> (let G (uni-gcd VA VB)
                  (if (zero-vec? G)
                      [none]
                      (if (and (gcd-divides? VA G) (gcd-divides? VB G))
                          [some (coeffs->expr V G)]
                          [none]))))

\\ does G divide Vec (remainder zero)?
(define gcd-divides?
  Vec G -> (zero-vec? (uni-rem Vec G)))

\\ ============================================================================
\\ Cancel[E]: E a ratio P/Q (Divide[P,Q]). Reduce to lowest terms via gcd.
\\ Returns Divide[P',Q'] (or P' if Q'=1). Inert if not a rational function or
\\ multivariate.
\\ ============================================================================
(define cancel-builtin
  E -> (trap-error (cancel-attempt E) (/. Er [none])))

(define cancel-attempt
  [H P Q] -> (if (pa-divide-head? H) (cancel-ratio P Q) [none])
  _ -> [none])

(define cancel-ratio
  P Q -> (let V (gcd-shared-var P Q)
              (if (= V [none])
                  [none]
                  (cancel-with-var (hd (tl V)) P Q))))

(define cancel-with-var
  V P Q -> (let CP (expr->coeffs V P)
                CQ (expr->coeffs V Q)
                (if (or (= CP [none]) (= CQ [none]))
                    [none]
                    (cancel-from-coeffs V (hd (tl CP)) (hd (tl CQ))))))

(define cancel-from-coeffs
  V VP VQ -> (let G (uni-gcd VP VQ)
                  (if (zero-vec? G)
                      [none]
                      (let DR (uni-divmod VP G)
                           DRq (uni-divmod VQ G)
                           Pn (hd DR) Pr (hd (tl DR))
                           Qn (hd DRq) Qr (hd (tl DRq))
                           (if (and (zero-vec? Pr) (zero-vec? Qr))
                               (cancel-build V Pn Qn)
                               [none])))))

\\ build the cancelled result; normalize sign so denom leading coeff is positive.
(define cancel-build
  V Pn Qn -> (let Qt (trim-coeffs Qn)
                  (if (and (= (coeffs-deg Qt) 0) (num-eq? (coeffs-lead Qt) [int 1]))
                      [some (coeffs->expr V Pn)]
                      [some [(pa-divide) (coeffs->expr V Pn) (coeffs->expr V Qn)]])))

\\ ============================================================================
\\ Together[E]: combine a Plus of rational terms over a common denominator into
\\ a single Divide[Num, Den]. Each addend is poly or poly/poly (univariate over
\\ the SAME single variable, or constant). Inert otherwise.
\\
\\ Represent each addend as [NumVec DenVec]. Accumulate sum as a single fraction:
\\   n1/d1 + n2/d2 = (n1*d2 + n2*d1)/(d1*d2).
\\ Final fraction is gcd-cancelled, then emitted as Divide[Num,Den] (Den=1 -> Num).
\\ ============================================================================
(define together-builtin
  E -> (trap-error (together-attempt E) (/. Er [none])))

(define together-attempt
  [H | Args] -> (if (pa-plus-head? H) (together-plus Args) [none])
  _ -> [none])

(define together-plus
  Args -> (let V (together-var Args)
               (if (= V [none])
                   [none]
                   (together-with-var (hd (tl V)) Args))))

\\ the single shared variable across ALL addends (union of free syms <=1), or
\\ [none] if multivariate. (All-constant Plus would already be folded by num.)
(define together-var
  Args -> (let U (dedup-syms (free-syms-of-list Args))
               (if (> (length U) 1)
                   [none]
                   (if (empty? U) [none] [some [sym (hd U)]]))))

(define free-syms-of-list
  [] -> []
  [A | As] -> (append (free-sym-names A) (free-syms-of-list As)))

(define together-with-var
  V Args -> (let Fracs (addends->fracs V Args [])
                 (if (= Fracs [none])
                     [none]
                     (together-combine V (hd (tl Fracs))))))

\\ convert each addend to [NumVec DenVec]; [none] if any addend isn't poly/poly.
(define addends->fracs
  V [] Acc -> [some (reverse Acc)]
  V [A | As] Acc -> (let F (addend->frac V A)
                         (if (= F [none])
                             [none]
                             (addends->fracs V As [(hd (tl F)) | Acc]))))

\\ addend -> [some [NumVec DenVec]] / [none].
(define addend->frac
  V [H P Q] -> (addend-divide V H P Q)
  V A -> (addend-poly V A))

(define addend-divide
  V H P Q -> (if (pa-divide-head? H)
                 (let CP (expr->coeffs V P)
                      CQ (expr->coeffs V Q)
                      (if (or (= CP [none]) (= CQ [none]))
                          [none]
                          [some [(hd (tl CP)) (hd (tl CQ))]]))
                 (addend-poly V [H P Q])))

(define addend-poly
  V A -> (let C (expr->coeffs V A)
              (if (= C [none])
                  [none]
                  [some [(hd (tl C)) [[int 1]]]])))

\\ fold the fraction list into one [NumVec DenVec], then cancel & emit.
(define together-combine
  V Fracs -> (let Sum (sum-fracs Fracs)
                  N (hd Sum) D (hd (tl Sum))
                  (together-emit V N D)))

(define sum-fracs
  [F] -> F
  [F | Fs] -> (add-frac F (sum-fracs Fs)))

(define add-frac
  [N1 D1] [N2 D2] -> [(vec-add (vec-mul N1 D2) (vec-mul N2 D1)) (vec-mul D1 D2)])

\\ cancel common gcd, then build Divide (or bare Num if Den is the constant 1).
(define together-emit
  V N D -> (let G (uni-gcd N D)
                (if (zero-vec? G)
                    [some (coeffs->expr V N)]   \\ numerator zero -> 0
                    (let Nn (hd (uni-divmod N G))
                         Dn (hd (uni-divmod D G))
                         (together-emit-norm V Nn Dn)))))

\\ normalize so the denominator's leading coeff is positive; Den const 1 -> Num.
(define together-emit-norm
  V N D -> (let Dt (trim-coeffs D)
                Lead (coeffs-lead Dt)
                Sgn (if (num-neg? Lead) [int -1] [int 1])
                Nn (vec-scale Sgn N)
                Dn (vec-scale Sgn Dt)
                (if (and (= (coeffs-deg Dn) 0) (num-eq? (coeffs-lead Dn) [int 1]))
                    [some (coeffs->expr V Nn)]
                    [some [(pa-divide) (coeffs->expr V Nn) (coeffs->expr V Dn)]])))

(define num-neg?
  N -> (< (rat-num (as-rat N)) 0))

\\ ============================================================================
\\ Factor[P]: univariate over Q, BOUNDED + SOUND.
\\   (a) pull rational content (overall rational common factor of the coeffs);
\\   (b) square-free split via gcd(P,P');
\\   (c) extract linear factors from rational roots (rational root theorem);
\\   (d) leave any remaining higher-degree factor as-is.
\\ SELF-SOUND: Expand[product of factors] content-eq Expand[P]. On any doubt
\\ (overflow / multivariate / failed self-check) return P unevaluated.
\\
\\ Strategy: compute a list of EXPR factors, then verify the product expands to
\\ the same poly as P. We represent the running result as a list of expr factors.
\\ ============================================================================
(define factor-builtin
  P -> (trap-error (factor-attempt P) (/. E [none])))

(define factor-attempt
  P -> (let V (single-var P)
            (if (= V [none])
                [none]
                (factor-with-var (hd (tl V)) P))))

(define factor-with-var
  V P -> (let C (expr->coeffs V P)
              (if (= C [none])
                  [none]
                  (factor-from-coeffs V P (trim-coeffs (hd (tl C)))))))

\\ given the trimmed coeff vector, factor it; verify; emit Times of factors.
(define factor-from-coeffs
  V P Vec -> (if (< (coeffs-deg Vec) 1)
                 [none]                           \\ constant: nothing to factor
                 (let Factors (factor-vec V Vec)
                      (factor-verify V P Factors))))

\\ verify Expand[product] == Expand[P]; else inert.
(define factor-verify
  V P Factors -> (let Prod (factors-product-expr Factors)
                      (if (content-eq (poly-expand Prod) (poly-expand P))
                          [some (factors->result Factors)]
                          [none])))

\\ Build the product expr from factor-expr list (for the self-check oracle).
(define factors-product-expr
  [] -> [int 1]
  [F] -> F
  Fs -> [(pa-times) | Fs])

\\ The returned result expr: single factor as-is, else Times[..].
(define factors->result
  [] -> [int 1]
  [F] -> F
  Fs -> [(pa-times) | Fs])

\\ ----------------------------------------------------------------------------
\\ factor-vec V Vec -> list of EXPR factors whose product is Vec's poly.
\\ (a) content: integer-rational content pulled out as a numeric factor.
\\ ----------------------------------------------------------------------------
(define factor-vec
  V Vec -> (let Cont (vec-content Vec)
                Prim (vec-scale (num-div [int 1] Cont) Vec)
                ContFactors (if (num-eq? Cont [int 1]) [] [Cont])
                (append ContFactors (factor-sqfree-roots V Prim))))

\\ content = gcd of integer coeffs (cleared to integers via common denom), with
\\ the sign of the leading coeff. We return a NUMERIC expr (the content) such that
\\ Vec / Cont is a primitive integer polynomial (best-effort; soundness is the
\\ Expand self-check, so an imperfect content still yields a valid factorization).
\\ Simpler + always-sound: pull out the leading coefficient so the primitive part
\\ is MONIC. monic part * lead = original. This needs no integer gcd and never
\\ overflows beyond the original coeffs.
(define vec-content
  Vec -> (coeffs-lead Vec))

\\ ----------------------------------------------------------------------------
\\ square-free + rational-root linear extraction on a MONIC primitive vector.
\\ We extract linear factors (x - r) for each rational root r (with multiplicity),
\\ then leave the remaining monic quotient as a single factor (as an expr).
\\ ----------------------------------------------------------------------------
(define factor-sqfree-roots
  V Vec -> (let Roots (rational-roots Vec)
                (extract-linear-factors V (make-monic Vec) Roots)))

\\ extract (x - r) factors greedily by repeated division; leftover -> one factor.
(define extract-linear-factors
  V Vec [] -> (leftover-factor V Vec)
  V Vec [R | Rs] -> (let Lin (linear-vec R)
                         DM (uni-divmod Vec Lin)
                         Q (hd DM) Rem (hd (tl DM))
                         (if (zero-vec? Rem)
                             [(linear-expr V R) | (extract-linear-factors V Q [R | Rs])]
                             (extract-linear-factors V Vec Rs))))

\\ leftover quotient as factors: degree 0 (constant 1) -> none; else one expr.
(define leftover-factor
  V Vec -> (let T (trim-coeffs Vec)
                (if (< (coeffs-deg T) 1)
                    (if (num-eq? (coeffs-lead T) [int 1]) [] [(coeffs->expr V T)])
                    [(coeffs->expr V T)])))

\\ linear coeff vector for root r = p/q : (x - r) -> [-r, 1].
(define linear-vec
  R -> [(num-mul [int -1] R) [int 1]])

\\ linear factor expr (x - r): if r=0 -> just V (x); else Plus[V, -r] / etc via
\\ coeffs->expr so it prints canonically.
(define linear-expr
  V R -> (coeffs->expr V (linear-vec R)))

\\ ----------------------------------------------------------------------------
\\ rational roots p/q of a vector (integer-cleared): p | c0, q | c_n. Bounded by
\\ the int64 divisor enumeration. Returns the DISTINCT rational roots; multiplicity
\\ is handled by repeated division in extract-linear-factors.
\\ We clear denominators to make the poly integer, then enumerate.
\\ ----------------------------------------------------------------------------
(define rational-roots
  Vec -> (let IV (clear-denoms Vec)
              (if (= IV [none])
                  []
                  (let Ints (hd (tl IV))
                       C0 (rat-num (as-rat (hd Ints)))
                       Cn (rat-num (as-rat (last-of Ints)))
                       (if (or (= C0 0) (= Cn 0))
                           (roots-with-zero Vec)
                           (candidate-roots Vec C0 Cn)))))) \\ test against ORIGINAL Vec

\\ if constant term is 0, x=0 is a root; recurse on the deflated poly's roots.
(define roots-with-zero
  Vec -> [(make-rat 0 1) | (rational-roots (hd (uni-divmod Vec [[int 0] [int 1]])))])

\\ candidate p/q with p | C0, q | Cn ; keep those that are actual roots of Vec.
(define candidate-roots
  Vec C0 Cn -> (filter-roots Vec
                  (dedup-rats (gen-candidates (divisors (abs-num C0))
                                              (divisors (abs-num Cn))))))

\\ generate +-p/q candidates from divisor lists.
(define gen-candidates
  Ps Qs -> (gen-cand-p Ps Qs))

(define gen-cand-p
  [] _ -> []
  [P | Ps] Qs -> (append (gen-cand-q P Qs) (gen-cand-p Ps Qs)))

(define gen-cand-q
  _ [] -> []
  P [Q | Qs] -> [(make-rat P Q) (make-rat (- 0 P) Q) | (gen-cand-q P Qs)])

\\ divisors of a positive integer N (1..N). Bounded; trap-error wraps the caller.
(define divisors
  N -> (if (<= N 0) [1] (divisors-loop N 1 [])))

(define divisors-loop
  N I Acc -> (if (> I N)
                 (reverse Acc)
                 (if (= (- N (* (intdiv N I) I)) 0)
                     (divisors-loop N (+ I 1) [I | Acc])
                     (divisors-loop N (+ I 1) Acc))))

(define dedup-rats
  [] -> []
  [R | Rs] -> (if (rat-member? R Rs) (dedup-rats Rs) [R | (dedup-rats Rs)]))

(define rat-member?
  _ [] -> false
  R [X | Xs] -> (if (num-eq? R X) true (rat-member? R Xs)))

\\ keep candidates that are actual roots: poly evaluated at r = 0.
(define filter-roots
  _ [] -> []
  Vec [R | Rs] -> (if (num-eq? (vec-eval Vec R) [int 0])
                      [R | (filter-roots Vec Rs)]
                      (filter-roots Vec Rs)))

\\ evaluate a coeff vector at numeric point R (Horner-ish, ascending).
(define vec-eval
  Vec R -> (vec-eval-loop (trim-coeffs Vec) R [int 1] [int 0]))

(define vec-eval-loop
  [] _ _ Acc -> Acc
  [C | Cs] R Pow Acc -> (vec-eval-loop Cs R (num-mul Pow R) (num-add Acc (num-mul C Pow))))

\\ clear denominators: multiply by the lcm of denominators so all coeffs integer.
\\ Returns [some IntVec] / [none] on overflow. Best-effort; soundness is enforced
\\ by the final Expand self-check, so a conservative [none] only loses roots.
(define clear-denoms
  Vec -> (trap-error [some (clear-denoms! (trim-coeffs Vec))] (/. E [none])))

(define clear-denoms!
  Vec -> (let L (vec-lcm-denom Vec 1)
              (vec-clear Vec L)))

(define vec-lcm-denom
  [] Acc -> Acc
  [C | Cs] Acc -> (vec-lcm-denom Cs (lcm-int Acc (rat-den (as-rat C)))))

(define lcm-int
  A B -> (intdiv (* A B) (gcd A B)))

(define vec-clear
  [] _ -> []
  [C | Cs] L -> [(num-mul C [int L]) | (vec-clear Cs L)])

(output "polyalg.shen loaded (univariate Q: PolynomialGCD/Cancel/Together/Factor).~%")
