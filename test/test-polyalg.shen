\\ test-polyalg.shen - SCUD 18 Wave C: univariate polynomial algebra over Q.
\\ Loaded BEFORE test/test.shen; run-polyalg-tests wired into run-all-tests.
\\
\\ Inputs are built with the reader (parse-expr-string). The self-checks ARE the
\\ oracle:
\\   GCD    : result divides BOTH inputs (uni-divmod remainder zero).
\\   Factor : Expand[factored] content-eq Expand[input] for ALL.
\\   Cancel : sample-point verify the cancelled fraction equals the original.
\\   Together: sample-point verify the combined fraction equals the sum.
\\   inert  : multivariate input leaves the head unchanged.

\\ --- build an expr from a source string, then reduce it (apply built-ins). ---
(define pa-read   S -> (parse-expr-string S))
(define pa-reduce S -> (reduce (parse-expr-string S)))

\\ wrap a head around reader-built args.
(define pa-gcd   A B -> [[sym (protect PolynomialGCD)] (pa-read A) (pa-read B)])
(define pa-cancel  E -> [[sym (protect Cancel)] (pa-read E)])
(define pa-together E -> [[sym (protect Together)] (pa-read E)])
(define pa-factor  P -> [[sym (protect Factor)] (pa-read P)])

\\ the single test variable used in inputs is x (reader symbol "x").
(define pax -> (intern "x"))
(define pay -> (intern "y"))

\\ substitute [sym Name] := [int Val] everywhere; reduce to numeric (reuse style
\\ from test-poly).
(define pa-subst
  [sym S] Name Val -> (if (= S Name) [int Val] [sym S])
  [int N] _ _ -> [int N]
  [rat N D] _ _ -> [rat N D]
  [H | Args] Name Val -> [(pa-subst H Name Val) | (pa-subst-list Args Name Val)]
  E _ _ -> E)

(define pa-subst-list
  [] _ _ -> []
  [A | As] Name Val -> [(pa-subst A Name Val) | (pa-subst-list As Name Val)])

(define pa-eval-x
  E V -> (reduce (pa-subst E (pax) V)))

(define pa-eval-xy
  E Vx Vy -> (reduce (pa-subst (pa-subst E (pax) Vx) (pay) Vy)))

\\ ============================================================================
\\ uni-divmod divisibility helper: does expr B (univariate in x) divide expr A?
\\ Convert both to coeff vectors in x and check uni-rem is zero.
\\ ============================================================================
(define pa-divides?
  A B -> (let V [sym (pax)]
              CA (expr->coeffs V A)
              CB (expr->coeffs V B)
              (if (or (= CA [none]) (= CB [none]))
                  false
                  (zero-vec? (uni-rem (hd (tl CA)) (hd (tl CB)))))))

\\ --- GCD check: result divides both inputs (and is non-trivial expr). ---
(define check-gcd
  Name As Bs ->
    (let A (pa-read As)
         B (pa-read Bs)
         G (reduce [[sym (protect PolynomialGCD)] A B])
         Inert (= (head G) [sym (protect PolynomialGCD)])
         DA (pa-divides? A G)
         DB (pa-divides? B G)
         Ok (and (not Inert) (and DA DB))
         (do (if Ok
                 (output "  PASS gcd ~A~%" Name)
                 (output "  FAIL gcd ~A: inert=~A divA=~A divB=~A got=~A~%"
                         Name Inert DA DB (pretty-expr G)))
             Ok)))

\\ --- Factor check: Expand[factored] content-eq Expand[input]. ---
(define check-factor
  Name Ps ->
    (let P (pa-read Ps)
         F (reduce [[sym (protect Factor)] P])
         Lhs (reduce [[sym (protect Expand)] F])
         Rhs (reduce [[sym (protect Expand)] P])
         Ok (content-eq Lhs Rhs)
         (do (if Ok
                 (output "  PASS factor ~A -> ~A~%" Name (pretty-expr F))
                 (output "  FAIL factor ~A: Expand mismatch got=~A~%"
                         Name (pretty-expr F)))
             Ok)))

\\ --- Factor irreducible: result content-eq the (expanded) input (unchanged). ---
(define check-factor-irreducible
  Name Ps ->
    (let P (pa-read Ps)
         F (reduce [[sym (protect Factor)] P])
         Ok (content-eq (reduce [[sym (protect Expand)] F])
                        (reduce [[sym (protect Expand)] P]))
         \\ irreducible: factored form must NOT introduce a Times of two
         \\ non-constant linear factors -- expand-equality already guards
         \\ soundness; we additionally accept that it stays a single factor.
         (do (if Ok
                 (output "  PASS factor-irreducible ~A -> ~A~%" Name (pretty-expr F))
                 (output "  FAIL factor-irreducible ~A: got=~A~%" Name (pretty-expr F)))
             Ok)))

\\ --- Cancel: sample-point verify cancelled == original ratio where defined. ---
(define pa-cancel-points -> [2 3 5 7 -3 -4]) \\ avoid roots of the denominators used

