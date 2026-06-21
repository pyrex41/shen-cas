\\ test-calculus.shen - SCUD 22 Wave 6: calculus corpus + executable rejection showcase.
\\ Loaded by load.shen BEFORE test/test.shen so run-all-tests can call run-calculus-tests.
\\ The differentiation/integration goldens proper live inline in test.shen (test-differentiation,
\\ test-integration). This file adds: (a) extra differentiate-back self-checks on cases not in the
\\ inline set, and (b) the thesis showcase -- a realistic calculus rule BUG caught at definition time.

(define tc-dvar -> [sym (protect xd)])
(define tc-d   E -> [[sym (protect D)] E (tc-dvar)])
(define tc-int E -> [[sym (protect Integrate)] E (tc-dvar)])

\\ differentiate-back self-check: d/dx (integral of F) must return F (Simplify[D[R]-F] == 0).
\\ This cannot be fooled by a table typo -- a wrong antiderivative fails the derivative check.
(define tc-diff-back?
  F -> (let R (reduce (tc-int F))
            Back (reduce [[sym (protect Simplify)]
                          [[sym (protect Plus)] (tc-d R) [[sym (protect Times)] [int -1] F]]])
            (content-eq Back [int 0])))

\\ THESIS SHOWCASE: a realistic derivative rule with a typo -- the chain-rule RHS
\\ references (sym v) but only u and x are bound on the LHS. bindings-cover? must
\\ reject this at registration, turning a silent runtime mis-derivative into a
\\ definition-time error.
(define tc-rej-typo-derivative
  -> (trap-error
        (do (register-rule
              (rule [[sym (protect D)] [[sym (protect Sin)] (named (protect u) (blank))] (named (protect xd) (blank))]
                    [[sym (protect Times)] [[sym (protect Cos)] [sym (protect v)]]
                                           [[sym (protect D)] [sym (protect u)] [sym (protect xd)]]]))
            false)
        (/. E true)))

\\ Gaussian Wave 1 goldens: prove the DEFINING differential relations (derivations,
\\ not tabulations) and INERTNESS of unsupported forms. Orderless Times goldens use
\\ term-set-eq? (multiset); bare-equality goldens use content-eq.
(define tc-normal-tests
  -> (let X (tc-dvar)
          NCDF (/. E [[sym (protect NormalCDF)] E])
          NPDF (/. E [[sym (protect NormalPDF)] E])
          G1 (content-eq (reduce (tc-d (NCDF X))) (NPDF X))
          G2 (term-set-eq? (reduce [[sym (protect Simplify)] (tc-d (NPDF X))])
                           [[sym (protect Times)] [int -1] X (NPDF X)])
          AX [[sym (protect Times)] [sym (protect aW1)] X]
          G3 (term-set-eq? (reduce [[sym (protect Simplify)] (tc-d (NCDF AX))])
                           [[sym (protect Times)] [sym (protect aW1)] (NPDF AX)])
          G4 (content-eq (reduce (tc-int (NPDF X))) (NCDF X))
          G5 (content-eq (reduce (NCDF X)) (NCDF X))
          R6 (reduce (tc-int [[sym (protect Times)] [[sym (protect Exp)] X] (NPDF X)]))
          G6 (= (head R6) [sym (protect Integrate)])
          Ok (and G1 (and G2 (and G3 (and G4 (and G5 G6)))))
          (do (output "wave1 normal: Ncdf=~A Npdf=~A chain=~A intpdf=~A inert-cdf=~A inert-prod=~A~%" G1 G2 G3 G4 G5 G6)
              (if Ok (output "gaussian wave 1: PASS~%") (output "gaussian wave 1: FAIL~%"))
              Ok)))

\\ ===========================================================================
\\ GAUSSIAN WAVE 2 goldens: the DEFINITE half-line Gaussian integral
\\   Integrate[e^(j u) NormalPDF[u], {u,-Infinity,c}] -> e^(j^2/2) NormalCDF[c-j]
\\ DERIVED by completing the square (csq-vertex), FTC + square-completion gated.
\\ Goldens prove (a) the derivation for several j (distinct e^{j^2/2}, c-j -- the
\\ anti-tabulation witness), (b) linearity, (c) csq-vertex genericity on a
\\ NON-Gaussian quadratic, (d) the round-trip FTC + negative control, (e) the
\\ inertness boundary. The closed form is NEVER pasted: it falls out of arithmetic.
\\ ===========================================================================

