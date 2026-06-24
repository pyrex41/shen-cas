\\ core.shen - Evaluation Core seam + real evaluator (SCUD 17a)
\\ match.shen + match-seq + match-ac are loaded by load.shen before core.
\\
\\ SCUD 17a: reduce-db is now a fixed-point driver over eval-step, implementing the
\\ Mathematica-ordered NON-CONFLUENT sequence:
\\   eval head -> eval args per Hold attrs -> Flat-flatten -> Orderless sort by content-hash
\\   -> Listable thread (gated behind *listable-on*) -> built-in arithmetic hook (num-builtin)
\\   -> DownValues (dispatch-candidates + try-reduce-db, seq/AC-aware match) -> UpValues
\\   -> else inert.
\\ A *max-eval-steps* guard warns and returns rather than hanging.

\\ ----------------------------------------------------------------------------
\\ Seam (16c): tag-dispatch on (current-core). shen-go cannot apply a returned
\\ function symbol, so route reduce/normal-form through reduce-via/normal-form-via.
\\ ----------------------------------------------------------------------------
(define reduce-ref
  E -> (reduce-db (value *db*) E))

(define normal-form-ref
  E -> (normal-form-db (value *db*) E))

(define reduce-compiled
  E -> E )

(define normal-form-compiled
  E -> E )

(set *current-core* ref)

(define current-core
  -> (value *current-core*))

(define set-current-core
  Tag -> (set *current-core* Tag))

(define reduce-via
  ref E -> (reduce-ref E)
  compiled E -> (reduce-compiled E)
  _ E -> (reduce-ref E))

(define normal-form-via
  ref E -> (normal-form-ref E)
  compiled E -> (normal-form-compiled E)
  _ E -> (normal-form-ref E))

\\ ----------------------------------------------------------------------------
\\ Evaluation controls
\\ ----------------------------------------------------------------------------
(set *max-eval-steps* 1000)
(set *listable-on* false)   \\ gated until List is bootstrapped (invariant 3)

\\ ----------------------------------------------------------------------------
\\ Dispatch
\\ ----------------------------------------------------------------------------
(define rules-for-expr
  Db E -> (if (and (cons? Db) (not (empty? (db-datoms Db))))
              (dispatch-candidates Db E)
              []))

\\ ----------------------------------------------------------------------------
\\ Argument evaluation (respect Hold control attrs; 16f)
\\ ----------------------------------------------------------------------------
(define reduce-args
  Db E -> (if (expr-compound? E)
              (reduce-args-compound Db E)
              E))

(define reduce-args-compound
  Db [H | Args] ->
    (if (sym? H)
        (let S (sym-name H)
             (if (holds-all? Db S)
                 [H | Args]
                 (if (holds-first? Db S)
                     [H | (cons (hd Args) (map (/. A (reduce-db Db A)) (tl Args)))]
                     (if (holds-rest? Db S)
                         [H | (cons (reduce-db Db (hd Args)) (tl Args))]
                         [H | (map (/. A (reduce-db Db A)) Args)]))))
        [H | (map (/. A (reduce-db Db A)) Args)]))

