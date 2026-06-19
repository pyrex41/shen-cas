\\ rule.shen - checked-rule + binding analysis (Phase 1)
\\ Uses pattern + expr.
\\ bindings-cover enforced at construction/registration time.
\\ 16e: deps (expr/pattern/db) are loaded by load.shen before rule; no redundant loads.

(define rule L R -> [rule L R])

\\ Free symbols in an expr (for RHS coverage)
(define free-symbols
  [sym S] -> [S]
  [int N] -> [] where (number? N)
  [rat N D] -> [] where (and (number? N) (number? D))
  [H | Args] -> (append (free-symbols H) (mapcan (/. X (free-symbols X)) Args))
  _ -> [])

\\ Known "globals" / builtins for Phase 1 (expand when db arrives)
(define phase1-globals
  -> [(protect Plus) (protect Times) (protect Minus) (protect Divide) (protect Power) (protect If) (protect True) (protect False) (protect List)
      \\ SCUD 20 Wave 4: calculus + elementary function heads. Every RHS head a
      \\ calculus rule can emit must be whitelisted here (or LHS-bound) -- this is
      \\ the static-check surface bindings-cover? enforces at registration.
      (protect D) (protect Integrate)
      (protect Sin) (protect Cos) (protect Tan) (protect Sec)
      (protect Exp) (protect Log) (protect Sqrt)
      (protect ArcSin) (protect ArcCos) (protect ArcTan)
      \\ SCUD 19 Wave D: Solve polynomial equations + the Equal head from '=='.
      (protect Equal) (protect Solve)
      \\ SCUD 20 Wave E: Taylor Series + Limit heads.
      (protect Series) (protect Limit)
      (protect Plus) (protect Times)])

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

\\ 18: a guarded rule (condition P Test) or (ptest P F) dispatches on the head of
\\ the WRAPPED pattern P, not the literal 'condition'/'ptest' tag, so D[x,x] /; ...
\\ is indexed under D. Peel guards before taking the head.
(define lhs-dispatch-pattern
  L -> (if (condition? L)
           (lhs-dispatch-pattern (condition-pattern L))
           (if (ptest? L)
               (lhs-dispatch-pattern (ptest-pattern L))
               L)))

(define rule-head
  [rule L _] -> (let P (lhs-dispatch-pattern L)
                     (if (cons? P) (hd P) P)))

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

\\ P0-2: shape check alone let malformed rules register (e.g. [rule [int 1] [int 2]],
\\ whose LHS is an integer literal, not a dispatchable pattern). A registrable rule's
\\ LHS must -- after peeling condition/ptest guards -- be a compound headed by a
\\ [sym S] (so it has a real dispatch head). bindings-cover? is enforced separately
\\ in register-rule and in the checked-rule datatype.
(define valid-rule-lhs?
  L -> (let P (lhs-dispatch-pattern L)
            (and (cons? P) (sym? (hd P)))))

(define checked-rule?
  [rule Lhs Rhs] -> (valid-rule-lhs? Lhs)
  X -> false)

(output "rule.shen loaded (checked-rule + bindings-cover).~%")