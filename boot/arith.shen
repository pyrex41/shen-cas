\\ boot/arith.shen
\\ SCUD 13.1 skeleton + SCUD 17 cleanup: core CAS symbols + identity rules only.
\\ 17b: bespoke literal numeric rules (Plus[2,3]->5, Minus[9,8]->1, Times[4,7]->28, ...)
\\      DELETED -- num-builtin now folds all-numeric arithmetic before user rules.
\\ 17d: duplicate both-orderings rules (Plus[0,x_], Times[1,x_]) DELETED -- a single
\\      rule now covers commuted args via Orderless matching (match-ac).

(define boot-declare-structural
  Sym Attrs -> (if (sig-present? Sym)
                    true
                    (declare-structural Sym Attrs)))

(boot-declare-structural (protect Plus) [(protect flat) (protect orderless)])
(boot-declare-structural (protect Times) [(protect flat) (protect orderless)])
(boot-declare-structural (protect Power) [])

\\ x + 0 -> x   (single rule; Orderless covers 0 + x)
(register-rule
  (rule [[sym (protect Plus)] (named (protect x) (blank)) [int 0]]
        [sym (protect x)]))

\\ x * 1 -> x   (single rule; Orderless covers 1 * x)
(register-rule
  (rule [[sym (protect Times)] (named (protect x) (blank)) [int 1]]
        [sym (protect x)]))

\\ x * 0 -> 0   (single rule; Orderless covers 0 * x)
(register-rule
  (rule [[sym (protect Times)] (named (protect x) (blank)) [int 0]]
        [int 0]))

\\ x - 0 -> x
(register-rule
  (rule [[sym (protect Minus)] (named (protect x) (blank)) [int 0]]
        [sym (protect x)]))

(boot-declare-structural (protect If) [])

(register-rule
  (rule [[sym (protect If)] [sym (protect True)] (named (protect then) (blank)) (named (protect else) (blank))]
        [sym (protect then)]))

(register-rule
  (rule [[sym (protect If)] [sym (protect False)] (named (protect then) (blank)) (named (protect else) (blank))]
        [sym (protect else)]))

(output "boot/arith.shen loaded.~%")
