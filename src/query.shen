\\ query.shen - dispatch index + cold analysis relations + lfp loop detection (SCUD 11.3)
\\ Per ADR-001 (prologue+datalogue_decision.md) and plan.md Phase 4 / task 11.3
\\ - native dispatch index (stub for 11.1)
\\ - plain analysis relations (stub for 11.2)
\\ - finite-set lfp + reach + rule-dependency-loops for cross-rule loops (this task)
\\
\\ All helpers plain Shen (no Prolog). Pure, cycle-safe via set lfp over finite heads.
\\ direct-deps now scans real db rule datoms (RHS mentioned heads); full integration per 11.3.
\\ Testable on small edge graphs via helpers below.
\\
\\ Usage for loops (once integrated):
\\   (rule-dependency-loops SomeDb)  => list of symbols in cycles e.g. [f g]
\\
\\ For now / tests:
\\   (rule-dependency-loops-from-edges [[f g] [g f]]) => [f g] or equiv (self-edges after closure)
\\
\\ Keep this file loadable before full db (no hard (load "src/db.shen") yet).

\\ --- finite set helpers (lists as sets; deduped, order irrelevant) ---
\\ Self-contained: provide own filter/map/mapcan (Shen env primitives vary under direct -e/-l)
(define my-filter
  _ [] -> []
  P [X | Y] -> (if (P X) [X | (my-filter P Y)] (my-filter P Y)))

(define my-map
  _ [] -> []
  F [X | Y] -> [(F X) | (my-map F Y)])

(define my-mapcan
  _ [] -> []
  F [X | Y] -> (append (F X) (my-mapcan F Y)))

(define set-member?
  _ [] -> false
  X [X | _] -> true
  X [_ | R] -> (set-member? X R))

(define set-adjoin
  X S -> (if (set-member? X S) S [X | S]))

(define dedup
  [] -> []
  [X | Xs] -> (set-adjoin X (dedup Xs)))

(define set-union
  [] S2 -> S2
  [X | R] S2 -> (set-union R (set-adjoin X S2)))

(define set-subset?
  [] _ -> true
  [X | R] S -> (and (set-member? X S) (set-subset? R S)))

\\ --- relational join for transitive step: [A B] o [B C] => [A C] ---
(define join
  Reach Edges ->
    (dedup (my-mapcan (/. AB (compose-step AB Edges)) Reach)))

(define compose-step
  [A B] Edges ->
    (let Matches (my-filter (/. E (and (cons? E) (= (head E) B))) Edges)
      (my-map (/. E [A (head (tail E))]) Matches))
  _ _ -> [])

\\ --- least fixpoint combinator (cycle-safe on finite set) ---
\\ (declare lfp [(list A) --> ((list A) --> (list A)) --> (list A)])  ; optional; removed for load in current skeleton (see notes)

(define lfp
  Facts Step ->
    (let New (set-union Facts (Step Facts))
      (if (set-subset? New Facts)
          Facts
          (lfp New Step))))

\\ --- reachability step over edge set ---
(define reach-step
  Edges Reach -> (set-union Reach (join Reach Edges)))

\\ --- helpers for loop results ---
(define self-edge?
  [H H] -> true
  _ -> false)

(define heads-in-cycles
  SelfEdges -> (dedup (my-map (/. E (head E)) SelfEdges)))

\\ --- direct-deps from RHS symbols (full version for db) ---
\\ For each rule datom, extract the rule rep, walk its RHS expr to collect mentioned head symbols,
\\ emit [H MentionedHead] edges (depth-1 direct deps).
\\ Robust to current skeleton rep ( [sym S], bare, lists ) and future real exprs.
\\ (See design: "RHS mentions H2")

(define rule-datom?
  D -> (and (cons? D) (= (length D) 4) (element? (hd (tl D)) [own down up])))

(define rhs-of-rep
  [rule _ R] -> R
  R -> R)

