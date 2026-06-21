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
          Ok (and B1 (and B2 (and Rej W1)))
          (do (output "22: diffback[cos]=~A diffback[x^2+x]=~A typo-derivative-rejected=~A~%" B1 B2 Rej)
              (if Ok (output "calculus corpus (SCUD 22): PASS~%")
                  (output "calculus corpus (SCUD 22): FAIL~%"))
              Ok)))

(output "test-calculus.shen loaded (SCUD 22 corpus + executable rejection showcase).~%")
