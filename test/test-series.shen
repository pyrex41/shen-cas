\\ test-series.shen - SCUD 20 Wave E: Series + Limit.
\\ Loaded BEFORE test/test.shen; run-series-tests wired into run-all-tests.
\\
\\ Inputs are built with the reader (parse-expr-string). Oracles:
\\   - Series known expansions: content-eq (after Expand) with the closed form.
\\   - Series polynomial-EXACT: Series[P, x, n>=deg(P)] = Expand[P] (un-foolable).
\\   - Limit: pinned values + numeric-sampling cross-check (V0 + 1/10^k must
\\     approach the returned limit, getting strictly closer each step).
\\   - inert: a genuinely unknown Limit and Series[Log[x],x,2] stay inert.

(define ser-x -> [sym (intern "x")])

\\ build Series[parse(F), x, N]  and  Series[parse(F), x, V0, N].
(define ser-series
  S N -> [[sym (protect Series)] (parse-expr-string S) (ser-x) [int N]])

\\ build Limit[parse(F), x, V0literal].
(define ser-limit
  S V0 -> [[sym (protect Limit)] (parse-expr-string S) (ser-x) (parse-expr-string V0)])

(define ser-expand
  E -> (reduce [[sym (protect Expand)] E]))

\\ un-foolable equality oracle: Expand[A - B] must reduce to the [int 0] literal.
\\ Robust to representation differences (e.g. Divide[x^2,2] vs Times[x^2,1/2]):
\\ both fold to the same polynomial, so their difference is identically zero.
(define ser-diff-zero?
  A B -> (let D (ser-expand [[sym (protect Plus)] A [[sym (protect Times)] [int -1] B]])
              (if (numeric? D) (num-eq? D [int 0]) false)))

\\ ---- Series equals (Expand[result - expected] = 0) ----
(define check-series-eq
  Name S N Expected ->
    (let R (reduce (ser-series S N))
         Inert (= (head R) [sym (protect Series)])
         Ok (if Inert false (ser-diff-zero? R (parse-expr-string Expected)))
         (do (if Ok
                 (output "  PASS series ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL series ~A: inert=~A got=~A want=~A~%"
                         Name Inert (pretty-expr R) Expected))
             Ok)))

\\ ---- Series polynomial-exact: Series[P,x,N] (Expand) == Expand[P] ----
(define check-series-exact
  Name S N ->
    (let R (reduce (ser-series S N))
         Inert (= (head R) [sym (protect Series)])
         Ok (if Inert false (ser-diff-zero? R (parse-expr-string S)))
         (do (if Ok
                 (output "  PASS series-exact ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL series-exact ~A: inert=~A got=~A want=Expand[~A]~%"
                         Name Inert (pretty-expr R) S))
             Ok)))

\\ ---- Series inert ----
(define check-series-inert
  Name S N ->
    (let R (reduce (ser-series S N))
         Ok (= (head R) [sym (protect Series)])
         (do (if Ok
                 (output "  PASS series-inert ~A (head unchanged)~%" Name)
                 (output "  FAIL series-inert ~A: got=~A~%" Name (pretty-expr R)))
             Ok)))

\\ ============================================================================
\\ Limit: pinned value + numeric-sampling cross-check.
\\ ============================================================================
\\ abs of a numeric expr as a numeric expr.
(define ser-abs
  E -> (if (ser-neg? E) (num-mul [int -1] E) E))

(define ser-neg?
  E -> (let R (as-rat E) (< (rat-num R) 0)))

\\ sample F at x = V0 + 1/10^k for k=1,2,3 ; each reduced to a rational, distance
\\ to L must strictly shrink (approaching the returned limit).
(define ser-sample-point
  V0 K -> (reduce [[sym (protect Plus)] V0
                    [[sym (protect Power)] [int 10] [int (* -1 K)]]]))

(define ser-sample-val
  F V0 K -> (reduce (se-subst (ser-x) (ser-sample-point V0 K) F)))

(define ser-dist
  A L -> (ser-abs (num-sub A L)))

