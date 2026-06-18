\\ scope.shen - Stub for Module/With/Block per SCUD 12 + design (minimal)
\\ Hygienic gensym; alpha renaming for hash (tied via store content-hash);
\\ Block as db fork stub (even if db partial); basic symbol-only checks for block bindings.
\\ Load after core (per loader and internal).

\\ Load order managed at top level (load.shen puts scope after core).
\\ Do not (load core) here to avoid reload side-effects on *rules*, counters, prints.

(set *gensym-counter* 0)

\\ Hygienic gensym (runtime fresh names for capture avoidance in Module/With expansion).
(define cas-gensym
  S -> (let N (value *gensym-counter*)
            _ (set *gensym-counter* (+ N 1))
            (intern (cn (str S) (cn "$" (str N))))))

\\ --- Alpha support for content hash tie-in (Module/With) ---
\\ These are called from store's alpha-canonicalize / content-hash path.
\\ Canon names are deterministic (G$0, G$1, ...) so alpha-equivalent forms share hash.

(define ensure-bare-symbol
  S -> S where (symbol? S)
  [sym S] -> S
  X -> (error "scope: binder must be symbol (not ~S)" X))

(define generate-canon-bare
  0 -> []
  N -> (generate-canon-bare-helper 0 N))

(define generate-canon-bare-helper
  I N -> [] where (>= I N)
  I N -> (cons (intern (cn "G$" (str I))) (generate-canon-bare-helper (+ I 1) N)))

(define rename-in-expr
  [] [] E -> E
  [Old | Olds] [New | News] E -> (rename-in-expr Olds News (rename-one Old New E))
  _ _ E -> E)

(define rename-one
  Old New [sym S] -> [sym New] where (= S Old)
  Old New S -> New where (and (symbol? S) (= S Old))
  Old New [int N] -> [int N]
  Old New [H | As] -> [(rename-one Old New H) | (map (/. X (rename-one Old New X)) As)]
  Old New X -> X)

(define alpha-canonicalize
  [ [sym module] Vars Body ] ->
    (let Bare (map ensure-bare-symbol Vars)
         Canon (generate-canon-bare (length Bare))
         NormBody (alpha-canonicalize (rename-in-expr Bare Canon Body))
         [ [sym module] Canon NormBody ])
  [ [sym with] V Val Body ] ->
    (let Bare (ensure-bare-symbol V)
         Canon (hd (generate-canon-bare 1))
         NormBody (alpha-canonicalize (rename-in-expr [Bare] [Canon] Body))
         [ [sym with] Canon Val NormBody ])
  [H | Args] -> [(alpha-canonicalize H) | (map alpha-canonicalize Args)]
  E -> E)

\\ --- Scoping forms ---

\\ Module: lexical, hygienic rename + alpha-canon (for hash sharing of equiv bodies).
(define module
  Vars Body ->
    (let Bare (map ensure-bare-symbol Vars)
         Canon (generate-canon-bare (length Bare))
         NormBody (alpha-canonicalize (rename-in-expr Bare Canon Body))
         (alpha-canonicalize [ [sym module] Canon NormBody ])))

\\ With: lexical let-style (single binder), hygienic + alpha for hash.
(define with
  Var Val Body ->
    (let Bare (ensure-bare-symbol Var)
         Canon (hd (generate-canon-bare 1))
         NormBody (alpha-canonicalize (rename-in-expr [Bare] [Canon] Body))
         (alpha-canonicalize [ [sym with] Canon Val NormBody ])))

\\ block-binding / block-form per sketch + design.
(datatype block-binding
  S : symbol; V : expr;
  ______________________
  (block-bind S V) : block-binding;)

(datatype block-form
  Binds : (list block-binding);
  Body : expr;
  ______________________________________
  (block Binds Body) : expr;)

\\ Basic checks: binding positions must be symbols only.
(define block-bind
  S V -> (if (symbol? S)
             [[sym block-bind] S V]
             (error "block-bind: symbol only")))

(define block-bind?
  [[sym block-bind] S _] -> (symbol? S)
  _ -> false)

(define block-bindings-ok?
  [] -> true
  [[[sym block-bind] S _] | Rest] -> (if (symbol? S) (block-bindings-ok? Rest) false)
  _ -> (error "block-binding: only symbols allowed in binding position"))

\\ Block: dynamic scope as db fork stub (even if db partial).
\\ Returns block term; fork semantics (temp assertions, discard fork, no leak) applied by core reduce later.
\\ Constructor performs basic symbol-only check now.
(define block
  Binds Body ->
    (if (block-bindings-ok? Binds)
        [[sym block] Binds Body]
        (error "block: non-symbol in binding position")))

\\ db fork stubs (partial; db.shen will provide real immutable fork later)
(define db-fork-stub
  _ -> (value *rules*))   \\ return something shape-compatible for now

(define get-current-basis-stub
  -> (value *rules*))

\\ Convenience recognizers (minimal)
(define module?
  [ [sym module] _ _ ] -> true
  _ -> false)

(define with?
  [ [sym with] _ _ _ ] -> true
  _ -> false)

(define block?
  [[sym block] _ _] -> true
  _ -> false)

(output "scope.shen (stub: Module/With/Block + hygienic gensym + alpha-for-hash tie + symbol-only block check).~%")