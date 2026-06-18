\\ boot/calculus.shen
\\ SCUD 20 Wave 4: symbolic differentiation rule library for D[expr, x].
\\
\\ Loaded AFTER arith, simplify, elemfun -- so D output auto-simplifies through
\\ the SAME unified fixpoint (constant folding, x^1->x, Times identity drop,
\\ OneIdentity collapse, etc.). Every RHS head (D, Plus, Times, Power, Divide,
\\ Sin, Cos, Tan, Sec, Exp, Log, Sqrt) is whitelisted in phase1-globals so
\\ bindings-cover? accepts these rules at registration.
\\
\\ Registration ORDER is dispatch order (first matching rule wins). The guarded
\\ rules come first so structural rules only see genuinely structural inputs;
\\ the chain-rule table relies on FreeQ declining when the variable occurs.
\\
\\ Strategy / termination notes:
\\  - Linearity + product are binary PEELS that strictly shrink the operand count
\\    (Plus/Times arg count drops by one each step); the transient single-arg
\\    Plus[u]/Times[u] collapse via the OneIdentity rules in simplify.
\\  - Power rule is chain-aware (multiplies by D[u,x]); the general u^v log-diff
\\    form sits AFTER it (only reached when FreeQ[n,x] fails).
\\  - Unknown heads (f[x]) match NO rule and stay INERT (never 0): the constant
\\    rule is guarded by FreeQ, which is false whenever x occurs.

\\ ---------------------------------------------------------------------------
\\ 1. D[x,x] -> 1   (independent-variable identity; condition+SameQ, no nonlinear)
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [condition [[sym (protect D)] [named (protect a) [blank]] [named (protect x) [blank]]]
                   [[sym (protect SameQ)] [sym (protect a)] [sym (protect x)]]]
        [int 1]))

\\ ---------------------------------------------------------------------------
\\ 2. D[c,x] -> 0   when c is free of x (constants, other variables, x-free exprs)
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [condition [[sym (protect D)] [named (protect a) [blank]] [named (protect x) [blank]]]
                   [[sym (protect FreeQ)] [sym (protect a)] [sym (protect x)]]]
        [int 0]))

\\ ---------------------------------------------------------------------------
\\ 3. Linearity (binary peel): D[Plus[a,r..],x] -> D[a,x] + D[Plus[r..],x]
\\    r__ is >=1 so this only fires on >=2 addends; the single-addend Plus[u]
\\    produced as the tail collapses via OneIdentity (simplify).
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [[sym (protect D)]
          [[sym (protect Plus)] [named (protect a) [blank]] [named (protect r) [blank-seq]]]
          [named (protect x) [blank]]]
        [[sym (protect Plus)]
          [[sym (protect D)] [sym (protect a)] [sym (protect x)]]
          [[sym (protect D)] [[sym (protect Plus)] [sym (protect r)]] [sym (protect x)]]]))

\\ ---------------------------------------------------------------------------
\\ 4. Power rule (chain-aware): D[u^n,x] /; FreeQ[n,x] -> n*u^(n-1)*D[u,x]
\\    Plus[n,-1] folds when n is a literal; D[u,x] supplies the chain factor.
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [condition [[sym (protect D)]
                     [[sym (protect Power)] [named (protect u) [blank]] [named (protect n) [blank]]]
                     [named (protect x) [blank]]]
                   [[sym (protect FreeQ)] [sym (protect n)] [sym (protect x)]]]
        [[sym (protect Times)]
          [sym (protect n)]
          [[sym (protect Power)] [sym (protect u)]
                                 [[sym (protect Plus)] [sym (protect n)] [int -1]]]
          [[sym (protect D)] [sym (protect u)] [sym (protect x)]]]))

\\ ---------------------------------------------------------------------------
\\ 5. General power (log-diff): D[u^v,x] -> u^v * D[v*Log[u], x]
\\    Reached only when FreeQ[n,x] failed above (exponent depends on x).
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [[sym (protect D)]
          [[sym (protect Power)] [named (protect u) [blank]] [named (protect v) [blank]]]
          [named (protect x) [blank]]]
        [[sym (protect Times)]
          [[sym (protect Power)] [sym (protect u)] [sym (protect v)]]
          [[sym (protect D)]
            [[sym (protect Times)] [sym (protect v)] [[sym (protect Log)] [sym (protect u)]]]
            [sym (protect x)]]]))