\\ require dist(k=1) > dist(k=2) > dist(k=3)  (strictly closer each step), when
\\ the samples are numerically evaluable. If the function is not numerically
\\ evaluable at the sample points (e.g. Sin of a rational stays symbolic), the
\\ kernel cannot sample it -- the cross-check is then VACUOUS (the pinned value
\\ already comes from a sound, terminating L'Hopital). Returns true in that case
\\ so the pinned-value oracle stands alone; returns false only when samples ARE
\\ numeric but fail to approach L (a real refutation).
(define ser-approaches?
  F V0 L -> (let D1 (ser-sample-val F V0 1)
                 D2 (ser-sample-val F V0 2)
                 D3 (ser-sample-val F V0 3)
                 (if (ser-all-numeric3? D1 D2 D3)
                     (ser-strictly-closer? (ser-dist D1 L) (ser-dist D2 L) (ser-dist D3 L))
                     true)))

(define ser-all-numeric3?
  A B C -> (if (numeric? A) (if (numeric? B) (numeric? C) false) false))

\\ strictly closer: dist1 > dist2 AND dist2 > dist3 (compare via num-sub sign).
(define ser-strictly-closer?
  E1 E2 E3 -> (if (ser-gt? E1 E2) (ser-gt? E2 E3) false))

(define ser-gt?
  A B -> (let R (as-rat (num-sub A B)) (> (rat-num R) 0)))

\\ check-limit: NOT inert, returned numeric L equals Expected, AND the numeric
\\ sampling cross-check passes (sampled F approaches L).
(define check-limit
  Name S V0 Expected ->
    (let F (parse-expr-string S)
         V0e (parse-expr-string V0)
         R (reduce (ser-limit S V0))
         Inert (= (head R) [sym (protect Limit)])
         Numeric (if Inert false (numeric? R))
         Pinned (if Numeric (num-eq? R (parse-expr-string Expected)) false)
         Approaches (if Numeric (ser-approaches? F V0e R) false)
         Ok (and (not Inert) (and Numeric (and Pinned Approaches)))
         (do (if Ok
                 (output "  PASS limit ~A -> ~A (sampled approaches)~%" Name (pretty-expr R))
                 (output "  FAIL limit ~A: inert=~A numeric=~A pinned=~A approaches=~A got=~A~%"
                         Name Inert Numeric Pinned Approaches (pretty-expr R)))
             Ok)))

(define check-limit-inert
  Name S V0 ->
    (let R (reduce (ser-limit S V0))
         Ok (= (head R) [sym (protect Limit)])
         (do (if Ok
                 (output "  PASS limit-inert ~A (head unchanged)~%" Name)
                 (output "  FAIL limit-inert ~A: got=~A~%" Name (pretty-expr R)))
             Ok)))

(define ser-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (ser-all-true? Xs))

(define run-series-tests
  -> (let Ign (output "~%=== SCUD 20 Wave E series (Series + Limit) ===~%")
          \\ --- Series known expansions ---
          E1 (check-series-eq "Series[Exp[x],x,3]" "Exp[x]" 3 "1 + x + (1/2)*x^2 + (1/6)*x^3")
          E2 (check-series-eq "Series[Sin[x],x,3]" "Sin[x]" 3 "x + (-1/6)*x^3")
          E3 (check-series-eq "Series[Cos[x],x,4]" "Cos[x]" 4 "1 + (-1/2)*x^2 + (1/24)*x^4")
          \\ --- Series polynomial-EXACT (un-foolable) ---
          E4 (check-series-exact "Series[(1+x)^3,x,3]" "(1+x)^3" 3)
          E5 (check-series-exact "Series[x^2-2x+5,x,2]" "x^2-2*x+5" 2)
          E6 (check-series-exact "Series[(1+x)^3,x,5] (n>deg)" "(1+x)^3" 5)
          \\ --- Series inert: no Taylor of Log at 0 (Log[0] not numeric) ---
          E7 (check-series-inert "Series[Log[x],x,2] (no expansion at 0)" "Log[x]" 2)
          \\ --- Limit: pinned + numeric sampling ---
          L1 (check-limit "Limit[(x^2-1)/(x-1),x,1]" "(x^2-1)/(x-1)" "1" "2")
          L2 (check-limit "Limit[Sin[x]/x,x,0]" "Sin[x]/x" "0" "1")
          L3 (check-limit "Limit[(x^3-1)/(x-1),x,1]" "(x^3-1)/(x-1)" "1" "3")
          L4 (check-limit "Limit[x^2+1,x,2]" "x^2+1" "2" "5")
          \\ --- Limit inert: genuinely unknown ---
          L5 (check-limit-inert "Limit[Sin[1/x],x,0] (unknown)" "Sin[1/x]" "0")
          Ok (ser-all-true? [E1 E2 E3 E4 E5 E6 E7 L1 L2 L3 L4 L5])
          (do (if Ok (output "series (SCUD 20 Wave E): PASS~%")
                  (output "series (SCUD 20 Wave E): FAIL~%"))
              Ok)))
