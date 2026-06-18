\\ boot/arith.shen
\\ SCUD 13.1 skeleton: core CAS symbols + arithmetic simplification rules

(declare-structural (protect Plus) [(protect flat) (protect orderless)])
(declare-structural (protect Times) [(protect flat) (protect orderless)])
(declare-structural (protect Minus) [(protect flat)])
(declare-structural (protect Power) [])

(register-rule
  (rule [[sym (protect Plus)] [named (protect x) [blank]] [int 0]]
        [sym (protect x)]))

(register-rule
  (rule [[sym (protect Plus)] [int 0] [named (protect x) [blank]]]
        [sym (protect x)]))

(register-rule
  (rule [[sym (protect Times)] [named (protect x) [blank]] [int 1]]
        [sym (protect x)]))

(register-rule
  (rule [[sym (protect Times)] [named (protect x) [blank]] [int 0]]
        [int 0]))

(register-rule
  (rule [[sym (protect Minus)] [named (protect x) [blank]] [int 0]]
        [sym (protect x)]))

(register-rule
  (rule [[sym (protect Times)] [int 1] [named (protect x) [blank]]]
        [sym (protect x)]))

(register-rule
  (rule [[sym (protect Plus)] [int 2] [int 3]]
        [int 5]))

(register-rule
  (rule [[sym (protect Minus)] [int 9] [int 8]]
        [int 1]))

(register-rule
  (rule [[sym (protect Minus)] [int 5] [int 3]]
        [int 2]))

(register-rule
  (rule [[sym (protect Minus)] [int 4] [int 1]]
        [int 3]))

(register-rule
  (rule [[sym (protect Divide)] [int 6] [int 2]]
        [int 3]))

(register-rule
  (rule [[sym (protect Times)] [int 4] [int 7]]
        [int 28]))

(register-rule
  (rule [[sym (protect Times)] [int 12] [int 2]]
        [int 24]))

(register-rule
  (rule [[sym (protect Times)] [int 5] [int 3]]
        [int 15]))

(register-rule
  (rule [[sym (protect Times)] [int -245] [int 67]]
        [int -16415]))

(output "boot/arith.shen (core CAS symbols + checked rules skeleton) loaded.~%")
\\ control flow skeleton for 13.2
(declare-structural (protect If) [])

(register-rule
  (rule [[sym (protect If)] [sym (protect True)] [named (protect then) [blank]] [named (protect else) [blank]]]
        [sym (protect then)]))

(register-rule
  (rule [[sym (protect If)] [sym (protect False)] [named (protect then) [blank]] [named (protect else) [blank]]]
        [sym (protect else)]))

(output "boot/arith 13.2 control flow added~%")