\\ build the definite-integral iterator AST directly (reader not extended in W2).
(define w2-defint
  G U Lo C -> [[sym (protect Integrate)] G [[sym (protect List)] U Lo C]])
(define w2-uu      -> [sym (protect uu)])
(define w2-cc      -> [sym (protect cc)])
(define w2-neg-inf -> [[sym (protect Times)] [int -1] [sym (protect Infinity)]])

\\ integrand e^(J u) * NormalPDF[u]
(define w2-egphi
  J -> [[sym (protect Times)]
         [[sym (protect Exp)] [[sym (protect Times)] J (w2-uu)]]
         [[sym (protect NormalPDF)] (w2-uu)]])

\\ run the half-line integral with lower limit -Infinity and upper limit c.
(define w2-run
  G -> (reduce (w2-defint G (w2-uu) (w2-neg-inf) (w2-cc))))

\\ expected e^K * NormalCDF[c - S] (reduced so c + (-1*S) folds to canonical form).
(define w2-expected
  K S -> (reduce [[sym (protect Times)] [[sym (protect Exp)] K]
                  [[sym (protect NormalCDF)] [[sym (protect Plus)] (w2-cc) [[sym (protect Times)] [int -1] S]]]]))

\\ inert: head must remain Integrate (the matcher declined cleanly).
(define w2-inert?
  G U Lo C -> (= (head (reduce (w2-defint G U Lo C))) [sym (protect Integrate)]))

