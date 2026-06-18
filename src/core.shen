\\ core.shen - Evaluation Core seam + naive reduce (Phase 1)
\\ Later: full attribute handling, db-backed, memo, etc.

(load "src/rule.shen")
(load "src/match.shen")

(define reduce
  E -> (let Rules (value *rules*)
            (try-reduce E Rules)))

(define try-reduce
  E [] -> E
  E [R | Rest] ->
    (let LHS (rule-lhs R)
         RHS (rule-rhs R)
         M (match LHS E)
         (if (some? M)
             (let New (substitute (unwrap M) RHS)
                  (if (= New E) E (reduce New)))   \\ fixed point
             (try-reduce E Rest))))

(define rule-lhs (rule L _) -> L)
(define rule-rhs (rule _ R) -> R)

\\ Naive registration of a few demo rules for testing the harness later
\\ (real ones will come from boot/ and checked registration)

\\ Example: x + 0 -> x   (but without Orderless yet)
\\ For skeleton we register simple literal rules.

(define demo-register-arith
  -> (do (register-rule (rule (int 0) (int 0)))   \\ trivial
         (register-rule (rule [(sym Plus) (int 0) (blank)] (blank)))  \\ very rough
         true))

(princ "core.shen (naive reduce) loaded.~%")