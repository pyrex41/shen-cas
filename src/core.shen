\\ core.shen - Evaluation Core seam + naive reduce (Phase 1)
\\ Later: full attribute handling, db-backed, memo, etc.

(load "src/rule.shen")
(load "src/match.shen")
(load "src/db.shen")

(define rules-for-expr
  Db E -> (if (and (cons? Db) (not (empty? (db-datoms Db))))
              (dispatch-candidates Db E)
              []))

(define reduce
  E -> (reduce (value *db*) E)
  Db E -> (let Rules (rules-for-expr Db E)
               (try-reduce-db Db E Rules)))

(define try-reduce-db
  Db E [] -> E
  Db E [R | Rest] ->
    (let LHS (rule-lhs R)
         RHS (rule-rhs R)
         M (match LHS E)
         (if (some? M)
             (let New (substitute (unwrap M) RHS)
                  (if (= New E) E (reduce Db New)))
             (try-reduce-db Db E Rest))))

(define rule-lhs [rule L _] -> L)
(define rule-rhs [rule _ R] -> R)

(define expr-head
  [[sym S] | _] -> [(sym S)]
  [(sym S) | _] -> [(sym S)]
  _ -> [])

\\ normal-form : content + basis keyed memo (SCUD 10.2)
(define normal-form
  Db E -> (let CH (content-hash E)
               BH (db-basis Db)
               K (nf-cache-key CH BH)
               Hit (nf-lookup K)
               (if (cons? Hit)
                   (hd (tl Hit))
                   (let NF (reduce Db E)
                        _ (nf-store! K NF)
                        NF)))
  E -> (normal-form (value *db*) E))

\\ Naive registration of arith rules (now delegated to boot/arith.shen skeleton for SCUD 13.1)
(define demo-register-arith
  -> (do 
       (load "boot/arith.shen")
       true))

(define demo-reduce
  E -> (let _ (demo-register-arith)
            (reduce E)))

(output "core.shen (db-aware reduce + normal-form memo) loaded.~%")