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

\\ Naive registration of a few demo rules for testing
(define demo-register-arith
  -> (do 
       (register-rule 
         (rule [(sym Plus) (int 0) (named x (blank))]
               (named x (blank))))
       (register-rule 
         (rule [(sym Plus) (named x (blank)) (int 0)]
               (named x (blank))))
       true))

(define demo-reduce
  E -> (let _ (demo-register-arith)
            (reduce E)))

(princ "core.shen (naive reduce) loaded.~%")