\\ test-properties.shen - deterministic property-style checks beyond exact goldens.
\\
\\ These properties use only the kernel itself plus exact integer/rational
\\ arithmetic. No floating-point sampling and no external CAS oracle.

(define prop-x -> [sym (intern "x")])
(define prop-y -> [sym (intern "y")])

(define prop-plus     -> [sym (protect Plus)])
(define prop-times    -> [sym (protect Times)])
(define prop-power    -> [sym (protect Power)])
(define prop-d-head   -> [sym (protect D)])
(define prop-simp-head -> [sym (protect Simplify)])
(define prop-expand-head -> [sym (protect Expand)])
(define prop-factor-head -> [sym (protect Factor)])
(define prop-cancel-head -> [sym (protect Cancel)])
(define prop-together-head -> [sym (protect Together)])

(define prop-read S -> (parse-expr-string S))
(define prop-d E -> [(prop-d-head) E (prop-x)])
(define prop-simplify E -> (reduce [(prop-simp-head) E]))
(define prop-expand E -> (reduce [(prop-expand-head) E]))

(define prop-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (prop-all-true? Xs))

(define prop-head-name?
  [sym S] Name -> (= (str S) Name)
  _ _ -> false)

(define prop-has-head?
  [H | _] Name -> (prop-head-name? H Name)
  _ _ -> false)

(define prop-report
  Label What true -> (do (output "  PASS property ~A: ~A~%" Label What) true)
  Label What false -> (do (output "  FAIL property ~A: ~A~%" Label What) false))

\\ ------------------------------------------------------------------------
\\ Simplify and Reduce idempotence
\\ ------------------------------------------------------------------------

(define prop-simplify-idempotent?
  S -> (let E (prop-read S)
            Once (prop-simplify E)
            Twice (prop-simplify Once)
            (content-eq Once Twice)))

(define prop-reduce-idempotent?
  S -> (let E (prop-read S)
            Once (reduce E)
            Twice (reduce Once)
            (content-eq Once Twice)))

(define prop-simplify-corpus
  -> ["x+0" "0+x+y" "x*1" "2*1*x" "x*0" "x^1" "x^0"
      "Simplify[x+x]" "Simplify[3*x+2*x]" "Simplify[x*x*x]"
      "Simplify[(x+1)^2-(x^2+2*x+1)]" "Simplify[Sin[x]^2+Cos[x]^2]"])

(define prop-reduce-corpus
  -> ["2*(3+4)" "Simplify[3*x+2*x+x*x]" "Expand[(x+1)^3]"
      "Factor[x^2-1]" "Cancel[(x^2-1)/(x-1)]"
      "Together[1/x+1/(x+1)]" "D[Sin[x^2],x]" "Integrate[x^2,x]"])

(define run-prop-simplify
  -> (let Cases (prop-simplify-corpus)
          Results (map (/. S (prop-report S "Simplify is idempotent"
                                  (prop-simplify-idempotent? S))) Cases)
          Ok (prop-all-true? Results)
          (do (if Ok (output "property simplify idempotence: PASS~%")
                  (output "property simplify idempotence: FAIL~%"))
              Ok)))

(define run-prop-reduce
  -> (let Cases (prop-reduce-corpus)
          Results (map (/. S (prop-report S "reduce is idempotent"
                                  (prop-reduce-idempotent? S))) Cases)
          Ok (prop-all-true? Results)
          (do (if Ok (output "property reduce idempotence: PASS~%")
                  (output "property reduce idempotence: FAIL~%"))
              Ok)))

\\ ------------------------------------------------------------------------
\\ Expand: idempotence plus deterministic exact integer semantic samples.
\\ ------------------------------------------------------------------------

(define prop-subst
  [sym S] Name Val -> (if (= S Name) [int Val] [sym S])
  [int N] _ _ -> [int N]
  [rat N D] _ _ -> [rat N D]
  [H | Args] Name Val -> [(prop-subst H Name Val) | (prop-subst-list Args Name Val)]
  E _ _ -> E)

(define prop-subst-list
  [] _ _ -> []
  [A | As] Name Val -> [(prop-subst A Name Val) | (prop-subst-list As Name Val)])

