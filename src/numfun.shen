\\ numfun.shen - elementary & number-theory function layer (scope expansion).
\\
\\ SymPy-guided breadth: a family of exact, numeric-grounded builtins
\\   Abs Sign Floor Ceiling Round IntegerPart FractionalPart
\\   Mod Quotient GCD LCM Factorial Binomial Max Min
\\
\\ GUIDING PRINCIPLE (project ethos): SOUND > COMPLETE. Each helper returns
\\ [some Result] only for a result it can prove exactly; for anything outside its
\\ numeric domain -- a symbolic argument, a non-integer where an integer is
\\ required, an int64 overflow -- it returns [none] and the head stays INERT
\\ (never a wrong or float answer). Constants of the form Abs[-3] therefore fold
\\ to 3, while Abs[x] / Floor[x] / GCD[x,6] stay unevaluated.
\\
\\ Wired (not register-rule) builtins: consulted from calc-by-name (calc-helpers)
\\ for these heads, after num-builtin and before user DownValues, so the args are
\\ already reduced when these see them.
\\
\\ Loaded AFTER calc-helpers (whose calc-by-name dispatches here at reduce time)
\\ and num.shen (all integer/rational arithmetic + the int64 overflow guard).
\\ shen-go portable: no native floor/truncate (uses num.shen intdiv), nested ifs,
\\ int64 only (trap-error around guarded arithmetic -> decline to inert).

\\ ============================================================================
\\ integer floored division (toward -inf) and helpers.
\\ num.shen intdiv truncates toward ZERO; correct it down by one when the
\\ remainder is nonzero and its sign differs from the divisor's (Python/SymPy
\\ floored-division semantics, so Mod's result carries the divisor's sign).
\\ ============================================================================
(define nf-opposite-sign
  R N -> (if (< R 0) (> N 0) (< N 0)))

(define nf-fdiv
  M N -> (let Q (intdiv M N)
              R (- M (* Q N))
              (if (= R 0)
                  Q
                  (if (nf-opposite-sign R N) (- Q 1) Q))))

(define nf-min2 A B -> (if (< A B) A B))
(define nf-max2 A B -> (if (> A B) A B))

(define nf-even? N -> (= 0 (- N (* (intdiv N 2) 2))))

\\ ============================================================================
\\ Abs / Sign
\\ ============================================================================
(define nf-abs
  [int N] -> [some [int (abs-num N)]]
  [rat N D] -> [some [rat (abs-num N) D]]   \\ D>0 by make-rat invariant; lowest-terms preserved
  _ -> [none])

(define nf-signum N -> (if (> N 0) 1 (if (< N 0) -1 0)))

(define nf-sign
  [int N] -> [some [int (nf-signum N)]]
  [rat N D] -> [some [int (nf-signum N)]]   \\ D>0, so sign is the numerator's
  _ -> [none])

\\ ============================================================================
\\ Floor / Ceiling / Round / IntegerPart / FractionalPart
\\ ============================================================================
(define nf-floor
  [int N] -> [some [int N]]
  [rat N D] -> [some [int (nf-fdiv N D)]]
  _ -> [none])

(define nf-ceiling
  [int N] -> [some [int N]]
  [rat N D] -> [some [int (- 0 (nf-fdiv (- 0 N) D))]]
  _ -> [none])

\\ IntegerPart truncates toward zero; FractionalPart = x - IntegerPart (same sign as x).
(define nf-intpart
  [int N] -> [some [int N]]
  [rat N D] -> [some [int (intdiv N D)]]
  _ -> [none])

(define nf-fracpart
  [int N] -> [some [int 0]]
  [rat N D] -> [some (make-rat (- N (* (intdiv N D) D)) D)]
  _ -> [none])

\\ Round to nearest integer, ties to EVEN (SymPy / Mathematica convention).
(define nf-round
  [int N] -> [some [int N]]
  [rat N D] -> [some [int (nf-round-rat N D)]]
  _ -> [none])

(define nf-round-rat
  N D -> (let F (nf-fdiv N D)            \\ floor
              R (- N (* F D))            \\ remainder in [0,D)
              T (* 2 R)                  \\ compare 2R to D
              (if (< T D)
                  F
                  (if (> T D)
                      (+ F 1)
                      (if (nf-even? F) F (+ F 1))))))   \\ exact half -> even

