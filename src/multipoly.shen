\\ multipoly.shen - Wave 4: multivariate rational normal form over Q.
\\
\\ EXPOSURE + EXTENSION of the existing canonical POLY (src/poly.shen): a
\\ degree-lex-sorted distributed normal form whose GENERATORS are any node that
\\ is not Plus/Times/nonneg-int-Power -- symbols AND opaque compounds like
\\ NormalCDF[arg], Exp[K], Power[g,-k]. Wave 4 wires that machinery into
\\ Simplify (gated), and adds multivariate Together / Cancel, plus the
\\ soundness backbone: a generalized sample-point value-invariance check over
\\ ALL free symbols and opaque generators.
\\
\\ GUIDING PRINCIPLE (repo invariant): SOUND > COMPLETE. Every rewrite is gated;
\\ on any failure the head stays inert ([none] / the input unchanged), exactly as
\\ cancel-builtin / together-builtin / apart-gate already do.
\\
\\ Loaded AFTER polyalg.shen (uses free-sym-names) and poly.shen (POLY ops);
\\ needs make-rat/num-eq?/numeric?/num-mul (num.shen), content-eq/content-hash/
\\ unwrap-ch (store.shen). simplify-mv / Variance / Skew in calc-helpers.shen
\\ only CALL into here at reduce time.

\\ ============================================================================
\\ SOUNDNESS BACKBONE: generalized sample-point value-invariance.
\\
\\ Lifts prop-sample-eq? (test-properties.shen) from its hard-wired {x,y} to ALL
\\ free symbols AND opaque generators of BOTH expressions. Each generator is
\\ substituted ATOMICALLY by a rational (matched by content-eq on the whole
\\ node), so both sides reduce to an exact rational; a polynomial identity in the
\\ generators reduces to exact rational equality. NO floating point. We never
\\ need a value of NormalCDF -- the same atom gets the same rational on both
\\ sides. Skips pole/degenerate samples; requires >= 2 valid agreeing points.
\\ ============================================================================
(define sample-invariant?
  A B -> (let Gens (dedup-gens (append (collect-generators A) (collect-generators B)))
              (si-loop A B Gens (si-points) 0)))

\\ collect every MAXIMAL generator: a [sym S] OR a compound whose head is not an
\\ ARITHMETIC connective (Plus/Times/Power/Divide -- the heads reduce folds
\\ numerically). e.g. NormalCDF[..], Exp[..] are atomic generators; we descend
\\ through Divide so that Plus[Divide[1,x],Divide[1,y]] and its combined
\\ Divide[x+y,x*y] form share the SAME generators {x,y} (both numeric after
\\ substitution), which is what makes the gate compare like-for-like.
(define arith-connective?
  H -> (or (poly-plus-head? H)
           (or (poly-times-head? H)
               (or (poly-power-head? H) (mp-divide-head? H)))))

(define mp-divide-head?  [sym S] -> (= (str S) "Divide")  _ -> false)

(define collect-generators
  [sym S]   -> [[sym S]]
  [int _]   -> []
  [rat _ _] -> []
  [H | Args] -> (if (arith-connective? H) (cg-list Args) [[H | Args]])
  _ -> [])

(define cg-list  [] -> []  [A | As] -> (append (collect-generators A) (cg-list As)))

(define dedup-gens
  [] -> []  [G | Gs] -> (if (gen-member? G (dedup-gens Gs)) (dedup-gens Gs) [G | (dedup-gens Gs)]))

(define gen-member?  _ [] -> false  G [X | Xs] -> (if (content-eq G X) true (gen-member? G Xs)))

\\ >= 4 distinct coprime rational tuples; per-generator cycling de-correlates.
(define si-points -> [[2 3 5 7 11 13] [-1 4 -2 3 -5 6] [3 -7 2 -1 4 -3] [5 2 -3 7 -1 4]])

