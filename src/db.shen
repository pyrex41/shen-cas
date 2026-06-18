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

(define compute-basis
  Ds -> (cn "basis:" (str (length Ds))))

(define db-basis
  Db -> (compute-basis (db-datoms Db)))

(define basis-hash-eq?
  A B -> (= A B))

\\ rule rep in skeleton
(define make-rule-stub L R -> [rule L R])
(define checked-rule? _ -> true)

(define assert-rule
  Db Sym Kind R -> (append (db-datoms Db) [[Sym Kind R (length (db-datoms Db))]]))

(define assert-attribute
  Db Sym Attr -> (append (db-datoms Db) [[Sym Attr (length (db-datoms Db))]]))

(define symbol-entry-view
  Db Sym ->
    (let Ds (db-datoms Db)
         Rs (filter (/. D (and (cons? D) (= (hd D) Sym) (element? (hd (tl D)) [own down up]))) Ds)
         As (filter (/. D (and (cons? D) (= (hd D) Sym))) Ds)
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
  Db -> (length (filter (/. D (and (cons? D) (element? (hd (tl D)) [own down up]))) (db-datoms Db))))
