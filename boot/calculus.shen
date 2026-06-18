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

\\ ===========================================================================
\\ SCUD 21 Wave 5: BOUNDED symbolic integration rule library for Integrate[E,x].
\\
\\ PRINCIPLE: every rule is a SOUND antiderivative identity. If nothing matches,
\\ the expression stays INERT (head still Integrate). NEVER returns a wrong
\\ answer. Constants of integration are omitted (indefinite, canonical branch).
\\
\\ Loaded AFTER the D library (same file). Registration order IS dispatch order
\\ (first matching rule wins), so the n=-1 -> Log[x] case is registered FIRST,
\\ ahead of the power rule (whose guard also excludes n=-1 for defence in depth).
\\
\\ Requires the exact-rational tower (power-rule denominator). Asserted at load
\\ time below.
\\ ===========================================================================

\\ --- load-time assertion: the rational tower is wired (make-rat present) ---
(if (= (make-rat 6 4) [rat 3 2])
    (output "SCUD 21: rational tower verified (make-rat 6 4 = [rat 3 2]).~%")
    (error "SCUD 21 integration requires the rational tower (make-rat) -- not wired"))

\\ ---------------------------------------------------------------------------
\\ I1. Log rule (ORDERED FIRST): Integrate[Power[x,-1],x] -> Log[x]
\\     Bare-variable power x^-1; intercepts before the power rule so the power
\\     rule never produces x^0/0.
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [condition [[sym (protect Integrate)]
                     [[sym (protect Power)] [named (protect u) [blank]] [int -1]]
                     [named (protect x) [blank]]]
                   [[sym (protect SameQ)] [sym (protect u)] [sym (protect x)]]]
        [[sym (protect Log)] [sym (protect x)]]))

\\ ---------------------------------------------------------------------------
\\ I2. Antiderivative table (bare-variable arg only): each guarded by SameQ so
\\     it fires ONLY on Integrate[g[x],x] with the SAME x (a g[other] stays inert,
\\     and the u-substitution rules below handle the linear-argument case).
\\       Sin -> -Cos , Cos -> Sin , Exp -> Exp
\\ ---------------------------------------------------------------------------
\\ Integrate[Sin[x],x] -> -Cos[x]
(register-rule
  (rule [condition [[sym (protect Integrate)] [[sym (protect Sin)] [named (protect u) [blank]]] [named (protect x) [blank]]]
                   [[sym (protect SameQ)] [sym (protect u)] [sym (protect x)]]]
        [[sym (protect Times)] [int -1] [[sym (protect Cos)] [sym (protect x)]]]))

\\ Integrate[Cos[x],x] -> Sin[x]
(register-rule
  (rule [condition [[sym (protect Integrate)] [[sym (protect Cos)] [named (protect u) [blank]]] [named (protect x) [blank]]]
                   [[sym (protect SameQ)] [sym (protect u)] [sym (protect x)]]]
        [[sym (protect Sin)] [sym (protect x)]]))

\\ Integrate[Exp[x],x] -> Exp[x]
(register-rule
  (rule [condition [[sym (protect Integrate)] [[sym (protect Exp)] [named (protect u) [blank]]] [named (protect x) [blank]]]
                   [[sym (protect SameQ)] [sym (protect u)] [sym (protect x)]]]
        [[sym (protect Exp)] [sym (protect x)]]))

\\ ---------------------------------------------------------------------------
\\ I3. Linear u-substitution per table function (FreeOf guards make a
\\     mis-binding fail SAFE to inert): for g in {Sin,Cos,Exp},
\\       Integrate[g[Plus[Times[a,x],b]],x] /; (FreeOf[a,x] and FreeOf[b,x])
\\         -> (1/a)*G[a*x+b]
\\     where G is the bare antiderivative (Sin->-Cos, Cos->Sin, Exp->Exp).
\\ ---------------------------------------------------------------------------
\\ Integrate[Sin[a x + b], x] -> -(1/a) Cos[a x + b]
(register-rule
  (rule [condition [[sym (protect Integrate)]
                     [[sym (protect Sin)]
                       [[sym (protect Plus)]
                         [[sym (protect Times)] [named (protect a) [blank]] [named (protect x) [blank]]]
                         [named (protect b) [blank]]]]
                     [named (protect x) [blank]]]
                   [[sym (protect And)]
                     [[sym (protect FreeQ)] [sym (protect a)] [sym (protect x)]]
                     [[sym (protect FreeQ)] [sym (protect b)] [sym (protect x)]]]]
        [[sym (protect Times)] [int -1] [[sym (protect Power)] [sym (protect a)] [int -1]]
          [[sym (protect Cos)]
            [[sym (protect Plus)] [[sym (protect Times)] [sym (protect a)] [sym (protect x)]] [sym (protect b)]]]]))

\\ Integrate[Cos[a x + b], x] -> (1/a) Sin[a x + b]
(register-rule
  (rule [condition [[sym (protect Integrate)]
                     [[sym (protect Cos)]
                       [[sym (protect Plus)]
                         [[sym (protect Times)] [named (protect a) [blank]] [named (protect x) [blank]]]
                         [named (protect b) [blank]]]]
                     [named (protect x) [blank]]]
                   [[sym (protect And)]
                     [[sym (protect FreeQ)] [sym (protect a)] [sym (protect x)]]
                     [[sym (protect FreeQ)] [sym (protect b)] [sym (protect x)]]]]
        [[sym (protect Times)] [[sym (protect Power)] [sym (protect a)] [int -1]]
          [[sym (protect Sin)]
            [[sym (protect Plus)] [[sym (protect Times)] [sym (protect a)] [sym (protect x)]] [sym (protect b)]]]]))

