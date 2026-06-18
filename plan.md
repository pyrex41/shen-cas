# shen-cas Implementation Plan

## Goal

Build a small, statically checked, Mathematica-inspired term rewriting kernel in Shen, then grow it into a usable CAS foundation.

The kernel's value proposition is not raw symbolic power first. It is moving common CAS rule bugs from runtime surprises to definition-time rejection:

- malformed patterns
- sequence variables in illegal positions
- unbound RHS variables
- inconsistent attributes
- invalid scoping forms
- stale memo/cache results after rule changes

The pure Shen reference evaluator is the specification. Every optimization, index, compiled dispatcher, or future backend must be observationally equivalent to it on the accepted fragment.

## Inputs Incorporated

- `sketch.md`: original typed rewriting kernel and matcher/evaluator design.
- `design.md`: v2 substrate, content addressing, immutable basis, memoization, backend seam, verification plan.
- `prologue+datalogue_decision.md`: replace broad "Datalog layer" with native dispatch index, plain analysis relations, and one least-fixpoint combinator.
- `book_of_shen_cas_relevant.md`: Book of Shen 4th ed. material for algebraic simplification, typed Shen YACC, and Shen Prolog.
- `grok_review.md`: validation that the v2 substrate is the right long-term architecture, plus emphasis on Book section 21.4, typed YACC, Prolog API, static-rejection tests, and canonicalization risk.

## Guiding Decisions

1. **Definition-time checking is the thesis.**

   The static rejection suite is not a side test; it is the core deliverable.

2. **Separate syntactic validity from semantic trust.**

   Shen can check that rules are well-formed and locally safe. It cannot generally prove that arbitrary algebraic rewrites preserve mathematical meaning. Bootstrap simplification rules are trusted unless later replaced with proof-carrying or restricted certified rules.

3. **Build a narrow content store early, not the whole substrate at once.**

   Content hashes and interning should exist before memoization and immutable db work. The first version should stay minimal: stable hashes, interned nodes, and O(1) equality. Basis hashing, db time travel, and memoization come after the first checked evaluator runs.

4. **Structural attributes are symbol-declaration facts.**

   `Orderless`, `Flat`, and `OneIdentity` affect hashing/canonicalization and must be immutable after symbol creation. Evaluation-control attributes such as `HoldAll`, `HoldFirst`, `HoldRest`, and `Listable` can remain ordinary db facts.

5. **Prolog is for matching, not global analysis.**

   Use Shen Prolog for sequence variables, `Orderless`, and `Flat` matching. Use native Shen structures for dispatch indexing and cyclic rule analysis.

6. **Typed reader is part of correctness, not cosmetics.**

   The Book's typed Shen YACC examples show the right model: surface syntax should compile into typed internal forms, and parse failures must not emit unchecked trees.

## Module Layout

Target dependency order:

| Module | Responsibility |
|---|---|
| `test.shen` | test harness, golden files, rejection tests, property-test helpers |
| `store.shen` | content hashes, interning, canonical constructors, O(1) equality |
| `expr.shen` | `expr` datatype, constructors, pretty-printer |
| `num.shen` | exact integer numeric layer first; room for rationals later |
| `pattern.shen` | `pattern`, `seq-pattern`, `pat-or-seq`, reserved pattern constructors |
| `rule.shen` | `checked-rule`, binding extraction, free-symbol analysis, registration gates |
| `attrs.shen` | attribute datatypes, structural-vs-control split, consistency checks |
| `match.shen` | first-order matcher and substitution |
| `match-seq.shen` | Prolog-backed sequence matching |
| `match-ac.shen` | `Orderless` / `Flat` matching support |
| `db.shen` | immutable datom db, basis hash, assertions, forks |
| `core.shen` | `reduce`, `normal-form`, evaluator loop, Evaluation Core seam |
| `query.shen` | dispatch index, cold analysis relations, `lfp`, loop detection |
| `scope.shen` | `Module`, `With`, `Block` as db fork |
| `warn.shen` | static warnings surfaced at rule/attribute registration |
| `boot/*.shen` | arithmetic, algebraic simplification, control flow, list ops |
| `read.shen` | typed reader for algebra/rule syntax |
| `print.shen` | readable algebraic printer and round-trip tests |