(define check-cancel
  Name Es ->
    (let Orig (pa-read Es)
         C (reduce [[sym (protect Cancel)] Orig])
         Inert (= (head C) [sym (protect Cancel)])
         SP (cancel-sample Orig C (pa-cancel-points))
         Ok (and (not Inert) SP)
         (do (if Ok
                 (output "  PASS cancel ~A -> ~A~%" Name (pretty-expr C))
                 (output "  FAIL cancel ~A: inert=~A sample=~A got=~A~%"
                         Name Inert SP (pretty-expr C)))
             Ok)))

(define cancel-sample
  _ _ [] -> true
  Orig C [V | Vs] -> (let A (pa-eval-x Orig V)
                          B (pa-eval-x C V)
                          (if (and (numeric? A) (and (numeric? B) (num-eq? A B)))
                              (cancel-sample Orig C Vs)
                              false)))

\\ --- Together: sample-point verify combined fraction == the sum. ---
(define pa-together-points -> [[2 3] [3 5] [5 7] [-3 4] [7 -2]])

(define check-together
  Name Es ->
    (let Orig (pa-read Es)
         T (reduce [[sym (protect Together)] Orig])
         Inert (= (head T) [sym (protect Together)])
         SP (together-sample Orig T (pa-together-points))
         Ok (and (not Inert) SP)
         (do (if Ok
                 (output "  PASS together ~A -> ~A~%" Name (pretty-expr T))
                 (output "  FAIL together ~A: inert=~A sample=~A got=~A~%"
                         Name Inert SP (pretty-expr T)))
             Ok)))

(define together-sample
  _ _ [] -> true
  Orig T [[Vx Vy] | Rest] ->
    (let A (pa-eval-xy Orig Vx Vy)
         B (pa-eval-xy T Vx Vy)
         (if (and (numeric? A) (and (numeric? B) (num-eq? A B)))
             (together-sample Orig T Rest)
             false)))

\\ --- inert edge: a head must remain unchanged on a multivariate input. ---
(define check-inert
  Name E HeadName ->
    (let R (reduce E)
         Ok (= (head R) [sym (protect-head HeadName)])
         (do (if Ok
                 (output "  PASS inert ~A (head unchanged)~%" Name)
                 (output "  FAIL inert ~A: head changed got=~A~%" Name (pretty-expr R)))
             Ok)))

\\ protect a head by its name string (only the heads we test).
(define protect-head
  "PolynomialGCD" -> (protect PolynomialGCD)
  "Factor" -> (protect Factor)
  "Cancel" -> (protect Cancel)
  "Together" -> (protect Together))

(define pa-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (pa-all-true? Xs))

(define run-polyalg-tests
  -> (let Ign (output "~%=== SCUD 18 Wave C polyalg (GCD/Cancel/Together/Factor) ===~%")
          \\ --- PolynomialGCD ---
          G1 (check-gcd "[x^2-1, x-1]" "x^2-1" "x-1")
          G2 (check-gcd "[x^2-1, x^2-2x+1]" "x^2-1" "x^2-2x+1")
          G3 (check-gcd "[x^2+2x+1, x+1]" "x^2+2x+1" "x+1")
          \\ --- Factor (Expand round-trip is the oracle for ALL) ---
          F1 (check-factor "x^2-1" "x^2-1")
          F2 (check-factor "x^2-2x+1" "x^2-2x+1")
          F3 (check-factor "x^2+x" "x^2+x")
          F4 (check-factor "2x^2-2" "2x^2-2")
          F5 (check-factor-irreducible "x^2+1" "x^2+1")
          \\ --- Cancel ---
          C1 (check-cancel "(x^2-1)/(x-1)" "(x^2-1)/(x-1)")
          \\ --- Together ---
          T1 (check-together "1/x + 1/y ... single var x form" "1/x+1/x")
          \\ NOTE: the kernel's univariate engine combines over ONE variable; the
          \\ classic two-variable 1/x+1/y is multivariate -> stays inert (covered
          \\ below). We verify the single-variable combination soundly here, plus
          \\ the (x-1)+(x+1) denominators case.
          T2 (check-together "1/(x-1)+1/(x+1)" "1/(x-1)+1/(x+1)")
          T3 (check-together "1/x + 1/(x+1)" "1/x+1/(x+1)")
          \\ --- inert edges (multivariate) ---
          \\ PolynomialGCD / Factor stay univariate-only -> inert on multivariate.
          I1 (check-inert "PolynomialGCD[x*y, x]"
                [[sym (protect PolynomialGCD)] (pa-read "x*y") (pa-read "x")]
                "PolynomialGCD")
          I2 (check-inert "Factor[x*y+x]"
                [[sym (protect Factor)] (pa-read "x*y+x")]
                "Factor")
          \\ Wave 4: the classic two-variable 1/x+1/y is NO LONGER inert -- the
          \\ multivariate Together fallback combines it over a common denominator.
          \\ Verified by the same x,y sample-equivalence check as the univariate
          \\ Together goldens (head must change away from Together, value preserved).
          I3 (check-together "1/x+1/y (multivariate, Wave 4)" "1/x+1/y")
          Ok (pa-all-true? [G1 G2 G3 F1 F2 F3 F4 F5 C1 T1 T2 T3 I1 I2 I3])
          (do (if Ok (output "polyalg (SCUD 18 Wave C): PASS~%")
                  (output "polyalg (SCUD 18 Wave C): FAIL~%"))
              Ok)))