(define w2-gaussian-tests
  -> (let
          \\ (a) DERIVATION goldens: distinct j -> distinct e^{j^2/2}, c-j.
          D2  (term-set-eq? (w2-run (w2-egphi [int 2]))   (w2-expected [int 2]   [int 2]))    \\ e^{4/2}=e^2, c-2
          D1  (term-set-eq? (w2-run (w2-egphi [int 1]))   (w2-expected [rat 1 2] [int 1]))    \\ e^{1/2},   c-1
          Dn1 (term-set-eq? (w2-run (w2-egphi [int -1]))  (w2-expected [rat 1 2] [int -1]))   \\ e^{1/2},   c+1
          Dh  (term-set-eq? (w2-run (w2-egphi [rat 1 2])) (w2-expected [rat 1 8] [rat 1 2]))  \\ e^{1/8},   c-1/2
          \\ (b) LINEARITY: a*e^{u}phi + b*e^{2u}phi distributes (a,b u-free).
          Lin (term-set-eq?
                (w2-run [[sym (protect Plus)]
                          [[sym (protect Times)] [sym (protect aW2)] [[sym (protect Exp)] [[sym (protect Times)] [int 1] (w2-uu)]] [[sym (protect NormalPDF)] (w2-uu)]]
                          [[sym (protect Times)] [sym (protect bW2)] [[sym (protect Exp)] [[sym (protect Times)] [int 2] (w2-uu)]] [[sym (protect NormalPDF)] (w2-uu)]]])
                [[sym (protect Plus)]
                  [[sym (protect Times)] [sym (protect aW2)] [[sym (protect Exp)] [rat 1 2]] [[sym (protect NormalCDF)] [[sym (protect Plus)] (w2-cc) [int -1]]]]
                  [[sym (protect Times)] [sym (protect bW2)] [[sym (protect Exp)] [int 2]]   [[sym (protect NormalCDF)] [[sym (protect Plus)] (w2-cc) [int -2]]]]])
          \\ (c) csq-vertex GENERICITY (NON-Gaussian): x^2+6x+5 -> [-3, -4]; -3u^2+2u -> [1/3, 1/3].
          CsqA (content-eq (csq-vertex [int 1]  [int 6] [int 5]) [[int -3] [int -4]])
          CsqB (content-eq (csq-vertex [int -3] [int 2] [int 0]) [[rat 1 3] [rat 1 3]])
          \\ ...and the Gaussian constant IS csq-vertex[-1/2, j, 0].const: for j=2 -> [Shift=2, K=2].
          CsqG (content-eq (csq-vertex [rat -1 2] [int 2] [int 0]) [[int 2] [int 2]])
          \\ (d) ROUND-TRIP FTC + NEGATIVE control. gd-emit commits the right [Shift K]
          \\     and DECLINES a deliberately-wrong shift (3 instead of 2 for j=2).
          FtcPos (= (head-of (gd-emit [int 1] [[int 2] [int 2]] [int 0] [int 2] (w2-uu) (w2-cc))) some)
          FtcNeg (= (gd-emit [int 1] [[int 3] [int 2]] [int 0] [int 2] (w2-uu) (w2-cc)) [none])
          \\ (e) INERTNESS boundary.
          IPow  (w2-inert? [[sym (protect Times)] [[sym (protect Power)] [[sym (protect Plus)] [sym (protect kW2)] [[sym (protect Times)] [int -1] [[sym (protect Exp)] (w2-uu)]]] [int 2]] [[sym (protect NormalPDF)] (w2-uu)]] (w2-uu) (w2-neg-inf) (w2-cc))
          ILo   (w2-inert? (w2-egphi [int 1]) (w2-uu) [int 0] (w2-cc))                    \\ lower limit != -Infinity
          ISym  (w2-inert? [[sym (protect Times)] [[sym (protect Exp)] [[sym (protect Times)] [sym (protect kW2)] (w2-uu)]] [[sym (protect NormalPDF)] (w2-uu)]] (w2-uu) (w2-neg-inf) (w2-cc))  \\ symbolic j
          IQuad (w2-inert? [[sym (protect Times)] [[sym (protect Exp)] [[sym (protect Power)] (w2-uu) [int 2]]] [[sym (protect NormalPDF)] (w2-uu)]] (w2-uu) (w2-neg-inf) (w2-cc))           \\ e^{u^2}
          IDen  (w2-inert? [[sym (protect Times)] [[sym (protect Exp)] (w2-uu)] [[sym (protect OtherPDF)] (w2-uu)]] (w2-uu) (w2-neg-inf) (w2-cc))                                            \\ non-NormalPDF
          \\ NOTE: the former IGab golden (general-(a,b) NormalPDF[(u-3)/2]) is
          \\ RE-HOMED to w3-gaussian-tests as a DERIVATION golden -- Wave 3 OPENS
          \\ this seam (intended behavior change, flagged in the PR).
          I2pdf (w2-inert? [[sym (protect Times)] [[sym (protect Exp)] (w2-uu)] [[sym (protect NormalPDF)] (w2-uu)] [[sym (protect NormalPDF)] (w2-uu)]] (w2-uu) (w2-neg-inf) (w2-cc))  \\ TWO phi factors: e^u phi^2 must stay inert (never drop a density)
          Deriv (and D2 (and D1 (and Dn1 Dh)))
          Csq   (and CsqA (and CsqB CsqG))
          Ftc   (and FtcPos FtcNeg)
          Inert (and IPow (and ILo (and ISym (and IQuad (and IDen I2pdf)))))
          Ok (and Deriv (and Lin (and Csq (and Ftc Inert))))
          (do (output "wave2 deriv: j2=~A j1=~A jn1=~A jhalf=~A~%" D2 D1 Dn1 Dh)
              (output "wave2 linearity=~A csq[NG]=~A,~A csq[G]=~A ftc[pos]=~A ftc[neg]=~A~%" Lin CsqA CsqB CsqG FtcPos FtcNeg)
              (output "wave2 inert: pow=~A lo=~A symj=~A quad=~A den=~A 2pdf=~A~%" IPow ILo ISym IQuad IDen I2pdf)
              (if Ok (output "wave2 gaussian: PASS~%") (output "wave2 gaussian: FAIL~%"))
              Ok)))

\\ ===========================================================================
\\ GAUSSIAN WAVE 3 goldens: the GENERAL-(a,b) half-line lemma + E[P^x] moment.
\\   Integrate[e^(j u) NormalPDF[(u-a)/b] Power[b,-1], {u,-Inf,c}]
\\     -> e^(j a + j^2 b^2/2) NormalCDF[(c-a-j b^2)/b]
\\ DERIVED at A=-1/(2b^2) via the cleared-denominator square-completion gate.
\\ The e^(...) factor and the shifted/scaled CDF argument are COMPUTED from
\\ (a,b,j) -- distinct per j, the anti-tabulation witness -- never pasted.
\\ ===========================================================================

