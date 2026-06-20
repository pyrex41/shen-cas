\\ test-pfrac.shen - generalized rational-function integration (Wave 4 extension):
\\ denominators that factor into several distinct linear factors (total degree >= 3)
\\ or one linear factor times one irreducible quadratic. Improper inputs handled
\\ by polynomial long division.
\\
\\ Oracle: numeric differentiate-back, but with a FLOAT evaluator (pf-eval) so it
\\ also verifies antiderivatives whose derivative carries Sqrt[..] coefficients
\\ (the irreducible-quadratic / ArcTan case for 1/(x^3+1)). For an integrand f,
\\ R = reduce(Integrate[f,x]); at several integer sample points s avoiding the
\\ poles, pf-eval(D[R,x]|x=s) must match pf-eval(f|x=s) to a tight tolerance.
\\ D[ArcTan[u]] = u'/(1+u^2) introduces no transcendental head, only Power/Plus/
\\ Times with possible Sqrt coefficients, all of which pf-eval handles exactly in
\\ floating point. A rational(+sqrt) identity holding at several points is the
\\ identity. Inert cases must keep the Integrate head.
\\
\\ Helper names are prefixed pf- to avoid collisions with other test files.

(define pf-x -> [sym (intern "x")])
(define pf-int F -> [[sym (protect Integrate)] F (pf-x)])
(define pf-d R -> [[sym (protect D)] R (pf-x)])
(define pf-read S -> (parse-expr-string S))

\\ -------- floating-point evaluator: Expr (x already substituted) -> [some F]/[none] --------
\\ Handles literals, Plus, Times, Power (int and 1/2 exponents -> sqrt), Divide.
\\ Any unsupported head (Log/ArcTan/symbol) -> [none] so the case cannot silently
\\ pass. Sound: floats are only used to CHECK an already-exactly-derived answer.
(define pf-eval
  [int N] -> [some (pf-i2f N)]
  [rat N D] -> [some (pf-div (pf-i2f N) (pf-i2f D))]
  [[sym S] | Args] -> (pf-eval-app (str S) Args)
  _ -> [none])

(define pf-i2f N -> (+ N 0.0))

(define pf-div A B -> (if (pf-fzero? B) (error "pf-eval: /0") (/ A B)))

(define pf-fzero? F -> (if (< F 0.0) false (if (> F 0.0) false true)))

(define pf-eval-app
  "Plus"   Args -> (pf-eval-sum Args 0.0)
  "Times"  Args -> (pf-eval-prod Args 1.0)
  "Power"  [B E] -> (pf-eval-power B E)
  "Divide" [A B] -> (pf-eval-divide A B)
  "Minus"  [A B] -> (pf-eval-minus A B)
  _ _ -> [none])

(define pf-eval-sum
  [] Acc -> [some Acc]
  [A | As] Acc -> (pf-eval-sum-2 As Acc (pf-eval A)))
(define pf-eval-sum-2
  As Acc [some V] -> (pf-eval-sum As (+ Acc V))
  As Acc _ -> [none])

(define pf-eval-prod
  [] Acc -> [some Acc]
  [A | As] Acc -> (pf-eval-prod-2 As Acc (pf-eval A)))
(define pf-eval-prod-2
  As Acc [some V] -> (pf-eval-prod As (* Acc V))
  As Acc _ -> [none])

(define pf-eval-minus
  A B -> (pf-eval-minus-2 (pf-eval A) (pf-eval B)))
(define pf-eval-minus-2
  [some X] [some Y] -> [some (- X Y)]
  _ _ -> [none])

(define pf-eval-divide
  A B -> (pf-eval-divide-2 (pf-eval A) (pf-eval B)))
(define pf-eval-divide-2
  [some X] [some Y] -> [some (pf-div X Y)]
  _ _ -> [none])

\\ Power: integer exponent (>=0 or <0) handled by repeated mult / reciprocal;
\\ exponent 1/2 -> sqrt (Newton); -1/2 -> 1/sqrt. Other exponents decline.
(define pf-eval-power
  B [int E] -> (pf-eval-power-int (pf-eval B) E)
  B [rat 1 2] -> (pf-eval-power-sqrt (pf-eval B) 1)
  B [rat -1 2] -> (pf-eval-power-sqrt (pf-eval B) -1)
  B _ -> [none])

(define pf-eval-power-int
  [some V] E -> [some (pf-ipow V E)]
  _ _ -> [none])

(define pf-ipow
  V 0 -> 1.0
  V E -> (if (< E 0)
             (pf-div 1.0 (pf-ipow-pos V (- 0 E)))
             (pf-ipow-pos V E)))