(define prop-eval-xy
  E Vx Vy -> (reduce (prop-subst (prop-subst E (intern "x") Vx) (intern "y") Vy)))

(define prop-sample-points -> [[2 3] [-1 5] [4 -2] [7 1]])

(define prop-sample-eq?
  Orig Expanded -> (prop-sample-eq-loop Orig Expanded (prop-sample-points)))

(define prop-sample-eq-loop
  _ _ [] -> true
  Orig Expanded [[Vx Vy] | Rest] ->
    (let A (prop-eval-xy Orig Vx Vy)
         B (prop-eval-xy Expanded Vx Vy)
         (if (and (numeric? A) (and (numeric? B) (num-eq? A B)))
             (prop-sample-eq-loop Orig Expanded Rest)
             false)))

(define prop-expand-ok?
  S -> (let E (prop-read S)
            Ex (prop-expand E)
            Idem (content-eq (prop-expand Ex) Ex)
            Sample (prop-sample-eq? E Ex)
            (and Idem Sample)))

(define prop-expand-corpus
  -> ["(x+1)^2" "(x+y)^3" "(2*x-3)*(x+5)" "(x-1)*(x+1)*(x+2)"])

(define run-prop-expand
  -> (let Cases (prop-expand-corpus)
          Results (map (/. S (prop-report S "Expand idempotent and sample-equal"
                                  (prop-expand-ok? S))) Cases)
          Ok (prop-all-true? Results)
          (do (if Ok (output "property expand: PASS~%")
                  (output "property expand: FAIL~%"))
              Ok)))

\\ ------------------------------------------------------------------------
\\ Factor / Cancel / Together: exact symbolic round trips.
\\ ------------------------------------------------------------------------

(define prop-zero-after-expand?
  E -> (content-eq (prop-simplify (prop-expand E)) [int 0]))

(define prop-factor-expand-roundtrip?
  S -> (let P (prop-read S)
            F (reduce [(prop-factor-head) P])
            (content-eq (prop-expand F) (prop-expand P))))

\\ A rational expression is represented as [Num Den]. Bare expressions use Den=1.
(define prop-rat-parts
  [H P Q] -> (if (prop-head-name? H "Divide") [P Q] [[H P Q] [int 1]])
  E -> [E [int 1]])

(define prop-add-rat
  [N1 D1] [N2 D2] -> [[(prop-plus) [(prop-times) N1 D2] [(prop-times) N2 D1]]
                      [(prop-times) D1 D2]])

(define prop-add-rat-list
  [] -> [[int 0] [int 1]]
  [T | Ts] -> (prop-add-rat (prop-rat-parts T) (prop-add-rat-list Ts)))

(define prop-sum-rat-parts
  [H | Terms] -> (if (prop-head-name? H "Plus")
                     (prop-add-rat-list Terms)
                     (prop-rat-parts [H | Terms]))
  E -> (prop-rat-parts E))

(define prop-rat-equivalent?
  [N1 D1] [N2 D2] ->
    (prop-zero-after-expand? [(prop-plus)
                              [(prop-times) N1 D2]
                              [(prop-times) [int -1] N2 D1]]))

(define prop-cancel-sane?
  S -> (let Orig (prop-read S)
            C (reduce [(prop-cancel-head) Orig])
            Active (not (prop-has-head? C "Cancel"))
            Same (prop-rat-equivalent? (prop-rat-parts Orig) (prop-rat-parts C))
            (and Active Same)))

(define prop-together-sane?
  S -> (let Orig (prop-read S)
            T (reduce [(prop-together-head) Orig])
            Active (not (prop-has-head? T "Together"))
            Same (prop-rat-equivalent? (prop-sum-rat-parts Orig) (prop-rat-parts T))
            (and Active Same)))

(define prop-factor-corpus
  -> ["x^2-1" "x^2-2*x+1" "x^3-x" "2*x^2-2" "x^3+3*x^2+3*x+1"
      "x^2+1"])

(define prop-cancel-corpus
  -> ["(x^2-1)/(x-1)" "(x^2+2*x+1)/(x+1)" "(x^3-x)/x"])

(define prop-together-corpus
  -> ["1/x+1/(x+1)" "1/(x-1)+1/(x+1)" "1/x+1/x" "x/(x+1)+1/(x+1)"])

