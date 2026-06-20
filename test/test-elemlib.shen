\\ test-elemlib.shen - elementary-library expansion: reciprocal-trig, hyperbolic,
\\ and inverse-hyperbolic functions (declarations, exact values, derivatives,
\\ and the two new sound integrals). Loaded BEFORE test/test.shen; run-elemlib-tests
\\ is wired into run-all-tests.
\\
\\ Oracles (un-foolable, orderless-robust):
\\   derivative : Simplify[ reduce(D[F,x]) - Expected ] == [int 0]
\\   integral   : Simplify[ D[Integrate[f,x],x] - f ] == [int 0]  (differentiate-back)
\\   value      : reduce(F) content-eq the exact literal
\\   inert      : reduce(F) keeps its head

(define el-x -> [sym (intern "x")])
(define el-h Name -> [sym (intern Name)])
(define el-c1 Name A -> [(el-h Name) A])
(define el-d F -> [[sym (protect D)] F (el-x)])
(define el-int F -> [[sym (protect Integrate)] F (el-x)])
(define el-pow B E -> [[sym (protect Power)] B E])
(define el-tms Fs -> [[sym (protect Times)] | Fs])
(define el-pls Fs -> [[sym (protect Plus)] | Fs])
(define el-neg E -> [[sym (protect Times)] [int -1] E])

(define el-zero?
  E -> (content-eq (reduce [[sym (protect Simplify)] E]) [int 0]))

\\ Simplify[ A - B ] == 0  (A,B reduced inside reduce/Simplify).
(define el-diff-zero?
  A B -> (el-zero? [[sym (protect Plus)] A (el-neg B)]))

\\ ---- derivative check: reduce(D[F,x]) equals Expected up to Simplify ----
(define el-check-deriv
  Name F Expected ->
    (let R (reduce (el-d F))
         NotInert (not (= (head R) [sym (protect D)]))
         Ok (if NotInert (el-diff-zero? R Expected) false)
         (do (if Ok
                 (output "  PASS deriv ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL deriv ~A: inert=~A got ~A~%" Name (not NotInert) (pretty-expr R)))
             Ok)))

\\ ---- integral check: differentiate-back to the integrand ----
(define el-check-integ-back
  Name F ->
    (let R (reduce (el-int F))
         Inert (= (head R) [sym (protect Integrate)])
         Ok (if Inert false (el-diff-zero? (el-d R) F))
         (do (if Ok
                 (output "  PASS integral ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL integral ~A: inert=~A got ~A~%" Name Inert (pretty-expr R)))
             Ok)))

\\ ---- exact value check ----
(define el-check-val
  Name F Expected ->
    (let R (reduce F)
         Ok (content-eq R Expected)
         (do (if Ok
                 (output "  PASS value ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL value ~A: got ~A want ~A~%" Name (pretty-expr R) (pretty-expr Expected)))
             Ok)))

(define el-check-inert
  Name F ->
    (let R (reduce F)
         Ok (= (head R) (head F))
         (do (if Ok
                 (output "  PASS inert ~A (head unchanged)~%" Name)
                 (output "  FAIL inert ~A: got ~A~%" Name (pretty-expr R)))
             Ok)))

(define el-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (el-all-true? Xs))

