# grok_review.md — Review of shen-cas Design Docs + Book Extraction

**Date:** 2026-06-18  
**Task:** Review design documents in repo; extract CAS-relevant sections from *The Book of Shen* 4th ed. (starting p. 288 per design.md risk note) into a standalone md; record thoughts here.

---

## 1. Summary of Design Documents Reviewed

### sketch.md (original design sketch)
- Core thesis: Shen is uniquely suited for a statically-checked Mathematica-style term rewriter because of (1) homoiconicity (exprs are native data), (2) built-in Prolog for backtracking search (sequence vars, Orderless/Flat), (3) extensible sequent-calculus type system that can encode domain invariants as `datatype` rules checked at definition time.
- Defines key datatypes: `expr`, `pattern`/`seq-pattern`/`compound-pattern` (the split is load-bearing), `rewrite-rule` (with `bindings-cover` side-condition), `valid-attrs` + `consistent?`, `symbol-entry`, `block-form`.
- Matcher: core + Prolog `match-arg-list`/`split`/`permutation`/`select` + `flatten-flat`.
- Evaluator mirrors Mathematica standard evaluation sequence (head, args w/ holds, flatten, orderless sort, listable thread, then DownValues then UpValues, fixed-point re-eval).
- Scoping: Module (gensym + alpha), Block (save/restore, with type guard for symbols only).
- Heuristics only for termination/confluence; static checks + warnings for the rest.
- Roadmap is phased but lighter on substrate than v2.

**Strength:** Excellent motivation and precise identification of where Shen's unique features pay off. The type rules are the intellectual payload.

**Limitation (addressed by v2):** Mutable global `*symbol-table*` via `set`/`value`. This makes memoization, forking (`Block`), reproducibility, and backend caching hard. Session state is imperative.

### design.md (v2 Design & Implementation Plan)
- Adds the missing substrate: 
  - **Content-addressed term store** (Merkle hashes + interning) for O(1) eq, structural sharing, alpha/Orderless/Flat canonicalization *before* hash (with structural attrs treated as immutable symbol signature).
  - **Immutable, accumulate-only Datomic-style rule DB**: datoms `[sym kind rule-hash tx]`, basis-hash identifies a db value. Assertions are pure `db → db'`.
  - **Datalog + Prolog split** (see ADR): Prolog only for matching (top-down, function symbols, backtracking); Datalog-ish for indexing + static analysis (bottom-up, coverage, attr consistency via negation, cross-rule loops via transitive closure + lfp).
  - **Basis-keyed everything**: normal-form memo is `(content-hash, basis-hash) → nf`. Backends (incl. future HVM) are basis-keyed → automatic invalidation.