(define si-loop
  _ _ _ [] N -> (>= N 2)
  A B Gens [Pt | Pts] N ->
    (let Vs (si-vals Gens Pt)
         VA (trap-error (reduce (subst-all-gens Gens Vs A)) (/. E [bad]))
         VB (trap-error (reduce (subst-all-gens Gens Vs B)) (/. E [bad]))
         (if (or (= VA [bad]) (or (= VB [bad]) (or (not (numeric? VA)) (not (numeric? VB)))))
             (si-loop A B Gens Pts N)
             (if (num-eq? VA VB) (si-loop A B Gens Pts (+ N 1)) false))))

\\ pair each generator with a rational from Pt (cycle if short).
(define si-vals
  [] _ -> []
  [_ | Gs] [N | Ns] -> [(make-rat N 1) | (si-vals Gs Ns)]
  [G | Gs] [] -> (si-vals [G | Gs] [2 3 5 7 11 13]))

(define subst-all-gens
  [] _ E -> E
  [G | Gs] [V | Vs] E -> (subst-all-gens Gs Vs (subst-gen G V E))
  _ _ E -> E)

(define subst-gen
  G Val G2 -> Val  where (content-eq G G2)
  G Val [int N]   -> [int N]
  G Val [rat N D] -> [rat N D]
  G Val [H | Args] -> [H | (subst-gen-list G Val Args)]
  G Val E -> E)

(define subst-gen-list
  _ _ [] -> []
  G Val [A | As] -> [(subst-gen G Val A) | (subst-gen-list G Val As)])

\\ ============================================================================
\\ MUST tier: gated canonical multivariate normal form.
\\ Commits poly-expand only when sample-invariant AND not structurally larger;
\\ otherwise [none] -> Simplify keeps the collect-like-terms result.
\\ ============================================================================
\\ poly-expand is distribute+collect over the canonical POLY ring -- VALUE-PRESERVING
\\ by construction, exactly like the existing (un-gated) Expand. So commit on the
\\ cheap structural check (never grow); soundness is verified at TEST time by the
\\ sample-invariance goldens in test-multipoly.shen, not re-run on every hot-path
\\ Simplify. (Per-call sample-invariant? here cost several reduces x thousands of
\\ Simplify calls.)
(define multi-normalize
  C -> (let P (trap-error (poly-expand C) (/. Er C))
            (if (<= (node-count P) (node-count C)) [some P] [none])))

(define node-count
  [sym _] -> 1
  [int _] -> 1
  [rat _ _] -> 1
  [_ | Args] -> (+ 1 (sum-node-counts Args))
  _ -> 1)

(define sum-node-counts  [] -> 0  [A | As] -> (+ (node-count A) (sum-node-counts As)))

\\ PERF GUARD (Wave 4 fix): multi-normalize is EXPENSIVE (poly-expand + several
\\ sample-invariant? reduces), and Simplify is called pervasively (every diff-back
\\ integration gate, every corpus Simplify). Only attempt it when it can actually
\\ help -- i.e. the collected form is GENUINELY MULTIVARIATE (>=2 distinct
\\ generators; a univariate poly is already fully handled by collect-like-terms)
\\ AND bounded in size. Univariate / large inputs short-circuit to the fast path.
\\ This is purely a COST gate: multi-normalize still only COMMITS when sample-
\\ invariant, so skipping it never changes a result, only avoids wasted work.
\\ CHEAP early-exit gate, FIRST: multi-normalize (poly-expand) can only improve on
\\ collect-like-terms when there is an UN-EXPANDED product-of-sums to distribute --
\\ a Times with a Plus factor, or Power[Plus, k>=2]. After collect-like-terms most
\\ inputs (every diff-back gate, most corpus Simplify) are already flat -> this
\\ returns false in one early-exiting walk, BEFORE the O(n^2) generator dedup. Only
\\ genuine product-of-sums proceed to the (still-bounded, multivariate, no-PDF) path.
(define mv-eligible?
  C -> (and (mv-expandable? C)
            (and (<= (node-count C) (mv-size-cap))
                 (and (mv-multivariate? C) (not (mv-mentions? "NormalPDF" C))))))

