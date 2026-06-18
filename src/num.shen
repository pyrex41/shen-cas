\\ num.shen - exact numeric layer (Phase 1 + SCUD 17b/17e)
\\ Supports [int N] and exact rationals [rat N D].
\\ All arith ops centralized here for hash stability + future HVM.
\\ shen-go has NO bignum (int64 saturation) and native '/' returns floats:
\\   - num-div NEVER uses native '/'; routes through make-rat.
\\   - *num-overflow-check* guards int64 saturation on +,-,*.

\\ --- overflow guard (int64) ---
(set *num-overflow-check* true)

\\ int64 max = 9223372036854775807 ; min = -9223372036854775808
\\ shen-go has NO bignum: arithmetic SATURATES at the int64 bounds (a too-big
\\ result is clamped to exactly int64-max / int64-min rather than wrapping). So
\\ overflow is detected by landing on a saturation sentinel, not by magnitude
\\ (the magnitude is already clamped by the time we see it).
(define int64-max -> 9223372036854775807)
(define int64-min -> -9223372036854775808)

(define overflow?
  N -> (if (value *num-overflow-check*)
           (or (>= N (int64-max)) (<= N (int64-min)))
           false))

\\ guard-int MUST abort the op when it sees a saturated int64 value: a saturated
\\ magnitude (~9.2e18) fed into make-rat -> gcd -> floor-iter loops by +1 from 0
\\ for billions of iterations and hangs the evaluator. So we warn and ERROR here,
\\ BEFORE the value can reach make-rat/gcd. num-builtin traps this error and
\\ declines (returns [none]) so the expression stays inert rather than corrupt.
(define guard-int
  N -> (if (overflow? N)
           (do (output "WARNING: int64 overflow in numeric op: ~A~%" N)
               (error "int64 overflow"))
           N))

\\ --- gcd (Euclid, on non-negative magnitudes) ---
(define abs-num
  N -> (if (< N 0) (- 0 N) N))

(define gcd
  A 0 -> (abs-num A)
  A B -> (gcd B (- A (* (intdiv A B) B))))

\\ integer division (truncating) without native '/'
(define intdiv
  A B -> (let Q (round-toward-zero A B) Q))

\\ shen-go: '/' returns float; truncate to integer toward zero.
(define round-toward-zero
  A B -> (let F (/ A B)
              T (truncate-float F)
              T))

\\ truncate a (possibly float) value to integer toward zero
(define truncate-float
  F -> (if (< F 0)
           (- 0 (floor-nonneg (- 0 F)))
           (floor-nonneg F)))

\\ floor of a non-negative number via integer? probe
(define floor-nonneg
  F -> (if (integer? F) F (floor-iter F 0)))

(define floor-iter
  F Acc -> (if (>= (- F (+ Acc 1)) 0)
               (floor-iter F (+ Acc 1))
               Acc))

\\ --- rational constructor (normalize) ---
\\ make-rat N D -> [rat N' D'] gcd-reduced, positive denom, D=1 -> [int N], N=0 -> [int 0]
(define make-rat
  _ 0 -> (error "make-rat: zero denominator")
  0 _ -> [int 0]
  N D -> (let Sign (if (< D 0) -1 1)
              N1 (* Sign N)
              D1 (* Sign D)
              G (gcd (abs-num N1) (abs-num D1))
              Nn (intdiv N1 G)
              Dn (intdiv D1 G)
              (if (= Dn 1) [int Nn] [rat Nn Dn])))

\\ --- promotion to (Numerator . Denominator) pair ---
(define as-rat
  [int N] -> [N 1]
  [rat N D] -> [N D])

(define rat-num [N _] -> N)
(define rat-den [_ D] -> D)

\\ --- arithmetic over int/rat (exact) ---
(define num-add
  A B -> (let RA (as-rat A) RB (as-rat B)
              Na (rat-num RA) Da (rat-den RA)
              Nb (rat-num RB) Db (rat-den RB)
              (make-rat (guard-int (+ (* Na Db) (* Nb Da))) (guard-int (* Da Db)))))

