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

\\ --- multiplicative identity drop: Times[..,1,..] -> Times[..] ---
\\ SCUD 20: substitute now SPLICES tagged sequence bindings (see match-seq /
\\ match.shen), so the n-ary identity drop CAN be a rule -- its RHS Times[s,t]
\\ splices the matched s___/t___ sequences back into the arg list. Strictly
\\ shrinks node count (drops the literal 1). Anchored by [int 1] so it only fires
\\ when a 1 is present and never loops. This is what lets D output like
\\ Times[3,Power[x,2],1] collapse to 3 x^2 in the unified fixpoint.
(register-rule
  (rule [[sym (protect Times)]
          [named (protect s) [blank-null-seq]]
          [int 1]
          [named (protect t) [blank-null-seq]]]
        [[sym (protect Times)] [sym (protect s)] [sym (protect t)]]))

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

\\ --- OneIdentity collapse: Plus[a]->a, Times[a]->a ---
\\ SCUD 20: single-argument Plus/Times collapse to their argument (Mathematica
\\ OneIdentity). These never arise from well-formed user input (Plus/Times have
\\ >=2 args) but the calculus binary-peel rules transiently build Plus[x]/Times[x];
\\ collapsing them keeps the fixpoint clean. Strictly shrinks node count.
(register-rule
  (rule [[sym (protect Plus)] [named (protect x) [blank]]]
        [sym (protect x)]))

(register-rule
  (rule [[sym (protect Times)] [named (protect x) [blank]]]
        [sym (protect x)]))

(output "boot/simplify.shen loaded.~%")