\\ standardized integrand e^(j u) * NormalPDF[(u-a)/b]  (no jacobian: result is
\\ exactly Exp[K]*NormalCDF[Arg], so K and Arg are read off directly).
(define w3-egphi
  J A B -> [[sym (protect Times)]
             [[sym (protect Exp)] [[sym (protect Times)] J (w2-uu)]]
             [[sym (protect NormalPDF)]
               [[sym (protect Times)]
                 [[sym (protect Plus)] (w2-uu) [[sym (protect Times)] [int -1] A]]
                 [[sym (protect Power)] B [int -1]]]]])

\\ expected b * e^K * NormalCDF[Arg] with K, Arg given as raw exprs (reduced).
\\ The MEASURE factor b is part of the true value of the half-line integral of
\\ e^(j u)*NormalPDF[(u-a)/b] (no jacobian): Integral phi((u-s)/b) du = b N((u-s)/b).
\\ Wave-2 standard (b=1) collapses this to e^K*N(Arg); for b!=1 the b survives,
\\ and the explicit density jacobian Power[b,-1] in expect-put-normal cancels it.
(define w3-expected
  B K Arg -> (reduce [[sym (protect Times)] B [[sym (protect Exp)] K]
                       [[sym (protect NormalCDF)] Arg]]))

\\ (c - a - j b^2)/b   and   j a + j^2 b^2/2, built and reduced for concrete a,b,j.
(define w3-arg
  C A B J -> [[sym (protect Times)]
               [[sym (protect Plus)] C [[sym (protect Times)] [int -1] A]
                 [[sym (protect Times)] [int -1] J [[sym (protect Power)] B [int 2]]]]
               [[sym (protect Power)] B [int -1]]])
(define w3-K
  A B J -> [[sym (protect Plus)] [[sym (protect Times)] J A]
             [[sym (protect Times)] [rat 1 2] [[sym (protect Power)] J [int 2]] [[sym (protect Power)] B [int 2]]]])

\\ run the general half-line integral (lower -Infinity, upper c).
(define w3-run
  G -> (reduce (w2-defint G (w2-uu) (w2-neg-inf) (w2-cc))))

\\ one derivation case: a,b,j concrete -> compare derived to computed b*Exp[K]*NCDF[Arg].
(define w3-deriv?
  A B J -> (term-set-eq? (w3-run (w3-egphi J A B))
                         (w3-expected B (reduce (w3-K A B J)) (reduce (w3-arg (w2-cc) A B J)))))

\\ symbolic scale symbols for the keystone golden.
(define w3-aa -> [sym (protect aW3)])
(define w3-bb -> [sym (protect bW3)])