\\ ---------------------------------------------------------------------------
\\ 6. Product rule (binary peel): D[Times[a,r..],x] -> D[a,x]*Times[r..] + a*D[Times[r..],x]
\\    r__ is >=1; transient single-factor Times[u] collapses via OneIdentity.
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [[sym (protect D)]
          [[sym (protect Times)] [named (protect a) [blank]] [named (protect r) [blank-seq]]]
          [named (protect x) [blank]]]
        [[sym (protect Plus)]
          [[sym (protect Times)]
            [[sym (protect D)] [sym (protect a)] [sym (protect x)]]
            [[sym (protect Times)] [sym (protect r)]]]
          [[sym (protect Times)]
            [sym (protect a)]
            [[sym (protect D)] [[sym (protect Times)] [sym (protect r)]] [sym (protect x)]]]]))

\\ ---------------------------------------------------------------------------
\\ 7. Quotient via normalization: D[Divide[a,b],x] -> D[a * b^(-1), x]
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [[sym (protect D)]
          [[sym (protect Divide)] [named (protect a) [blank]] [named (protect b) [blank]]]
          [named (protect x) [blank]]]
        [[sym (protect D)]
          [[sym (protect Times)] [sym (protect a)]
                                 [[sym (protect Power)] [sym (protect b)] [int -1]]]
          [sym (protect x)]]))

\\ ---------------------------------------------------------------------------
\\ 8. Chain-rule table (each: outer-derivative * D[u,x])
\\ ---------------------------------------------------------------------------
\\ D[Sin[u],x] -> Cos[u]*D[u,x]
(register-rule
  (rule [[sym (protect D)] [[sym (protect Sin)] [named (protect u) [blank]]] [named (protect x) [blank]]]
        [[sym (protect Times)] [[sym (protect Cos)] [sym (protect u)]]
                               [[sym (protect D)] [sym (protect u)] [sym (protect x)]]]))

\\ D[Cos[u],x] -> -Sin[u]*D[u,x]
(register-rule
  (rule [[sym (protect D)] [[sym (protect Cos)] [named (protect u) [blank]]] [named (protect x) [blank]]]
        [[sym (protect Times)] [int -1] [[sym (protect Sin)] [sym (protect u)]]
                               [[sym (protect D)] [sym (protect u)] [sym (protect x)]]]))

\\ D[Exp[u],x] -> Exp[u]*D[u,x]
(register-rule
  (rule [[sym (protect D)] [[sym (protect Exp)] [named (protect u) [blank]]] [named (protect x) [blank]]]
        [[sym (protect Times)] [[sym (protect Exp)] [sym (protect u)]]
                               [[sym (protect D)] [sym (protect u)] [sym (protect x)]]]))

\\ D[Log[u],x] -> u^(-1)*D[u,x]
(register-rule
  (rule [[sym (protect D)] [[sym (protect Log)] [named (protect u) [blank]]] [named (protect x) [blank]]]
        [[sym (protect Times)] [[sym (protect Power)] [sym (protect u)] [int -1]]
                               [[sym (protect D)] [sym (protect u)] [sym (protect x)]]]))

\\ D[Tan[u],x] -> Sec[u]^2 * D[u,x]
(register-rule
  (rule [[sym (protect D)] [[sym (protect Tan)] [named (protect u) [blank]]] [named (protect x) [blank]]]
        [[sym (protect Times)] [[sym (protect Power)] [[sym (protect Sec)] [sym (protect u)]] [int 2]]
                               [[sym (protect D)] [sym (protect u)] [sym (protect x)]]]))

\\ D[Sqrt[u],x] -> D[u^(1/2), x]  (route through the power rule; needs rationals)
(register-rule
  (rule [[sym (protect D)] [[sym (protect Sqrt)] [named (protect u) [blank]]] [named (protect x) [blank]]]
        [[sym (protect D)] [[sym (protect Power)] [sym (protect u)] [rat 1 2]] [sym (protect x)]]))

(output "boot/calculus.shen loaded (D rule library).~%")
