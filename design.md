# Design & Implementation Plan v2: A Statically Checked Term Rewriting Kernel in Shen

**Status:** Implementation-ready design. Supersedes v1. Derived from the design sketch *"Toward a Statically Checked Term Rewriting Kernel in Shen,"* extended with a content-addressed term store, a Datomic-style immutable rule database, and a Datalog/Prolog analysis split.
**Audience:** an implementer (human or coding agent) who has read the sketch.
**How to use:** Sections 1–7 are the build spec. Section 5 is the substrate (the main v2 addition). Section 9 answers the performance/HVM question. Appendix A is a liftable agent prompt; Appendix B is the per-phase acceptance checklist.

---

## 0. What this document adds to the sketch

The sketch establishes *what* to build and *why Shen*. v2 adds four things an implementer needs:

1. **A backend seam** (Section 4) — a narrow `reduce`/`match`/`substitute`/`normal-form` interface separating *what the system means* (Shen-checked rules + reference evaluator) from *how a reduction executes*. HVM, if it enters, enters here as one backend, never as the host.
2. **A content-addressed, immutable substrate** (Section 5) — the sketch's mutable `*symbol-table*` becomes an accumulate-only fact database of datoms over content-hashed terms, with a Datalog layer for indexing and cross-rule analysis. This is what makes evaluation memoization, clean backend-cache invalidation, reproducibility, and `Block`/session semantics fall out instead of being bolted on.
3. **A concrete module/file layout and dependency order** (Sections 6–7).
4. **A verification strategy** turning the sketch's informal invariants into executable tests (Section 8).

The sketch's `datatype`/typing rules are authoritative for the data model. This doc operationalizes them.

> The sketch cites *The Book of Shen, 3rd edition*; the current edition is the 4th (Tarver, 2025). Re-verify all sequent-calculus `datatype` syntax against the 4th edition before Phase 1.

---

## 1. Scope and non-goals

**In scope (the kernel):** homoiconic `expr`; statically checked `pattern`/`seq-pattern`; `checked-rule` with definition-time binding coverage; `valid-attrs` with definition-time consistency; a matcher (`Blank`, `BlankSequence`, `BlankNullSequence`, named, `Condition`, `PatternTest`, `Alternatives`, `Orderless`, `Flat`); a fixed-point evaluator mirroring the standard evaluation sequence; `Module`/`Block`/`With`; a bootstrap rule library; heuristic static warnings.

**Added to scope in v2 (the substrate):** content-addressed term store (Merkle hashing + interning); immutable, accumulate-only rule database with versioned basis; Datalog index/analysis layer; content+basis-keyed evaluation memoization.

**Non-goals (MVP):** a numerics tower beyond Shen's; confluence/termination *guarantees* (heuristics + tests only); a notebook UI (Phase 5 ships a minimal reader only); any *performance backend* beyond the in-model substrate (HVM etc. are post-MVP, Section 9).

Guiding principle: **the pure-Shen reference evaluator is the specification.** Every backend is correct iff observationally equivalent to it on the supported fragment.

---

## 2. Architecture overview

