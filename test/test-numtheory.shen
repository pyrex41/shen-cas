\\ test-numtheory.shen - number-theory predicates & sequences.
\\ Loaded BEFORE test/test.shen; run-numtheory-tests is wired into run-all-tests.
\\
\\ Oracle: reduce(Call[args]) content-eq the exact expected literal (True/False or
\\ an integer); inert cases keep their head.

(define nt-h Name -> [sym (intern Name)])
(define nt-call Name Args -> [(nt-h Name) | Args])
(define nt-i N -> [int N])
(define nt-true -> [sym (protect True)])
(define nt-false -> [sym (protect False)])
(define nt-x -> [sym (intern "x")])

(define nt-check
  Name In Expected ->
    (let R (reduce In)
         Ok (content-eq R Expected)
         (do (if Ok
                 (output "  PASS numtheory ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL numtheory ~A: got ~A want ~A~%"
                         Name (pretty-expr R) (pretty-expr Expected)))
             Ok)))

(define nt-check-inert
  Name In ->
    (let R (reduce In)
         Ok (= (head R) (head In))
         (do (if Ok
                 (output "  PASS numtheory-inert ~A (head unchanged)~%" Name)
                 (output "  FAIL numtheory-inert ~A: got ~A~%" Name (pretty-expr R)))
             Ok)))

(define nt-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (nt-all-true? Xs))

(define run-numtheory-tests
  -> (let Ign (output "~%=== number theory (EvenQ/OddQ/Divisible/CoprimeQ/PrimeQ/NextPrime/Prime/Fibonacci/PowerMod) ===~%")
          \\ --- parity ---
          E1 (nt-check "EvenQ[4]" (nt-call "EvenQ" [(nt-i 4)]) (nt-true))
          E2 (nt-check "EvenQ[3]" (nt-call "EvenQ" [(nt-i 3)]) (nt-false))
          E3 (nt-check "OddQ[3]"  (nt-call "OddQ"  [(nt-i 3)]) (nt-true))
          E4 (nt-check "OddQ[-4]" (nt-call "OddQ"  [(nt-i -4)]) (nt-false))
          \\ --- divisibility / coprimality ---
          D1 (nt-check "Divisible[12,3]" (nt-call "Divisible" [(nt-i 12) (nt-i 3)]) (nt-true))
          D2 (nt-check "Divisible[12,5]" (nt-call "Divisible" [(nt-i 12) (nt-i 5)]) (nt-false))
          D3 (nt-check "CoprimeQ[8,9]"   (nt-call "CoprimeQ"  [(nt-i 8) (nt-i 9)])  (nt-true))
          D4 (nt-check "CoprimeQ[8,12]"  (nt-call "CoprimeQ"  [(nt-i 8) (nt-i 12)]) (nt-false))
          \\ --- primality ---
          P1 (nt-check "PrimeQ[7]"  (nt-call "PrimeQ" [(nt-i 7)])  (nt-true))
          P2 (nt-check "PrimeQ[1]"  (nt-call "PrimeQ" [(nt-i 1)])  (nt-false))
          P3 (nt-check "PrimeQ[2]"  (nt-call "PrimeQ" [(nt-i 2)])  (nt-true))
          P4 (nt-check "PrimeQ[91]" (nt-call "PrimeQ" [(nt-i 91)]) (nt-false))
          P5 (nt-check "PrimeQ[97]" (nt-call "PrimeQ" [(nt-i 97)]) (nt-true))
          P6 (nt-check "NextPrime[10]" (nt-call "NextPrime" [(nt-i 10)]) (nt-i 11))
          P7 (nt-check "NextPrime[20]" (nt-call "NextPrime" [(nt-i 20)]) (nt-i 23))
          P8 (nt-check "Prime[1]"   (nt-call "Prime" [(nt-i 1)])  (nt-i 2))
          P9 (nt-check "Prime[5]"   (nt-call "Prime" [(nt-i 5)])  (nt-i 11))
          P10 (nt-check "Prime[10]" (nt-call "Prime" [(nt-i 10)]) (nt-i 29))
          \\ --- sequences / modular exponentiation ---
          B1 (nt-check "Fibonacci[0]"  (nt-call "Fibonacci" [(nt-i 0)])  (nt-i 0))
          B2 (nt-check "Fibonacci[1]"  (nt-call "Fibonacci" [(nt-i 1)])  (nt-i 1))
          B3 (nt-check "Fibonacci[10]" (nt-call "Fibonacci" [(nt-i 10)]) (nt-i 55))
          B4 (nt-check "Fibonacci[20]" (nt-call "Fibonacci" [(nt-i 20)]) (nt-i 6765))
          B5 (nt-check "PowerMod[2,10,1000]" (nt-call "PowerMod" [(nt-i 2) (nt-i 10) (nt-i 1000)]) (nt-i 24))
          B6 (nt-check "PowerMod[3,4,5]"     (nt-call "PowerMod" [(nt-i 3) (nt-i 4) (nt-i 5)])     (nt-i 1))
          B7 (nt-check "PowerMod[7,0,5]"     (nt-call "PowerMod" [(nt-i 7) (nt-i 0) (nt-i 5)])     (nt-i 1))
          B8 (nt-check "PowerMod[2,5,7]"     (nt-call "PowerMod" [(nt-i 2) (nt-i 5) (nt-i 7)])     (nt-i 4))
          \\ --- soundness: symbolic / out-of-domain stay INERT ---
          I1 (nt-check-inert "EvenQ[x]"        (nt-call "EvenQ"     [(nt-x)]))
          I2 (nt-check-inert "PrimeQ[x]"       (nt-call "PrimeQ"    [(nt-x)]))
          I3 (nt-check-inert "Fibonacci[-1]"   (nt-call "Fibonacci" [(nt-i -1)]))
          I4 (nt-check-inert "Divisible[7,0]"  (nt-call "Divisible" [(nt-i 7) (nt-i 0)]))
          I5 (nt-check-inert "Prime[0]"        (nt-call "Prime"     [(nt-i 0)]))
          I6 (nt-check-inert "PowerMod[2,-1,5]" (nt-call "PowerMod" [(nt-i 2) (nt-i -1) (nt-i 5)]))
          Ok (nt-all-true? [E1 E2 E3 E4 D1 D2 D3 D4
                            P1 P2 P3 P4 P5 P6 P7 P8 P9 P10
                            B1 B2 B3 B4 B5 B6 B7 B8
                            I1 I2 I3 I4 I5 I6])
          (do (if Ok (output "number theory: PASS~%")
                  (output "number theory: FAIL~%"))
              Ok)))