(define w3-gaussian-tests
  -> (let
          \\ (a) DERIVATION (a=1,b=2): distinct K and Arg per j prove COMPUTATION.
          \\     j=1 -> Exp[3]*NCDF[(c-5)/2], j=2 -> Exp[10]*NCDF[(c-9)/2],
          \\     j=3 -> Exp[21]*NCDF[(c-13)/2].
          GD1 (w3-deriv? [int 1] [int 2] [int 1])
          GD2 (w3-deriv? [int 1] [int 2] [int 2])
          GD3 (w3-deriv? [int 1] [int 2] [int 3])
          \\ SANITY: (a=0,b=1) reduces to the Wave-2 standard answer e^{j^2/2}NCDF[c-j].
          GStd (term-set-eq? (w3-run (w3-egphi [int 2] [int 0] [int 1]))
                             (w2-expected [int 2] [int 2]))
          \\ (b) RE-HOMED former IGab: NormalPDF[(u-3)/2] (a=3,b=2,j=1) DERIVES now.
          \\     j*a+j^2 b^2/2 = 3+2 = 5; arg = (c-3-4)/2 = (c-7)/2. NO jacobian, so
          \\     the measure factor b=2 SURVIVES: result is 2*Exp[5]*NCDF[(c-7)/2]
          \\     (true value of Integral e^u phi((u-3)/2) du; verified by quadrature).
          GGab (term-set-eq? (w3-run (w3-egphi [int 1] [int 3] [int 2]))
                             (w3-expected [int 2] [int 5] (reduce (w3-arg (w2-cc) [int 3] [int 2] [int 1]))))
          \\     and WITH an explicit Power[2,-1] DENSITY JACOBIAN: the lemma's
          \\     measure factor b=2 cancels the 1/2 EXACTLY ONCE -> result is the
          \\     CLEAN Exp[5]*NCDF[(c-7)/2] (this is the path expect-put-normal uses;
          \\     it pins the jacobian as consumed-once, not double-counted nor dropped).
          GJac (term-set-eq?
                 (w3-run [[sym (protect Times)] [[sym (protect Power)] [int 2] [int -1]] (w3-egphi [int 1] [int 3] [int 2])])
                 (w3-expected [int 1] [int 5] (reduce (w3-arg (w2-cc) [int 3] [int 2] [int 1]))))
          \\ (c) SYMBOLIC KEYSTONE: gd-csq-ok-gen? == [int 0] for symbolic a,b and
          \\     the cleared identity gd-vtx-cleared - gd-intg-cleared Expands to 0.
          \\     Shift = a + j b^2, K = j a + j^2 b^2/2 (j0=0).
          KS1 (gd-csq-ok-gen? (reduce [[sym (protect Plus)] (w3-aa) [[sym (protect Times)] [int 1] [[sym (protect Power)] (w3-bb) [int 2]]]])
                              (reduce (w3-K (w3-aa) (w3-bb) [int 1])) [int 0] [int 1] (w3-aa) (w3-bb) (w2-uu))
          KS2 (gd-csq-ok-gen? (reduce [[sym (protect Plus)] (w3-aa) [[sym (protect Times)] [int 2] [[sym (protect Power)] (w3-bb) [int 2]]]])
                              (reduce (w3-K (w3-aa) (w3-bb) [int 2])) [int 0] [int 2] (w3-aa) (w3-bb) (w2-uu))
          \\     DIRECT cleared-identity Expand-to-0 (locks the gate against refactors).
          KDir (content-eq
                 (reduce [[sym (protect Expand)]
                   [[sym (protect Plus)]
                     (gd-vtx-cleared (reduce [[sym (protect Plus)] (w3-aa) [[sym (protect Power)] (w3-bb) [int 2]]]) (reduce (w3-K (w3-aa) (w3-bb) [int 1])) (w3-bb) (w2-uu))
                     [[sym (protect Times)] [int -1] (gd-intg-cleared [int 0] [int 1] (w3-aa) (w3-bb) (w2-uu))]]])
                 [int 0])
          \\     NEGATIVE control: wrong Shift (a + 2 j b^2) -> nonzero -> gate rejects.
          KNeg (not (gd-csq-ok-gen? (reduce [[sym (protect Plus)] (w3-aa) [[sym (protect Times)] [int 2] [int 1] [[sym (protect Power)] (w3-bb) [int 2]]]])
                                    (reduce (w3-K (w3-aa) (w3-bb) [int 1])) [int 0] [int 1] (w3-aa) (w3-bb) (w2-uu)))
          \\ (d) FTC round-trip + negatives (general lemma commit / decline).
          \\     concrete (a=1,b=2,j=1) commits [some]; symbolic (a,b) also commits
          \\     (exercises the reused FTC gate with the 1/b chain factor).
          FPos (= (head-of (gd-emit-gen [int 1] [int 0] [int 1] [int 1] [int 2] (w2-uu) (w2-cc))) some)
          FSym (= (head-of (gd-emit-gen [int 1] [int 0] [int 1] (w3-aa) (w3-bb) (w2-uu) (w2-cc))) some)
          \\     wrong K (a + 2 j^2 b^2/2 instead of j a + j^2 b^2/2) -> gate rejects.
          FNeg (not (gd-csq-ok-gen? (reduce [[sym (protect Plus)] (w3-aa) [[sym (protect Power)] (w3-bb) [int 2]]])
                                    (reduce [[sym (protect Plus)] (w3-aa) [[sym (protect Power)] (w3-bb) [int 2]]])
                                    [int 0] [int 1] (w3-aa) (w3-bb) (w2-uu)))
          \\ (e) E[P^x] MOMENT for x=1,2,3: must DERIVE (head some). NUMERIC params
          \\     (k=2, a=-1/50, b=3/20, r=1/100, T=1) keep the symbolic D/Simplify in
          \\     the per-term FTC gate small -- symbolic a,b moment assembly is sound
          \\     but the j=2,3 terms' Exp[2a+2b^2] blow up reduce, so the moment is
          \\     validated NUMERICALLY here (head=some) + the python quadrature/Erfc
          \\     oracle cross-check (scripts/wave3_put_moment_check.py); the per-term
          \\     ARGUMENT EMERGENCE is proven SYMBOLICALLY by GD1/GD2/GD3 above.
          M1 (= (head-of (expect-put-normal [int 1] [int 2] [rat -1 50] [rat 3 20] [rat 1 100] [int 1] (w2-uu))) some)
          M2 (= (head-of (expect-put-normal [int 2] [int 2] [rat -1 50] [rat 3 20] [rat 1 100] [int 1] (w2-uu))) some)
          M3 (= (head-of (expect-put-normal [int 3] [int 2] [rat -1 50] [rat 3 20] [rat 1 100] [int 1] (w2-uu))) some)
          \\ (f) INERTNESS: symbolic moment order x -> [none].
          ISymX (= (expect-put-normal (w3-xx) (w3-kk) (w3-aa) (w3-bb) (w3-rr) (w3-tt) (w2-uu)) [none])
          Deriv (and GD1 (and GD2 (and GD3 (and GStd (and GGab GJac)))))
          Keys  (and KS1 (and KS2 (and KDir KNeg)))
          Ftc   (and FPos (and FSym FNeg))
          Mom   (and M1 (and M2 M3))
          Ok (and Deriv (and Keys (and Ftc (and Mom ISymX))))
          (do (output "wave3 deriv: gd1=~A gd2=~A gd3=~A std=~A gab=~A jac=~A~%" GD1 GD2 GD3 GStd GGab GJac)
              (output "wave3 keystone: ks1=~A ks2=~A direct=~A neg-reject=~A~%" KS1 KS2 KDir KNeg)
              (output "wave3 moment: E[P^1]=~A E[P^2]=~A E[P^3]=~A inert-symx=~A~%" M1 M2 M3 ISymX)
              (if Ok (output "gaussian wave 3: PASS~%") (output "gaussian wave 3: FAIL~%"))
              Ok)))