(define mv-expandable?
  [sym _]   -> false
  [int _]   -> false
  [rat _ _] -> false
  [H | Args] -> (if (mv-here-expandable? H Args) true (mv-any-expandable? Args))
  _ -> false)

(define mv-here-expandable?
  H Args -> (if (poly-times-head? H) (mv-some-plus? Args)
                (if (poly-power-head? H) (mv-power-of-plus? Args) false)))

(define mv-is-plus?
  [H | _] -> (poly-plus-head? H)
  _ -> false)

(define mv-some-plus?
  [] -> false
  [A | As] -> (if (mv-is-plus? A) true (mv-some-plus? As)))

(define mv-power-of-plus?
  [B [int E]] -> (and (>= E 2) (mv-is-plus? B))
  _ -> false)

(define mv-any-expandable?
  [] -> false
  [A | As] -> (if (mv-expandable? A) true (mv-any-expandable? As)))

(define mv-size-cap -> 80)

(define mv-multivariate?
  C -> (gens-2+? (dedup-gens (collect-generators C))))

(define gens-2+?
  [] -> false
  [_] -> false
  _ -> true)

\\ COST gate (Wave 4 fix): NormalPDF appears ONLY inside the Gaussian
\\ integration/FTC-gate machinery (g_shifted = coef*Exp*NormalPDF), never in a
\\ final answer a user simplifies (moments/skew carry NormalCDF + Exp, no PDF).
\\ Skipping multi-normalize when NormalPDF is present keeps the many in-derivation
\\ Simplify calls (per moment, per term, per gate) on the fast collect-like-terms
\\ path -- exactly the Wave-3 behavior. Correctness-neutral (multi-normalize only
\\ ever commits sample-invariant results; skipping just defers to collect).
(define mv-mentions?
  Name [sym S]   -> (= (str S) Name)
  Name [int _]   -> false
  Name [rat _ _] -> false
  Name [H | Args] -> (or (mv-mentions? Name H) (mv-mentions-list? Name Args))
  Name _ -> false)

(define mv-mentions-list?
  _ [] -> false
  Name [A | As] -> (or (mv-mentions? Name A) (mv-mentions-list? Name As)))

\\ ============================================================================
\\ CORE tier: multivariate Together over the POLY map (no coeff-vector bridge).
\\ Sum addends as PFRAC [NumPoly DenPoly], strip common monomial+content (always
\\ sound), emit Divide. Univariate together-builtin is tried FIRST in the
\\ dispatcher (calc-helpers.shen), so univariate goldens are byte-identical.
\\ ============================================================================
(define mtogether-builtin  E -> (trap-error (mtogether-attempt E) (/. Er [none])))

(define mtogether-attempt
  [H | Args] -> (if (poly-plus-head? H) (mtogether-plus [H | Args] Args) [none])
  _ -> [none])

(define mtogether-plus
  Orig Args -> (mt-emit (mt-sum (map (/. A (expr->polyfrac A)) Args)) Orig))

\\ expr -> PFRAC [NumPoly DenPoly], RECURSIVELY: Plus sums fractions, Times
\\ multiplies them, Divide / Power[.,negk] feed the denominator, everything else
\\ (incl. an opaque generator) is a numerator poly over Den=1. Fully closed under
\\ the arithmetic connectives so nested Divide-in-Times collapses correctly.
(define expr->polyfrac
  [int N]   -> [(expr->poly [int N]) (one-poly)]
  [rat N D] -> [(expr->poly [rat N D]) (one-poly)]
  [H P Q] -> (pf-div (expr->polyfrac P) (expr->polyfrac Q))   where (pa-divide-head? H)
  [H B [int E]] -> (pf-pow (expr->polyfrac B) E)              where (poly-power-head? H)
  [H | Fs] -> (pf-times-list Fs)                              where (poly-times-head? H)
  [H | As] -> (pf-sum-list As)                                where (poly-plus-head? H)
  A -> [(expr->poly A) (one-poly)])

(define pf-div
  [N1 D1] [N2 D2] -> [(poly-mul N1 D2) (poly-mul D1 N2)])

