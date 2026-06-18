\\ boot/simplify.shen
\\ SCUD 19 Wave 3: rule-based canonical-form / simplification identities.
\\ Loaded AFTER boot/arith.shen (Plus/Times/Power already declared flat/orderless
\\ resp.) and BEFORE any calculus boot. Every rule here STRICTLY SHRINKS node
\\ count (so the fixpoint driver terminates):
\\
\\   Times[s___,0,t___] -> 0          (n-ary absorbing zero)
\\   Times[s___,1,t___] -> Times[s,t] (n-ary multiplicative identity drop)
\\   Power[0,n_] /; Positive[n] -> 0  (ordered FIRST: 0^positive)
\\   Power[x_,1] -> x
\\   Power[x_,0] /; UnsameQ[x,0] -> 1 (x^0 = 1, but 0^0 left INERT)
\\
\\ Constant folding (Plus[7,8]->15, Power[2,3]->8, ...) is already handled by the
\\ Wave-1 num-builtin hook, which also DECLINES 0^0 so it stays inert.
\\ Like-term collection (3x+2x, x*x) is NOT a confluent rule set: it is the
\\ audited non-rule collect-like-terms pass surfaced as the Simplify head.

\\ --- absorbing zero: Times[..,0,..] -> 0 ---
(register-rule
  (rule [[sym (protect Times)]
          [named (protect s) [blank-null-seq]]
          [int 0]
          [named (protect t) [blank-null-seq]]]
        [int 0]))

\\ NOTE: the n-ary multiplicative-identity drop (Times[s___,1,t___]->Times[s,t])
\\ is intentionally NOT a rule: its RHS would require sequence-splicing in
\\ substitute (not yet supported -- bindings are lists). The binary Times[x_,1]->x
\\ (boot/arith) collapses 2-arg cases, and the audited collect-like-terms pass
\\ (Simplify head) drops literal-1 factors and folds numeric coefficients n-arily.

\\ --- 0^positive -> 0  (ordered before x^0 so 0^0 never matches x^0) ---
(register-rule
  (rule [condition [[sym (protect Power)] [int 0] [named (protect n) [blank]]]
                   [[sym (protect Positive)] [sym (protect n)]]]
        [int 0]))

\\ --- x^1 -> x ---
(register-rule
  (rule [[sym (protect Power)] [named (protect x) [blank]] [int 1]]
        [sym (protect x)]))

\\ --- x^0 -> 1, guarded x != 0 so 0^0 stays inert ---
(register-rule
  (rule [condition [[sym (protect Power)] [named (protect x) [blank]] [int 0]]
                   [[sym (protect UnsameQ)] [sym (protect x)] [int 0]]]
        [int 1]))

(output "boot/simplify.shen loaded.~%")