\\ ============================================================================
\\ Mod / Quotient (integers only; result of Mod carries the divisor's sign).
\\ ============================================================================
(define nf-quotient
  [int M] [int N] -> (if (= N 0) [none] [some [int (nf-fdiv M N)]])
  _ _ -> [none])

(define nf-mod
  [int M] [int N] -> (if (= N 0) [none] [some [int (- M (* (nf-fdiv M N) N))]])
  _ _ -> [none])

\\ ============================================================================
\\ GCD / LCM (n-ary over integers; non-integer arg -> inert).
\\ ============================================================================
(define nf-int? [int _] -> true _ -> false)
(define nf-int-val [int N] -> N)

(define nf-all-int? [] -> true [A | As] -> (if (nf-int? A) (nf-all-int? As) false))

(define nf-gcd
  Args -> (if (nf-all-int? Args) (nf-gcd-go Args) [none]))

(define nf-gcd-go
  [] -> [none]                         \\ GCD[] undefined here -> inert
  [A] -> [some [int (abs-num (nf-int-val A))]]
  [A B | Rest] -> (nf-gcd-go [[int (gcd (nf-int-val A) (nf-int-val B))] | Rest]))

(define nf-lcm
  Args -> (if (nf-all-int? Args) (trap-error (nf-lcm-go Args) (/. E [none])) [none]))

(define nf-lcm-go
  [] -> [none]
  [A] -> [some [int (abs-num (nf-int-val A))]]
  [A B | Rest] -> (nf-lcm-go [[int (nf-lcm2 (nf-int-val A) (nf-int-val B))] | Rest]))

\\ lcm(a,b) = |a / gcd(a,b) * b| ; 0 if either is 0. guard-int on the product.
(define nf-lcm2
  0 _ -> 0
  _ 0 -> 0
  A B -> (abs-num (guard-int (* (intdiv A (gcd A B)) B))))

\\ ============================================================================
\\ Factorial / Binomial (nonneg integers; int64 overflow -> inert).
\\ ============================================================================
(define nf-factorial
  [int N] -> (if (< N 0) [none] (trap-error [some [int (nf-fact-loop N 1)]] (/. E [none])))
  _ -> [none])

(define nf-fact-loop
  0 Acc -> Acc
  N Acc -> (nf-fact-loop (- N 1) (guard-int (* Acc N))))

\\ Binomial[n,k]: 0 for k<0 or k>n (n>=0); exact incremental product otherwise.
(define nf-binomial
  [int N] [int K] -> (nf-binom-dispatch N K)
  _ _ -> [none])

(define nf-binom-dispatch
  N K -> (if (< N 0)
             [none]                                  \\ generalized binomial: out of scope
             (if (if (< K 0) true (> K N))
                 [some [int 0]]
                 (trap-error [some [int (nf-binom N (nf-min2 K (- N K)))]] (/. E [none])))))

\\ C(n,k) via the exact incremental recurrence: each step's division is exact.
(define nf-binom
  N K -> (nf-binom-loop N K 1 1))

(define nf-binom-loop
  N K I Acc -> (if (> I K)
                   Acc
                   (nf-binom-loop N K (+ I 1)
                                  (intdiv (guard-int (* Acc (+ (- N I) 1))) I))))

\\ ============================================================================
\\ Max / Min (n-ary; fold only when ALL args are numeric, else inert).
\\ ============================================================================
(define nf-num? E -> (numeric? E))

(define nf-all-num? [] -> true [A | As] -> (if (nf-num? A) (nf-all-num? As) false))

\\ A > B for numeric A,B via the sign of (A - B).
(define nf-num-gt?
  A B -> (> (rat-num (as-rat (num-sub A B))) 0))

(define nf-max
  Args -> (if (if (nf-all-num? Args) (cons? Args) false)
              (trap-error [some (nf-max-go (tl Args) (hd Args))] (/. E [none]))
              [none]))

(define nf-max-go
  [] Best -> Best
  [A | As] Best -> (nf-max-go As (if (nf-num-gt? A Best) A Best)))

(define nf-min
  Args -> (if (if (nf-all-num? Args) (cons? Args) false)
              (trap-error [some (nf-min-go (tl Args) (hd Args))] (/. E [none]))
              [none]))

(define nf-min-go
  [] Best -> Best
  [A | As] Best -> (nf-min-go As (if (nf-num-gt? Best A) A Best)))

\\ ============================================================================
\\ Number theory: EvenQ OddQ Divisible CoprimeQ PrimeQ NextPrime Prime
\\                Fibonacci PowerMod.
\\ All decidable over the integers and SOUND: a predicate answers True/False only
\\ when it can decide exactly; functions decline ([none]) outside their domain, on
\\ int64 overflow, or when the trial bound would be too large to compute without
\\ hanging (bounded primality keeps the evaluator responsive -- it returns inert,
\\ never a wrong answer, for arguments beyond the bound).
\\ ============================================================================
(define nf-prime-bound -> 100000000)       \\ PrimeQ/NextPrime trial-division ceiling
(define nf-nth-prime-bound -> 2000)        \\ Prime[n] index ceiling

\\ remainder N - trunc(N/M)*M ; only used in == 0 divisibility tests (sign-agnostic).
(define nf-rem M N -> (- N (* (intdiv N M) M)))

(define nf-evenq
  [int N] -> [some (bool->expr (nf-even? N))]
  _ -> [none])

(define nf-oddq
  [int N] -> [some (bool->expr (not (nf-even? N)))]
  _ -> [none])

(define nf-divisible
  [int N] [int M] -> (if (= M 0) [none] [some (bool->expr (= 0 (nf-rem M N)))])
  _ _ -> [none])

(define nf-coprimeq
  [int A] [int B] -> [some (bool->expr (= 1 (gcd A B)))]
  _ _ -> [none])

\\ boolean primality (trial division by odd divisors up to sqrt; caller bounds N).
(define nf-is-prime?
  N -> (if (< N 2) false
           (if (= N 2) true
               (if (nf-even? N) false (nf-prime-odd? N 3)))))

(define nf-prime-odd?
  N D -> (if (> (* D D) N)
             true
             (if (= 0 (nf-rem D N)) false (nf-prime-odd? N (+ D 2)))))

(define nf-primeq
  [int N] -> (if (> (abs-num N) (nf-prime-bound)) [none] [some (bool->expr (nf-is-prime? N))])
  _ -> [none])

(define nf-nextprime
  [int N] -> (if (>= N (nf-prime-bound)) [none] [some [int (nf-next-prime-from (+ N 1))]])
  _ -> [none])

(define nf-next-prime-from
  K -> (if (nf-is-prime? K) K (nf-next-prime-from (+ K 1))))

(define nf-prime
  [int N] -> (if (if (< N 1) true (> N (nf-nth-prime-bound))) [none] [some [int (nf-nth-prime N 0 1)]])
  _ -> [none])

\\ nth prime by counting candidates from 2 upward (N within nth-prime-bound).
(define nf-nth-prime
  N Count Cand -> (let C2 (+ Cand 1)
                       (if (nf-is-prime? C2)
                           (if (= (+ Count 1) N) C2 (nf-nth-prime N (+ Count 1) C2))
                           (nf-nth-prime N Count C2))))

(define nf-fibonacci
  [int N] -> (if (< N 0) [none] (trap-error [some [int (nf-fib N 0 1)]] (/. E [none])))
  _ -> [none])

(define nf-fib
  0 A B -> A
  N A B -> (nf-fib (- N 1) B (guard-int (+ A B))))

\\ PowerMod[a,b,m] = a^b mod |m|, b>=0, via fast (square-and-multiply) exponentiation.
\\ Result normalized to [0,|m|). Declines on b<0, m=0, or int64 overflow of a product.
(define nf-powermod
  [int A] [int B] [int M] -> (if (if (< B 0) true (= M 0))
                                 [none]
                                 (trap-error [some [int (nf-pmod A B (abs-num M) 1)]] (/. E [none])))
  _ _ _ -> [none])

(define nf-pmod
  Base 0 M Acc -> (nf-mod-pos Acc M)
  Base E M Acc -> (if (nf-even? E)
                      (nf-pmod (nf-mod-pos (guard-int (* Base Base)) M) (intdiv E 2) M Acc)
                      (nf-pmod Base (- E 1) M (nf-mod-pos (guard-int (* Acc Base)) M))))

\\ nonnegative residue X mod M (M>0).
(define nf-mod-pos
  X M -> (let R (nf-rem M X) (if (< R 0) (+ R M) R)))

(output "numfun.shen loaded (Abs/Sign/Floor/Ceiling/Round/IntegerPart/FractionalPart/Mod/Quotient/GCD/LCM/Factorial/Binomial/Max/Min + number theory: EvenQ/OddQ/Divisible/CoprimeQ/PrimeQ/NextPrime/Prime/Fibonacci/PowerMod).~%")
