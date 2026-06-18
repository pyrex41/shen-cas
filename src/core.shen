\\ core.shen - Evaluation Core seam + naive reduce (Phase 1)
\\ Later: full attribute handling, db-backed, memo, etc.
\\ match.shen + match-seq + match-ac are loaded by load.shen before core.

\\ SCUD 15: backend seam (ref + stubs for compiled). Parameterize via current-*
\\ Future backends must be basis-keyed and pass full harness.

(load "src/db.shen")

\\ ref impl
(define reduce-ref
  E -> (reduce-db (value *db*) E))

(define normal-form-ref
  E -> (normal-form-db (value *db*) E))

\\ stub compiled backend (basis-keyed compiled dispatch etc.)
(define reduce-compiled
  E -> E )

(define normal-form-compiled
  E -> E )

(define current-core
  -> 'ref )

(define current-reduce
  -> reduce-ref )

(define current-normal-form
  -> normal-form-ref )

(define rules-for-expr
  Db E -> (if (and (cons? Db) (not (empty? (db-datoms Db))))
              (dispatch-candidates Db E)
              []))

(define reduce-args
  Db E -> (if (expr-compound? E)
              (reduce-args-compound Db E)
              E))

(define reduce-args-compound
  Db [H | Args] -> (append [H] (map (/. A (reduce-db Db A)) Args)))

(define reduce-db
  Db E -> (if (block-form? E)
              (reduce-block Db E)
              (let E1 (reduce-args Db E)
                   Rules (rules-for-expr Db E1)
                   (try-reduce-db Db E1 Rules))))

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
    (let TempDatom [S own (make-rule-datum [sym S] V) (db-size Db)]
         Child (db-fork-with Db [TempDatom])
         (apply-block-binds Child Rest))
  Db _ -> Db)

(define reduce
  E -> ((current-reduce) E))

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

(define normal-form-db
  Db E -> (let CH (content-hash E)
               BH (db-basis Db)
               K (nf-cache-key CH BH)
               Hit (nf-lookup K)
               (if (assoc-hit? Hit)
                   (hd (tl Hit))
                   (let NF (reduce-db Db E)
                        Ign (nf-store! K NF)
                        NF))))

(define normal-form
  E -> ((current-normal-form) E))

(define demo-register-arith
  -> (do (load "boot/arith.shen") true))

(define demo-reduce
  E -> (let Ign (demo-register-arith)
            (reduce E)))

(output "core.shen (db-aware reduce + normal-form memo) loaded.~%")