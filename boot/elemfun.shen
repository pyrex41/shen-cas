\\ boot/elemfun.shen
\\ SCUD 20 Wave 4: elementary function symbols + an UNIMPEACHABLE exact-value table.
\\
\\ These symbols (Sin Cos Tan Sec Exp Log Sqrt ArcSin ArcCos ArcTan) carry NO
\\ structural attrs -- they are ordinary (non-Flat, non-Orderless) heads whose args
\\ are evaluated normally. Declaring them gives the evaluator a symbol entry and
\\ makes their (protect ...) interning canonical for hashing/dispatch.
\\
\\ The value table holds ONLY exact, branch-safe identities (no floats, no
\\ multivalued inverses). We OMIT branch-unsafe rules like Log[Exp[u]]->u and
\\ Sqrt[u^2]->u; everything not in the table stays INERT.
\\
\\ Loaded AFTER arith (Plus/Times/Power) and simplify, BEFORE calculus.

(define boot-declare-elem
  Sym -> (if (sig-present? Sym) true (declare-structural Sym [])))

(boot-declare-elem (protect Sin))
(boot-declare-elem (protect Cos))
(boot-declare-elem (protect Tan))
(boot-declare-elem (protect Sec))
(boot-declare-elem (protect Exp))
(boot-declare-elem (protect Log))
(boot-declare-elem (protect Sqrt))
(boot-declare-elem (protect ArcSin))
(boot-declare-elem (protect ArcCos))
(boot-declare-elem (protect ArcTan))
\\ Elementary-library expansion: reciprocal-trig, hyperbolic, inverse-hyperbolic.
(boot-declare-elem (protect Cot))
(boot-declare-elem (protect Csc))
(boot-declare-elem (protect Sinh))
(boot-declare-elem (protect Cosh))
(boot-declare-elem (protect Tanh))
(boot-declare-elem (protect Coth))
(boot-declare-elem (protect Sech))
(boot-declare-elem (protect Csch))
(boot-declare-elem (protect ArcSinh))
(boot-declare-elem (protect ArcCosh))
(boot-declare-elem (protect ArcTanh))
(boot-declare-elem (protect D))
(boot-declare-elem (protect Integrate))

\\ --- exact-value table (each RHS a literal; unimpeachable) ---
(register-rule (rule [[sym (protect Sin)] [int 0]] [int 0]))
(register-rule (rule [[sym (protect Cos)] [int 0]] [int 1]))
(register-rule (rule [[sym (protect Tan)] [int 0]] [int 0]))
(register-rule (rule [[sym (protect Exp)] [int 0]] [int 1]))
(register-rule (rule [[sym (protect Log)] [int 1]] [int 0]))
\\ Hyperbolic / inverse-hyperbolic exact values at 0 (branch-safe; undefined-at-0
\\ functions Cot/Csc/Coth/Csch are OMITTED so they stay inert there).
(register-rule (rule [[sym (protect Sinh)] [int 0]] [int 0]))
(register-rule (rule [[sym (protect Cosh)] [int 0]] [int 1]))
(register-rule (rule [[sym (protect Tanh)] [int 0]] [int 0]))
(register-rule (rule [[sym (protect Sech)] [int 0]] [int 1]))
(register-rule (rule [[sym (protect ArcSinh)] [int 0]] [int 0]))
(register-rule (rule [[sym (protect ArcTanh)] [int 0]] [int 0]))
(register-rule (rule [[sym (protect ArcCosh)] [int 1]] [int 0]))
(register-rule (rule [[sym (protect Sqrt)] [int 0]] [int 0]))
(register-rule (rule [[sym (protect Sqrt)] [int 1]] [int 1]))
\\ General radical normalization: Sqrt[u] -> u^(1/2). Registered AFTER the exact
\\ Sqrt[0]/Sqrt[1] cases (first match wins) so those still intercept. This unifies
\\ radicals with the power tower: the bare-power integration rule then handles
\\ Integrate[Sqrt[x],x] = (2/3) x^(3/2), and differentiate-back verifies because
\\ both the integrand and D[antiderivative] live in Power form. (Sqrt prints as
\\ u^(1/2); Solve's quadratic roots remain inert as before.)
(register-rule (rule [[sym (protect Sqrt)] [named (protect u) [blank]]]
                     [[sym (protect Power)] [sym (protect u)] [rat 1 2]]))
\\ (u^(1/2))^2 -> u : sound radical-square simplification (principal branch). The
\\ Power form of the old Power[Sqrt[u],2] -> u rule, now that Sqrt is normalized away.
(register-rule (rule [[sym (protect Power)] [[sym (protect Power)] [named (protect u) [blank]] [rat 1 2]] [int 2]]
                     [sym (protect u)]))

(output "boot/elemfun.shen loaded (elementary symbols + exact-value table).~%")