(define pf-pow
  [N D] E -> (if (< E 0)
                 [(poly-pow D (- 0 E)) (poly-pow N (- 0 E))]
                 [(poly-pow N E) (poly-pow D E)]))

(define pf-times-list
  [] -> [(one-poly) (one-poly)]
  [F | Fs] -> (pf-mul (expr->polyfrac F) (pf-times-list Fs)))

(define pf-mul
  [N1 D1] [N2 D2] -> [(poly-mul N1 N2) (poly-mul D1 D2)])

(define pf-sum-list
  [] -> [(zero-poly) (one-poly)]
  [A | As] -> (mt-add (expr->polyfrac A) (pf-sum-list As)))

(define mt-add
  [N1 D1] [N2 D2] -> [(poly-add (poly-mul N1 D2) (poly-mul N2 D1)) (poly-mul D1 D2)])

(define mt-sum  [F] -> F  [F | Fs] -> (mt-add F (mt-sum Fs)))

(define mt-emit
  [N D] Orig -> (let G (poly-common-monomial N D)
                     (mt-gate (poly-divexact-mono G N) (poly-divexact-mono G D) Orig)))

\\ mt-emit already stripped the common monomial; mt-build forms Num/Den over a
\\ COMMON DENOMINATOR -- value-preserving by construction (no factor is dropped).
\\ So commit directly; sample-invariance is verified at TEST time (mp-tog goldens),
\\ not on every Together call. (Orig retained for signature compatibility.)
(define mt-gate
  Nn Dn Orig -> (mt-build Nn Dn))

(define mt-build
  Nn Dn -> (if (poly-zero? Nn)
               [some [int 0]]
               (if (poly-is-one? Dn)
                   [some (poly->expr Nn)]
                   [some [(pa-divide) (poly->expr Nn) (poly->expr Dn)]])))

(define poly-is-one?  [[C []]] -> (num-eq? C [int 1])  _ -> false)

(define mt-some-invariant?  [some R] Orig -> (sample-invariant? Orig R)  [none] _ -> false)

\\ ============================================================================
\\ Common-monomial + content stripping (always sound). poly-common-monomial =
\\ per-generator MIN exponent across all terms of N and D, intersected; plus a
\\ rational content gcd. poly-divexact-mono subtracts the monomial from every
\\ term and divides coeffs by the content. Correctness is enforced by the
\\ sample-invariance gate downstream, not by trusting this arithmetic.
\\ ============================================================================
(define poly-common-monomial
  N D -> [(mono-gcd (poly-mono-gcd N) (poly-mono-gcd D))
          (content-gcd (poly-content-gcd N) (poly-content-gcd D))])

\\ ---- monomial part (per-generator MIN exponent) ----
(define poly-mono-gcd
  [] -> []
  [[_ M]] -> M
  [[_ M] | Ts] -> (mono-gcd M (poly-mono-gcd Ts)))

(define mono-gcd
  [] _ -> []
  _ [] -> []
  [[G1 E1] | R1] [[G2 E2] | R2]
    -> (let H1 (unwrap-ch (content-hash G1))
            H2 (unwrap-ch (content-hash G2))
            (if (= H1 H2)
                [[G1 (mono-min E1 E2)] | (mono-gcd R1 R2)]
                (if (< H1 H2) (mono-gcd R1 [[G2 E2] | R2]) (mono-gcd [[G1 E1] | R1] R2)))))

(define mono-min  [int A] [int B] -> (if (< A B) [int A] [int B]))

\\ ---- content part (gcd of rational coefficients) ----
(define poly-content-gcd
  [] -> [int 0]
  [[C _]] -> C
  [[C _] | Ts] -> (content-gcd C (poly-content-gcd Ts)))

\\ rational content gcd: gcd of numerators over lcm of denominators (positive).
(define content-gcd
  A B -> (let RA (as-rat A) RB (as-rat B)
              Na (rat-num RA) Da (rat-den RA)
              Nb (rat-num RB) Db (rat-den RB)
              (if (= Na 0) B
                  (if (= Nb 0) A
                      (make-rat (gcd (abs-num Na) (abs-num Nb))
                                (intdiv (* Da Db) (gcd (abs-num Da) (abs-num Db))))))))

