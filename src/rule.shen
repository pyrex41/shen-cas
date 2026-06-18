\\ rule.shen - checked-rule + binding analysis (Phase 1)
\\ Uses pattern + expr.
\\ bindings-cover enforced at construction/registration time.
\\ 16e: deps (expr/pattern/db) are loaded by load.shen before rule; no redundant loads.

(define rule L R -> [rule L R])

\\ Free symbols in an expr (for RHS coverage)
(define free-symbols
  [sym S] -> [S]
  [int N] -> [] where (number? N)
  [H | Args] -> (append (free-symbols H) (mapcan (/. X (free-symbols X)) Args))
  _ -> [])

\\ Known "globals" / builtins for Phase 1 (expand when db arrives)
(define phase1-globals
  -> [(protect Plus) (protect Times) (protect Minus) (protect Divide) (protect Power) (protect If) (protect True) (protect False) (protect List)])

(define known-symbol?
  S -> (element? S (phase1-globals)))

(define rule-filter
  _ [] -> []
  F [X | Xs] -> (if (F X) [X | (rule-filter F Xs)] (rule-filter F Xs)))

(define rule-lhs
  [rule L _] -> L)

(define rule-rhs
  [rule _ R] -> R)

(define bindings-cover?
  LHS RHS ->
    (let Bound (extract-bindings LHS)
         Free  (free-symbols RHS)
         Unknown (rule-filter (/. V (not (or (element? V Bound)
                                            (known-symbol? V))))
                             Free)
         (if (empty? Unknown)
             true
             (do (output "bindings-cover? failed unbound: ~A~%" Unknown)
                 false))))

(datatype checked-rule
  LHS : pattern;
  RHS : expr;
  (bindings-cover? LHS RHS);
  _________________________
  [rule LHS RHS] : checked-rule; )

\\ Registration via db assert (SCUD 10.2)
(set *db* (empty-db))

(define rule-head
  [rule L _] -> (if (cons? L) (hd L) L))

\\ 16d: nested if (not 'and') so rule-lhs/rule-rhs are never applied to a
\\ non-[rule ...] value; a malformed input raises the clean error, not an accessor crash.
(define register-rule
  R -> (if (checked-rule? R)
           (if (bindings-cover? (rule-lhs R) (rule-rhs R))
               (let Sym (rule-head R)
                    Kind down
                    NewDb (assert-rule (value *db*) Sym Kind R)
                    _ (set *db* NewDb)
                    Ign (trap-error (warn-on-rule-registration R) (/. Err true))
                    R)
               (error "register-rule: not a checked-rule or bindings not covered ~A" R))
           (error "register-rule: not a checked-rule or bindings not covered ~A" R)))

(define checked-rule?
  [rule Lhs Rhs] -> true
  X -> false)

(output "rule.shen loaded (checked-rule + bindings-cover).~%")