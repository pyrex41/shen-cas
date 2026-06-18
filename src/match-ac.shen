\\ match-ac.shen - Orderless + Flat (AC) matching (SCUD 17d)
\\ Per sketch §7.3-7.4, plan Wave 1.
\\ 16e: match (and match-seq) are loaded by load.shen before match-ac; no redundant load.
\\
\\ 17d fixes:
\\  - flatten-flat detects NESTED same-head compounds via headed-by-sym? (mirror
\\    store's flatten-args-for-hash), not bare sym?.
\\  - Orderless matching fires REGARDLESS of seq-var count (permutation search even
\\    with no seq var), bounded by *ac-max-args* and a Flat+Orderless+>1-seq-var warning.

(set *ac-max-args* 8)

(define ac-known-heads
  -> [[sym (protect Plus)] [sym (protect Times)] (protect Plus) (protect Times)])

(define is-ac-head?
  H -> (element? H (ac-known-heads)) where (cons? H)
  H -> (element? H (ac-known-heads)))

(define ac-head-has-orderless?
  H -> (or (is-ac-head? H)
           (if (sym? H) (has-orderless? (sym-name H)) false)))

(define ac-head-has-flat?
  H -> (or (is-ac-head? H)
           (if (sym? H) (has-flat? (sym-name H)) false)))

(define count-seq-vars
  [] -> 0
  [[blank-seq] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[blank-null-seq] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[named Name [blank-seq]] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[named Name [blank-null-seq]] | Rest] -> (+ 1 (count-seq-vars Rest))
  [X | Rest] -> (count-seq-vars Rest))

(define ac-blowup-warning
  Head PArgs ->
    (if (and (ac-head-has-flat? Head) (ac-head-has-orderless? Head)
             (> (count-seq-vars PArgs) 1))
        (do (output "WARNING: AC blowup risk for ~A (Flat+Orderless + >1 seq var)~%" Head)
            true)
        true))

\\ Flat flatten: inline any argument that is itself headed by the SAME symbol as Head.
\\ Uses headed-by-sym? (store mirror) so nested compounds are detected, not just bare syms.
(define flatten-flat
  Head [] -> []
  Head [A | Rest] ->
    (if (and (sym? Head) (headed-by-sym? (sym-name Head) A))
        (append (flatten-flat Head (tl A))
                (flatten-flat Head Rest))
        (cons A (flatten-flat Head Rest))))

(define flatten-flat-args
  Head EArgs ->
    (if (ac-head-has-flat? Head)
        (flatten-flat Head EArgs)
        EArgs))

\\ Pure-Shen permutation generation + search. We must NOT use the Prolog engine
\\ here: match (via match-ac match-compound) and match-arg-list (via match-seq) can
\\ themselves re-enter prolog?, and nesting prolog? inside a prolog? (is ...) goal
\\ overflows the engine's binding-trail vector. Plain Shen keeps each match call
\\ self-contained.

\\ all permutations of a list (bounded externally by *ac-max-args*)
(define ac-permutations
  [] -> [[]]
  L -> (ac-perm-insert-each L))

(define ac-perm-insert-each
  L -> (ac-perm-loop L L))

\\ For each element X of Picks, prepend X to every permutation of (L without X).
(define ac-perm-loop
  [] _ -> []
  [X | Rest] L -> (append (ac-prepend-all X (ac-permutations (ac-remove-first X L)))
                          (ac-perm-loop Rest L)))

(define ac-prepend-all
  _ [] -> []
  X [P | Ps] -> (cons (cons X P) (ac-prepend-all X Ps)))

(define ac-remove-first
  _ [] -> []
  X [Y | Ys] -> (if (= X Y) Ys (cons Y (ac-remove-first X Ys))))

\\ Orderless matching: try every permutation of EArgs against PArgs (seq-aware via
\\ match-arg-list from match-seq). Bounded by *ac-max-args*; first matching
\\ permutation wins. Fires regardless of seq-var count.
(define match-orderless
  Head PArgs EArgs ->
    (if (> (length EArgs) (value *ac-max-args*))
        (do (output "WARNING: AC permutation search skipped for ~A (>~A args)~%" Head (value *ac-max-args*))
            (match-arg-list PArgs EArgs))
        (match-orderless-perms PArgs (ac-permutations EArgs))))

(define match-orderless-perms
  _ [] -> match-none
  PArgs [Perm | Rest] ->
    (let M (match-arg-list PArgs Perm)
         (if (match-some? M) M (match-orderless-perms PArgs Rest))))

(define match-compound
  PH PArgs EH EArgs ->
    (let HeadMatch (match PH EH)
         (if (match-some? HeadMatch)
             (let FlatEArgs (if (cons? EH) (flatten-flat-args EH EArgs) EArgs)
                  Ign (if (cons? EH) (ac-blowup-warning EH PArgs) true)
                  ArgMatch (if (and (cons? EH) (ac-head-has-orderless? EH))
                               (match-orderless EH PArgs FlatEArgs)
                               (match-arg-list PArgs FlatEArgs))
                  (if (match-some? ArgMatch)
                      (match-some (append (match-unwrap HeadMatch) (match-unwrap ArgMatch)))
                      match-none))
             match-none)))

(output "match-ac.shen loaded (orderless perm any-seq-count + flat nested flatten + blowup warning).~%")