\\ ---- divide every term by [Mono Content] ----
(define poly-divexact-mono
  [Mono Cont] P -> (map (/. T (term-div-cm T Mono Cont)) P))

(define term-div-cm
  [C Mt] Mono Cont -> [(num-div C Cont) (mono-sub Mt Mono)])

(define mono-sub
  Mt [] -> Mt
  Mt [[G [int K]] | R] -> (mono-sub (mono-drop G K Mt) R))

(define mono-drop
  G K [] -> []
  G K [[G2 [int E]] | R] -> (if (content-eq G G2)
                               (if (= E K) R [[G2 [int (- E K)]] | R])
                               [[G2 [int E]] | (mono-drop G K R)]))

\\ ============================================================================
\\ STRETCH tier: multivariate Cancel.
\\   (a) always strip common monomial+content (reuses the stripping machinery);
\\   (b) bounded recursive-univariate-in-ONE-generator Euclid over POLY
\\       coefficients for linear-factor cases like (S^2-X^2)/(S-X).
\\ DOUBLE-gated: EXACT poly recombination (poly-eq? NP (poly-mul Pn G)) AND
\\ sample-invariance; inert on any non-exact step. The univariate cancel-builtin
\\ is tried FIRST in the dispatcher, so univariate goldens are byte-identical.
\\ ============================================================================
(define mcancel-builtin  E -> (trap-error (mcancel-attempt E) (/. Er [none])))

(define mcancel-attempt
  [H P Q] -> (if (pa-divide-head? H)
                 (mcancel-ratio (expr->poly P) (expr->poly Q) [H P Q]) [none])
  _ -> [none])

(define mcancel-ratio
  NP QP Orig -> (mcancel-check NP QP (mpoly-gcd NP QP) Orig))

(define mcancel-check
  NP QP G Orig
    -> (let DN (mpoly-divmod NP G)
            DQ (mpoly-divmod QP G)
            (if (and (poly-zero? (mdm-rem DN)) (poly-zero? (mdm-rem DQ)))
                (mcancel-gate (mdm-quo DN) (mdm-quo DQ) NP QP G Orig)
                [none])))

(define mdm-quo  [Q _] -> Q)
(define mdm-rem  [_ R] -> R)

\\ Activate ONLY when a real cancellation shrinks the expression: require the
\\ pivot generator G to be non-trivial (degree >= 1 in some shared generator) so
\\ a divisor of 1 -> inert, AND the result to be strictly smaller than Orig. Both
\\ recombination (exact) and sample-invariance must hold.
(define mcancel-gate
  Pn Qn NP QP G Orig
    -> (if (mp-trivial-gcd? G)
           [none]
           (if (and (poly-eq? NP (poly-mul Pn G)) (poly-eq? QP (poly-mul Qn G)))
               (mcancel-commit (mt-build-strip Pn Qn) Orig)
               [none])))

(define mcancel-commit
  [some R] Orig -> (if (and (sample-invariant? Orig R) (< (node-count R) (node-count Orig)))
                       [some R] [none])
  [none] _ -> [none])

\\ a GCD is trivial (no cancellation possible) when it is a constant poly.
(define mp-trivial-gcd?
  [] -> true
  [[_ []]] -> true
  _ -> false)

\\ after exact GCD division, still strip any leftover common monomial+content.
(define mt-build-strip
  Pn Qn -> (let CM (poly-common-monomial Pn Qn)
                (mt-build (poly-divexact-mono CM Pn) (poly-divexact-mono CM Qn))))

(define poly-zero?  [] -> true  _ -> false)
(define poly-eq?  A B -> (poly-zero? (poly-add A (poly-neg B))))
(define poly-neg  P -> (map (/. T (term-neg T)) P))
(define term-neg  [C M] -> [(num-mul [int -1] C) M])