(define head-symbol-from-expr
  [sym S] -> [S]
  S -> [S] where (symbol? S)
  [H | Args] -> (append (head-symbol-from-expr H) (my-mapcan (/. X (head-symbol-from-expr X)) Args))
  _ -> [])

(define collect-mentioned-heads
  E -> (dedup (head-symbol-from-expr E)))

(define deps-from-rule-datom
  D -> (let Rep (hd (tl (tl D)))
            H (hd D)
            Rhs (rhs-of-rep Rep)
            Ms (collect-mentioned-heads Rhs)
            (my-map (/. M [H M]) Ms)))

(define direct-deps
  Db -> (let Ds (db-datoms Db)
             (dedup (my-mapcan (/. D (if (rule-datom? D) (deps-from-rule-datom D) [])) Ds))))

\\ Pure helper for direct deps given pairs of (Head . [RhsSym ...])
\\ Useful for tests and future impl of direct-deps.
(define direct-deps-from-pairs
  Pairs -> (dedup (my-mapcan (/. P (let H (head P)
                                     Rhss (head (tail P))
                                  (my-map (/. R [H R]) (dedup Rhss))))
                          Pairs)))

\\ --- main loop detector (per ADR spec) ---
\\ (declare rule-dependency-loops [A --> (list B)])

(define rule-dependency-loops
  Db -> (let Edges (direct-deps Db)
             Reach (lfp Edges (/. R (reach-step Edges R)))
             (heads-in-cycles (my-filter (/. E (self-edge? E)) Reach))))

\\ --- pure testable entrypoint for SCUD 11.3 verification (no db needed) ---
\\ Accepts a list of edges e.g. [[f g] [g f]] or [[f f]] or [[f g] [g h]]
\\ Returns list of heads that participate in (any) cycle.
(define rule-dependency-loops-from-edges
  Edges -> (let Norm (dedup Edges)
              Reach (lfp Norm (/. R (reach-step Norm R)))
              (heads-in-cycles (my-filter (/. E (self-edge? E)) Reach))))

\\ --- simple reachability via lfp for tests (transitive closure) ---
(define reachable-from-edges
  Edges -> (let Norm (dedup Edges)
              (lfp Norm (/. R (reach-step Norm R)))))

\\ --- native basis-keyed dispatch index (SCUD 11.1) ---
(set *dispatch-cache* [])

(define dispatch-cache-key
  B Hs Sh -> [B Hs Sh])

(define dispatch-lookup
  K -> (assoc K (value *dispatch-cache*)))

(define dispatch-cache-hit?
  Hit -> (if (cons? Hit) (not (empty? Hit)) false))

(define dispatch-store!
  K V -> (set *dispatch-cache* (adjoin [K V] (value *dispatch-cache*))))

(define expr-head-symbol
  [[sym S] | Rest] -> [sym S]
  E -> (if (cons? E) (hd E) E))

(define shape-key
  E -> (let Hs (expr-head-symbol E)
            n (if (and (cons? E) (cons? (tl E))) (length (tl E)) 0)
         [Hs n]))

(define compute-cands-for-head
  Db Hs ->
    (if (not (cons? Hs))
        []
        (let V (symbol-entry-view Db Hs)
             Own (hd (tl V))
             Down (hd (tl (tl V)))
             Up (hd (tl (tl (tl V))))
             (append Own (append Down Up)))))

(define dispatch-candidates
  Db E ->
    (let B (db-basis Db)
         Hs (expr-head-symbol E)
         Sh (shape-key E)
         K (dispatch-cache-key B Hs Sh)
         Hit (dispatch-lookup K)
         (if (dispatch-cache-hit? Hit)
             (hd (tl Hit))
             (let Cands (compute-cands-for-head Db Hs)
                  (do (dispatch-store! K Cands)
                      Cands)))))

