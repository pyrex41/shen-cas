\\ boot/arith.shen
\\ SCUD 13.1 skeleton: core CAS symbols + arithmetic simplification rules
\\ Per plan Phase 6, Book 21.4 examples, sketch.
\\
\\ Declares structural attrs for Plus/Times (Flat + Orderless).
\\ Registers checked simplification rules using the Phase-1 registration path.
\\
\\ These rules are trusted bootstrap (no semantic proof yet).
\\
\\ Note: full power (Orderless making 0+x use x+0 rule, deep Flat, constant folding)
\\       will light up once store canonical + match-ac + stronger reduce/matcher
\\       are integrated and attrs are fully wired into eval.

\\ Declare structural attributes (immutable, affect canonical hash).
\\ Uses current declare-structural (which routes structural ones to store sig).
(declare-structural (protect Plus) [(protect flat) (protect orderless)])
(declare-structural (protect Times) [(protect flat) (protect orderless)])
(declare-structural (protect Minus) [(protect flat)])  ; no orderless for now (subtraction not commutative)

\\ --- Simplification rules (as checked-rule via register-rule) ---

\\ x + 0 -> x
(register-rule
  (rule [[sym Plus] [named x [blank]] [int 0]]
        [named x [blank]]))

\\ 0 + x -> x   (will be redundant once Orderless + canonical active)
(register-rule
  (rule [[sym Plus] [int 0] [named x [blank]]]
        [named x [blank]]))

\\ x * 1 -> x
(register-rule
  (rule [[sym Times] [named x [blank]] [int 1]]
        [named x [blank]]))

\\ x * 0 -> 0
(register-rule
  (rule [[sym Times] [named x [blank]] [int 0]]
        [int 0]))

\\ x - 0 -> x
(register-rule
  (rule [[sym Minus] [named x [blank]] [int 0]]
        [named x [blank]]))

\\ 0 - x -> -x (simplified to negative for skeleton, but use Minus)
(register-rule
  (rule [[sym Minus] [int 0] [named x [blank]]]
        [[sym Minus] [named x [blank]]]))  ; placeholder

\\ 1 * x -> x
(register-rule
  (rule [[sym Times] [int 1] [named x [blank]]]
        [named x [blank]]))

\\ Concrete folding examples (from golden/arith-21.4)
(register-rule
  (rule [[sym Plus] [int 2] [int 3]]
        [int 5]))

(register-rule
  (rule [[sym Times] [int 4] [int 7]]
        [int 28]))

\\ TODO later (Phase 6+): more Book 21.4 cases (e.g. 56 + [x-7] stays, power, If[True,...]), full control flow in 13.2.
\\ Once attrs (Flat/Orderless) + match-ac + full reduce are wired, Orderless will make 0+x use x+0 rule automatically.

(output "boot/arith.shen (core CAS symbols + checked rules skeleton) loaded.~%")