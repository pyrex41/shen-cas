\\ Phase 0+ test harness for shen-cas
\\ Golden format in golden/ : one or more lines of "INPUT -> EXPECTED"
\\ where INPUT and EXPECTED are readable s-expr or algebra syntax (later).
\\ Rejection tests: declare expected errors at load/registration time.
\\
\\ Run: (load "test/test.shen") then (run-tests) or equivalent.

(define run-golden
  _ -> (do (output "Golden tests not yet implemented (Phase 0 skeleton).~%")
           true))

(define run-rejection-tests
  _ -> (do (output "Static rejection tests not yet implemented (Phase 0 skeleton).~%")
           true))

(define run-all-tests
  -> (let _ (output "=== shen-cas test harness (Phase 0 skeleton) ===~%")
          g (run-golden [])
          r (run-rejection-tests [])
          (if (and g r)
              (do (output "PASS (skeleton)~%") true)
              (do (output "FAIL (skeleton)~%") false))))

\\ Entry
(run-all-tests)
