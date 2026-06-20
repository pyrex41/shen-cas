\\ db.shen - immutable datom db stub (SCUD 10.1, design §5.2)
\\ Skeleton: represent db as a simple list of datoms + basis hash computed over them.
\\ Pure functions returning new db.
\\ datoms, immutable basis value + basis hash, pure assert-rule/assert-attribute,
\\ symbol-entry-view, fork primitive.
\\ No full indexing, no wiring to core/normal-form yet.
\\ Datoms: [sym kind rule-rep tx] or [sym attr tx]

(define empty-db -> [])

(define db-datoms
  Db -> Db)

(define filter
  _ [] -> []
  F [X | Xs] -> (if (F X) [X | (filter F Xs)] (filter F Xs)))

(define basis-token
  [] -> "[]"
  [X | Xs] -> (cn "[" (cn (basis-token X) (cn "|" (cn (basis-token Xs) "]"))))
  X -> (str X) where (symbol? X)
  X -> (str X) where (number? X)
  X -> (str X))

(define compute-basis
  Ds -> (cn "basis:" (str (cas-str-hash (basis-token Ds)))))  \\ content-derived skeleton basis id (pure-Shen hash)

(define db-basis
  Db -> (compute-basis (db-datoms Db)))

(define basis-hash-eq?
  A B -> (= A B))

\\ rule rep in skeleton
(define make-rule-datum L R -> [rule L R])
(define make-rule-stub L R -> [rule L R])  \\ alias for compatibility
\\ 16b: the always-true checked-rule? was deleted; the strict [rule Lhs Rhs] version
\\ in rule.shen is the single source of truth (rule.shen loads after db.shen).

(define assert-rule
  Db Sym Kind R -> (append (db-datoms Db) [[Sym Kind R (length (db-datoms Db))]]))

(define assert-attribute
  Db Sym Attr -> (append (db-datoms Db) [[Sym Attr (length (db-datoms Db))]]))

(define rule-datom?
  D -> (and (cons? D) (= (length D) 4) (element? (hd (tl D)) [own down up])))

(define attr-datom?
  D -> (and (cons? D) (= (length D) 3)))

(define symbol-entry-view
  Db Sym ->
    (let Ds (db-datoms Db)
         Rs (filter (/. D (and (= (hd D) Sym) (rule-datom? D))) Ds)
         As (filter (/. D (and (= (hd D) Sym) (attr-datom? D))) Ds)
         Own (map (/. D (hd (tl (tl D)))) (filter (/. D (= (hd (tl D)) own)) Rs))
         Down (map (/. D (hd (tl (tl D)))) (filter (/. D (= (hd (tl D)) down)) Rs))
         Up (map (/. D (hd (tl (tl D)))) (filter (/. D (= (hd (tl D)) up)) Rs))
         Attrs (map (/. D (hd (tl D))) As)
         [Sym Own Down Up Attrs]))

(define db-fork
  Db -> (db-datoms Db))   \\ same list snapshot (immutable)

(define db-fork-with
  Db Extra -> (append (db-datoms Db) Extra))

\\ fork primitive is provided as db-fork / db-fork-with (fork name collides with Shen builtin)

(define db-size
  Db -> (length (db-datoms Db)))

(define db-rule-count
  Db -> (length (filter (/. D (rule-datom? D)) (db-datoms Db))))

\\ --- 16f: control-attribute accessors ---
\\ Control attrs (hold-all/hold-first/hold-rest/listable) are stored as attr datoms
\\ via assert-attribute and surfaced in the Attrs slot of symbol-entry-view.
\\ (Structural attrs stay in the content-hash sig per invariant 1; only control attrs
\\  reach the db per invariant 3.)

\\ Attrs slot is element index 4 of [Sym Own Down Up Attrs].
(define head-attrs
  Db Sym -> (hd (tl (tl (tl (tl (symbol-entry-view Db Sym)))))))

(define attr-present?
  Db Sym Attr -> (element? Attr (head-attrs Db Sym)))

(define holds-all?
  Db Sym -> (attr-present? Db Sym (intern "hold-all")))

(define holds-first?
  Db Sym -> (attr-present? Db Sym (intern "hold-first")))

(define holds-rest?
  Db Sym -> (attr-present? Db Sym (intern "hold-rest")))

(define listable?
  Db Sym -> (attr-present? Db Sym (intern "listable")))