(define run-elemlib-tests
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== elementary-library expansion (recip-trig / hyperbolic / inverse-hyperbolic) ===~%")
          X (el-x)
          \\ --- reciprocal-trig derivatives ---
          D1 (el-check-deriv "D[Cot[x]]" (el-c1 "Cot" X)
                          (el-neg (el-pow (el-c1 "Csc" X) [int 2])))
          D2 (el-check-deriv "D[Csc[x]]" (el-c1 "Csc" X)
                          (el-neg (el-tms [(el-c1 "Csc" X) (el-c1 "Cot" X)])))
          \\ --- hyperbolic derivatives ---
          D3 (el-check-deriv "D[Sinh[x]]" (el-c1 "Sinh" X) (el-c1 "Cosh" X))
          D4 (el-check-deriv "D[Cosh[x]]" (el-c1 "Cosh" X) (el-c1 "Sinh" X))
          D5 (el-check-deriv "D[Tanh[x]]" (el-c1 "Tanh" X) (el-pow (el-c1 "Sech" X) [int 2]))
          D6 (el-check-deriv "D[Coth[x]]" (el-c1 "Coth" X) (el-neg (el-pow (el-c1 "Csch" X) [int 2])))
          D7 (el-check-deriv "D[Sech[x]]" (el-c1 "Sech" X) (el-neg (el-tms [(el-c1 "Sech" X) (el-c1 "Tanh" X)])))
          D8 (el-check-deriv "D[Csch[x]]" (el-c1 "Csch" X) (el-neg (el-tms [(el-c1 "Csch" X) (el-c1 "Coth" X)])))
          \\ --- inverse-hyperbolic derivatives ---
          D9  (el-check-deriv "D[ArcSinh[x]]" (el-c1 "ArcSinh" X)
                           (el-pow (el-pls [[int 1] (el-pow X [int 2])]) [rat -1 2]))
          D10 (el-check-deriv "D[ArcCosh[x]]" (el-c1 "ArcCosh" X)
                           (el-pow (el-pls [[int -1] (el-pow X [int 2])]) [rat -1 2]))
          D11 (el-check-deriv "D[ArcTanh[x]]" (el-c1 "ArcTanh" X)
                           (el-pow (el-pls [[int 1] (el-neg (el-pow X [int 2]))]) [int -1]))
          \\ --- chain rule through a hyperbolic ---
          D12 (el-check-deriv "D[Sinh[x^2]]" (el-c1 "Sinh" (el-pow X [int 2]))
                           (el-tms [[int 2] X (el-c1 "Cosh" (el-pow X [int 2]))]))
          \\ --- new integrals (differentiate-back) ---
          I1 (el-check-integ-back "Int[Sinh[x]]"   (el-c1 "Sinh" X))
          I2 (el-check-integ-back "Int[Cosh[x]]"   (el-c1 "Cosh" X))
          I3 (el-check-integ-back "Int[Sinh[2x+3]]"
                               (el-c1 "Sinh" (el-pls [(el-tms [[int 2] X]) [int 3]])))
          I4 (el-check-integ-back "Int[Cosh[2x+3]]"
                               (el-c1 "Cosh" (el-pls [(el-tms [[int 2] X]) [int 3]])))
          \\ --- exact values at the branch-safe points ---
          V1 (el-check-val "Sinh[0]"    (el-c1 "Sinh" [int 0])    [int 0])
          V2 (el-check-val "Cosh[0]"    (el-c1 "Cosh" [int 0])    [int 1])
          V3 (el-check-val "Tanh[0]"    (el-c1 "Tanh" [int 0])    [int 0])
          V4 (el-check-val "Sech[0]"    (el-c1 "Sech" [int 0])    [int 1])
          V5 (el-check-val "ArcSinh[0]" (el-c1 "ArcSinh" [int 0]) [int 0])
          V6 (el-check-val "ArcTanh[0]" (el-c1 "ArcTanh" [int 0]) [int 0])
          V7 (el-check-val "ArcCosh[1]" (el-c1 "ArcCosh" [int 1]) [int 0])
          V8 (el-check-val "Tan[0]"     (el-c1 "Tan" [int 0])     [int 0])
          \\ --- soundness: undefined-at-0 / symbolic stay inert ---
          N1 (el-check-inert "Cot[0]"  (el-c1 "Cot" [int 0]))
          N2 (el-check-inert "Csc[0]"  (el-c1 "Csc" [int 0]))
          N3 (el-check-inert "Coth[0]" (el-c1 "Coth" [int 0]))
          N4 (el-check-inert "Sinh[x]" (el-c1 "Sinh" X))
          Ok (el-all-true? [D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11 D12
                            I1 I2 I3 I4
                            V1 V2 V3 V4 V5 V6 V7 V8 N1 N2 N3 N4])
          (do (if Ok (output "elementary-library expansion: PASS~%")
                  (output "elementary-library expansion: FAIL~%"))
              Ok)))