\\ --- 11.2 cold analysis relations (plain Shen over db values) ---
\\ Per SCUD 11.2, ADR-001, plan Phase 4: plain non-recursive relations (no Prolog).
\\ Use db-datoms + symbol-entry-view + direct-deps style where helpful.
\\ All use my- set helpers for self-contained purity. Runtime fns from rule/attrs/pattern/store
\\ (loaded by call time) are used for extract/free/consistent/sig.
\\ covers? reuses spirit of bindings-cover? (head/arity shape check here for patterns).
\\ oneid-no-unary is analysis result (set diff) NOT type rejection.

(define attr-datom?
  D -> (and (cons? D) (= (length D) 3)))

(define all-heads
  Db -> (dedup (my-map (/. D (hd D)) (my-filter (/. D (rule-datom? D)) (db-datoms Db)))))

(define set-difference
  A B -> (my-filter (/. X (not (set-member? X B))) A))

(define head-symbol
  [[sym S] | _] -> S
  [sym S] -> S
  [H | _] -> (head-symbol H)
  S -> S where (symbol? S)
  _ -> false)

\\ simplistic covers: head match + arity1 >= arity2 (over-approx shape)
(define covers-patterns?
  P1 P2 -> (and (cons? P1) (cons? P2)
                (equal? (head-symbol P1) (head-symbol P2))
                (>= (length (tl P1)) (length (tl P2)))))

\\ covers? : Db -> (P1 -> (P2 -> bool))   ; per stubs/ADR flavor
(define covers?
  _ -> (/. P1 (/. P2 (covers-patterns? P1 P2))))

(define my-some
  _ [] -> false
  P [X | Y] -> (or (P X) (my-some P Y)))

(define unbound-vars
  Db -> (let Rs (all-rule-reps Db)
             (my-mapcan (/. R (let B (extract-bindings (rule-lhs R))
                              F (free-symbols (rule-rhs R))
                              U (my-filter (/. V (not (or (element? V B)
                                                         (known-symbol? V))))
                                           F)
                           (if (empty? U) [] [[R U]])))
                    Rs)))

(define all-rule-reps
  Db -> (my-mapcan (/. D (if (rule-datom? D) [(hd (tl (tl D)))] [])) (db-datoms Db)))

(define symbol-attrs
  Db S -> (let V (symbol-entry-view Db S)
               (if (cons? V) (hd (tl (tl (tl (tl V))))) [])))

(define attr-conflicts
  Db -> (let Heads (all-heads Db)
             AttrHeads (my-map (/. D (hd D)) (my-filter (/. D (attr-datom? D)) (db-datoms Db)))
             Syms (dedup (append Heads AttrHeads))
             (my-filter (/. S (not (consistent-attrs? (symbol-attrs Db S))))
                       Syms)))

\\ oneid via structural sig (declared) OR db attr list
(define has-one-identity?
  Db S -> (or (structural-sig-contains-name? S "one-identity")
              (element? (intern "one-identity") (symbol-attrs Db S))))

(define has-unary-rule?
  Db S -> (let V (symbol-entry-view Db S)
               Rs (if (cons? V)
                      (let Own (hd (tl V))
                           Down (hd (tl (tl V)))
                           UpL (if (cons? (tl (tl (tl V)))) (hd (tl (tl (tl V)))) [])
                           (append Own (append Down UpL)))
                      [])
               (my-some (/. R (unary-rule-lhs? (rule-lhs R))) Rs)))

(define unary-rule-lhs?
  L -> (and (cons? L) (= (length (tl L)) 1)))

(define oneid-no-unary
  Db -> (let Heads (all-heads Db)
             AttrHeads (my-map (/. D (hd D)) (my-filter (/. D (attr-datom? D)) (db-datoms Db)))
             Syms (dedup (append Heads AttrHeads))
             (my-filter (/. S (and (has-one-identity? Db S)
                                   (not (has-unary-rule? Db S))))
                       Syms)))

\\ brute set-difference version for invariant: must match on simple cases
(define oneid-no-unary-brute
  Db -> (let oneids (my-filter (/. S (has-one-identity? Db S)) (all-heads Db))
             unaries (my-filter (/. S (has-unary-rule? Db S)) oneids)
             (set-difference oneids unaries)))

