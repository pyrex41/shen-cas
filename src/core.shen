\\ core.shen - Evaluation Core seam + naive reduce (Phase 1)
\\ Later: full attribute handling, db-backed, memo, etc.

(load "src/rule.shen")
(load "src/match.shen")
(load "src/db.shen")

(define rules-for-expr
  Db E -> (if (and (cons? Db) (not (empty? (db-datoms Db))))
              (dispatch-candidates Db E)
              []))

(define reduce-db
  Db E -> (if (block-form? E)
              (reduce-block Db E)
              (let Rules (rules-for-expr Db E)
                   (try-reduce-db Db E Rules))))

(define block-form?
  [[sym block] _ _] -> true
  _ -> false)

(define reduce-block
  Db [[sym block] Binds Body] ->
    (let ChildDb (apply-block-binds Db Binds)
         (reduce-db ChildDb Body))
  Db E -> E)

(define apply-block-binds
  Db [] -> Db
  Db [[[sym block-bind] S V] | Rest] ->
    \\ temporary binding: for skeleton, fork and add a simple constant-like datom for the symbol head
    \\ (real system could register a value rule or special entry)
    (let TempDatom [S own (make-rule-stub [sym S] V) (db-size Db)]  ; use stub per reviewer findings for 019edc98-07ed...
         Child (db-fork-with Db [TempDatom])
         (apply-block-binds Child Rest))
  Db _ -> Db)

(define reduce
  E -> (reduce-db (value *db*) E))

(define try-reduce-db
  Db E [] -> E
  Db E [R | Rest] ->
    (let LHS (rule-lhs R)
         RHS (rule-rhs R)
         M (match LHS E)
         (if (match-some? M)
             (let New (substitute (match-unwrap M) RHS)
                  (if (= New E) E (reduce-db Db New)))
             (try-reduce-db Db E Rest))))

(define rule-lhs [rule L _] -> L)
(define rule-rhs [rule _ R] -> R)

(define expr-head
  [[sym S] | _] -> [sym S]
  _ -> [])

\\ normal-form : content + basis keyed memo (SCUD 10.2)
(define normal-form-db
  Db E -> (let CH (content-hash E)
               BH (db-basis Db)
               K (nf-cache-key CH BH)
               Hit (nf-lookup K)
               (if (cons? Hit)
                   (hd (tl Hit))
                   (let NF (reduce-db Db E)
                        Ign (nf-store! K NF)
                        NF))))

(define normal-form
  E -> (normal-form-db (value *db*) E))

\\ Naive registration of arith rules (now delegated to boot/arith.shen skeleton for SCUD 13.1)
(define demo-register-arith
  -> (do 
       (load "boot/arith.shen")
       true))

(define demo-reduce
  E -> (let Ign (demo-register-arith)
            (reduce E)))

(output "core.shen (db-aware reduce + normal-form memo) loaded.~%")