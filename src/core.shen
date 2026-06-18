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

(define rule-lhs [rule L _] -> L)
(define rule-rhs [rule _ R] -> R)

\\ Naive registration of arith rules (now delegated to boot/arith.shen skeleton for SCUD 13.1)
(define demo-register-arith
  -> (do 
       (load "boot/arith.shen")
       true))

(define demo-reduce
  E -> (let _ (demo-register-arith)
            (reduce E)))

(output "core.shen (naive reduce) loaded.~%")