\\ ----------------------------------------------------------------------------
\\ Canonicalization: Flat-flatten + Orderless sort (per head's structural sig)
\\ ----------------------------------------------------------------------------
(define canon-flat-orderless
  Db [H | Args] ->
    (if (sym? H)
        (let S (sym-name H)
             Flat (if (has-flat? S) (flatten-flat-args H Args) Args)
             Sorted (if (has-orderless? S) (sort-exprs-by-hash Flat) Flat)
             [H | Sorted])
        [H | Args])
  Db E -> E)

\\ stable sort of expressions by their content-hash value (17a)
(define sort-exprs-by-hash
  Es -> (sort-exprs-insert Es))

(define sort-exprs-insert
  [] -> []
  [E | Es] -> (insert-expr-by-hash E (sort-exprs-insert Es)))

(define insert-expr-by-hash
  E [] -> [E]
  E [Y | Ys] -> (if (<= (unwrap-ch (content-hash E)) (unwrap-ch (content-hash Y)))
                    [E Y | Ys]
                    [Y | (insert-expr-by-hash E Ys)]))

\\ ----------------------------------------------------------------------------
\\ Built-in arithmetic hook (17b): fires only when all args numeric, BEFORE user rules.
\\ ----------------------------------------------------------------------------
(define try-builtin
  [H | Args] -> (if (sym? H)
                    (apply-builtin-result (builtin-result H Args) [H | Args])
                    [H | Args])
  E -> E)

\\ Numeric arithmetic first (highest priority), then wired calculus predicates
\\ (SameQ/UnsameQ/FreeQ/NumberQ via calc-helpers); [none] means fall through.
(define builtin-result
  H Args -> (let R (num-builtin H Args)
                 (if (= R [none]) (calc-builtin H Args) R)))

(define apply-builtin-result
  [some R] _ -> R
  [none] E -> E
  _ E -> E)

\\ ----------------------------------------------------------------------------
\\ UpValues: rules attached to the head symbols of arguments.
\\ ----------------------------------------------------------------------------
(define up-candidates
  Db [_ | Args] -> (up-candidates-for-args Db Args)
  Db _ -> [])

(define up-candidates-for-args
  Db [] -> []
  Db [A | As] -> (append (up-candidates-for-arg Db A)
                         (up-candidates-for-args Db As)))

(define up-candidates-for-arg
  Db [H | _] -> (if (sym? H) (up-rules Db (sym-name H)) [])
  Db _ -> [])

(define up-rules
  Db S -> (let V (symbol-entry-view Db [sym S])
               (hd (tl (tl (tl V))))))

\\ ----------------------------------------------------------------------------
\\ One evaluation step (returns a possibly-rewritten expr).
\\ ----------------------------------------------------------------------------
(define eval-step
  Db E ->
    (if (block-form? E)
        (reduce-block Db E)
        (if (expr-compound? E)
            (eval-step-compound Db E)
            E)))

(define eval-step-compound
  Db E ->
    (let E1 (reduce-args Db E)
         E2 (canon-flat-orderless Db E1)
         E3 (try-builtin E2)
         (if (not (content-eq E3 E2))
             E3
             (let Down (rules-for-expr Db E2)
                  E4 (try-reduce-db Db E2 Down)
                  (if (not (content-eq E4 E2))
                      E4
                      (let Up (up-candidates Db E2)
                           (try-reduce-db Db E2 Up)))))))

\\ ----------------------------------------------------------------------------
\\ Fixed-point driver with *max-eval-steps* guard.
\\ ----------------------------------------------------------------------------
(define reduce-db
  Db E -> (reduce-fixpoint Db E (value *max-eval-steps*)))

(define reduce-fixpoint
  Db E 0 -> (do (output "WARNING: *max-eval-steps* exceeded; returning ~A~%" (pretty-expr E)) E)
  Db E N -> (let E1 (eval-step Db E)
                 (if (content-eq E1 E)
                     E1
                     (reduce-fixpoint Db E1 (- N 1)))))

\\ ----------------------------------------------------------------------------
\\ Rule application: first matching rule wins; substitute then return new expr
\\ (the driver re-evaluates). try-reduce-db does NOT recurse itself.
\\ SCUD 19: fuel cap (*max-rule-tries*) bounds the number of candidate rules
\\ attempted at one node in one step, so a pathologically large candidate list
\\ cannot stall a step; it warns and returns the expr unchanged (stays inert).
\\ ----------------------------------------------------------------------------
(set *max-rule-tries* 2000)

(define try-reduce-db
  Db E Rules -> (try-reduce-db-fuel Db E Rules (value *max-rule-tries*)))

(define try-reduce-db-fuel
  Db E [] _ -> E
  Db E [R | Rest] 0 -> (do (output "WARNING: *max-rule-tries* exceeded at ~A; leaving inert~%" (pretty-expr E)) E)
  Db E [R | Rest] N ->
    (if (checked-rule? R)
        (let LHS (rule-lhs R)
             RHS (rule-rhs R)
             M (match LHS E)
             (if (match-some? M)
                 (substitute (match-unwrap M) RHS)
                 (try-reduce-db-fuel Db E Rest (- N 1))))
        (try-reduce-db-fuel Db E Rest (- N 1))))

(define rule-lhs [rule L _] -> L)
(define rule-rhs [rule _ R] -> R)

\\ ----------------------------------------------------------------------------
\\ Block scoping (db-fork) - unchanged from SCUD 12.
\\ ----------------------------------------------------------------------------
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
  E -> (reduce-via (current-core) E))

\\ ----------------------------------------------------------------------------
\\ normal-form memo (content-hash + basis keyed)
\\ ----------------------------------------------------------------------------
(define normal-form-db
  Db E -> (let CH (content-hash E)
               BH (db-basis Db)
               K (nf-cache-key CH BH E)
               Hit (nf-lookup K)
               (if (assoc-hit? Hit)
                   (hd (tl Hit))
                   (let NF (reduce-db Db E)
                        Ign (nf-store! K NF)
                        NF))))

(define normal-form
  E -> (normal-form-via (current-core) E))

(define demo-register-arith
  -> (do (load "boot/arith.shen") true))

\\ SCUD 19: load the simplification identity rules (after arith, which declares
\\ Plus/Times/Power). collect-like-terms (Simplify head) is wired in calc-helpers,
\\ not a register-rule, so it needs no loader.
(define demo-register-simplify
  -> (do (demo-register-arith) (load "boot/simplify.shen") true))

\\ SCUD 20 Wave 4: load elementary-function symbols/table + the D rule library.
\\ Order matters: simplify BEFORE calculus so D output auto-simplifies in the
\\ unified fixpoint; elemfun supplies Sin/Cos/... symbols + exact-value table.
(define demo-register-calculus
  -> (do (demo-register-simplify)
         (load "boot/elemfun.shen")
         (load "boot/calculus.shen")
         true))

(define demo-reduce
  E -> (let Ign (demo-register-arith)
            (reduce E)))

(output "core.shen (eval-step fixpoint evaluator + arith hook + seam) loaded.~%")
