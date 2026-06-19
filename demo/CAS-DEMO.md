# shen-cas: a statically-checked term-rewriting CAS in Shen

*2026-06-19T01:20:59Z by Showboat 0.6.1*
<!-- showboat-id: 24a80cbe-9cf4-4791-82f7-30ef0e27e153 -->

A small Mathematica-inspired term-rewriting kernel in Shen, running on the shen-go port. It does exact arithmetic, algebraic simplification, symbolic differentiation, and a bounded subset of symbolic integration -- with every rewrite rule checked at definition time. There is no surface-syntax reader yet, so this demo builds terms with a tiny readable DSL (vx=x, lit=integer, pls/tms/powr/quo, f-sin/f-cos/f-exp/f-log, deriv=d/dx, integ=integral dx, simp=Simplify) and reduces them to normal form. Output is bracket-AST: [Times 3 [Power x 2]] means 3*x^2. Every code block is executable and re-checkable with: showboat verify demo/CAS-DEMO.md

## 1. Exact arithmetic and rationals

```bash
python3 demo/cas-eval.py '(output "Plus[7,8]        = ~A~%" (shw (pls (lit 7) (lit 8))))
(output "Times[-245,67]   = ~A~%" (shw (tms (lit -245) (lit 67))))
(output "Divide[6,4]      = ~A   (exact rational, not 1.5)~%" (shw (quo (lit 6) (lit 4))))
(output "1/2 + 1/3        = ~A~%" (shw (pls (quo (lit 1) (lit 2)) (quo (lit 1) (lit 3)))))
(output "(2/3) * 3        = ~A~%" (shw (tms (quo (lit 2) (lit 3)) (lit 3))))'

```

```output
Plus[7,8]        = 15
Times[-245,67]   = -16415
Divide[6,4]      = [3 / 2]   (exact rational, not 1.5)
1/2 + 1/3        = [5 / 6]
(2/3) * 3        = 2
```

## 2. Algebraic simplification (identities, zero/one laws, collecting like terms)

```bash
python3 demo/cas-eval.py '(output "x + 0            = ~A~%" (shw (pls (vx) (lit 0))))
(output "x * 1            = ~A~%" (shw (tms (vx) (lit 1))))
(output "x * 0            = ~A~%" (shw (tms (vx) (lit 0))))
(output "x ^ 1            = ~A~%" (shw (powr (vx) (lit 1))))
(output "x ^ 0            = ~A~%" (shw (powr (vx) (lit 0))))
(output "3x + 2x          = ~A   (collect like terms)~%" (shw (simp (pls (tms (lit 3) (vx)) (tms (lit 2) (vx))))))
(output "x * x            = ~A~%" (shw (simp (tms (vx) (vx)))))
(output "1*cos x + 0*sin x = ~A   (messy -> clean)~%" (shw (simp (pls (tms (lit 1) (f-cos (vx))) (tms (lit 0) (f-sin (vx)))))))'

```

```output
x + 0            = x
x * 1            = x
x * 0            = 0
x ^ 1            = x
x ^ 0            = 1
3x + 2x          = [Times x 5]   (collect like terms)
x * x            = [Power x 2]
1*cos x + 0*sin x = [Cos x]   (messy -> clean)
```

## 3. Orderless heads and content addressing -- Plus and Times are commutative/associative, folded into the content hash, so a single rule matches any argument order.

```bash
python3 demo/cas-eval.py '(output "Plus[1,2] and Plus[2,1] are the SAME term? ~A~%" (content-eq [[sym (protect Plus)] [int 1] [int 2]] [[sym (protect Plus)] [int 2] [int 1]]))
(output "0 + x            = ~A   (one rule x+0->x matches commuted args)~%" (shw (pls (lit 0) (vx))))'

```

```output
Plus[1,2] and Plus[2,1] are the SAME term? true
0 + x            = x   (one rule x+0->x matches commuted args)
```