\\ Integrate[Exp[a x + b], x] -> (1/a) Exp[a x + b]
(register-rule
  (rule [condition [[sym (protect Integrate)]
                     [[sym (protect Exp)]
                       [[sym (protect Plus)]
                         [[sym (protect Times)] [named (protect a) [blank]] [named (protect x) [blank]]]
                         [named (protect b) [blank]]]]
                     [named (protect x) [blank]]]
                   [[sym (protect And)]
                     [[sym (protect FreeQ)] [sym (protect a)] [sym (protect x)]]
                     [[sym (protect FreeQ)] [sym (protect b)] [sym (protect x)]]]]
        [[sym (protect Times)] [[sym (protect Power)] [sym (protect a)] [int -1]]
          [[sym (protect Exp)]
            [[sym (protect Plus)] [[sym (protect Times)] [sym (protect a)] [sym (protect x)]] [sym (protect b)]]]]))

\\ ---------------------------------------------------------------------------
\\ I4. Power rule (bare variable): Integrate[Power[x,n],x]
\\        /; (FreeOf[n,x] and UnsameQ[n,-1]) -> Power[x,n+1]/(n+1)
\\     n=-1 excluded (handled by the Log rule above); SameQ[u,x] keeps the base
\\     a bare variable. Plus[n,1] and the Divide fold exactly via the rational
\\     tower, e.g. n=2 -> x^3 * (1/3) = [rat] coefficient.
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [condition [[sym (protect Integrate)]
                     [[sym (protect Power)] [named (protect u) [blank]] [named (protect n) [blank]]]
                     [named (protect x) [blank]]]
                   [[sym (protect And)]
                     [[sym (protect SameQ)] [sym (protect u)] [sym (protect x)]]
                     [[sym (protect And)]
                       [[sym (protect FreeQ)] [sym (protect n)] [sym (protect x)]]
                       [[sym (protect UnsameQ)] [sym (protect n)] [int -1]]]]]
        [[sym (protect Times)]
          [[sym (protect Power)] [sym (protect x)] [[sym (protect Plus)] [sym (protect n)] [int 1]]]
          [[sym (protect Power)] [[sym (protect Plus)] [sym (protect n)] [int 1]] [int -1]]]))

\\ ---------------------------------------------------------------------------
\\ I5. Integrate[x,x] -> x^2/2   (bare variable, the n=1 base case the power
\\     rule cannot see because x is not written as Power[x,1]).
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [condition [[sym (protect Integrate)] [named (protect u) [blank]] [named (protect x) [blank]]]
                   [[sym (protect SameQ)] [sym (protect u)] [sym (protect x)]]]
        [[sym (protect Times)] [[sym (protect Power)] [sym (protect x)] [int 2]] [rat 1 2]]))

\\ ---------------------------------------------------------------------------
\\ I6. Linearity (binary peel): Integrate[Plus[a,r..],x]
\\        -> Integrate[a,x] + Integrate[Plus[r..],x]
\\     r__ >= 1 so this only fires on >=2 addends; the single-addend Plus[u]
\\     tail collapses via OneIdentity (simplify), then matches a leaf rule.
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [[sym (protect Integrate)]
          [[sym (protect Plus)] [named (protect a) [blank]] [named (protect r) [blank-seq]]]
          [named (protect x) [blank]]]
        [[sym (protect Plus)]
          [[sym (protect Integrate)] [sym (protect a)] [sym (protect x)]]
          [[sym (protect Integrate)] [[sym (protect Plus)] [sym (protect r)]] [sym (protect x)]]]))

\\ ---------------------------------------------------------------------------
\\ I7. Constant-factor pull-out (single leading factor, guaranteed progress):
\\        Integrate[Times[c,f..],x] /; FreeOf[c,x]
\\          -> c * Integrate[Times[f..],x]
\\     c is ONE factor free of x; f__ >= 1. The inner Times[f..] has one fewer
\\     factor each step (terminates); a single remaining factor collapses via
\\     OneIdentity to a bare integrand the leaf rules handle. If the whole
\\     product is x-free, the constant rule (I8) catches it first via dispatch
\\     (Times integrand with no x).
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [condition [[sym (protect Integrate)]
                     [[sym (protect Times)] [named (protect c) [blank]] [named (protect f) [blank-seq]]]
                     [named (protect x) [blank]]]
                   [[sym (protect FreeQ)] [sym (protect c)] [sym (protect x)]]]
        [[sym (protect Times)] [sym (protect c)]
          [[sym (protect Integrate)] [[sym (protect Times)] [sym (protect f)]] [sym (protect x)]]]))

\\ ---------------------------------------------------------------------------
\\ I8. Constant rule (ORDERED LAST among leaf rules): Integrate[c,x] -> c*x
\\     when c is free of x. Unknown f[x] (x occurs) fails FreeQ -> stays INERT.
\\ ---------------------------------------------------------------------------
(register-rule
  (rule [condition [[sym (protect Integrate)] [named (protect c) [blank]] [named (protect x) [blank]]]
                   [[sym (protect FreeQ)] [sym (protect c)] [sym (protect x)]]]
        [[sym (protect Times)] [sym (protect c)] [sym (protect x)]]))

(output "boot/calculus.shen loaded (D + bounded Integrate rule library).~%")
