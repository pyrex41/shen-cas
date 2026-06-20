\\ test-numfun.shen - elementary & number-theory function layer.
\\ Loaded BEFORE test/test.shen; run-numfun-tests is wired into run-all-tests.
\\
\\ Oracle: reduce(Call[args]) content-eq the exact expected literal; inert cases
\\ keep their head. Inputs are built directly (head [sym (intern Name)]) so the
\\ by-name builtin dispatch is exercised regardless of (protect ...) interning.

(define nf-h Name -> [sym (intern Name)])
(define nf-call Name Args -> [(nf-h Name) | Args])
(define nf-i N -> [int N])
(define nf-r N D -> (make-rat N D))
(define nf-x -> [sym (intern "x")])

(define nf-check
  Name In Expected ->
    (let R (reduce In)
         Ok (content-eq R Expected)
         (do (if Ok
                 (output "  PASS numfun ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL numfun ~A: got ~A want ~A~%"
                         Name (pretty-expr R) (pretty-expr Expected)))
             Ok)))

(define nf-check-inert
  Name In ->
    (let R (reduce In)
         Ok (= (head R) (head In))
         (do (if Ok
                 (output "  PASS numfun-inert ~A (head unchanged)~%" Name)
                 (output "  FAIL numfun-inert ~A: got ~A~%" Name (pretty-expr R)))
             Ok)))

(define nf-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (nf-all-true? Xs))

