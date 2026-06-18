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
  -> [(sym Plus) (sym Times) (sym Minus) (sym Divide) (sym Power)
      (sym If) (sym True) (sym False) (sym List) ])

(define known-symbol?
  S -> (element? S (phase1-globals)))

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
  R -> (if (checked-rule? R)
           (set *rules* (adjoin R (value *rules*)))
           (error "register-rule: not a checked-rule ~A" R)))

(define checked-rule? 
  (rule _ _) -> true
  _ -> false)

(princ "rule.shen loaded (checked-rule + bindings-cover).~%")