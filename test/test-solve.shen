\\ test-solve.shen - SCUD 19 Wave D: Solve polynomial equations in one var over Q.
\\ Loaded BEFORE test/test.shen; run-solve-tests wired into run-all-tests.
\\
\\ Inputs are built with the reader (parse-expr-string) and the '==' operator.
\\ The PRIMARY oracle is the substitute-back check: every returned root r, when
\\ substituted into the equation's polynomial P and reduced, must give [int 0].
\\ Where the root set is exact we ALSO assert the expected set (as a multiset of
\\ reduced roots).  Inert cases assert the Solve head is unchanged.

\\ the test variable in every input is x.
(define sol-x -> (intern "x"))

\\ build Solve[parse(S), x].
(define sol-solve
  S -> [[sym (protect Solve)] (parse-expr-string S) [sym (sol-x)]])

\\ the equation's polynomial P = L - R (Equal normalize), for the oracle.
(define sol-poly
  S -> (solve-normalize (parse-expr-string S)))

\\ substitute x := R into P and reduce (reuse solve.shen's helper).
(define sol-eval
  P R -> (reduce (sv-subst [sym (sol-x)] R P)))

\\ --- extract the root list from a reduced Solve result (List[..] head). ---
(define sol-roots
  [H | Roots] -> (if (= (str (sol-head-name H)) "List") Roots [bad])
  _ -> [bad])

(define sol-head-name
  [sym S] -> S
  _ -> [sym none])

\\ --- every root substitutes back to 0 ? ---
(define sol-all-zero?
  _ [] -> true
  P [R | Rs] -> (let V (sol-eval P R)
                     (if (and (numeric? V) (num-eq? V [int 0]))
                         (sol-all-zero? P Rs)
                         false)))

\\ --- multiset equality of two root lists (by content-eq on reduced forms). ---
(define sol-set-eq?
  As Bs -> (and (= (length As) (length Bs))
                (and (sol-subset? As Bs) (sol-subset? Bs As))))

(define sol-subset?
  [] _ -> true
  [A | As] Bs -> (if (sol-member? A Bs) (sol-subset? As Bs) false))

(define sol-member?
  _ [] -> false
  A [B | Bs] -> (if (content-eq (reduce A) (reduce B)) true (sol-member? A Bs)))

\\ ============================================================================
\\ check-solve-set: solve S, require (a) NOT inert, (b) substitute-back oracle on
\\ all roots, (c) the root multiset equals Expected (a reader-built list of exprs).
\\ ============================================================================
(define check-solve-set
  Name S Expected ->
    (let R (reduce (sol-solve S))
         Inert (= (head R) [sym (protect Solve)])
         Roots (if Inert [bad] (sol-roots R))
         P (sol-poly S)
         Oracle (if (= Roots [bad]) false (sol-all-zero? P Roots))
         SetOk (if (= Roots [bad]) false (sol-set-eq? Roots Expected))
         Ok (and (not Inert) (and Oracle SetOk))
         (do (if Ok
                 (output "  PASS solve ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL solve ~A: inert=~A oracle=~A set=~A got=~A~%"
                         Name Inert Oracle SetOk (pretty-expr R)))
             Ok)))

\\ check-solve-oracle: NOT inert + substitute-back oracle only (root form may be
\\ symbolic, e.g. Sqrt). Used where we don't pin the exact expected set.
(define check-solve-oracle
  Name S ->
    (let R (reduce (sol-solve S))
         Inert (= (head R) [sym (protect Solve)])
         Roots (if Inert [bad] (sol-roots R))
         P (sol-poly S)
         Oracle (if (= Roots [bad]) false (sol-all-zero? P Roots))
         Ok (and (not Inert) Oracle)
         (do (if Ok
                 (output "  PASS solve-oracle ~A -> ~A~%" Name (pretty-expr R))
                 (output "  FAIL solve-oracle ~A: inert=~A oracle=~A got=~A~%"
                         Name Inert Oracle (pretty-expr R)))
             Ok)))

\\ check-solve-inert: head must remain Solve (no answer returned).
(define check-solve-inert
  Name Expr ->
    (let R (reduce Expr)
         Ok (= (head R) [sym (protect Solve)])
         (do (if Ok
                 (output "  PASS solve-inert ~A (head unchanged)~%" Name)
                 (output "  FAIL solve-inert ~A: got=~A~%" Name (pretty-expr R)))
             Ok)))

(define sol-all-true?
  [] -> true
  [false | _] -> false
  [_ | Xs] -> (sol-all-true? Xs))

\\ expected-root helpers (reader-built numeric exprs).
(define sol-int E -> (parse-expr-string E))

(define run-solve-tests
  -> (let Ign (output "~%=== SCUD 19 Wave D solve (Solve over Q + '==' reader) ===~%")
          \\ --- reader: '==' parses + round-trips ---
          P1 (sol-parse-check "x^2==1")
          \\ --- degree 1 (exact set) ---
          S1 (check-solve-set "x-3==0" "x-3==0" [(parse-expr-string "3")])
          S2 (check-solve-set "2*x+6==0" "2*x+6==0" [(parse-expr-string "-3")])
          \\ --- degree 2 with rational roots (exact set) ---
          S3 (check-solve-set "x^2-1==0" "x^2-1==0"
                [(parse-expr-string "1") (parse-expr-string "-1")])
          S4 (check-solve-set "x^2-5*x+6==0" "x^2-5*x+6==0"
                [(parse-expr-string "2") (parse-expr-string "3")])
          \\ --- degree 2 irrational: INERT under current rules (Sqrt[2]^2 does not
          \\     reduce to 2, so the substitute-back gate cannot verify) ---
          S5 (check-solve-inert "x^2-2==0 (irrational, Sqrt unverifiable)"
                (sol-solve "x^2-2==0"))
          \\ --- degree 3 via Factor (exact set) ---
          S6 (check-solve-set "x^3-x==0" "x^3-x==0"
                [(parse-expr-string "0") (parse-expr-string "1") (parse-expr-string "-1")])
          \\ --- inert: irreducible cubic ---
          S7 (check-solve-inert "x^3-x-1==0 (irreducible cubic)"
                (sol-solve "x^3-x-1==0"))
          \\ --- inert: symbolic coefficients ---
          S8 (check-solve-inert "a*x+b==0 (symbolic coeff)"
                [[sym (protect Solve)] (parse-expr-string "a*x+b==0") [sym (sol-x)]])
          Ok (sol-all-true? [P1 S1 S2 S3 S4 S5 S6 S7 S8])
          (do (if Ok (output "solve (SCUD 19 Wave D): PASS~%")
                  (output "solve (SCUD 19 Wave D): FAIL~%"))
              Ok)))

\\ '==' parse + print round-trip: parse S, print it, re-parse, require content-eq.
(define sol-parse-check
  S -> (let E (parse-expr-string S)
            Pr (print-expr E)
            E2 (parse-expr-string Pr)
            Ok (and (op-headed? "Equal" E) (content-eq E E2))
            (do (if Ok
                    (output "  PASS reader ~A -> ~A (round-trips)~%" S Pr)
                    (output "  FAIL reader ~A: print=~A E=~A E2=~A~%" S Pr E E2))
                Ok)))