(define w3-kk -> [sym (protect kW3)])
(define w3-rr -> [sym (protect rW3)])
(define w3-tt -> [sym (protect tW3)])
(define w3-xx -> [sym (protect xW3)])

(define run-calculus-tests
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== SCUD 22 calculus corpus + rejection showcase ===~%")
          X (tc-dvar)
          \\ differentiate-back on cases NOT covered by the inline SCUD 21 self-check:
          B1 (tc-diff-back? [[sym (protect Cos)] X])                       \\ ∫cos x dx = sin x
          B2 (tc-diff-back? [[sym (protect Plus)] [[sym (protect Power)] X [int 2]] X])  \\ ∫(x²+x) via linearity
          \\ realistic derivative-rule typo rejected at definition time (the thesis):
          Rej (tc-rej-typo-derivative)
          \\ Gaussian Wave 1 derivation + inertness goldens:
          W1 (tc-normal-tests)
          \\ Gaussian Wave 2 definite half-line integral goldens:
          W2 (w2-gaussian-tests)
          \\ Gaussian Wave 3 general-(a,b) lemma + E[P^x] moment goldens:
          W3 (w3-gaussian-tests)
          Ok (and B1 (and B2 (and Rej (and W1 (and W2 W3)))))
          (do (output "22: diffback[cos]=~A diffback[x^2+x]=~A typo-derivative-rejected=~A~%" B1 B2 Rej)
              (if Ok (output "calculus corpus (SCUD 22): PASS~%")
                  (output "calculus corpus (SCUD 22): FAIL~%"))
              Ok)))

(output "test-calculus.shen loaded (SCUD 22 corpus + executable rejection showcase).~%")