```
            ┌────────────────────────────────────────────────────────┐
            │              Surface Reader (Phase 5)                   │  f[x_,y_]:=x+y → S-expr
            └───────────────────────────┬────────────────────────────┘
            ┌───────────────────────────▼────────────────────────────┐
            │         Definition-time Static Checking (Shen)          │  expr · pattern/seq ·
            │   sequent-calculus datatypes; nothing ill-formed passes │  checked-rule · valid-attrs
            └───────────────────────────┬────────────────────────────┘
                                        │ assert (accumulate-only)
            ┌───────────────────────────▼────────────────────────────┐
            │   SUBSTRATE  (Section 5)                                │
            │   ┌──────────────────────────────────────────────┐     │
            │   │ Immutable rule DB (Datomic-style)             │     │  db value ↔ basis-hash
            │   │  datoms: [sym kind rule-hash tx] / [sym attr] │     │
            │   └───────────────┬──────────────────────────────┘     │
            │   ┌───────────────▼──────────────────────────────┐     │
            │   │ Datalog index + analysis (bottom-up)          │     │  dispatch candidates,
            │   │  candidate-rule queries; cross-rule warnings  │     │  coverage, loop detection
            │   └───────────────┬──────────────────────────────┘     │
            │   ┌───────────────▼──────────────────────────────┐     │
            │   │ Content-addressed term store (Merkle + intern)│     │  hash→node; O(1) eq;
            │   └──────────────────────────────────────────────┘     │  memo: (term,basis)→nf
            └───────────────────────────┬────────────────────────────┘
            ┌───────────────────────────▼────────────────────────────┐
            │   EVALUATION CORE (the seam)  (Section 4)               │  reduce · match ·
            │   reads a db value; Prolog drives sequence/AC matching  │  substitute · normal-form
            └───────────┬────────────────────────────┬───────────────┘
        ┌───────────────▼─────────┐      ┌────────────▼────────────────────┐
        │ Reference backend       │      │ Optional perf backends (Sec 9)   │
        │ pure Shen + Prolog = SPEC│     │ HVM fragment offload · compiled  │
        └─────────────────────────┘      │ dispatch · all keyed by basis    │
                                         └──────────────────────────────────┘
```

Three load-bearing invariants:

- **Nothing ill-formed reaches the database.** Static checking is a gate, not a skippable pass.
- **The database is an immutable value.** Assertions produce a *new* db identified by a *basis hash*; nothing mutates in place. (This replaces the sketch's `set`/`value` assoc list.)
- **The Evaluation Core is the only replaceable layer.** Backends never see un-checked rules and never redefine semantics; they execute reductions the reference evaluator would also accept, keyed by the current basis.

---

## 3. Core data model (the build contract)

Use the sketch's `datatype` definitions verbatim. Implementation notes:

| Type | Source | Note |
|---|---|---|
| `expr` | sketch §2 | Tagged lists, **content-addressed** (Section 5.1) — every node carries/derives a Merkle hash; construction interns into the content store. |
| `pattern`/`seq-pattern` | sketch §3 | The `pattern` vs `seq-pattern` split is the load-bearing invariant; keep `pat-or-seq` only inside compound arg lists. Patterns are content-addressed too (so rules get stable hashes). |
| `checked-rule` | sketch §4 | `bindings-cover` runs as a definition-time side condition; `extract-bindings`/`free-symbols`/`bindings-cover?` are reused by the Datalog coverage relation. |
| `valid-attrs` | sketch §5 | `consistent?` is the extensible point. **v2 constraint:** the *structural* attributes `Orderless`/`Flat`/`OneIdentity` are part of a symbol's immutable signature (Section 5.1, canonicalization) — they may be set at symbol creation but not flipped at runtime; doing so requires a cache flush. The *evaluation-control* attributes (`HoldAll`, `Listable`, …) remain freely mutable facts. |
| `symbol-entry` | sketch §6 | Becomes a *view* computed from the db, not a stored mutable record (Section 5.2). |
| scoping forms | sketch §9 | `block-binding`/`block-form` enforce symbol-only binding positions at type-check time. `Block` is reimplemented as a db fork (Section 5.2), not save/restore. |

**Lock at Phase 1:** integer representation. Centralize numeric ops behind a `num` module. The int/bignum choice leaks into arithmetic rules, into content-hash stability, and into any future HVM backend (HVM is fixed-width — Section 9.4).

---

## 4. The Evaluation Core interface (the seam)

```
\\ reduce: full standard evaluation sequence to a fixed point, against a db value.
\\ MUST be idempotent on output; MUST read attrs/rules from the supplied db.
(declare reduce        [db --> (expr --> expr)])

\\ normal-form: memoized reduce. Key = (content-hash E, basis-hash db).
\\ Cache lives in the content store; (normal-form Db E) = (reduce Db E) always.
(declare normal-form   [db --> (expr --> expr)])

\\ match: structural match, respecting Orderless/Flat of the head. (some Subst) | none.
(declare match         [pattern --> (expr --> (maybe subst))])

\\ substitute: instantiate an RHS under a substitution.
(declare substitute    [subst --> (expr --> expr)])

\\ current-core: backend selector. Reference is always present and is the oracle.
(declare current-core  [--> core])
```

Contract every backend honors:

1. **Observational equivalence to the reference** on every supported `E` (modulo canonical ordering for Orderless heads). This is the acceptance gate (Section 8.5).
2. **Basis-keyed rule set.** The reference reads the live db, so new rules take effect immediately. A *compiling* backend (dispatch tables, HVM) is keyed to a **basis hash**: a new assertion yields a new basis, so its caches for the old basis are simply never consulted. **This is how v2 dissolves the v1 "manual invalidation" problem** — see Section 5.
3. **No new acceptance.** A backend may not evaluate what the reference rejects or leaves stuck; only faster.
4. **Strategy fidelity.** Reproduce Mathematica's *ordered, generally non-confluent* strategy's result (DownValues before UpValues, left-to-right, re-eval to fixed point) — not merely *a* normal form. (This is where confluent runtimes like HVM create friction — Section 9.3.)

With the seam plus the basis-keyed substrate, "use HVM" becomes a precise, testable task: *implement a `reduce` backend for fragment F, keyed by basis, that passes the equivalence harness.*

---

## 5. The substrate: content-addressing + an immutable, queryable rule database

This is the v2 core addition. Three layers, bottom-up.

### 5.1 Content-addressed term store (upgrades hash-consing)

Every `expr`, `pattern`, and `rule` is named by a **Merkle hash** of its content: an atom hashes by `(tag, value)`; a compound hashes as a pure function of its head-hash and the (ordered) list of arg-hashes. A global **content store** maps `hash → node`; construction interns, so equal subterms are physically shared.

Payoff: structural sharing across the whole system; **O(1) structural equality** (compare hashes); **O(1) `contains-subexpr?`/subterm identity**; and the substrate for memoization (5.4).

**Canonicalization before hashing — the subtlety to get right.** A content hash must depend only on what is *definitionally* true regardless of the (mutable) rule set, or sharing breaks across db versions. Three cases:

- **Alpha-equivalence (always safe).** Binders are syntactic, so hash `Module`/`With` bodies *modulo alpha* (de Bruijn indices or canonical renaming). Alpha-equivalent bodies share a hash. The hasher must know binders.
- **Orderless / Flat (safe *only* because v2 fixes them).** `Plus[a,b]` and `Plus[b,a]` should share a hash, which requires sorting args canonically (Orderless) / flattening (Flat) *before* hashing. But "is `Plus` Orderless?" is itself a fact that could change — coupling the hash to the db basis, which we forbid. **Resolution:** treat `Orderless`/`Flat`/`OneIdentity` as part of a symbol's *immutable signature* (declared at symbol creation, not flippable at runtime). Then commutative/associative canonicalization is db-independent and safe to fold into the hash. Flipping a structural attribute is unsupported and, if ever allowed, must flush the content/memo caches.
- **Rule-driven equality (never folded).** Equalities produced *by rules* (e.g. `x+0 → x`) are the *output* of evaluation and depend on the basis. They are never folded into the content hash; they are cached separately as `(term-hash, basis) → nf-hash` (5.4).

This is the Unison model — code/data addressed by content — specialized to a rewriting kernel, with attributes and binders co-designed into the hash.

### 5.2 Immutable, accumulate-only rule database (Datomic-style)

Replace the sketch's mutable `*symbol-table*` with an immutable **database value**.

- **Datoms (accumulate-only).** A rule registration asserts `[symbol, kind, rule-hash, tx]` with `kind ∈ {own, down, up}`; an attribute assertion is `[symbol, attribute, tx]`. Entities are content hashes (5.1); nothing is overwritten.
- **A db value = a basis.** Each db value is an immutable snapshot identified by a **basis hash** (a Merkle root over its asserted datoms). `register-rule`/`set-attributes` are pure: `db → db'`, returning a new value with a new basis. A REPL session is a thread of basis values; the "current" symbol table is `(symbol-entry-view db sym)` computed on demand.
- **Time is first-class.** Evaluate "as of" any basis. This gives **reproducibility** (a result is a function of `(term, basis)`), **undo/redo** (keep prior bases), and clean **session forking**.
- **Scoping falls out.**
  - `Block` (dynamic scope) = evaluate the body against a *forked* db with temporary assertions, then discard the fork. The sketch's save/restore hack disappears; the immutable model makes it leak-proof by construction.
  - `Module`/`With` (lexical) = alpha-renaming, already handled by content-addressing modulo-alpha (5.1).

This directly answers Evaluation-Core clause 2: because the rule set *is* a value, a compiled or HVM backend caches against a basis hash and is auto-invalidated when the basis changes. No invalidation bookkeeping.

### 5.3 Datalog + Prolog: two engines, two jobs

Be precise about which engine does what — they are not interchangeable.

- **Prolog (top-down, backtracking, function symbols) — the matching inner loop.** Sequence matching (`BlankSequence`/`BlankNullSequence`), Orderless permutation search, Flat splitting — exactly the sketch's §7.2–7.3. Unchanged. Prolog is right here because matching needs unification over terms *with* function symbols and on-demand backtracking.
- **Datalog (bottom-up, set-oriented, stratified, terminating; no function symbols in heads) — indexing + analysis over the db.**
  - **Rule dispatch as a relational query (term indexing).** Index rule LHSs by head and top-level shape as relations; "candidate DownValues for a term shaped *S* under head *H*" is a Datalog query returning only plausibly-matching rules, instead of trying all in order. This is the term-indexing performance win, expressed natively over the fact db.
  - **Static analysis as derived facts**, complementing (not replacing) the sequent-calculus definition-time checks:
    - binding coverage as a relation `covers(Rule)` / `unbound(Rule, Var)`;
    - attribute consistency and `OneIdentity`-without-unary-rule via **stratified negation**;
    - **cross-rule loop detection** via recursion/transitive closure over a rule-dependency graph — this catches the `f→g→f` cycle the sketch explicitly admits its single-rule heuristic cannot (§10.2). A real upgrade, not a restatement.

Datalog is the *analysis and indexing* layer; it is **not** the rewriter. Function-symbol-laden rewriting stays in the evaluator/Prolog. Don't claim Datalog's termination guarantees for the rewrite layer.

### 5.4 The payoff: evaluation memoization (often a bigger win than HVM)

`normal-form` (Section 4) is a content- and basis-keyed cache: `(content-hash E, basis-hash db) → nf-hash`, stored in the content store.

- Re-simplifying a subterm under an unchanged db is an **O(1) lookup**. CAS workloads are dense with repeated subexpressions and iterative simplification, so this is typically a larger and more *reliable* speedup than HVM — and it lives entirely in-model with no external runtime.
- The cache is **mergeable/persistable/distributable** because it is content-addressed (the Unison/Datomic property): cross-session caching and even a shared team cache become possible.
- It **subsumes backend invalidation**: any backend's cached compilation is keyed by basis; the memo and the basis together mean correctness is automatic across rule changes.

**Costs to flag honestly:** canonicalization-before-hash must be consistent (5.1) or sharing/memo silently corrupts; the memo key *must* include the basis (a rule change must not return a stale normal form); the accumulate-only db and content store grow, so a compaction/GC story is needed (affine-GC-friendly — and conveniently aligned with HVM's affine collector if that backend is adopted); hashing cost is amortized by incremental Merkle hashing over already-interned children.

---

## 6. Module breakdown

`.shen` files in dependency order (substrate modules in **bold**):

| Module | Responsibility | Depends on | LOC |
|---|---|---|---|
| **`store.shen`** | content store, Merkle hashing, interning, alpha/Orderless/Flat canonicalization, O(1) equality | — | 200 |
| `expr.shen` | `expr` datatype, constructors (interning), pretty-printer | store | 110 |
| `num.shen` | numeric ops behind one interface (int/real, future bignum) | expr | 60 |
| `pattern.shen` | `pattern`/`seq-pattern`/`pat-or-seq`/`compound-pattern` datatypes | expr | 150 |
| `rule.shen` | `checked-rule`, `extract-bindings`, `free-symbols`, `bindings-cover?` | pattern, expr | 120 |
| `attrs.shen` | `attribute`, `valid-attrs`, `consistent?`; structural-vs-control split | — | 110 |
| **`db.shen`** | immutable datom db, basis hashing, assert, `symbol-entry-view`, db fork | rule, attrs, store | 200 |
| **`query.shen`** | Datalog index (dispatch candidates) + analysis relations (coverage, loops, attr checks) | db | 220 |
| `match.shen` | core matcher (non-sequence) + `substitute` | pattern, db | 180 |
| `match-seq.shen` | sequence matching via Prolog (`match-arg-list`, `split`) | match | 160 |
| `match-ac.shen` | Orderless (`permutation`/`select`) + Flat (`flatten-flat`) | match-seq | 130 |
| `core.shen` | Evaluation Core interface; reference `reduce`/`normal-form` (memoized)/`eval-args`/`held?`/`try-rules` | match-ac, db, query, store | 240 |
| `scope.shen` | `gensym`, `Module`/`Block`(=db fork)/`With` + scoping datatypes | core, db | 150 |
| `warn.shen` | surface Datalog analysis results as load-time warnings | query | 80 |
| `boot/*.shen` | arithmetic, simplification, control-flow rule libraries | all above | 500+ |
| `read.shen` | Phase 5 surface reader (infix → S-expr) | expr, pattern, rule | 300 |

Typed core (everything above `boot/`/`read.shen`) is ~1,600 lines — about 400 over the sketch's estimate, the cost of the substrate, repaid by memoization, clean scoping, and cross-rule analysis.

---

## 7. (reserved — merged into 6)

---

## 8. Phased implementation plan & verification

Each phase ends with a runnable deliverable and a green acceptance set (Appendix B). Don't start a phase before the prior one's tests pass — the static-checking thesis only holds if each layer's guarantees are actually verified.

**Phase 0 — Harness & oracle (~150 LOC).** Test harness, golden-file format (`input → expected nf`), and if available a thin shell to Wolfram Engine/Mathics to *generate* golden expectations; otherwise hand-authored, frozen.

**Phase 1 — Core + content store (~450 LOC).** `store` (hashing/interning/canonicalization) + `expr`/`pattern` datatypes + non-sequence matcher + `substitute` + evaluator loop without attributes. Deliverable: a first-order rewriter that statically rejects malformed patterns and unbound-RHS rules, with content-addressed terms and O(1) equality.

**Phase 2 — Immutable DB + sequences + attributes (~600 LOC).** `db` (datoms, basis, fork), Prolog sequence matching, `valid-attrs`+`consistent?`, attribute-aware evaluation (hold/flatten/sort/thread), Orderless+Flat. Deliverable: full matcher over an immutable, versioned rule db.

**Phase 3 — Datalog dispatch/analysis + memoization (~300 LOC).** `query` (candidate-rule index + coverage/loop/attr relations), `warn`, and basis-keyed `normal-form` memo. Deliverable: indexed dispatch, cross-rule warnings, and memoized evaluation.

**Phase 4 — Scoping (~150 LOC).** `Module`/`With` (alpha via content-addressing), `Block` (db fork) + scoping type rules.

**Phase 5 — Bootstrap (~500+ LOC of rules).** Arithmetic, algebraic simplification, control flow, list ops, all as checked rules.

**Phase 6 — Surface syntax (~300 LOC).** Reader: `f[x_, y_] := x + y` → internal form.

**Phase 7+ — Perf backends (post-MVP).** Compiled dispatch, then the HVM offload experiment — each a Section-4-conformant, basis-keyed backend gated by the Section 8.5 equivalence harness (Section 9).

### 8.1 Static-rejection tests (the thesis)
Assert *definition-time* rejection for: malformed patterns (`Pattern[3,5]`); `(named x (blank-seq))` outside arg position; unbound RHS vars; `hold-all`+`hold-first`; `listable`+`hold-all` without opt-in; `Block` with a non-symbol binding. This suite *is* the paper's contribution made concrete.

### 8.2 Matcher property tests
Successful match re-matches after instantiation; Orderless invariant under permutation; Flat invariant under re-association; sequence matching enumerates exactly the expected splits (vs a brute-force reference).

### 8.3 Substrate tests (new)
- **Hash canonicalization:** `Plus[a,b]` and `Plus[b,a]` share a hash (Orderless); nested `Plus` shares after flatten; alpha-equivalent `Module` bodies share; rule-driven equalities do *not* alter content hashes.
- **Memo correctness:** `(normal-form Db E) = (reduce Db E)` for all corpus `E`; a rule assertion (new basis) does not return a stale normal form.
- **DB time-travel:** evaluating `E` as-of an older basis ignores later rules; `Block` fork leaves the parent basis unchanged.
- **Datalog analysis:** coverage/loop/attr relations agree with brute-force reference checks; the `f→g→f` cross-rule loop is detected.

### 8.4 Evaluator property tests
Idempotence (`reduce∘reduce = reduce`) on a generated corpus, run automatically on rule registration; confluence probes for rule sets declared confluent; the Phase-0 golden corpus.

### 8.5 Backend equivalence harness
Parameterize the entire golden + property suite over `current-core`. A backend is "done" when it passes the full suite with `current-core` bound to it. This single gate makes experimenting with HVM safe.

---

## 9. Performance, and whether HVM fits

### 9.1 Where a CAS spends its time
Not arithmetic — *pattern matching against a large, growing rule database, plus traversal and normalization*. Highest-leverage optimizations, in order: (1) **content-addressing + memoization** (Section 5.1, 5.4) — repeated subterms reduce once; (2) **Datalog term indexing** (5.3) — retrieve only candidate rules; (3) **compiled dispatch** — generate a decision procedure per symbol from its rules (Shen homoiconicity makes this natural); (4) **AC-matching specialization** — bounded algorithms for Orderless+Flat instead of naive permutation. **All four are in-model and need no external runtime. Do them before considering HVM.**

### 9.2 What HVM is
HVM3 and HVM4 are runtimes for the **Interaction Calculus** — affine/linear lambdas, no scope boundaries, first-class **duplication** and **superposition**, **optimal beta-reduction** (Lévy-optimal sharing, exponential speedups on some higher-order programs), an efficient affine GC, and inherent **parallelism** (local interaction-net rewrites). HVM3 is Haskell+C and targets being Bend's compile target (interpreted + `-c`-compiled-to-C modes); HVM4 is a leaner, mostly-C, **pre-launch** rewrite with superposition/collapse syntax. HVM's zone of dominance: *higher-order, confluent reduction with optimal sharing.*

### 9.3 Why HVM is the wrong *host*
Four model-level disagreements: (1) **AC matching** (Orderless/Flat) — the combinatorial heart of the matcher — is not beta-reduction-shaped; HVM gives no native help, while Shen's Prolog fits it. (2) **Ordered, non-confluent strategy vs confluent runtime** — Mathematica's results depend on a specific strategy and Hold-attributes; IC is confluent by design, so you'd fight its defining property (Evaluation-Core clause 4). (3) **Runtime rule extensibility vs ahead-of-time compilation** — a CAS redefines rules mid-session; HVM's speed is in `-c` compilation, so hosting means recompiling the world per `:=` or living in the slow interpreter. (4) **Not stable** — HVM4 is pre-launch, HVM3 WIP. The sketch's instinct (Shen host, Prolog for the hard matching) is right.

### 9.4 Where HVM *could* help (behind the seam, basis-keyed)
Only as a **backend for a delimited, confluent, higher-order functional fragment** reached via a Shen→HVM compile pass: heavy `Function`/`Fold`/`Nest`/combinator/recursion-scheme evaluation maps well onto IC and is where optimal beta-reduction shines; and **parallel batch simplification** of large independent subterms suits interaction-net parallelism (a "GPU for symbolic reduction"). Integration shape: identify fragment **F** (pure, confluent, higher-order); write `reduce_F` as a compile-and-run backend; register it behind the Evaluation Core as the handler for **F** with fallback to the reference for everything else; key its compiled artifacts and results by **basis hash** (5.2) so invalidation is automatic; gate with the equivalence harness (8.5). Compile *whole subtrees*, never single steps — marshaling cost across the Shen↔HVM boundary only pays when the offloaded subcomputation is large. Reconcile numerics: HVM is fixed-width, so the `num` decision (Section 3) bounds what offloads losslessly. Note the affine-GC alignment: the substrate's accumulate-only store wants compaction anyway, and HVM's affine collector is congenial if that backend is adopted.

### 9.5 Recommendation
1. Build the MVP on the pure-Shen reference evaluator — it is the spec.
2. Spend the first performance budget on the substrate: **content-addressing → memoization → Datalog indexing → compiled dispatch → AC specialization.** These are where the time goes and they need no external runtime.
3. Keep the Evaluation Core seam clean and basis-keyed so a backend slots in without restructuring.
4. Treat HVM as a Phase-7+ experiment: a basis-keyed backend for a confluent higher-order fragment and/or parallel batch simplification, validated by the harness, pinned to a specific HVM revision. Prefer HVM3 for Haskell-side tooling and the Bend trajectory; watch HVM4 for the leaner C core post-launch.

In one line: **content-addressing + an immutable, Datalog-indexed rule database is the real performance and reproducibility win; Shen hosts and defines; Prolog does the hard matching; HVM, if ever, is a JIT for the pure higher-order corners — never the kernel.**

---

## 10. Risks & open questions

- **Type-rule syntax drift.** Verify all `datatype` rules against *The Book of Shen* 4th ed. before Phase 1.
- **Canonicalization correctness.** Orderless-sort, Flat-flatten, and alpha-canonicalization must be consistent and db-independent (5.1); a bug here silently corrupts sharing and the memo. Make the structural-attribute-immutability constraint explicit and tested.
- **`bindings-cover` as a type-level side condition.** Confirm the 4th-ed. type checker permits calling these predicates as side conditions; if not, run binding coverage as a registration-time gate (still definition-time) plus the Datalog `covers` relation.
- **Prolog/typed-data boundary.** Ensure the matcher's typed `pattern` values pushed into `defprolog` cannot fabricate ill-typed bindings.
- **DB/store growth.** Accumulate-only needs a compaction/GC story; design it affine-friendly from the start.
- **Datalog stratification.** Negation (OneIdentity, etc.) must be stratified; loop detection needs recursion/transitive closure — confirm the Datalog layer (whether Shen-Prolog-hosted or a small custom engine) supports both.
- **HVM volatility.** Pin a revision; expect API churn.
- **`tbos_288.html`** could not be extracted (client-side rendered). If it documents a feature this design should use, supply its text.

---

## Appendix A — Liftable implementation prompt

> Implement a statically checked, Mathematica-inspired term rewriting kernel in Shen, following this design and the attached sketch.
>
> Build in phase order (0→6); don't begin a phase until the prior phase's acceptance tests (Appendix B) pass. The pure-Shen reference evaluator is the specification — never weaken a static check or the ordered evaluation strategy for performance.
>
> Phase 0: harness + golden format first. Phase 1: content store (Merkle hashing, interning, alpha/Orderless/Flat canonicalization with structural attributes treated as an immutable symbol signature) + `expr`/`pattern` datatypes (verbatim from the sketch, re-verified against Book of Shen 4th ed.) + non-sequence matcher + evaluator loop; enforce every static-rejection case in 8.1 as a definition-time rejection test. Phase 2: immutable datom database (basis hashing, assert, db fork) + Prolog sequence matching + attributes + Orderless/Flat. Phase 3: Datalog candidate-rule index + analysis relations (coverage, attribute consistency, cross-rule loop via transitive closure) + basis-keyed `normal-form` memoization. Phase 4: scoping (`Module`/`With` via alpha-canonicalization, `Block` as db fork). Phase 5: bootstrap rule libraries. Phase 6: surface reader.
>
> Structure all evaluation behind the Evaluation Core interface (Section 4); key every cache by `(content-hash, basis-hash)`. Do not implement an external performance backend (HVM) until the MVP passes the full suite; when you do, implement it as a basis-keyed, Section-4-conformant backend for a delimited confluent higher-order fragment, validated by the equivalence harness (8.5), with fallback to the reference evaluator.
>
> Deliver per phase: the module(s), their tests, and a note on which sketch invariants are now machine-checked. Flag any check the current Shen type checker cannot express as written and implement the closest definition-time equivalent.

## Appendix B — Per-phase acceptance checklist

- **Phase 0:** harness runs; golden format parses; one end-to-end golden case executes against a trivial evaluator.
- **Phase 1:** malformed patterns + unbound-RHS rules rejected at load time; first-order golden cases pass; content hashing gives O(1) equality; `Plus[a,b]`≡`Plus[b,a]` and alpha-equivalent bodies share hashes; `reduce∘reduce = reduce` on the Phase-1 corpus.
- **Phase 2:** sequence-split enumeration matches brute force; Orderless/Flat invariances hold; `hold-all`+`hold-first` and `listable`+`hold-all` rejected; AC-blowup warning fires; db assertions are pure (parent basis unchanged); as-of evaluation ignores later rules.
- **Phase 3:** Datalog dispatch returns exactly the candidate rules; coverage/attr/loop relations match brute force; `f→g→f` loop detected; `(normal-form Db E) = (reduce Db E)`; new basis never returns a stale nf.
- **Phase 4:** `Module` alpha-renames correctly; `Block` fork restores by construction; `Block` with non-symbol binding rejected at load time.
- **Phase 5:** arithmetic + simplification golden suite passes; Orderless makes `0 + x` reduce via the single `x + 0` rule; idempotence across the bootstrap corpus.
- **Phase 6:** reader round-trips `f[x_, y_] := x + y`; parse errors reported, not silently mis-parsed.
- **Any backend (Phase 7+):** passes the entire golden + property suite with `current-core` bound to it; basis-keyed; no expression accepted that the reference rejects.

## References

- Tarver, M. (2025). *The Book of Shen*, 4th edition. Shen Technology.
- Tarver, M. *Shen Language Specification.* shenlanguage.org.
- Wolfram, S. (2002). *A New Kind of Science*, ch. 12. Wolfram Media.
- *Wolfram Language Documentation — Standard Evaluation Sequence.* reference.wolfram.com.
- Baader, F. & Nipkow, T. (1998). *Term Rewriting and All That.* Cambridge University Press. (Term indexing, AC matching.)
- Hickey, R. et al. *Datomic* — immutable, accumulate-only database with Datalog query and as-of time travel. (Architectural reference for Section 5.2.)
- *Unison Language* — content-addressed code/data by hash. (Architectural reference for Section 5.1/5.4.)
- HigherOrderCO. *HVM3* — Interaction Calculus runtime (Haskell+C; Bend target). github.com/HigherOrderCO/HVM3
- HigherOrderCO. *HVM4* — leaner mostly-C IC runtime (pre-launch). github.com/HigherOrderCO/HVM4
- Taelin, V. *Interaction Calculus.* github.com/VictorTaelin/Interaction-Calculus
