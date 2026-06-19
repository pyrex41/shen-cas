\\ demo/dsl.shen - tiny readable constructor DSL for the demo.
\\ A hand-built stand-in for the surface-syntax reader that SCUD 14.2 will provide:
\\ it just builds the kernel's bracket-AST so the demo forms read like math.

(define vx -> [sym (protect x)])           \\ the variable x
(define vy -> [sym (protect y)])           \\ an independent variable y
(define lit N -> [int N])                  \\ integer literal

(define pls A B -> [[sym (protect Plus)] A B])
(define tms A B -> [[sym (protect Times)] A B])
(define powr B E -> [[sym (protect Power)] B E])
(define quo A B -> [[sym (protect Divide)] A B])

(define f-sin E -> [[sym (protect Sin)] E])
(define f-cos E -> [[sym (protect Cos)] E])
(define f-exp E -> [[sym (protect Exp)] E])
(define f-log E -> [[sym (protect Log)] E])
(define f-unknown E -> [[sym (protect g)] E])   \\ a symbol with no rules

(define deriv F -> [[sym (protect D)] F (vx)])        \\ d/dx F
(define integ F -> [[sym (protect Integrate)] F (vx)]) \\ ∫ F dx
(define simp E -> [[sym (protect Simplify)] E])

\\ reduce to normal form and pretty-print
(define shw E -> (pretty-expr (reduce E)))

(output "demo/dsl.shen loaded.~%")
