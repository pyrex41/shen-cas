\\ Phase 0+ test harness for shen-cas
\\ Golden format in golden/ : lines like   EXPR -> EXPECTED
\\ (s-exprs; simple for skeleton; full reader later).
\\ Rejection tests declared as data for future gate.
\\
\\ Run: (load "test/test.shen")

\\ Trivial identity "reduce" for skeleton Phase 0 (later replaced by real reduce)
(define trivial-reduce
  E -> E)

\\ Very small golden parser: split on first " -> " , read as Shen data.
\\ For MVP skeleton we use a hand-curated list + file scan where possible.
(define load-golden-file
  Path -> (trap-error (read-file-as-bytelist Path) (/. _ [])))   \\ placeholder; real impl uses line parse

\\ For skeleton: hard-coded cases + one file-backed to demonstrate.
\\ Expanded from SCUD task 3 subagent + Book 21.4
(define golden-cases
  -> [
    [12 -> 12]
    [(sym Plus) -> (sym Plus)]
    [[(sym Plus) (int 1) (int 2)] -> [(sym Plus) (int 1) (int 2)]]
    [[(int 12) * [(int 5) - (int 3)]] -> [(int 24)]]   \\ Book-inspired
    [[(int 9) - (int 8)] -> (int 1)]
    [[(int 2) + (int 3)] -> (int 5)]
    [[(int 6) / (int 2)] -> (int 3)]
    [[(int 4) * (int 7)] -> (int 28)]
  ])

\\ Run one case with trivial-reduce; return (pass? input expected got)
(define run-golden-case
  [In -> Exp] -> (let Got (trivial-reduce In)
                      Pass (= Got Exp)
                      (do (if Pass
                              (output "  PASS: ~A -> ~A~%" In Exp)
                              (output "  FAIL: ~A -> ~A got ~A~%" In Exp Got))
                          Pass)))

(define run-golden
  _ -> (let Cases (golden-cases)
            Results (map run-golden-case Cases)
            Passed (filter (/. X X) Results)
            (do (output "Golden: ~A/~A passed~%" (length Passed) (length Cases))
                (= (length Passed) (length Cases)))))

\\ Rejection fixture declarations (data only in Phase 0; harness will load/attempt later)
\\ Sourced/enriched from SCUD task 3 (Book + plan §8.1)
(define rejection-fixtures
  -> [
    "malformed-pattern: Pattern[3,5]   # Pattern name must be symbol, not literal"
    "malformed-pattern: (pattern 3 5)"
    "seq-outside-arg: (named x (blank-seq))   # seq-patterns only inside compound arg lists"
    "seq-outside-arg: (blank-seq)             # not at head or top level"
    "unbound-rhs: x_ -> y                     # y unbound on LHS (and not builtin)"
    "unbound-rhs: {x_ y_ -> z}"
    "bad-attr: hold-all + hold-first"
    "bad-attr: listable + hold-all            # without explicit opt-in"
    "bad-attr: (hold-all hold-first)"
  ])

(define run-rejection-tests
  _ -> (let Fixes (rejection-fixtures)
            (do (output "Rejection fixtures declared (~A):~%" (length Fixes))
                (map (/. F (output "  - ~A~%" F)) Fixes)
                (output "  (enforcement comes in Phase 1+ with checked datatypes)~%")
                true)))

(define run-all-tests
  -> (let _ (output "=== shen-cas test harness (Phase 0) ===~%")
          g (run-golden [])
          r (run-rejection-tests [])
          (if (and g r)
              (do (output "~%PASS~%") true)
              (do (output "~%FAIL~%") false))))

\\ Auto-run on load
(run-all-tests)
