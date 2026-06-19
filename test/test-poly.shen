\\ test-poly.shen - SCUD 17 Wave B: polynomial normal form (Expand) + PolynomialQ.
\\ Loaded BEFORE test/test.shen; run-poly-tests is wired into run-all-tests.
\\
\\ Each Expand golden is checked TWO ways:
\\   (1) content-eq against the stated canonical normal form;
\\   (2) a SAMPLE-POINT check: substitute integer values for the variables in
\\       BOTH the original and the Expand result, reduce each to a number, and
\\       assert the numbers are equal (catches algebraic errors content-eq can't).
\\ Plus normal-form idempotence: Expand[Expand[E]] content-eq Expand[E].

\\ --- expr builders (over the poly-test variables xp / yp) ---
(define pv-x -> [sym (protect xp)])
(define pv-y -> [sym (protect yp)])
(define p-plus  -> [sym (protect Plus)])
(define p-times -> [sym (protect Times)])
(define p-power -> [sym (protect Power)])

(define mk-expand  E -> [[sym (protect Expand)] E])
(define mk-polyq   E V -> [[sym (protect PolynomialQ)] E V])

\\ --- substitution: replace [sym Name] with [int Val] everywhere ---
(define poly-subst
  [sym S] Name Val -> (if (= S Name) [int Val] [sym S])
  [int N] _ _ -> [int N]
  [rat N D] _ _ -> [rat N D]
  [H | Args] Name Val -> [(poly-subst H Name Val)
                          | (poly-subst-list Args Name Val)]
  E _ _ -> E)

(define poly-subst-list
  [] _ _ -> []
  [A | As] Name Val -> [(poly-subst A Name Val) | (poly-subst-list As Name Val)])

\\ substitute x:=Vx, y:=Vy and reduce to a (hopefully) numeric expr.
(define poly-eval-xy
  E Vx Vy -> (reduce (poly-subst (poly-subst E (protect xp) Vx) (protect yp) Vy)))

\\ sample-point equality at several (x,y) points; both must reduce numeric & equal.
(define sample-points -> [[2 3] [-1 5] [4 -2] [7 1]])

(define sample-eq?
  Orig Expanded -> (sample-eq-loop Orig Expanded (sample-points)))

(define sample-eq-loop
  _ _ [] -> true
  Orig Expanded [[Vx Vy] | Rest] ->
    (let A (poly-eval-xy Orig Vx Vy)
         B (poly-eval-xy Expanded Vx Vy)
         (if (and (numeric? A) (and (numeric? B) (num-eq? A B)))
             (sample-eq-loop Orig Expanded Rest)
             false)))

\\ --- one Expand golden: content-eq AND sample-point ---
(define check-expand
  Name Orig Expected ->
    (let Got (reduce (mk-expand Orig))
         CE (content-eq Got Expected)
         SP (sample-eq? Orig Got)
         Idem (content-eq (reduce (mk-expand Got)) Got)
         Ok (and CE (and SP Idem))
         (do (if Ok
                 (output "  PASS expand ~A~%" Name)
                 (output "  FAIL expand ~A: ce=~A sample=~A idem=~A got=~A~%"
                         Name CE SP Idem (pretty-expr Got)))
             Ok)))

\\ --- sample-only Expand golden (Expected normal form harder to spell exactly) ---
(define check-expand-sample
  Name Orig ->
    (let Got (reduce (mk-expand Orig))
         SP (sample-eq? Orig Got)
         Idem (content-eq (reduce (mk-expand Got)) Got)
         Ok (and SP Idem)
         (do (if Ok
                 (output "  PASS expand ~A (sample+idem)~%" Name)
                 (output "  FAIL expand ~A: sample=~A idem=~A got=~A~%"
                         Name SP Idem (pretty-expr Got)))
             Ok)))

\\ content-eq + idempotence only (for opaque-generator goldens like Sin[x] where
\\ a generator does not reduce to a number, so the sample-point check N/A).
(define check-expand-ce
  Name Orig Expected ->
    (let Got (reduce (mk-expand Orig))
         CE (content-eq Got Expected)
         Idem (content-eq (reduce (mk-expand Got)) Got)
         Ok (and CE Idem)
         (do (if Ok
                 (output "  PASS expand ~A (ce+idem)~%" Name)
                 (output "  FAIL expand ~A: ce=~A idem=~A got=~A~%"
                         Name CE Idem (pretty-expr Got)))
             Ok)))

(define check-polyq
  Name E V Expected ->
    (let Got (reduce (mk-polyq E V))
         Ok (content-eq Got (bool->expr Expected))
         (do (if Ok
                 (output "  PASS PolynomialQ ~A~%" Name)
                 (output "  FAIL PolynomialQ ~A: got ~A want ~A~%"
                         Name (pretty-expr Got) Expected))
             Ok)))

(define poly-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (poly-all-true? Xs))

(define run-poly-tests
  -> (let Ign0 (demo-register-arith)
          Ign (output "~%=== SCUD 17 Wave B poly (Expand / PolynomialQ) ===~%")
          X (pv-x)
          Y (pv-y)
          \\ (x+1)^2 -> x^2 + 2x + 1
          E1 [(p-power) [(p-plus) X [int 1]] [int 2]]
          Exp1 [(p-plus) [(p-power) X [int 2]] [(p-times) [int 2] X] [int 1]]
          Ok1 (check-expand "(x+1)^2" E1 Exp1)
          \\ (x+1)(x-1) -> x^2 - 1
          E2 [(p-times) [(p-plus) X [int 1]]
                        [(p-plus) X [(p-times) [int -1] [int 1]]]]
          Exp2 [(p-plus) [(p-power) X [int 2]] [int -1]]
          Ok2 (check-expand "(x+1)(x-1)" E2 Exp2)
          \\ (x+y)^2 -> x^2 + 2xy + y^2   (exact normal form depends on hash order;
          \\ verify via sample + idempotence which are order-independent)
          E3 [(p-power) [(p-plus) X Y] [int 2]]
          Ok3 (check-expand-sample "(x+y)^2" E3)
          \\ (x+1)^3
          E4 [(p-power) [(p-plus) X [int 1]] [int 3]]
          Ok4 (check-expand-sample "(x+1)^3" E4)
          \\ (2x+3)(x-1)
          E5 [(p-times) [(p-plus) [(p-times) [int 2] X] [int 3]]
                        [(p-plus) X [int -1]]]
          Ok5 (check-expand-sample "(2x+3)(x-1)" E5)
          \\ (Sin[x]+1)^2 -> Sin[x]^2 + 2 Sin[x] + 1  (opaque generator)
          SinX [[sym (protect Sin)] X]
          E6 [(p-power) [(p-plus) SinX [int 1]] [int 2]]
          Exp6 [(p-plus) [(p-power) SinX [int 2]] [(p-times) [int 2] SinX] [int 1]]
          Ok6 (check-expand-ce "(Sin[x]+1)^2" E6 Exp6)
          \\ numeric/constant case: (2+3)^2 -> 25
          E7 [(p-power) [(p-plus) [int 2] [int 3]] [int 2]]
          Ok7 (check-expand "(2+3)^2" E7 [int 25])
          \\ --- PolynomialQ goldens ---
          Q1 (check-polyq "x^2+1 in x"
                [(p-plus) [(p-power) X [int 2]] [int 1]] X true)
          Q2 (check-polyq "a x^2 + b in x"
                [(p-plus) [(p-times) [sym (protect ap)] [(p-power) X [int 2]]]
                          [sym (protect bp)]] X true)
          Q3 (check-polyq "Sin[x] in x" [[sym (protect Sin)] X] X false)
          Q4 (check-polyq "1/x in x"
                [(p-power) X [int -1]] X false)
          Q5 (check-polyq "x^(1/2) in x"
                [(p-power) X [rat 1 2]] X false)
          Ok (poly-all-true? [Ok1 Ok2 Ok3 Ok4 Ok5 Ok6 Ok7 Q1 Q2 Q3 Q4 Q5])
          (do (if Ok (output "poly (SCUD 17 Wave B): PASS~%")
                  (output "poly (SCUD 17 Wave B): FAIL~%"))
              Ok)))