## 4. Symbolic differentiation -- d/dx. Constant, variable, and independent-variable rules use definition-time guards (SameQ/FreeQ).

```bash
python3 demo/cas-eval.py '(output "d/dx x^3         = ~A   (power rule)~%" (shw (deriv (powr (vx) (lit 3)))))
(output "d/dx (x^2 + x)   = ~A   (linearity)~%" (shw (simp (deriv (pls (powr (vx) (lit 2)) (vx))))))
(output "d/dx 5           = ~A~%" (shw (deriv (lit 5))))
(output "d/dx x           = ~A~%" (shw (deriv (vx))))
(output "d/dx y           = ~A   (y independent of x)~%" (shw (deriv (vy))))'

```

```output
d/dx x^3         = [Times 3 [Power x 2]]   (power rule)
d/dx (x^2 + x)   = [Plus 1 [Times x 2]]   (linearity)
d/dx 5           = 0
d/dx x           = 1
d/dx y           = 0   (y independent of x)
```

Chain rule, product rule, and the elementary-function table. An unknown function g stays inert (never wrongly zero).

```bash
python3 demo/cas-eval.py '(output "d/dx sin x       = ~A~%" (shw (deriv (f-sin (vx)))))
(output "d/dx sin(x^2)    = ~A   (chain rule)~%" (shw (simp (deriv (f-sin (powr (vx) (lit 2)))))))
(output "d/dx (x*sin x)   = ~A   (product rule)~%" (shw (simp (deriv (tms (vx) (f-sin (vx)))))))
(output "d/dx exp x       = ~A~%" (shw (deriv (f-exp (vx)))))
(output "d/dx log x       = ~A   (= 1/x)~%" (shw (deriv (f-log (vx)))))
(output "d/dx g(x)        = ~A   (unknown g: stays inert)~%" (shw (deriv (f-unknown (vx)))))'

```

```output
d/dx sin x       = [Cos x]
d/dx sin(x^2)    = [Times x [Cos [Power x 2]] 2]   (chain rule)
d/dx (x*sin x)   = [Plus [Times x [Cos x]] [Sin x]]   (product rule)
d/dx exp x       = [Exp x]
d/dx log x       = [Power x -1]   (= 1/x)
d/dx g(x)        = [D [g x] x]   (unknown g: stays inert)
```

## 5. Symbolic integration (bounded subset) -- power rule, 1/x, the elementary table, linearity, and depth-capped integration by parts. Anything outside the supported patterns stays inert by design (it never returns a wrong antiderivative).

```bash
python3 demo/cas-eval.py '(output "int x^2 dx       = ~A   (power rule, needs exact rationals)~%" (shw (integ (powr (vx) (lit 2)))))
(output "int x^-1 dx      = ~A   (the n=-1 special case)~%" (shw (integ (powr (vx) (lit -1)))))
(output "int sin x dx     = ~A~%" (shw (integ (f-sin (vx)))))
(output "int cos x dx     = ~A~%" (shw (integ (f-cos (vx)))))
(output "int (2x+3) dx    = ~A   (linearity)~%" (shw (simp (integ (pls (tms (lit 2) (vx)) (lit 3))))))
(output "int x*exp x dx   = ~A   (by parts; = (x-1)exp x)~%" (shw (simp (integ (tms (vx) (f-exp (vx)))))))
(output "int sin(x^2) dx  = ~A   (no elementary form: inert)~%" (shw (integ (f-sin (powr (vx) (lit 2))))))
(output "int g(x) dx      = ~A   (unknown g: inert)~%" (shw (integ (f-unknown (vx)))))'

```

