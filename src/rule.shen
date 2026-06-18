\\ rule.shen - checked-rule + binding analysis (Phase 1)
\\ Uses pattern + expr.
\\ bindings-cover enforced at construction/registration time.

(load "src/expr.shen")
(load "src/pattern.shen")

(datatype checked-rule
  LHS : pattern;
  RHS : expr;
  (bindings-cover? LHS RHS);
  _________________________
  (rule LHS RHS) : checked-rule; )

\\ Free symbols in an expr (for RHS coverage)
(define free-symbols
  (sym S) -> [S]
  (int _) -> []
  [H | Args] -> (append (free-symbols H) (mapcan (fn free-symbols) Args))
  _ -> [])

\\ Known "globals" / builtins for Phase 1 (expand when db arrives)
(define phase1-globals
  -> [Plus Times Minus Divide Power If True False List])  ; bare symbols; free-symbols emits bare S

(define known-symbol?
  S -> (element? S (phase1-globals)))

(define rule-lhs
  (rule L _) -> L)

(define rule-rhs
  (rule _ R) -> R)

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

\\ Registration helper (naive list for Phase 1; db later)
(set *rules* [])

(define register-rule
  R -> (if (and (checked-rule? R)
                (bindings-cover? (rule-lhs R) (rule-rhs R)))
           (set *rules* (adjoin R (value *rules*)))
           (error "register-rule: not a checked-rule or bindings not covered ~A" R)))

(define checked-rule? 
  (rule _ _) -> true
  _ -> false)

(princ "rule.shen loaded (checked-rule + bindings-cover).~%")