(define run-numfun-tests
  -> (let Ign (output "~%=== elementary & number-theory functions ===~%")
          \\ --- Abs / Sign ---
          A1 (nf-check "Abs[-3]"      (nf-call "Abs"  [(nf-i -3)])    (nf-i 3))
          A2 (nf-check "Abs[-7/2]"    (nf-call "Abs"  [(nf-r -7 2)])  (nf-r 7 2))
          A3 (nf-check "Sign[-5]"     (nf-call "Sign" [(nf-i -5)])    (nf-i -1))
          A4 (nf-check "Sign[0]"      (nf-call "Sign" [(nf-i 0)])     (nf-i 0))
          A5 (nf-check "Sign[3/4]"    (nf-call "Sign" [(nf-r 3 4)])   (nf-i 1))
          \\ --- Floor / Ceiling (esp. negatives) ---
          F1 (nf-check "Floor[7/2]"    (nf-call "Floor"   [(nf-r 7 2)])   (nf-i 3))
          F2 (nf-check "Floor[-7/2]"   (nf-call "Floor"   [(nf-r -7 2)])  (nf-i -4))
          F3 (nf-check "Ceiling[7/2]"  (nf-call "Ceiling" [(nf-r 7 2)])   (nf-i 4))
          F4 (nf-check "Ceiling[-7/2]" (nf-call "Ceiling" [(nf-r -7 2)])  (nf-i -3))
          \\ --- Round (ties to even) ---
          R1 (nf-check "Round[5/2]"  (nf-call "Round" [(nf-r 5 2)])  (nf-i 2))
          R2 (nf-check "Round[7/2]"  (nf-call "Round" [(nf-r 7 2)])  (nf-i 4))
          R3 (nf-check "Round[3/2]"  (nf-call "Round" [(nf-r 3 2)])  (nf-i 2))
          R4 (nf-check "Round[-5/2]" (nf-call "Round" [(nf-r -5 2)]) (nf-i -2))
          R5 (nf-check "Round[7/3]"  (nf-call "Round" [(nf-r 7 3)])  (nf-i 2))
          \\ --- IntegerPart / FractionalPart ---
          P1 (nf-check "IntegerPart[-7/2]"    (nf-call "IntegerPart"    [(nf-r -7 2)]) (nf-i -3))
          P2 (nf-check "FractionalPart[7/2]"  (nf-call "FractionalPart" [(nf-r 7 2)])  (nf-r 1 2))
          P3 (nf-check "FractionalPart[-7/2]" (nf-call "FractionalPart" [(nf-r -7 2)]) (nf-r -1 2))
          \\ --- Mod / Quotient (sign of divisor) ---
          M1 (nf-check "Mod[7,3]"       (nf-call "Mod"      [(nf-i 7) (nf-i 3)])  (nf-i 1))
          M2 (nf-check "Mod[-7,3]"      (nf-call "Mod"      [(nf-i -7) (nf-i 3)]) (nf-i 2))
          M3 (nf-check "Mod[7,-3]"      (nf-call "Mod"      [(nf-i 7) (nf-i -3)]) (nf-i -2))
          M4 (nf-check "Quotient[7,3]"  (nf-call "Quotient" [(nf-i 7) (nf-i 3)])  (nf-i 2))
          M5 (nf-check "Quotient[-7,3]" (nf-call "Quotient" [(nf-i -7) (nf-i 3)]) (nf-i -3))
          \\ --- GCD / LCM (n-ary) ---
          G1 (nf-check "GCD[12,18]"    (nf-call "GCD" [(nf-i 12) (nf-i 18)])           (nf-i 6))
          G2 (nf-check "GCD[12,18,30]" (nf-call "GCD" [(nf-i 12) (nf-i 18) (nf-i 30)]) (nf-i 6))
          G3 (nf-check "LCM[4,6]"      (nf-call "LCM" [(nf-i 4) (nf-i 6)])             (nf-i 12))
          G4 (nf-check "LCM[4,6,8]"    (nf-call "LCM" [(nf-i 4) (nf-i 6) (nf-i 8)])    (nf-i 24))
          \\ --- Factorial / Binomial ---
          C1 (nf-check "Factorial[5]"  (nf-call "Factorial" [(nf-i 5)])          (nf-i 120))
          C2 (nf-check "Factorial[0]"  (nf-call "Factorial" [(nf-i 0)])          (nf-i 1))
          C3 (nf-check "Binomial[5,2]" (nf-call "Binomial"  [(nf-i 5) (nf-i 2)]) (nf-i 10))
          C4 (nf-check "Binomial[6,0]" (nf-call "Binomial"  [(nf-i 6) (nf-i 0)]) (nf-i 1))
          C5 (nf-check "Binomial[5,7]" (nf-call "Binomial"  [(nf-i 5) (nf-i 7)]) (nf-i 0))
          C6 (nf-check "Binomial[10,3]" (nf-call "Binomial" [(nf-i 10) (nf-i 3)]) (nf-i 120))
          \\ --- Max / Min (n-ary, incl. rationals) ---
          X1 (nf-check "Max[3,7,2]"    (nf-call "Max" [(nf-i 3) (nf-i 7) (nf-i 2)]) (nf-i 7))
          X2 (nf-check "Min[3,7,2]"    (nf-call "Min" [(nf-i 3) (nf-i 7) (nf-i 2)]) (nf-i 2))
          X3 (nf-check "Max[1/2,1/3]"  (nf-call "Max" [(nf-r 1 2) (nf-r 1 3)])      (nf-r 1 2))
          X4 (nf-check "Min[1/2,1/3]"  (nf-call "Min" [(nf-r 1 2) (nf-r 1 3)])      (nf-r 1 3))
          \\ --- soundness: symbolic / out-of-domain stay INERT ---
          I1 (nf-check-inert "Abs[x]"        (nf-call "Abs"       [(nf-x)]))
          I2 (nf-check-inert "Floor[x]"      (nf-call "Floor"     [(nf-x)]))
          I3 (nf-check-inert "GCD[x,6]"      (nf-call "GCD"       [(nf-x) (nf-i 6)]))
          I4 (nf-check-inert "Max[x,2]"      (nf-call "Max"       [(nf-x) (nf-i 2)]))
          I5 (nf-check-inert "Mod[x,3]"      (nf-call "Mod"       [(nf-x) (nf-i 3)]))
          I6 (nf-check-inert "Factorial[-1]" (nf-call "Factorial" [(nf-i -1)]))
          I7 (nf-check-inert "Mod[7,0]"      (nf-call "Mod"       [(nf-i 7) (nf-i 0)]))
          Ok (nf-all-true? [A1 A2 A3 A4 A5 F1 F2 F3 F4 R1 R2 R3 R4 R5
                            P1 P2 P3 M1 M2 M3 M4 M5 G1 G2 G3 G4
                            C1 C2 C3 C4 C5 C6 X1 X2 X3 X4
                            I1 I2 I3 I4 I5 I6 I7])
          (do (if Ok (output "elementary & number-theory functions: PASS~%")
                  (output "elementary & number-theory functions: FAIL~%"))
              Ok)))