```output
int x^2 dx       = [Times [1 / 3] [Power x 3]]   (power rule, needs exact rationals)
int x^-1 dx      = [Log x]   (the n=-1 special case)
int sin x dx     = [Times -1 [Cos x]]
int cos x dx     = [Sin x]
int (2x+3) dx    = [Plus [Power x 2] [Times x 3]]   (linearity)
int x*exp x dx   = [Plus [Times -1 [Exp x]] [Times x [Exp x]]]   (by parts; = (x-1)exp x)
int sin(x^2) dx  = [Integrate [Sin [Power x 2]] x]   (no elementary form: inert)
int g(x) dx      = [Integrate [g x] x]   (unknown g: inert)
```

## 6. The un-foolable check: differentiate the integral back. For each result R of an integral, Simplify(d/dx R - integrand) must be 0. A wrong antiderivative would fail this -- it cannot be faked by a table typo.

```bash
python3 demo/cas-eval.py '(output "d/dx(int x^2) - x^2     = ~A   (expect 0)~%" (shw (simp (pls (deriv (integ (powr (vx) (lit 2)))) (tms (lit -1) (powr (vx) (lit 2)))))))
(output "d/dx(int cos x) - cos x = ~A   (expect 0)~%" (shw (simp (pls (deriv (integ (f-cos (vx)))) (tms (lit -1) (f-cos (vx)))))))
(output "d/dx(int x*exp x) - x*exp x = ~A   (expect 0)~%" (shw (simp (pls (deriv (integ (tms (vx) (f-exp (vx))))) (tms (lit -1) (tms (vx) (f-exp (vx))))))))'

```

```output
d/dx(int x^2) - x^2     = 0   (expect 0)
d/dx(int cos x) - cos x = 0   (expect 0)
d/dx(int x*exp x) - x*exp x = 0   (expect 0)
```

## 7. The thesis: ill-formed rules are rejected at definition time, not at runtime. This is the project's core value -- rule bugs become load-time errors.

```bash
python3 demo/cas-eval.py '(output "well-formed rule (Foo[x_,0]->x) registers : ~A~%" (trap-error (do (register-rule (rule [[sym (protect Foo)] (named (protect x) (blank)) [int 0]] [sym (protect x)])) "OK") (/. E "ERROR")))
(output "malformed LHS (rule 1 -> 2)              : ~A~%" (trap-error (do (register-rule (rule [int 1] [int 2])) "ACCEPTED (bad)") (/. E "REJECTED")))
(output "unbound RHS (H[x_] -> y)                 : ~A~%" (trap-error (do (register-rule (rule [[sym (protect H)] (named (protect x) (blank))] [sym (protect y)])) "ACCEPTED (bad)") (/. E "REJECTED")))
(output "repeated var: register Fdup[x_,x_]->x then reduce Fdup[1,2]~%")
(output "  Fdup[1,1] = ~A   (equal args: collapses)~%" (let Ig (register-rule (rule [[sym (protect Fdup)] (named (protect x) (blank)) (named (protect x) (blank))] [sym (protect x)])) (shw [[sym (protect Fdup)] [int 1] [int 1]])))
(output "  Fdup[1,2] = ~A   (unequal args: stays inert -- sound)~%" (shw [[sym (protect Fdup)] [int 1] [int 2]]))'

```

```output
well-formed rule (Foo[x_,0]->x) registers : OK
malformed LHS (rule 1 -> 2)              : REJECTED
bindings-cover? failed unbound: [y]
unbound RHS (H[x_] -> y)                 : REJECTED
repeated var: register Fdup[x_,x_]->x then reduce Fdup[1,2]
  Fdup[1,1] = 1   (equal args: collapses)
  Fdup[1,2] = [Fdup 1 2]   (unequal args: stays inert -- sound)
```

## Summary -- This kernel does exact rational arithmetic, rule-based simplification with like-term collection, full symbolic differentiation (power/product/chain rules + elementary functions), and a bounded but sound symbolic integration subset verified by differentiating results back. Every rule is statically checked at registration, and the matcher is sound for repeated pattern variables. Not yet built: a surface-syntax reader/printer (terms are bracket-AST today), a polynomial normal form (Expand/Factor), floats/bignums, and broad CAS (Solve/Series/Limit).
