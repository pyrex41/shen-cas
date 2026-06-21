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
          IGab  (w2-inert? [[sym (protect Times)] [[sym (protect Exp)] (w2-uu)] [[sym (protect NormalPDF)] [[sym (protect Times)] [[sym (protect Plus)] (w2-uu) [int -3]] [[sym (protect Power)] [int 2] [int -1]]]]] (w2-uu) (w2-neg-inf) (w2-cc))  \\ general-(a,b) seam
          I2pdf (w2-inert? [[sym (protect Times)] [[sym (protect Exp)] (w2-uu)] [[sym (protect NormalPDF)] (w2-uu)] [[sym (protect NormalPDF)] (w2-uu)]] (w2-uu) (w2-neg-inf) (w2-cc))  \\ TWO phi factors: e^u phi^2 must stay inert (never drop a density)
          Deriv (and D2 (and D1 (and Dn1 Dh)))
          Csq   (and CsqA (and CsqB CsqG))
          Ftc   (and FtcPos FtcNeg)
          Inert (and IPow (and ILo (and ISym (and IQuad (and IDen (and IGab I2pdf))))))
          Ok (and Deriv (and Lin (and Csq (and Ftc Inert))))
          (do (output "wave2 deriv: j2=~A j1=~A jn1=~A jhalf=~A~%" D2 D1 Dn1 Dh)
              (output "wave2 linearity=~A csq[NG]=~A,~A csq[G]=~A ftc[pos]=~A ftc[neg]=~A~%" Lin CsqA CsqB CsqG FtcPos FtcNeg)
              (output "wave2 inert: pow=~A lo=~A symj=~A quad=~A den=~A gab=~A 2pdf=~A~%" IPow ILo ISym IQuad IDen IGab I2pdf)
              (if Ok (output "wave2 gaussian: PASS~%") (output "wave2 gaussian: FAIL~%"))
              Ok)))

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
          Ok (and B1 (and B2 (and Rej (and W1 W2))))
          (do (output "22: diffback[cos]=~A diffback[x^2+x]=~A typo-derivative-rejected=~A~%" B1 B2 Rej)
              (if Ok (output "calculus corpus (SCUD 22): PASS~%")
                  (output "calculus corpus (SCUD 22): FAIL~%"))
              Ok)))

(output "test-calculus.shen loaded (SCUD 22 corpus + executable rejection showcase).~%")
