\\ test-trigint.shen - trigonometric integration rules (SCUD trig integrals).
\\ Adds antiderivatives for Sec^2, Csc^2, Sec*Tan, Csc*Cot, Sin*Cos, Sin^2, Cos^2.
\\
\\ Oracle policy (per task spec):
\\   - The 5 "matches-as-same-term" cases (Sec^2, Csc^2, Sec*Tan, Csc*Cot, Sin*Cos)
\\     are verified by the un-foolable differentiate-back check:
\\        content-eq( reduce(Simplify[ D[R,x] + (-1)*f ]), 0 ).
\\   - Sin^2 / Cos^2 need the Pythagorean identity for differentiate-back, which the
\\     simplifier does not know, so they are verified by content-eq of reduce(Integrate[f,x])
\\     against the exact expected closed form (trusted identity), consistent with the
\\     existing trusted table entries.
\\   - Plus one INERT check: Integrate[Tan[x],x] must stay inert (head Integrate).
\\
\\ Helper names are prefixed tg- to avoid collisions with other test files.

\\ the bare integration variable used in all integrands.
(define tg-x -> [sym (intern "x")])

\\ wrap heads
(define tg-int E -> [[sym (protect Integrate)] E (tg-x)])
(define tg-d   E -> [[sym (protect D)] E (tg-x)])

\\ symbolic-function applications over the bare variable
(define tg-sin -> [[sym (protect Sin)] (tg-x)])
(define tg-cos -> [[sym (protect Cos)] (tg-x)])
(define tg-tan -> [[sym (protect Tan)] (tg-x)])
(define tg-sec -> [[sym (protect Sec)] (tg-x)])
(define tg-csc -> [[sym (protect Csc)] (tg-x)])
(define tg-cot -> [[sym (protect Cot)] (tg-x)])
(define tg-pow E N -> [[sym (protect Power)] E [int N]])

\\ differentiate-back oracle: reduce(Simplify[D[R,x] + (-1)*f]) content-eq 0.
\\ R is the reduced antiderivative of F. Cannot be fooled by a table typo.
(define tg-diff-back?
  F -> (let R (reduce (tg-int F))
            Back (reduce [[sym (protect Simplify)]
                          [[sym (protect Plus)] (tg-d R) [[sym (protect Times)] [int -1] F]]])
            (content-eq Back [int 0])))

\\ closed-form oracle: reduce(Integrate[F,x]) content-eq the expected expr.
(define tg-closed?
  F Expected -> (content-eq (reduce (tg-int F)) (reduce Expected)))

\\ one differentiate-back case
(define tg-check-db
  Name F -> (let Ok (tg-diff-back? F)
                 (do (if Ok
                         (output "  PASS diffback ~A~%" Name)
                         (output "  FAIL diffback ~A: got=~A~%" Name (pretty-expr (reduce (tg-int F)))))
                     Ok)))

\\ one closed-form case
(define tg-check-closed
  Name F Expected -> (let Ok (tg-closed? F Expected)
                          (do (if Ok
                                  (output "  PASS closed  ~A -> ~A~%" Name (pretty-expr (reduce (tg-int F))))
                                  (output "  FAIL closed  ~A: got=~A want=~A~%"
                                          Name (pretty-expr (reduce (tg-int F))) (pretty-expr (reduce Expected))))
                              Ok)))

\\ inert check: head of reduce(E) must still be Integrate
(define tg-check-inert
  Name E -> (let R (reduce E)
                 Ok (= (head R) [sym (protect Integrate)])
                 (do (if Ok
                         (output "  PASS inert   ~A (head still Integrate)~%" Name)
                         (output "  FAIL inert   ~A: head changed got=~A~%" Name (pretty-expr R)))
                     Ok)))

(define tg-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (tg-all-true? Xs))

(define run-trigint-tests
  -> (let Ign0 (demo-register-calculus)
          Ign  (output "~%=== trigonometric integration rules ===~%")
          \\ --- differentiate-back-verifiable (5) ---
          A1 (tg-check-db "Sec[x]^2"        (tg-pow (tg-sec) 2))
          A2 (tg-check-db "Csc[x]^2"        (tg-pow (tg-csc) 2))
          A3 (tg-check-db "Sec[x]*Tan[x]"   [[sym (protect Times)] (tg-sec) (tg-tan)])
          A4 (tg-check-db "Csc[x]*Cot[x]"   [[sym (protect Times)] (tg-csc) (tg-cot)])
          A5 (tg-check-db "Sin[x]*Cos[x]"   [[sym (protect Times)] (tg-sin) (tg-cos)])
          \\ --- closed-form-verified power reductions (2) ---
          \\ Sin^2 -> 1/2 x - 1/2 Sin Cos ; Cos^2 -> 1/2 x + 1/2 Sin Cos
          B1 (tg-check-closed "Sin[x]^2"
                (tg-pow (tg-sin) 2)
                [[sym (protect Plus)]
                  [[sym (protect Times)] [rat 1 2] (tg-x)]
                  [[sym (protect Times)] [rat -1 2] (tg-sin) (tg-cos)]])
          B2 (tg-check-closed "Cos[x]^2"
                (tg-pow (tg-cos) 2)
                [[sym (protect Plus)]
                  [[sym (protect Times)] [rat 1 2] (tg-x)]
                  [[sym (protect Times)] [rat 1 2] (tg-sin) (tg-cos)]])
          \\ --- inert: Tan[x] has no rule, must stay inert ---
          I1 (tg-check-inert "Integrate[Tan[x],x]" (tg-int (tg-tan)))
          Ok (tg-all-true? [A1 A2 A3 A4 A5 B1 B2 I1])
          (do (if Ok (output "trigonometric integration: PASS~%")
                  (output "trigonometric integration: FAIL~%"))
              Ok)))

(output "test-trigint.shen loaded (trigonometric integration rules).~%")
