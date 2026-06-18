\\ query.shen - dispatch index + cold analysis relations + lfp loop detection (SCUD 11.3)
\\ Per ADR-001 (prologue+datalogue_decision.md) and plan.md Phase 4 / task 11.3
\\ - native dispatch index (stub for 11.1)
\\ - plain analysis relations (stub for 11.2)
\\ - finite-set lfp + reach + rule-dependency-loops for cross-rule loops (this task)
\\
\\ All helpers plain Shen (no Prolog). Pure, cycle-safe via set lfp over finite heads.
\\ direct-deps / db integration stubbed here; full when db.shen + symbol-entry-view ready.
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

\\ --- direct-deps from RHS symbols (full version when db ready) ---
\\ Stub: returns no edges today. Later:
\\   for each rule in db for head H, walk RHS exprs, collect head symbols mentioned,
\\   emit [H MentionedHead] for each (depth-1 direct).
\\ (See design: "RHS mentions H2")
\\ (declare direct-deps [A --> (list (list B))])  ; optional typing; omitted (list undefined at load in skeleton)

(define direct-deps
  _ -> [])   \\ TODO: integrate with db.shen when symbol-entry-view / rules available

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
             (heads-in-cycles (my-filter (fn self-edge?) Reach))))

\\ --- pure testable entrypoint for SCUD 11.3 verification (no db needed) ---
\\ Accepts a list of edges e.g. [[f g] [g f]] or [[f f]] or [[f g] [g h]]
\\ Returns list of heads that participate in (any) cycle.
(define rule-dependency-loops-from-edges
  Edges -> (let Norm (dedup Edges)
              Reach (lfp Norm (/. R (reach-step Norm R)))
              (heads-in-cycles (my-filter (fn self-edge?) Reach))))

\\ --- simple reachability via lfp for tests (transitive closure) ---
(define reachable-from-edges
  Edges -> (let Norm (dedup Edges)
              (lfp Norm (/. R (reach-step Norm R)))))

\\ --- basic dispatch/analysis stubs (for 11.1/11.2 placeholders; expanded later) ---
(define shape-key _ -> [])   \\ stub (unit may not be bound)

(define dispatch-candidates _ -> (/. _ []))

(define covers? _ -> (/. _ true))

(define unbound-vars _ -> (/. _ []))

(define attr-conflicts _ -> (/. _ []))

(define oneid-no-unary _ -> [])

\\ (princ ...) omitted: I/O names can be environment-sensitive under -e/-l in this Shen; messages emitted by load harness elsewhere.