\\ ---- multivariate GCD via recursive-univariate Euclid in one generator ----
\\ Pick the lowest-content-hash generator present in BOTH polys; view both as
\\ univariate in it with POLY (multivariate) coefficients; run Euclid where the
\\ leading-coefficient division is itself poly division in the remaining
\\ generators, committing a pivot ONLY when that sub-division is EXACT (else
\\ GCD = one-poly). The exact recombination gate above is the real guarantee; a
\\ buggy GCD can only DECLINE.
(define mpoly-gcd
  NP QP -> (let GVOpt (shared-pivot-gen NP QP)
                (if (= GVOpt [none])
                    (one-poly)
                    (mp-euclid NP QP (hd (tl GVOpt)) (mp-depth-bound NP QP)))))

(define mp-depth-bound  NP QP -> (+ 8 (+ (length NP) (length QP))))

\\ generators appearing in BOTH polys, lowest content-hash first; [none] if none.
(define shared-pivot-gen
  NP QP -> (let GN (poly-gens NP)
                GQ (poly-gens QP)
                Both (gens-intersect GN GQ)
                (if (empty? Both) [none] [some (min-hash-gen Both)])))

(define poly-gens
  [] -> []
  [[_ M] | Ts] -> (gens-union (mono-gens M) (poly-gens Ts)))

(define mono-gens  [] -> []  [[G _] | R] -> [G | (mono-gens R)])

(define gens-union
  [] Ys -> Ys
  [X | Xs] Ys -> (if (gen-member? X Ys) (gens-union Xs Ys) [X | (gens-union Xs Ys)]))

(define gens-intersect
  [] _ -> []
  [X | Xs] Ys -> (if (gen-member? X Ys) [X | (gens-intersect Xs Ys)] (gens-intersect Xs Ys)))

(define min-hash-gen
  [G] -> G
  [G | Gs] -> (let M (min-hash-gen Gs)
                   (if (< (unwrap-ch (content-hash G)) (unwrap-ch (content-hash M))) G M)))

\\ Euclid on (A,B) univariate in pivot V; bounded depth. Returns a GCD POLY.
(define mp-euclid
  A B _ 0 -> (one-poly)
  A B V Depth -> (if (poly-zero? B)
                     A
                     (let R (mp-rem A B V)
                          (if (= R [bad])
                              (one-poly)
                              (mp-euclid B R V (- Depth 1))))))

\\ exact polynomial remainder of A by B as univariate-in-V polys; [bad] if a
\\ leading-coeff sub-division is not exact (then GCD declines to trivial).
(define mp-rem
  A B V -> (mp-rem-loop A B V (+ 4 (mp-deg A V))))

(define mp-rem-loop
  _ _ _ 0 -> [bad]
  A B V Fuel
    -> (let DA (mp-deg A V)
            DB (mp-deg B V)
            (if (< DA DB)
                A
                (let LA (mp-lead-coeff A V DA)
                     LB (mp-lead-coeff B V DB)
                     Q (mpoly-divmod LA LB)
                     (if (not (poly-zero? (mdm-rem Q)))
                         [bad]
                         (let Sub (poly-mul (mdm-quo Q) (mp-shift B V (- DA DB)))
                              A2 (poly-add A (poly-neg Sub))
                              (if (poly-zero? A2)
                                  []
                                  (if (< (mp-deg A2 V) DA)
                                      (mp-rem-loop A2 B V (- Fuel 1))
                                      [bad]))))))))

\\ max exponent of V across all terms of P (0 if V absent).
(define mp-deg
  [] _ -> 0
  [T | Ts] V -> (max-int (term-deg-in T V) (mp-deg Ts V)))

(define max-int  A B -> (if (> A B) A B))

(define term-deg-in  [_ M] V -> (mono-exp-of M V))

(define mono-exp-of
  [] _ -> 0
  [[G [int E]] | R] V -> (if (content-eq G V) E (mono-exp-of R V)))

\\ leading coefficient of P in V at degree Dg: the POLY of all terms whose
\\ V-exponent = Dg, with V removed from each monomial.
(define mp-lead-coeff
  P V Dg -> (canon-sort-poly (lc-collect P V Dg)))