- Clean **Evaluation Core seam** (`reduce`, `normal-form`, `match`, `substitute`, `current-core`) — reference impl is the spec; backends must be observationally equivalent.
- `Block` becomes a db fork (semantically leak-proof). `Module`/`With` via alpha-canonicalization in content hashes.
- Phases + strong verification story (golden files, property tests, backend equivalence harness, static-rejection tests that *are* the paper's contribution).
- Performance analysis: memo + indexing + compiled dispatch + AC specialization before even thinking HVM. HVM only as delimited backend for confluent higher-order fragment, never the host.
- Explicit contract: pure-Shen reference evaluator = specification.

**Major advance over sketch:** The mutable state problem is solved at the architectural level rather than bolted on. Memoization, reproducibility, clean scoping, and backend composition all "fall out."

### prologue+datalogue_decision.md (ADR-001)
- Sharp workload analysis of the "Datalog layer" required by design §5.3.
- Only cross-rule loop detection is truly recursive + cyclic-data-safe (needs least fixpoint over sets).
- Dispatch (hot path) must be a native index, not a Prolog query.
- Decision: tiered (Option C) — native discrimination-tree index for dispatch + plain Shen relations for non-recursive analysis + tiny `lfp` combinator for the one recursive case.
- Clear graduation path to full semi-naive Datalog later without changing call sites.
- Excellent engineering judgment: "YAGNI" for a full engine just to serve one query today.

All three docs are coherent, high-signal, and implementation-ready. v2 is a strict improvement that preserves the sketch's invariants while making the hard parts (state, memo, analysis, scoping) tractable.

---

## 2. The Book Extraction (book_of_shen_cas_relevant.md)

Created `book_of_shen_cas_relevant.md` with curated excerpts anchored at p. 288 (22.3 Montague Grammars / Ch. 22) plus the immediately preceding 21.4 "Algebraic Simplification" (p. 274) because:

- The design explicitly calls out `tbos_288.html` as unextracted and potentially relevant.
- 21.4 is the *only* place the book directly discusses "Computer algebra programs" + building simplification with Shen's concrete + abstract datatypes + validity-preserving operations + fixed-point reduction (`thrash` = evaluate to fixed point).
- p. 288+ material (Montague example, `datatype t`/`f`, defcc YACC, side-condition `verified` rules, gensym hygiene, higher-order semantics) shows exactly how to write the kind of sequent `datatype` rules the sketch depends on in 4th-edition syntax.
- Ch. 25 Shen Prolog (p. 345) material (defprolog syntax, `prolog?`, return/findall, occurs-check, integration with type checker) is the precise API used in the sketch's matcher.

**What was extracted (curated, not full chapters):**
- 21.4 in full (the CAS heart).
- p. 288 Montague intro + `datatype t`/`f` + recognizers + sample defcc rules.
- YACC compilation internals (how defcc becomes executable + type-preserving code).
- Full relevant Shen Prolog explanation + examples.
- Framing notes tying each piece to design phases/invariants.

OCR noise is left in place with warning; implementers must cross-check against canonical 4th ed.

---

## 3. Alignment & Validation Between Designs and Book (4th ed.)

**Strong positive alignments:**

1. **Datatype style and side conditions** — The book's `(datatype expr ... (if (not (element? ...)) ... verified ...))` and use of `(datatype ...)` to introduce `ok-expr` / `valid` wrappers is *identical* in spirit and syntax to sketch's `checked-rule` (LHS : pattern; RHS : expr; (bindings-cover LHS RHS)) and `valid-attrs`. The 4th ed examples at p. 274 and p. 288– confirm the surface syntax the sketch assumed from 3rd ed still holds (with minor surface differences). Design correctly flags re-verification as Phase-0/1 gate.

2. **Prolog role** — Book states "In Shen, Prolog is the language into which type declarations are compiled" and shows the exact `defprolog` + `prolog?` + `return` / `findall` / `when` / `is` / `bind` forms used in sketch §7.2–7.3. This validates the decision to keep Prolog *only* for the matcher (sequence/AC) and not abuse it for Datalog analysis (ADR).

3. **Priority/ordered rewriting** — 2.7 (cross-ref) + evaluator description confirm Shen `define` is a priority rewrite system (rules tried top-to-bottom; first match wins). Design §4 and §9.3 correctly insist the Evaluation Core must reproduce *this* strategy (not confluent IC semantics) to match Mathematica CAS expectations and the book's model.

4. **Algebraic simplification as bootstrap** — 21.4's `arith` + `walk` + `thrash` + `simplify` (higher-order valid ops driven to fixed point, with type checker enforcing both syntax and "meaning preservation") is literally a tiny working CAS kernel. Phase 5 bootstrap can treat the book's example (plus more rules for commutativity etc. via Orderless) as golden target. The `ok-expr` distinction maps cleanly onto "nothing ill-formed reaches the database."

5. **YACC + surface syntax** — Ch. 22 (p. 288+) shows a complete typed parser (defcc + semantic actions producing typed logic terms, gensym for hygiene). This directly de-risks Phase 6 reader: `f[x_, y_] := x + y` → internal `checked-rule` that already satisfies the sequent invariants.

6. **Gensym + hygiene** — Used in the book examples exactly where design needs it for `Module` alpha-renaming inside content hashes.

**Gaps / what the book does *not* provide (correctly handled by designs):**

- No content-addressing, Merkle, interning, or immutable fact DB. (These are the v2 additions — Unison/Datomic inspired, not Shen-book material.)
- No discussion of basis versioning or cross-rule static analysis beyond what sequent rules + heuristics give. (ADR + Datalog layer is the right extension.)
- Algebraic example is small (level-6 algebra) and uses mutable style in places; the design's immutable substrate + checked rules is a strict generalization that also solves the "how do I fork for Block" problem the book leaves imperative.
- No HVM/Interaction Calculus discussion (post-dates book; design's treatment in §9 is balanced and appropriately cautious).

---

## 4. Specific Thoughts & Recommendations

- **The substrate is the right bet.** The biggest source of complexity/bugs in real CAS kernels is rule database evolution + memo/cache invalidation + session forking. By making the db an immutable value identified by basis-hash and keying *everything* (terms, memos, compiled backends) to `(content-hash, basis)`, v2 dissolves an entire class of problems that the sketch's `*symbol-table*` would have inflicted. Memoization becomes the primary performance lever (as design claims), not HVM.

- **Evaluation Core seam is excellent discipline.** It forces the reference evaluator to stay the spec and makes any future perf backend a testable, isolated experiment. Do not let performance work leak into `core.shen` until the harness is green.

- **Include 21.4's `ok-expr` / validity pattern in the design's mental model.** Even if the final `checked-rule` is slightly different, the book's separation of "syntactically legal expr" vs "result of a meaning-preserving operation" is a clean way to think about what the static checks + Datalog analysis buy us.

- **Phase ordering is correct.** Do the content store + expr/pattern + basic checker (Phase 1) *before* the full immutable db. You need stable content hashes and the static rejection tests early; the db then layers on top without changing the meaning of terms.

- **Canonicalization correctness is the highest-risk invariant.** As design §5.1 and §10 note: Orderless/Flat canonicalization + alpha must be *db-independent* or sharing + memo silently corrupt. Treat structural attributes as creation-time-only (immutable signature) exactly as specified. Test the hash-sharing properties as a Phase-1/2 gate.

- **Datalog tiering (ADR) is pragmatic.** Implementing a full stratified semi-naive engine just for one loop-detection query would have been premature. The `lfp` + native dispatch index + plain relations is the 80/20 solution and has a clean upgrade path. Implement the tests in ADR §5 early.

- **HVM posture is correct.** Design correctly refuses to make HVM the host. Only consider it later as a basis-keyed backend for a *delimited* pure confluent higher-order fragment. The AC matching heart of a real CAS is not beta-reduction shaped.

- **Surface reader can be YACC or custom.** The book gives a full YACC model; a hand-written recursive-descent reader that directly produces `pattern`/`expr` values (and immediately type-checks) may be simpler for Mathematica-like notation. Either way, the reader must never be allowed to emit unchecked structures.

- **Static-rejection tests (design §8.1) are the contribution.** The paper's value is moving "mysterious runtime failure" bugs into "definition rejected at load time." Make the test suite loud and authoritative; every Phase N must add rejection cases the previous phase could not yet express.

- **Numerical representation decision (design §3) has long tail.** Centralize behind `num.shen`. It affects content-hash stability, arithmetic rule bootstrapping, and any future HVM offload (fixed width). Do it early.

- **Compaction/GC story needed.** Accumulate-only store + memo will grow. Design flags this; align any GC with affine thinking (HVM's collector would be congenial if that backend is ever adopted). Start with an explicit "basis retirement" or epoch model even if full GC is later.

- **Book extraction is now "done" for the 288 risk.** The `tbos_288.html` note in design.md can be closed or updated to "see book_of_shen_cas_relevant.md (curated 4th-ed excerpts for datatype style, Prolog API, YACC reader model, and algebraic simplification example)."

---

## 5. Minor Observations / Polish

- In sketch and design the `bindings-cover` side condition is powerful; confirm 4th-ed type checker accepts calling such predicates inside sequent rules (or fall back to registration-time gate + Datalog relation as design already contemplates).
- Sketch's `extract-bindings` / `free-symbols` / `bindings-cover?` are reusable across the Datalog coverage analysis — good.
- The design's "three load-bearing invariants" (nothing ill-formed in db; db is immutable value; core seam is the only replaceable layer) should be turned into executable comments or a tiny `assert-invariant` harness.
- Consider adding a small "algebra bootstrap corpus" test taken directly from the book's 21.4 example + extensions; it will double as both golden file and demonstration that the static story works for real CAS rules.

---

## 6. Conclusion

The design documents are mature and well-integrated. v2's content-addressed immutable substrate is the crucial upgrade that turns a promising sketch into a practical, memoizable, forkable, backend-extensible kernel suitable for a real CAS. The extracted book material strongly validates the choice of Shen and the datatype/Prolog/YACC patterns used in the sketch, while highlighting exactly where the 4th-edition syntax and examples must be re-checked.

**Recommended next concrete step:** 
1. Stand up Phase 0 harness + golden format (use book's algebraic examples + hand-written cases).
2. Implement `store.shen` (Merkle + canonicalization with the immutable structural-attr rule) + basic `expr`/`pattern` datatypes matching 4th-ed style.
3. Write the static-rejection tests from design §8.1 as the first executable proof of the thesis.

The foundation is sound. Build the seam and the store first; everything else composes on top.

---

**Files produced:**
- `book_of_shen_cas_relevant.md` — standalone curated excerpts.
- This `grok_review.md`.

**References:**
- All three design/ADR docs in repo.
- *The Book of Shen* 4th ed. excerpts (p. 274– , 288– , 345– ).
- Cross-cites to Unison, Datomic, HVM as in design.md.
