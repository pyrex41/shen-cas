\\ rule.shen - checked-rule + binding analysis (Phase 1)
\\ Uses pattern + expr.
\\ bindings-cover enforced at construction/registration time.

(load "src/expr.shen")
(load "src/pattern.shen")
(load "src/db.shen")

(define rule L R -> [rule L R])

\\ Free symbols in an expr (for RHS coverage)
(define free-symbols
  [sym S] -> [S]
  [int _] -> []
  [H | Args] -> (append (free-symbols H) (mapcan (/. X (free-symbols X)) Args))
  _ -> [])

\\ Known "globals" / builtins for Phase 1 (expand when db arrives)
(define phase1-globals
  -> [(protect Plus) (protect Times) (protect Minus) (protect Divide) (protect Power) (protect If) (protect True) (protect False) (protect List)])  ; protected symbols; free-symbols emits bare S; protect avoids free var

(define known-symbol?
  S -> (element? S (phase1-globals)))

(define filter
  _ [] -> []
  F [X | Xs] -> (if (F X) [X | (filter F Xs)] (filter F Xs)))

(define rule-lhs
  [rule L _] -> L)

(define rule-rhs
  [rule _ R] -> R)

(define bindings-cover?
  LHS RHS ->
    (let Bound (extract-bindings LHS)
         Free  (free-symbols RHS)
         Unknown (filter (/. V (not (or (element? V Bound)
                                        (known-symbol? V))))
                         Free)
         (if (empty? Unknown)
             true
             (do (output "bindings-cover? failed; unbound: ~A~%" Unknown)
                 false))))

(datatype checked-rule
  LHS : pattern;
  RHS : expr;
  (bindings-cover? LHS RHS);
  _________________________
  (rule LHS RHS) : checked-rule; )

\\ Registration via db assert (SCUD 10.2)
(set *db* (empty-db))

(define rule-head
  (rule L _) -> (if (cons? L) (hd L) L))

(define register-rule
  R -> (if (and (checked-rule? R)
                (bindings-cover? (rule-lhs R) (rule-rhs R)))
           (let Sym (rule-head R)
                Kind down
                NewDb (assert-rule (value *db*) Sym Kind R)
                _ (set *db* NewDb)
                _ (trap-error (warn-on-rule-registration R) (/. _ true))
                R)
           (error "register-rule: not a checked-rule or bindings not covered ~A" R)))

(define checked-rule? 
  [rule _ _] -> true
  _ -> false)

(output "rule.shen loaded (checked-rule + bindings-cover).~%")