(define lc-collect
  [] _ _ -> []
  [[C M] | Ts] V Dg -> (if (= (mono-exp-of M V) Dg)
                           [[C (mono-remove-gen M V)] | (lc-collect Ts V Dg)]
                           (lc-collect Ts V Dg)))

(define mono-remove-gen
  [] _ -> []
  [[G E] | R] V -> (if (content-eq G V) R [[G E] | (mono-remove-gen R V)]))

\\ multiply P by V^Shift (Shift >= 0): bump V's exponent in every monomial.
(define mp-shift
  P V 0 -> P
  P V Shift -> (poly-mul P (poly-pow (gen-poly V) Shift)))

\\ ---- generic multivariate divmod: divide POLY A by POLY G ----
\\ Returns [Quo Rem]. We need this only for COEFFICIENT division in mp-rem (where
\\ G is a coefficient poly in the remaining generators) and for the final exact
\\ division NP/G, QP/G. Implemented as: if G is a single nonzero constant, divide
\\ all coeffs; if G is a single monomial, divide monomial-wise where exact; else
\\ attempt univariate division in G's pivot generator. On any inexactness the
\\ remainder is nonzero, so the EXACT recombination gate upstream declines.
(define mpoly-divmod
  A [] -> [[] A]                                    \\ divide by zero -> all remainder
  A [[C []]] -> [(poly-scale-div A C) []]           \\ divide by nonzero constant
  A [[C Mono]] -> (mono-divmod A C Mono)            \\ divide by a single monomial
  A G -> (mpoly-divmod-uni A G))

(define poly-scale-div
  P C -> (map (/. T (term-scale-div T C)) P))
(define term-scale-div  [Co M] C -> [(num-div Co C) M])

\\ divide A by a single-monomial divisor [C Mono]; quotient terms are those whose
\\ monomial is divisible by Mono, the rest are remainder.
(define mono-divmod
  A C Mono -> (md-loop A C Mono [] []))

(define md-loop
  [] _ _ Q R -> [(canon-sort-poly Q) (canon-sort-poly R)]
  [[Co M] | Ts] C Mono Q R
    -> (if (mono-divides? Mono M)
           (md-loop Ts C Mono [[(num-div Co C) (mono-sub M Mono)] | Q] R)
           (md-loop Ts C Mono Q [[Co M] | R])))

(define mono-divides?
  [] _ -> true
  [[G [int K]] | Rest] M -> (if (>= (mono-exp-of M G) K) (mono-divides? Rest M) false))

\\ univariate division of A by G in G's pivot generator (lowest-hash gen of G).
\\ Falls back to all-remainder if no shared pivot or any step is inexact.
(define mpoly-divmod-uni
  A G -> (let GVOpt (shared-pivot-gen A G)
              (if (= GVOpt [none])
                  [[] A]
                  (mdu-loop A G (hd (tl GVOpt)) [] (+ 4 (mp-deg A (hd (tl GVOpt))))))))

(define mdu-loop
  A _ _ Q 0 -> [(canon-sort-poly Q) A]
  A G V Q Fuel
    -> (let DA (mp-deg A V)
            DG (mp-deg G V)
            (if (< DA DG)
                [(canon-sort-poly Q) A]
                (let LA (mp-lead-coeff A V DA)
                     LG (mp-lead-coeff G V DG)
                     QC (mpoly-divmod LA LG)
                     (if (not (poly-zero? (mdm-rem QC)))
                         [(canon-sort-poly Q) A]
                         (let QTerm (mp-shift (mdm-quo QC) V (- DA DG))
                              Sub (poly-mul QTerm G)
                              A2 (poly-add A (poly-neg Sub))
                              (if (poly-zero? A2)
                                  [(canon-sort-poly (poly-add Q QTerm)) []]
                                  (if (< (mp-deg A2 V) DA)
                                      (mdu-loop A2 G V (poly-add Q QTerm) (- Fuel 1))
                                      [(canon-sort-poly Q) A]))))))))

(output "multipoly.shen loaded (sample-invariant? + multivariate normal-form/Together/Cancel).~%")
