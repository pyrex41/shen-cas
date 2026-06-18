# ADR-001: How to implement the analysis/indexing layer (Section 5.3)

**Status:** Proposed.
**Context doc:** *Design & Implementation Plan v2*, Section 5.3 (Datalog + Prolog).
**Decision:** Do **not** host a general Datalog layer on Shen's Prolog (Option A), and do **not** build a general semi-naive Datalog engine yet (Option B). Adopt a **tiered split (Option C)**: a native dispatch index (hot path), plain non-recursive relations (cold path), and one small cycle-safe least-fixpoint combinator for the single genuinely recursive analysis — with a specified graduation path to Option B if the analysis set grows.

---

## 1. The actual workload

Section 5.3 asks the "Datalog layer" to do four things. Separated by their real computational shape and *when they run*:

| # | Task | Recursive? | Negation? | When it runs | True shape |
|---|---|---|---|---|---|
| 1 | Candidate-rule dispatch (term index) | no | no | **hot** (per subexpr, per eval step) | indexed lookup |
| 2 | Binding coverage (`covers`/`unbound`) | no | no | cold (per rule registration) | one-pass relation |
| 3 | Attribute consistency, `OneIdentity`-without-unary | no | yes (simple) | cold | negated lookup |
| 4 | Cross-rule loop detection (`f→g→f`) | **yes, over a cyclic graph** | no (now) | cold | least fixpoint |

The surprising conclusion: **only task #4 needs Datalog's defining capability** (bottom-up fixpoint that terminates on cyclic data). Tasks #1–#3 are an index and two non-recursive relations. A full Datalog engine would be built almost entirely to serve one query.

And the two tasks with the strongest constraints pull in *opposite* directions:

- #1 is **hot** and latency-critical — it cannot afford a Prolog resolution or a fixpoint round per call; it needs an O(1)-ish index with results cached per basis.
- #4 is **cold** but needs cycle-safe recursion — exactly what top-down Prolog gets wrong.

So no single engine is the right home for all four.

---

## 2. Why not Option A (host on Shen's Prolog)

Prolog's top-down SLD resolution is the wrong evaluation strategy for #4, and the wrong cost model for #1.

- **#4 loops on cyclic input.** The canonical transitive-closure clause
  `reachable(X,Z) :- edge(X,Y), reachable(Y,Z).`
  does not terminate when the `edge` graph contains a cycle — and detecting cycles is the entire point of loop detection. Making it safe requires hand-threaded visited-sets on every recursive predicate, plus `findall`/`setof` for set semantics, plus careful grounding for the negation in #3. At that point you have re-implemented the easy 80% of a Datalog engine inside Prolog, with none of its guarantees. *(Caveat to verify: if the installed Shen Prolog provides SLG/tabling, top-down recursion becomes terminating and memoized and this objection weakens. Confirm before relying on it; standard embedded Prologs, which Shen's appears to be, do not table by default.)*
- **#1 is too slow as a query.** A Prolog goal per dispatch, executed once per subexpression per evaluation step, is the hot loop. Dispatch must be a native index with a per-basis cache, not a resolution.
- **Net:** "pure Prolog" is not actually less code once correctness is paid for; it is the same work in a worse substrate.

Prolog keeps its existing, correct role — the **matching inner loop** (sequence/AC matching, sketch §7.2–7.3). That is top-down, function-symbol-laden, backtracking search: precisely Prolog's strength. This ADR does not touch that.

---

## 3. Why not Option B (general semi-naive Datalog engine) — *yet*

A proper engine (relations as tuple sets, stratification by predicate-dependency topological sort, semi-naive delta evaluation) is the *right* long-term home if the analysis set grows — confluence analysis, definedness/totality analysis, user-supplied analyses, richer global properties. It also pairs beautifully with the accumulate-only datom log: each assertion is a delta, and semi-naive evaluation consumes deltas incrementally, with derived relations cached per basis.

But for the *current* four tasks it is premature: ~300–400 lines plus a real correctness burden (stratification and fixpoint bugs) to serve one recursive query. YAGNI. Build the small thing now; keep the upgrade non-destructive (Section 6).

---

## 4. Decision: Option C (tiered), with concrete specs

### 4.1 Hot path — `dispatch-index` (native index, no engine)

A first-argument-indexed table from `(head-symbol, top-shape-key)` to the ordered list of candidate `checked-rule` hashes, where `top-shape-key` is a cheap discriminator of a term's top level (head of arg 0, arity bucket, presence of sequence patterns). This is a one-level **discrimination tree**; deepen later if profiling demands.

```
\\ built/extended at rule registration; queried in the eval loop.
(declare dispatch-candidates [db --> (expr --> (list rule-hash))])

\\ key derivation is pure and cheap; results cached by (basis-hash, key).
(declare shape-key [expr --> shape])
```

- **Basis-keyed cache.** Lookups memoize on `(basis-hash, head, shape)`. A new assertion yields a new basis → stale entries are simply never hit (consistent with the Evaluation-Core contract, v2 §4 clause 2). No invalidation bookkeeping.
- **Soundness obligation:** the index may over-approximate (return a superset of truly-matching rules — the matcher is still the authority) but must **never under-approximate**. Tested in §5.
- Not Datalog, not Prolog. Just an index. This is the highest-leverage performance item in the whole analysis layer because it runs in the hot loop.

### 4.2 Cold path, non-recursive — analysis relations (plain Shen)

Tasks #2 and #3 are pure functions over the db, surfaced as relations for uniformity and testability:

```
(declare covers?        [db --> (rule-hash --> boolean)])      \\ reuses bindings-cover?
(declare unbound-vars   [db --> (rule-hash --> (list symbol))])
(declare attr-conflicts [db --> (symbol --> (list conflict))]) \\ reuses consistent?
(declare oneid-no-unary [db --> (list symbol)])                \\ negated lookup
```

`oneid-no-unary` is the only negation here and it is *non-recursive*: "has `OneIdentity`" ∧ ¬"has a unary rule". Evaluate as a plain set difference — no stratification machinery needed.

### 4.3 Cold path, recursive — the one piece with teeth: `lfp`

A minimal **cycle-safe least-fixpoint** combinator. Set semantics gives termination over the finite domain of head symbols; this is exactly what top-down Prolog cannot do safely.

```
\\ Iterate an immediate-consequence operator to a fixed point.
\\ Terminates because facts are a set over a finite domain (dedup + monotone growth).
(declare lfp [(set fact) --> ((set fact) --> (set fact)) --> (set fact)])

(define lfp
  Facts Step -> (let New (set-union Facts (Step Facts))
                   (if (set-subset? New Facts) Facts (lfp New Step))))
```

Loop detection (task #4) expressed with it:

```
\\ direct-deps: edge H1 -> H2 when some rule headed H1 has an RHS that can trigger
\\ a rule headed H2 (RHS mentions H2, or a symbol whose rules mention H2 ... at depth 1).
(declare direct-deps [db --> (set edge)])

\\ one immediate-consequence step = relational join of the closure with the edge set.
(define reach-step
  Edges Reach -> (set-union Reach (join Reach Edges)))   \\ [A B]∘[B C] => [A C]

(define rule-dependency-loops
  Db -> (let Edges (direct-deps Db)
             Reach (lfp Edges (/. R (reach-step Edges R)))
             (filter self-edge? Reach)))                 \\ [H H] => H is in a cycle
```

`rule-dependency-loops` catches the cross-rule `f→g→f` cycle the sketch concedes its single-rule heuristic misses (v2 §5.3, sketch §10.2), and it terminates *because* the graph is cyclic-data-safe — the property Prolog lacks here.

**Size:** `lfp` + `join` + `direct-deps` + the loop query is ~80–120 lines including tests. That is the entire "Datalog" cost for the MVP.

### 4.4 Where each lands in the module map (v2 §6)

- `dispatch-index` → fold into `query.shen` (or split a `dispatch.shen`); it is hot and deserves its own tests.
- analysis relations + `lfp` + loop detection → `query.shen`; warnings surfaced via `warn.shen`.
- No change to `match*.shen` (Prolog matching) or the Evaluation Core.

---

## 5. Test obligations

- **Dispatch soundness:** for random `(rule-set, term)` pairs, `dispatch-candidates` ⊇ {rules that actually match per the reference matcher}. Never a miss. (Over-approximation allowed.)
- **Dispatch cache coherence:** after an assertion (new basis), candidates reflect the new rule; old-basis lookups unaffected.
- **`lfp` termination & correctness:** on hand-built cyclic and acyclic graphs, `reach-step` fixpoint equals brute-force transitive closure; terminates on cycles.
- **Loop detection:** `f→g→f`, `f→f`, and a deep acyclic chain classified correctly vs a brute-force reference.
- **Negation:** `oneid-no-unary` matches a brute-force set difference.

These plug into the Phase-3 acceptance set (v2 Appendix B).

---

## 6. Graduation path to Option B (non-destructive)

If/when analyses multiply or any analysis needs **recursive negation** (e.g. "symbol is fully defined" via recursion through "has an undefined dependency"), upgrade `lfp` into a stratified semi-naive engine *without touching call sites*:

1. **Relations already are tuple sets** keyed in the content store — the engine's native representation. No data migration.
2. **Replace `lfp` internals** with semi-naive delta evaluation: track newly-derived facts each round and join only the delta against the rules. Same signature; cold-path call sites unchanged.
3. **Add stratification** as a topological sort over the predicate-dependency graph, evaluating lower strata to fixpoint before negations against them. Only needed when the first recursive-negated analysis appears.
4. **Incremental maintenance** comes nearly free from the Datomic-style log: an assertion is a delta; feed it to semi-naive evaluation to update derived relations, cache per basis. (This is the payoff that made the accumulate-only DB worth it.)

The point of the tiered design is that this upgrade is an *internal* change to one combinator plus an added stratifier — not a rewrite of the analyses or the dispatch path.

---

## 7. Consequences

**Positive:** smallest correct implementation now (~80–120 lines of "Datalog" + a native index); the hot dispatch path is an index, not a query engine; the one cyclic-recursive analysis is correct by construction; Prolog keeps its strong, unchanged role in matching; clean, signature-preserving upgrade to a full engine later; everything stays basis-keyed and cache-coherent with the substrate.

**Negative / watch:** `lfp` is naive (recomputes `Step` over all facts each round) — fine cold-path at MVP rule counts, but profile it; if loop analysis becomes hot or rule counts large, that is the trigger to graduate (Section 6). The dispatch index's `shape-key` discriminator must be kept in sync with what the matcher considers structurally relevant, or it silently over-returns (slow) — never under-returns (unsound), which the §5 test guards.

**Open item to verify before build:** whether the installed Shen Prolog provides tabling. It does not change this decision (dispatch and #4 still want the tiered design), but it affects how much hand-rolling any *future* Prolog-side recursion would cost.