(define run-prop-factor
  -> (let Cases (prop-factor-corpus)
          Results (map (/. S (prop-report S "Expand[Factor[p]] equals Expand[p]"
                                  (prop-factor-expand-roundtrip? S))) Cases)
          Ok (prop-all-true? Results)
          (do (if Ok (output "property factor/expand round-trip: PASS~%")
                  (output "property factor/expand round-trip: FAIL~%"))
              Ok)))

(define run-prop-cancel-together
  -> (let CancelCases (prop-cancel-corpus)
          TogetherCases (prop-together-corpus)
          CancelResults (map (/. S (prop-report S "Cancel preserves rational identity"
                                        (prop-cancel-sane? S))) CancelCases)
          TogetherResults (map (/. S (prop-report S "Together preserves rational sum"
                                          (prop-together-sane? S))) TogetherCases)
          Ok (prop-all-true? (append CancelResults TogetherResults))
          (do (if Ok (output "property cancel/together: PASS~%")
                  (output "property cancel/together: FAIL~%"))
              Ok)))

\\ ------------------------------------------------------------------------
\\ D consistency: linearity, product rule, and unary chain rule.
\\ ------------------------------------------------------------------------

(define prop-equal-under-simplify?
  A B -> (content-eq (prop-simplify [(prop-plus) A [(prop-times) [int -1] B]]) [int 0]))

(define prop-d-linearity?
  F G -> (prop-equal-under-simplify?
           (reduce (prop-d [(prop-plus) F G]))
           (reduce [(prop-plus) (prop-d F) (prop-d G)])))

(define prop-d-product?
  F G -> (prop-equal-under-simplify?
           (reduce (prop-d [(prop-times) F G]))
           (reduce [(prop-plus)
                    [(prop-times) (prop-d F) G]
                    [(prop-times) F (prop-d G)]])))

(define prop-d-chain-sin?
  Inner -> (prop-equal-under-simplify?
             (reduce (prop-d [[sym (protect Sin)] Inner]))
             (reduce [(prop-times) [[sym (protect Cos)] Inner] (prop-d Inner)])))

(define run-prop-d
  -> (let X (prop-x)
          F1 [(prop-power) X [int 3]]
          G1 [[sym (protect Sin)] X]
          F2 [(prop-plus) [(prop-power) X [int 2]] [int 1]]
          G2 [[sym (protect Exp)] X]
          Inner1 [(prop-power) X [int 2]]
          L1 (prop-report "D linearity x^3 + Sin[x]" "D[f+g]=D[f]+D[g]"
                          (prop-d-linearity? F1 G1))
          L2 (prop-report "D linearity (x^2+1) + Exp[x]" "D[f+g]=D[f]+D[g]"
                          (prop-d-linearity? F2 G2))
          P1 (prop-report "D product x * Sin[x]" "D[f*g]=D[f]g+fD[g]"
                          (prop-d-product? X G1))
          P2 (prop-report "D product (x^2+1) * Exp[x]" "D[f*g]=D[f]g+fD[g]"
                          (prop-d-product? F2 G2))
          C1 (prop-report "D chain Sin[x^2]" "D[Sin[g]]=Cos[g]D[g]"
                          (prop-d-chain-sin? Inner1))
          Ok (prop-all-true? [L1 L2 P1 P2 C1])
          (do (if Ok (output "property D consistency: PASS~%")
                  (output "property D consistency: FAIL~%"))
              Ok)))

(define run-property-tests
  -> (let SavedDb (value *db*)
          SavedSigs (value *structural-sigs*)
          Ign (output "~%=== property-style CAS checks ===~%")
          Ok (and (run-prop-simplify)
                  (and (run-prop-expand)
                       (and (run-prop-factor)
                            (and (run-prop-cancel-together)
                                 (and (run-prop-d) (run-prop-reduce))))))
          RestoreDb (set *db* SavedDb)
          RestoreSigs (set *structural-sigs* SavedSigs)
          (do (if Ok (output "property-style CAS checks: PASS~%")
                  (output "property-style CAS checks: FAIL~%"))
              Ok)))

(output "test-properties.shen loaded (deterministic property-style checks).~%")
