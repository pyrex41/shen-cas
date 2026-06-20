\\ test-trace.shen - step-by-step derivation tracer (src/trace.shen).
\\ Loaded by load.shen BEFORE test/test.shen so run-all-tests can call run-trace-tests.
\\
\\ KEY INVARIANT (faithfulness): the LAST expression of a derivation trace must
\\ equal (reduce E). reduce-trace walks the same ordered reduction sequence as the
\\ evaluator, one micro-step at a time, so it can never reach a different answer
\\ than the engine -- it only makes the intermediate steps visible. We also check
\\ that genuinely-reducing inputs produce a non-empty trace, and that an inert
\\ input (unknown head) yields the same inert form with an empty derivation.

(define tt-x -> [sym (protect xt)])
(define tt-d   E -> [[sym (protect D)] E (tt-x)])
(define tt-int E -> [[sym (protect Integrate)] E (tt-x)])
(define tt-simp E -> [[sym (protect Simplify)] E])

\\ final form of a derivation == the trace's last After (or E if no steps).
(define tt-final
  E -> (tr-final E (reduce-trace E)))

\\ the trace's final form must agree with the engine's normal form.
(define tt-faithful?
  E -> (content-eq (tt-final E) (reduce E)))

(define tt-nonempty?
  E -> (not (empty? (reduce-trace E))))

(define run-trace-tests
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== step-by-step derivations (reduce-trace / derive) ===~%")
          X (tt-x)
          \\ faithfulness across the operation surface (final step == reduce):
          P1 (tt-faithful? (tt-d [[sym (protect Power)] X [int 3]]))            \\ d/dx x^3
          P2 (tt-faithful? (tt-d [[sym (protect Plus)] [[sym (protect Power)] X [int 2]] X]))  \\ d/dx (x^2+x)
          P3 (tt-faithful? (tt-d [[sym (protect Sin)] [[sym (protect Power)] X [int 2]]]))     \\ chain rule
          P4 (tt-faithful? (tt-int [[sym (protect Cos)] X]))                    \\ int Cos x dx
          P5 (tt-faithful? (tt-int [[sym (protect Power)] X [int 2]]))          \\ int x^2 dx
          P6 (tt-faithful? (tt-simp [[sym (protect Plus)] [[sym (protect Times)] [int 3] X]
                                                          [[sym (protect Times)] [int 2] X]]))  \\ collect
          P7 (tt-faithful? [[sym (protect Plus)] [int 7] [int 8]])             \\ arithmetic
          \\ a reducing input has at least one recorded step:
          N1 (tt-nonempty? (tt-d [[sym (protect Power)] X [int 3]]))
          \\ inert input (unknown head g): trace empty, final == reduce (still inert):
          Inert (tt-d [[sym (protect gt)] X])
          I1 (and (empty? (reduce-trace Inert)) (tt-faithful? Inert))
          Ok (and P1 (and P2 (and P3 (and P4 (and P5 (and P6 (and P7 (and N1 I1))))))))
          (do (output "trace: dx^3=~A d(x^2+x)=~A chain=~A intCos=~A intx^2=~A collect=~A arith=~A nonempty=~A inert=~A~%"
                      P1 P2 P3 P4 P5 P6 P7 N1 I1)
              (if Ok (output "step-by-step derivations: PASS~%")
                  (output "step-by-step derivations: FAIL~%"))
              Ok)))

(output "test-trace.shen loaded (reduce-trace / derive faithfulness corpus).~%")