(define pf-ipow-pos
  V 0 -> 1.0
  V E -> (* V (pf-ipow-pos V (- E 1))))

(define pf-eval-power-sqrt
  [some V] Sgn -> (pf-sqrt-result (pf-sqrt V) Sgn)
  _ _ -> [none])
(define pf-sqrt-result
  S 1 -> [some S]
  S -1 -> [some (pf-div 1.0 S)])

\\ Newton's method for sqrt of a non-negative float.
(define pf-sqrt
  X -> (if (< X 0.0) (error "pf-eval: sqrt of negative") (pf-sqrt-iter X (pf-sqrt-init X) 60)))
(define pf-sqrt-init X -> (if (< X 1.0) 1.0 X))
(define pf-sqrt-iter
  X G 0 -> G
  X G N -> (pf-sqrt-iter X (* 0.5 (+ G (pf-div X G))) (- N 1)))

\\ tolerance compare
(define pf-fabs F -> (if (< F 0.0) (- 0.0 F) F))
(define pf-close? A B -> (< (pf-fabs (- A B)) 0.000001))

\\ -------- differentiate-back at samples via the float oracle --------
(define pf-sample-eq?
  DR Ig S -> (pf-sample-eq-2 (pf-eval (reduce (se-subst (pf-x) [int S] DR)))
                             (pf-eval (reduce (se-subst (pf-x) [int S] Ig)))))
(define pf-sample-eq-2
  [some L] [some R] -> (pf-close? L R)
  _ _ -> false)

(define pf-samples-ok?
  DR Ig [] -> true
  DR Ig [S | Ss] -> (if (pf-sample-eq? DR Ig S) (pf-samples-ok? DR Ig Ss) false))

(define pf-back-ok?
  Ig Samples -> (let R (reduce (pf-int Ig))
                     (if (= (head R) [sym (protect Integrate)])
                         false
                         (pf-samples-ok? (reduce (pf-d R)) Ig Samples))))

(define pf-check
  Name S Samples -> (let Ig (pf-read S)
                         Ok (pf-back-ok? Ig Samples)
                         (do (if Ok
                                 (output "  PASS pfrac ~A: ~A -> ~A~%" Name S (pretty-expr (reduce (pf-int Ig))))
                                 (output "  FAIL pfrac ~A: ~A -> ~A~%" Name S (pretty-expr (reduce (pf-int Ig)))))
                             Ok)))

(define pf-check-inert
  Name S -> (let Ig (pf-read S)
                 R (reduce (pf-int Ig))
                 Ok (= (head R) [sym (protect Integrate)])
                 (do (if Ok
                         (output "  PASS pfrac-inert ~A (head unchanged)~%" Name)
                         (output "  FAIL pfrac-inert ~A: ~A -> ~A~%" Name S (pretty-expr R)))
                     Ok)))

(define pf-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (pf-all-true? Xs))

(define run-pfrac-tests
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== generalized partial-fraction integration ===~%")
          \\ --- (a) several distinct linear factors, total degree >= 3 ---
          \\ 1/(x^3-x): poles at 0, +-1 -> samples 2,3,5,7
          T1 (pf-check "3 linear 1/(x^3-x)"        "1/(x^3-x)"        [2 3 5 7])
          \\ another all-linear cubic: 1/((x-1)(x-2)(x-3)) -> poles 1,2,3
          T2 (pf-check "3 linear 1/(x^3-6x^2+11x-6)" "1/(x^3-6*x^2+11*x-6)" [4 5 7 9])
          \\ --- (b) one linear factor x one irreducible quadratic ---
          \\ 1/(x^3+1) = 1/((x+1)(x^2-x+1)): pole -1 -> samples 0,2,3,5
          \\ (verified through the float oracle, which folds the Sqrt[3/4] coeff)
          A1 (pf-check "lin x quad 1/(x^3+1)"      "1/(x^3+1)"        [0 2 3 5])
          \\ --- mixed / improper (step 2: poly part + proper part) ---
          M1 (pf-check "improper (x^2+1)/(x^3-x)"  "(x^2+1)/(x^3-x)"  [2 3 5 7])
          M2 (pf-check "improper (x^3)/(x^3-x)"    "(x^3)/(x^3-x)"    [2 3 5 7])
          \\ --- inert: x^4+1 has no rational roots and no usable factorization ---
          I1 (pf-check-inert "1/(x^4+1)"           "1/(x^4+1)")
          Ok (pf-all-true? [T1 T2 A1 M1 M2 I1])
          (do (if Ok (output "generalized partial-fraction integration: PASS~%")
                  (output "generalized partial-fraction integration: FAIL~%"))
              Ok)))
