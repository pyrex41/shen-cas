\\ test-ratint.shen - rational-function integration (Wave 4).
\\ Loaded BEFORE test/test.shen; run-ratint-tests is wired into run-all-tests.
\\
\\ Oracle: numeric differentiate-back. R = Integrate[f,x]; for several integer
\\ sample points s (chosen to avoid the poles), reduce(D[R,x]|x=s) must equal
\\ reduce(f|x=s). A rational identity that holds at enough points is identically
\\ true, so this soundly verifies Log/ArcTan antiderivatives that the Simplify-
\\ based differentiate-back cannot reduce to 0. Inert cases keep the Integrate head.

(define ri-x -> [sym (intern "x")])
(define ri-int F -> [[sym (protect Integrate)] F (ri-x)])
(define ri-d R -> [[sym (protect D)] R (ri-x)])
(define ri-read S -> (parse-expr-string S))

\\ samples avoid x = 0, +-1, +-2 (the poles in the test denominators).
(define ri-samples -> [3 5 7 11])

(define ri-sample-eq?
  DR Ig S -> (let L (reduce (se-subst (ri-x) [int S] DR))
                  Rr (reduce (se-subst (ri-x) [int S] Ig))
                  (if (numeric? L)
                      (if (numeric? Rr) (num-eq? L Rr) false)
                      false)))

(define ri-samples-ok?
  DR Ig [] -> true
  DR Ig [S | Ss] -> (if (ri-sample-eq? DR Ig S) (ri-samples-ok? DR Ig Ss) false))

(define ri-back-ok?
  Ig -> (let R (reduce (ri-int Ig))
             (if (= (head R) [sym (protect Integrate)])
                 false
                 (ri-samples-ok? (reduce (ri-d R)) Ig (ri-samples)))))

(define ri-check
  Name S -> (let Ig (ri-read S)
                 Ok (ri-back-ok? Ig)
                 (do (if Ok
                         (output "  PASS ratint ~A: ~A -> ~A~%" Name S (pretty-expr (reduce (ri-int Ig))))
                         (output "  FAIL ratint ~A: ~A -> ~A~%" Name S (pretty-expr (reduce (ri-int Ig)))))
                     Ok)))

(define ri-check-inert
  Name S -> (let Ig (ri-read S)
                 R (reduce (ri-int Ig))
                 Ok (= (head R) [sym (protect Integrate)])
                 (do (if Ok
                         (output "  PASS ratint-inert ~A (head unchanged)~%" Name)
                         (output "  FAIL ratint-inert ~A: ~A -> ~A~%" Name S (pretty-expr R)))
                     Ok)))

(define ri-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (ri-all-true? Xs))

(define run-ratint-tests
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== rational-function integration ===~%")
          \\ --- Cancel-then-integrate (reducible ratio) ---
          C1 (ri-check "cancel (x+1)/(x^2-1)" "(x+1)/(x^2-1)")
          \\ --- distinct rational roots -> partial fractions (2 logs, verified) ---
          T1 (ri-check "2log 1/(x^2-1)"       "1/(x^2-1)")
          T2 (ri-check "2log x/(x^2-1)"        "x/(x^2-1)")
          T3 (ri-check "2log (2x+3)/(x^2-4)"   "(2*x+3)/(x^2-4)")
          \\ --- irreducible quadratic -> ArcTan (complete the square) ---
          A1 (ri-check "arctan 1/(x^2+1)"      "1/(x^2+1)")
          A2 (ri-check "arctan 1/(x^2+2x+2)"   "1/(x^2+2*x+2)")
          A3 (ri-check "log+arctan (x+1)/(x^2+1)" "(x+1)/(x^2+1)")
          \\ --- frontier: stays inert (no rational roots, degree-4 leftover;
          \\     cubics are now handled in test-pfrac.shen) ---
          I1 (ri-check-inert "1/(x^4+1)"     "1/(x^4+1)")
          I2 (ri-check-inert "1/(x^4+x^2+1)" "1/(x^4+x^2+1)")
          Ok (ri-all-true? [C1 T1 T2 T3 A1 A2 A3 I1 I2])
          (do (if Ok (output "rational-function integration: PASS~%")
                  (output "rational-function integration: FAIL~%"))
              Ok)))
