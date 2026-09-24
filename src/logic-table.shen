\\ logic-table.shen - finite, positive, tabled relations over CAS expressions.
\\ Facts and clauses are data, never Shen Prolog assertions. Saturation computes
\\ the least fixed point, so a left-recursive rule does not recurse on the stack.
\\ [logic-atom predicate [arg ...]]; [logic-rule head [body-atom ...]].
\\ An arg is a ground CAS expr or [logic-var name]. Variables occupy whole
\\ argument positions; compound terms with variables and negation are excluded.

(set *logic-max-facts* 10000)

(define logic-ground-expr?
  [sym S] -> (symbol? S)
  [int N] -> (number? N)
  [rat N D] -> (and (number? N) (number? D))
  [H | Args] -> (and (logic-ground-expr? H) (logic-ground-list? Args))
  _ -> false)

(define logic-ground-list?
  [] -> true
  [X | Xs] -> (and (logic-ground-expr? X) (logic-ground-list? Xs))
  _ -> false)

(define logic-arg?
  [logic-var S] -> (symbol? S)
  X -> (logic-ground-expr? X))

(define logic-args?
  [] -> true
  [X | Xs] -> (and (logic-arg? X) (logic-args? Xs))
  _ -> false)

(define logic-atom?
  [logic-atom P Args] -> (and (symbol? P) (logic-args? Args))
  _ -> false)

(define logic-ground-atom?
  [logic-atom P Args] -> (and (symbol? P) (logic-ground-list? Args))
  _ -> false)

(define logic-body?
  [] -> true
  [A | As] -> (and (logic-atom? A) (logic-body? As))
  _ -> false)

(define logic-vars-args
  [] -> []
  [[logic-var S] | Rest] -> (cons S (logic-vars-args Rest))
  [_ | Rest] -> (logic-vars-args Rest))

(define logic-vars-body
  [] -> []
  [[logic-atom _ Args] | Rest] -> (append (logic-vars-args Args) (logic-vars-body Rest)))

(define logic-bound-vars?
  [] _ -> true
  [V | Vs] Bound -> (and (element? V Bound) (logic-bound-vars? Vs Bound)))

(define logic-safe-rule?
  [logic-rule [logic-atom P HeadArgs] Body] ->
    (and (symbol? P) (logic-args? HeadArgs) (logic-body? Body)
         (logic-bound-vars? (logic-vars-args HeadArgs) (logic-vars-body Body)))
  _ -> false)

(define logic-check-facts
  [] -> true
  [F | Fs] -> (if (logic-ground-atom? F)
                 (logic-check-facts Fs)
                 (error "logic-table: non-ground or malformed fact ~A" F))
  _ -> (error "logic-table: facts must be a list"))

(define logic-check-rules
  [] -> true
  [R | Rs] -> (if (logic-safe-rule? R)
                 (logic-check-rules Rs)
                 (error "logic-table: unsafe or malformed rule ~A" R))
  _ -> (error "logic-table: rules must be a list"))

\\ A failed join has no substitutions. Successful joins return a list of them;
\\ [[]] means one solution with no bindings.
(define logic-bind-arg
  [logic-var V] Value Env ->
    (let Hit (assoc V Env)
         (if (assoc-hit? Hit)
             (if (= (hd (tl Hit)) Value) [Env] [])
             [(cons [V Value] Env)]))
  Pattern Value Env -> (if (= Pattern Value) [Env] []))

(define logic-bind-args
  [] [] Env -> [Env]
  [P | Ps] [V | Vs] Env ->
    (logic-bind-args-envs Ps Vs (logic-bind-arg P V Env))
  _ _ _ -> [])

(define logic-bind-args-envs
  _ _ [] -> []
  Ps Vs [Env | Envs] ->
    (append (logic-bind-args Ps Vs Env) (logic-bind-args-envs Ps Vs Envs)))

(define logic-bind-atom
  [logic-atom P Args] [logic-atom P Values] Env ->
    (logic-bind-args Args Values Env)
  _ _ _ -> [])

(define logic-join-facts
  _ [] _ -> []
  Pattern [Fact | Facts] Env ->
    (append (logic-bind-atom Pattern Fact Env)
            (logic-join-facts Pattern Facts Env)))

(define logic-join-envs
  _ _ [] -> []
  Pattern Facts [Env | Envs] ->
    (append (logic-join-facts Pattern Facts Env)
            (logic-join-envs Pattern Facts Envs)))

(define logic-solve-body
  [] _ Envs -> Envs
  [Goal | Goals] Facts Envs ->
    (logic-solve-body Goals Facts (logic-join-envs Goal Facts Envs)))

(define logic-instantiate-arg
  [logic-var V] Env -> (let Hit (assoc V Env) (hd (tl Hit)))
  Ground _ -> Ground)

(define logic-instantiate-args
  [] _ -> []
  [A | As] Env -> (cons (logic-instantiate-arg A Env)
                      (logic-instantiate-args As Env)))

(define logic-instantiate-head
  [logic-atom P Args] Env -> [logic-atom P (logic-instantiate-args Args Env)])

(define logic-produce
  _ [] -> []
  Head [Env | Envs] ->
    (cons (logic-instantiate-head Head Env) (logic-produce Head Envs)))

(define logic-rule-answers
  [logic-rule Head Body] Facts ->
    (logic-produce Head (logic-solve-body Body Facts [[]])))

(define logic-rule-answers-all
  [] _ -> []
  [R | Rs] Facts ->
    (append (logic-rule-answers R Facts) (logic-rule-answers-all Rs Facts)))

\\ Only facts from the previous round feed a round. Duplicate answers are
\\ suppressed structurally. With whole-argument variables and finite input
\\ constants, the possible fact set is finite; the guard also caps resources.
(define logic-close
  Rules Facts ->
    (let Next (set-union (logic-rule-answers-all Rules Facts) Facts)
         (if (> (length Next) (value *logic-max-facts*))
             (error "logic-table: fact limit exceeded")
             (if (= (length Next) (length Facts))
                 Facts
                 (logic-close Rules Next)))))

(define logic-table
  Facts Rules -> (do (logic-check-facts Facts)
                    (logic-check-rules Rules)
                    (logic-close Rules (dedup Facts))))

(define logic-select
  _ [] -> []
  Pattern [Fact | Facts] ->
    (if (= (logic-bind-atom Pattern Fact []) [])
        (logic-select Pattern Facts)
        (cons Fact (logic-select Pattern Facts))))

(define logic-query
  Facts Rules Pattern ->
    (if (logic-atom? Pattern)
        (logic-select Pattern (logic-table Facts Rules))
        (error "logic-table: malformed query ~A" Pattern)))

(output "logic-table.shen loaded (finite positive tabled relations).~%")