## Phase 0: Harness, Corpus, And Syntax Verification

Deliverable: a runnable test harness and frozen examples before kernel code grows.

Tasks:

- Create a minimal test runner that can load modules and report pass/fail.
- Define a golden format: `input -> expected normal form`.
- Add rejection-test support: expected load/registration/type errors.
- Extract a small algebra corpus from Book of Shen 21.4:
  - arithmetic simplification equivalent to `arith`
  - tree walking / repeated simplification equivalent to `walk`, `thrash`, `simplify`
  - simple expressions like `[12 * (5 - 3)] -> 24`
- Re-verify 4th-edition Shen syntax for:
  - `datatype`
  - side conditions using `verified`
  - `defprolog`
  - `prolog?`
  - typed Shen YACC `defcc` / `==>`
- Decide the first numeric policy: exact integers only.

Acceptance:

- Harness runs with at least one trivial passing golden test.
- Harness can express an expected static rejection.
- A short `notes/syntax-verification.md` or equivalent comment block records any 4th-edition syntax corrections needed before implementation.

## Phase 1: Checked First-Order Rewriter

Deliverable: a minimal statically checked first-order rewriter with content-hashed expressions.

Tasks:

- Implement `store.shen` with:
  - content hash type
  - intern table
  - canonical constructors
  - equality by hash
  - no basis/memoization yet
- Implement `expr.shen`:
  - tagged atoms: symbol, integer, real/string only if needed
  - compounds as checked expression trees
  - constructors that go through `store`
- Implement `pattern.shen`:
  - literal patterns
  - `blank`
  - typed blank
  - named pattern
  - condition and pattern-test stubs if feasible
  - explicit split between `pattern` and `seq-pattern`
  - reserved pattern constructors so literal expressions cannot masquerade as pattern syntax
- Implement `rule.shen`:
  - `checked-rule`
  - `extract-bindings`
  - `free-symbols`
  - initial `bindings-cover?`
  - registration-time fallback if Shen cannot call the side condition directly from the datatype rule
- Implement `match.shen`:
  - literal match
  - blank match
  - named match
  - first-order compound match
  - substitution
- Implement a naive `reduce` loop in `core.shen` over an in-memory ordered rule list.

Acceptance:

- Reject malformed pattern constructors.
- Reject sequence patterns outside argument position.
- Reject unbound RHS variables for first-order rules.
- First-order golden reductions pass.
- `reduce` is idempotent on Phase 1 golden cases.
- Content equality works by hash for identical expressions.

## Phase 2: Attributes, Sequences, And AC Matching

Deliverable: the full matcher shape from the sketch, still before immutable db/memo complexity.

Tasks:

- Implement `attrs.shen`:
  - structural attributes: `Flat`, `Orderless`, `OneIdentity`
  - evaluation-control attributes: `HoldAll`, `HoldFirst`, `HoldRest`, `Listable`
  - consistency checks
  - explicit symbol declaration form for structural attributes
- Extend `store.shen` canonicalization:
  - `Orderless` argument sorting for declared symbols
  - `Flat` flattening for declared symbols
  - no rule-driven equality in content hashes
- Implement `match-seq.shen` using Shen Prolog:
  - `BlankSequence`
  - `BlankNullSequence`
  - named sequence variables in argument position
  - split enumeration tests
- Implement `match-ac.shen`:
  - `Orderless` matching via permutation/search
  - `Flat` matching via flattening/splitting
  - warning threshold for `Flat + Orderless` with multiple sequence variables
- Extend evaluator:
  - head evaluation
  - held argument evaluation
  - flatten/sort/thread steps
  - ordered rule application to fixed point

Acceptance:

- `hold-all + hold-first` rejected.
- `listable + hold-all` rejected unless an explicit opt-in is designed.
- `Plus[a,b]` and `Plus[b,a]` share a hash after structural declaration.
- Nested `Plus` shares after `Flat` canonicalization.
- Sequence matching enumerates the same splits as a brute-force reference.
- `Orderless` matching is invariant under argument permutation.
- `Flat` matching is invariant under reassociation.
- AC blowup warning fires for the known pathological shape.