(define num-sub
  A B -> (let RA (as-rat A) RB (as-rat B)
              Na (rat-num RA) Da (rat-den RA)
              Nb (rat-num RB) Db (rat-den RB)
              (make-rat (guard-int (- (* Na Db) (* Nb Da))) (guard-int (* Da Db)))))

(define num-mul
  A B -> (let RA (as-rat A) RB (as-rat B)
              Na (rat-num RA) Da (rat-den RA)
              Nb (rat-num RB) Db (rat-den RB)
              (make-rat (guard-int (* Na Nb)) (guard-int (* Da Db)))))

\\ exact division via make-rat (NEVER native '/')
(define num-div
  A B -> (let RA (as-rat A) RB (as-rat B)
              Na (rat-num RA) Da (rat-den RA)
              Nb (rat-num RB) Db (rat-den RB)
              (if (= Nb 0)
                  (error "num-div: division by zero")
                  (make-rat (guard-int (* Na Db)) (guard-int (* Da Nb))))))

\\ integer power; negative exponent -> reciprocal (rationals)
(define num-pow
  Base 0 -> [int 1]
  Base E -> (if (< E 0)
                (num-div [int 1] (num-pow-pos Base (- 0 E)))
                (num-pow-pos Base E)))

(define num-pow-pos
  Base 0 -> [int 1]
  Base E -> (num-mul Base (num-pow-pos Base (- E 1))))

\\ --- predicates / equality ---
(define numeric?
  [int N] -> (number? N)
  [rat N D] -> (and (number? N) (number? D))
  _ -> false)

(define num-eq?
  A B -> (let RA (as-rat A) RB (as-rat B)
              (and (= (rat-num RA) (rat-num RB)) (= (rat-den RA) (rat-den RB)))))

\\ --- built-in arithmetic hook (SCUD 17b) ---
\\ num-builtin fires only when ALL args numeric; highest-priority DownValue.
\\ Returns [some Result] / [none] so the evaluator can fall through to user rules.
(define all-numeric?
  [] -> true
  [A | As] -> (if (numeric? A) (all-numeric? As) false))

\\ trap an int64-overflow error from guard-int and DECLINE (the expr stays inert),
\\ so a saturating computation errors/returns rather than corrupting or hanging.
(define num-builtin
  H Args -> (if (all-numeric? Args)
                (trap-error (num-apply H Args) (/. E [none]))
                [none]))

\\ dispatch on the head symbol's NAME (str) so it works regardless of (protect ...)
\\ interning; the head arrives as [sym Plus] where Plus is a symbol.
(define num-apply
  [sym S] Args -> (num-apply-by-name (str S) Args)
  _ _ -> [none])

(define num-apply-by-name
  "Plus"   Args -> [some (num-sum [int 0] Args)]
  "Times"  Args -> [some (num-prod [int 1] Args)]
  "Minus"  [A B] -> [some (num-sub A B)]
  "Divide" [A B] -> (num-apply-div A B)
  "Power"  [A [int E]] -> (num-apply-pow A E)
  _ _ -> [none])

\\ 0^0 must stay INERT (decline) rather than fold to 1 (SCUD 19 simplify).
(define num-apply-pow
  A E -> (if (and (num-eq? A [int 0]) (= E 0))
             [none]
             [some (num-pow A E)]))

(define num-apply-div
  A B -> (if (num-eq? B [int 0]) [none] [some (num-div A B)]))

\\ inlined folds (shen-go forbids bare higher-order function application)
(define num-sum
  Acc [] -> Acc
  Acc [X | Xs] -> (num-sum (num-add Acc X) Xs))

(define num-prod
  Acc [] -> Acc
  Acc [X | Xs] -> (num-prod (num-mul Acc X) Xs))

(output "num.shen (int + exact rationals + builtin arith) loaded.~%")