## Phase 3: Immutable DB, Basis Hashes, And Memoization

Deliverable: replace ad hoc rule state with immutable database values and basis-keyed normal-form memoization.

Tasks:

- Implement `db.shen`:
  - datoms for rule assertions
  - datoms for attributes
  - db value as immutable basis
  - basis hash
  - pure `assert-rule` / `assert-attribute`: `db -> db'`
  - `symbol-entry-view` as a computed view
- Move rule registration from naive list to db assertions.
- Implement `normal-form`:
  - key: `(term-content-hash, basis-hash)`
  - value: normal-form content hash
  - guarantee: `normal-form Db E == reduce Db E`
- Implement db fork primitive for later `Block`.
- Add simple basis-retirement notes or hooks so compaction/GC has a future home.

Acceptance:

- Rule assertion produces a new basis; parent db unchanged.
- Evaluation as of an older basis ignores later rules.
- New basis never returns stale memoized normal forms.
- `normal-form` agrees with `reduce` for the full current corpus.
- Store/db growth risks are documented with a first GC/compaction sketch.

## Phase 4: Dispatch Index And Static Analysis

Deliverable: ADR-001 implemented: native hot dispatch, plain cold relations, one cycle-safe least fixpoint.

Tasks:

- Implement `query.shen` dispatch index:
  - `shape-key`
  - `(basis-hash, head, shape)` cache
  - ordered candidate rule list
  - over-approximation allowed
  - under-approximation forbidden
- Implement cold relations:
  - `covers?`
  - `unbound-vars`
  - `attr-conflicts`
  - `oneid-no-unary`
- Implement finite-set helpers and `lfp`.
- Implement rule dependency graph:
  - direct dependencies from rule RHS symbols
  - transitive closure via `lfp`
  - loop detection for `f -> g -> f` and `f -> f`
- Implement `warn.shen` to surface static warnings at rule/attribute registration.

Acceptance:

- Dispatch candidates are always a superset of actually matching rules.
- Dispatch cache coherence holds across basis changes.
- `lfp` terminates on cyclic graphs.
- Loop detection classifies self-cycle, mutual cycle, and acyclic chain correctly.
- `oneid-no-unary` matches brute-force set difference.
- No global recursive analysis is implemented in Prolog.

## Phase 5: Scoping

Deliverable: lexical and dynamic scoping forms integrated into the checked evaluator.

Tasks:

- Implement `Module` and `With` with hygienic renaming.
- Add alpha-canonicalization to content hashing for binder forms.
- Implement `Block` as db fork:
  - temporary assertions apply only in fork
  - parent basis survives unchanged
- Implement `block-binding` / `block-form` checks.
- Extend `bindings-cover?` and free-symbol analysis to understand binders and held/quoted contexts.

Acceptance:

- Alpha-equivalent `Module` bodies share a hash.
- `Block` with non-symbol binding is rejected.
- `Block` temporary values/rules do not leak into parent basis.
- RHS binding coverage handles local binders correctly for the supported subset.

## Phase 6: Bootstrap CAS Rules

Deliverable: a small checked algebra system.

Tasks:

- Define core symbols:
  - `Plus`
  - `Times`
  - `Power`
  - `List`
  - `If`
  - `CompoundExpression`
- Declare structural attributes:
  - `Plus`: `Flat`, `Orderless`
  - `Times`: `Flat`, `Orderless`
- Add exact integer arithmetic rules.
- Add simplification rules:
  - `x + 0 -> x`
  - `x * 1 -> x`
  - `x * 0 -> 0`
  - simple constant folding
  - simple nested arithmetic from Book 21.4
- Add control-flow rules with hold behavior:
  - `If[True, then, else] -> then`
  - `If[False, then, else] -> else`
- Add a small algebra bootstrap corpus based on Book exercises.

Acceptance:

- Book 21.4-style arithmetic simplification passes.
- `0 + x` reduces via the single `x + 0` rule because `Plus` is `Orderless`.
- Bootstrap corpus is idempotent under `reduce`.
- All bootstrap rules are checked rules.
- Known non-goals are explicit: no general semantic proof, no complete algebra system, no confluence guarantee.

## Phase 7: Typed Reader And Printer

Deliverable: usable surface syntax that compiles into checked internal terms.

Tasks:

- Choose implementation path:
  - typed Shen YACC if syntax fits cleanly
  - recursive-descent reader if Mathematica-like syntax is simpler by hand
- Parse expressions:
  - integers
  - symbols
  - function application: `f[x, y]`
  - infix `+`, `*`, `^`
  - parentheses
  - implicit multiplication: `2a -> Times[2, a]`
- Parse patterns:
  - `x_`
  - `x__`
  - `x___`
  - typed blanks if supported
- Parse rules:
  - `f[x_] := rhs`
  - immediate rule form if needed later
- Printer:
  - internal expression to readable algebra syntax
  - round-trip tests for supported subset

Acceptance:

- `f[x_, y_] := x + y` parses into a checked rule.
- `2a` parses as multiplication, not an invalid token sequence.
- Parse errors are reported; unchecked fallback trees are impossible.
- Reader/printer round-trips supported algebra expressions.

## Phase 8: Backend And Performance Experiments

Deliverable: only after MVP is green; no backend may change semantics.

Tasks:

- Parameterize the whole test suite over `current-core`.
- Add compiled dispatch only if profiling shows dispatch dominates.
- Add AC matching specialization only after measuring permutation/split blowups.
- Consider HVM only for a delimited pure, confluent, higher-order fragment.

Acceptance:

- Any backend passes all golden, rejection, property, memo, and basis tests.
- Backend artifacts are keyed by basis hash.
- Backend never accepts or reduces an expression the reference evaluator rejects or leaves stuck.

## Cross-Phase Test Matrix

These tests should grow monotonically; never remove an earlier rejection or golden case.

| Category | Starts | Examples |
|---|---:|---|
| Static rejection | Phase 0 | malformed pattern, unbound RHS, bad attrs, bad block |
| Golden reduction | Phase 0 | Book arithmetic, simplification rules |
| Matcher properties | Phase 1 | match then substitute re-matches |
| Sequence properties | Phase 2 | all split enumerations |
| AC properties | Phase 2 | permutation/reassociation invariance |
| Store properties | Phase 1 | hash equality, no rule-driven equality in hash |
| Basis properties | Phase 3 | as-of evaluation, no stale memo |
| Analysis properties | Phase 4 | dispatch superset, loop detection |
| Scoping properties | Phase 5 | alpha hash, `Block` fork isolation |
| Reader properties | Phase 7 | parse failure safety, round-trip |
| Backend properties | Phase 8 | equivalence to reference |

## Immediate Next Tasks

1. Create repository structure for `src/`, `test/`, `golden/`, and `notes/`.
2. Write Phase 0 harness skeleton.
3. Add the first golden corpus from Book 21.4.
4. Add static-rejection test declarations, even before implementation.
5. Verify 4th-edition Shen syntax for `datatype`, `defprolog`, and `defcc`.
6. Implement `store.shen`, `expr.shen`, and `pattern.shen` in that order.

## Open Questions To Resolve Before Phase 1 Completes

- Can 4th-edition Shen `datatype` rules call `bindings-cover?` as a side condition in exactly the way the sketch assumes?
- What is the exact representation of reserved pattern constructors so literal expressions cannot collide with pattern syntax?
- Which hash algorithm is available or easiest to implement portably in Shen?
- Does the installed Shen Prolog provide tabling? The plan does not rely on it, but future Prolog recursion decisions should know.
- Should exact rationals enter before or after the first algebra bootstrap?
- What is the minimum symbol declaration syntax for immutable structural attributes?

## Definition Of MVP Done

The MVP is done when:

- malformed rule definitions are rejected at definition/registration time;
- a small algebra corpus simplifies correctly;
- `Plus` / `Times` support `Flat` and `Orderless`;
- sequence patterns work through Shen Prolog;
- rules live in an immutable basis-keyed db;
- normal-form memoization is basis-safe;
- `Block` cannot leak dynamic changes;
- the typed reader can parse and reject the supported rule syntax safely;
- the full test suite passes against the pure Shen reference evaluator.

HVM, full Datalog, broad algebraic simplification, and proof-carrying semantic validity are post-MVP.
