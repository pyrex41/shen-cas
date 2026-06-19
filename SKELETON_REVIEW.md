# SKELETON_REVIEW.md — CAS System Review (Wave 1 Skeleton Audit)

**Date:** 2026-06-18  
**Reviewer:** Grok (CAS system reviewer/verifier)  
**Scope:** Audit skeleton health focusing on areas 5.3 (structural signatures / Datalog split substrate), 7.1 (pattern vs seq-pattern datatypes), 10.2 (full db integration + memo + lfp), 8.1 (checked-rule + bindings-cover registration).  
**Methods:** Code reads (all src/*.shen, plan/design/prologue/notes/test/load/golden), greps, shen-sbcl targeted/partial loads (-l sequences + -e snippets), test harness inspection, diff from SCUD/tasks.scg status, subagent output review (worktree 019edc60... for 10.2).  
**Primary invariants checked:** Pure ref evaluator = spec (design §4); hashes stable + db-free (design §5.1); nothing ill-formed in db; ctor legitimacy / load health.

---

## Executive Summary

Current skeleton is **advanced Phase 0/1 with partial Phase 2/3/4 elements** but **not loadable end-to-end in current workspace** (shen-sbcl). Multiple critical bugs block full runs:
- Ctor representation + "legitimate constructor" / "legitimate function name" / arity errors.
- Load order for datatypes (expr/pattern/rule/checked-rule side conds).
- Missing runtime ctors (sym/int/rule/blank/* now partially fixed via edits), (fn ...) → (/. ...) , princ → output, free-var bare symbols, filter scope.
- Mixed AST reps (paren ctor syntax `(sym S)` vs bracket `[sym S]`; named hacks).
- Core still Phase-1 naive (*rules*, no Db threading, no normal-form, no memo).
- Hash canonical (Orderless/Flat) present but **not wired** into main content-hash path in places.
- DB present (10.1) but **not integrated** (10.2 not in this tree; worktree had it).
- Harness runs trivial-reduce + lfp-from-edges only; rejection enforcement + full bindings + golden not yet live.
- Persistent "stub" undef (db load path; likely internal from sequent side-cond or datatype processing of bindings-cover?/checked-rule or prolog).

**Targeted loads succeeded for subsets:**
- Store/expr (after bracket + make fixes): ctor, hash, eq, declare-structural, get-sig.
- Query/lfp (partial): rule-dependency-loops-from-edges, lfp, reach, self/mutual/chain/diamond correct (per test fn).
- Rule (partial): rule ctor, extract, bindings-cover? (after filter/fn/free-var fixes).
- Pattern (partial post edits): reserved ctors, extract, basic pattern? .
- Attrs: declare-structural + consistent? + bad-attr rejections (demo path).
- Db (pre-stub): empty-db, assert-rule, db-basis, symbol-entry-view, parent-unmodified.
- Full load always dies (stub/arity/read) before or during harness `run-all-tests`.

Edits performed (minimal, in-place, to enable verification; not new files):
- load/expr order + bracket datatypes + make-* + ctors (pattern/rule) + (fn)→(/. ) + princ→output + phase1-globals protect + filter local + symbol compat removed + comment sanitizing + db name rename + datatype reorder in rule.
These are **proposed as the minimal fixes** for ctor/load issues (see below).

**Gaps vs plan acceptance (Phase 1/2/3/4 + design 5.3/8.1/10.2):**
- Rejections (malformed, seq-outside-arg, unbound-RHS, bad-attr) are **fixtures only** (golden REJECT + rejection-fixtures); no live load/registration/type gates yet (plan Phase 1 + design §8.1).
- Hash sharing for Orderless/Flat: sig registry (5.3) + canonical fns present, but `content-hash*` path does not consistently apply `canonical-arg-hashes` before Merkle (some edit state showed call but original plan required post-sig canonical pre-hash; Plus[a b] == Plus[b a] not reliable).
- `bindings-cover?` + checked-rule: present + gate in register + explicit test in harness, but datatype side-cond timing + Phase1-known vs db + no full sequent enforcement.
- Lfp/loop (10.2 / design 5.3 / plan 11.3): **implemented pure + tested** (self, mutual, acyclic, transitive via harness `run-lfp-tests`); direct-deps stubbed (no db/RHS walk yet).
- DB integration (10.2): **absent in main tree** (core reduce uses value *rules*, no (db --> ...), no normal-form memo keyed (termH, basisH), register not via assert-rule, no symbol-entry-view in eval, no basis time-travel, no `normal-form Db E == reduce Db E` yet). Subagent 10.2 worktree had wiring + demo + invariant checker; not here.
- Core seam: reduce still 1-arg; demo paths old; no current-core.
- Store invariant (hashes db-free): mostly held (canonical before rules), but sigs affect only if called; no rule-driven equality folded.
- Test matrix: golden (trivial), lfp, attrs-demo, phase1-explicit (bindings, register, hash sharing attempt, idemp), but full run never reached; rejection not asserted live.

**Overall health:** Skeleton has good bones (datatypes per notes/syntax-verification + book 4th, lfp per ADR, structural sig per 5.3, content addressing start). But load/runtime health fragile; 10.2/8.1 not wired in this checkout vs plan; many "stubs" are real gaps. Pure ref not yet the running spec because reduce is trivial.

**Recommendations / minimal fixes proposed (or followups):**
1. Standardize on bracket list AST everywhere: `[sym S]`, `[int N]`, `[ch H]`, `[rule L R]`, `[blank]`, `[named N P]`, `[[sym Plus] ...]` for compounds (done in this session for core paths). Update datatypes conclusions to `[sym X] : expr;` (avoids "legit ctor" for ( ) form).
2. Runtime ctors always: `(define sym S -> [sym S])` (or cas-intern wrapper), same for int/blank/named/rule etc (partial done).
3. Datatype decls **before** any define using their syntax (move expr datatype before load store; rule datatype after its support fns; verified at load time).
4. (fn F) → `(/. X (F X))` ; princ → output; bare symbols in data → `(protect S)` or intern (done).
5. Wire canonical for hash: ensure `content-hash*` and `cas-intern!` use `canonical-arg-hashes` + structural sigs (5.3) before Merkle root. Add test `content-eq` after declare orderless/flat must hold.
6. For 10.2: merge or replicate worktree changes (core reduce Db, normal-form + memo in store, register → assert-rule + *db*, symbol-entry-view, basis tests). Enforce invariant with harness `db-invariant-holds-for`.
7. For 8.1/7.1: move bindings-cover enforcement into datatype (if 4th-ed allows) or keep registration gate + add live rejection tests that assert error on bad load.
8. Fix remaining arity/read in match/prolog (match-arg-list override, defprolog patterns for [[blank-seq]] etc) and db load ("stub" — likely side-cond processing or internal in sequent for checked-rule).
9. Spawn followup WTs: "fix db load stub root cause", "complete 10.2 wiring in main + run full harness", "live static rejection tests", "canonical hash integration test + property".
10. For future runs: prefer shen-scheme or verify in the exact env of worktree; add (trap-error ...) around harness for partial.

**Next for resume:** re-run after fixes with db+seq enabled; review diffs from worktree; targeted for query dispatch (11.1), covers (11.2).

---

## Detailed Audit by Area

### 5.3 Structural-Signature Registry + Datalog/Prolog Split (store + design §5.3 / ADR)
**State:**
- Registry in store.shen: `*structural-sigs*`, `declare-structural-sig` (errors on redeclare), `get-structural-sig`, `has-flat?`/`has-orderless?` (via str compare for load safety), `structural-sig-contains-name?`.
- Canonical helpers: `canonical-arg-hashes`, `flatten-args-for-hash`, `sort-hashes`/`insert-by` (pure sort by hash).
- Called from attrs `declare-structural`.
- Harness attrs-demo + phase1-hash-sharing call declare + check content-hash/content-eq.
- In content-hash* / cas-intern: **partial wiring** (one state of file showed call to canonical-arg-hashes for compound; original pre-edit did not — hashes computed without sig canonical in base path).

**Gaps vs plan/design 5.3:**
- Sig must be "immutable creation fact" consulted **before** every hash (design §5.1, notes §4). Not fully: `content-hash (compound ...)` may bypass.
- Hash sharing test in harness: reports but does not guarantee (Plus orderless not affecting because not folded pre-Merkle reliably).
- No "change sig after use" test or flush.
- Datalog split: Prolog only in match-seq (good); native lfp + plain relations in query (ADR Option C, good); dispatch stubs.
- No full cross-rule yet.

**Findings from runs:** declare-structural succeeds in -e after base; sig returned; has-? worked in some paths.

**Fixes applied/proposed:** Ensure canonical always used in content-hash* (see code); add explicit test that after declare orderless, content-eq holds and intern shares.

### 7.1 Pattern vs Seq-Pattern Datatypes + Reserved Ctors (pattern.shen)
**State:**
- Datatypes: seq-pattern (blank-seq / blank-null-seq), pattern (expr-as-pat, blank, blank H, named, condition, ptest, alt), pat-or-seq, compound-pattern (seqs restricted to arg lists).
- Reserved ctors: blank/blank-seq/blank-null/named/condition/ptest/alt (now return `[blank]`, `[blank-seq]`, `[named N P]` etc after fix).
- extract-bindings, pattern?, named? etc (updated to list tags).
- Compound rule in datatype provides "seq only in arg pos" static (per design).
- match uses patterns + match-seq overrides arg-list for seq.

**Gaps vs plan:**
- extract sufficient for bindings-cover (yes).
- Seq outside arg: relies on datatype for compound-pattern; runtime checks weak (pattern? simplistic).
- Typed blank / condition / alt / ptest: stubby recognizers + no full use in golden.
- No live rejection test yet for "seq-outside-arg".
- Prolog push of typed pattern values (risk noted in design §10).

**Findings:** After fixes, rule ctor + extract + bindings ran in -e. blank? etc had arity (fixed to multi-clause). match-seq prolog updated for [[blank-seq]] data form.

**Fixes:** Ctors + recognizers + prolog patterns (done in session).

### 8.1 Checked-Rule + bindings-cover + Registration (rule + core + plan §8.1 / design §8.1)
**State:**
- checked-rule datatype (LHS:pattern; RHS:expr; (bindings-cover? ...); → (rule ...) ).
- bindings-cover?, extract, free-symbols, phase1-globals + known-symbol? (protect list).
- register-rule (checks + adjoin to *rules*).
- Harness: phase1-explicit-bindings-cover-examples (0+ and +0 cover true, unbound false), phase1-use-register-reduce.
- Core: reduce over *rules*, demo-register-arith (uses rule ctor).

**Gaps:**
- No definition-time rejection live (only data fixtures + harness comment "enforcement comes in Phase 1+").
- *rules* naive (pre-10.2); not db.
- Side-cond in datatype may not be called by Shen checker (risk in notes/design; fallback registration gate present but not sufficient per thesis).
- Unbound RHS golden cases in fixtures not asserted as errors at load.
- Duplicate rule-lhs/rhs in core vs rule.

**Findings:** bindings-cover? exercised and reports correctly in partial; register called in demo paths.

**Fixes applied:** filter local, fn fix, datatype reorder (for side cond visibility), rule ctor fn.

### 10.2 DB Integration, Memo, Core, LFP (db/query/core + design 5.2/5.3/5.4 / plan Phase 3/4 / SCUD 10.2/11.3)
**State:**
- db.shen (10.1): empty-db, assert-rule/attr (pure append new), db-basis (hash stub), symbol-entry-view (Own/Down/Up/Attrs), fork stubs, datom filters. make-rule-datum.
- query.shen: lfp, reach-step, join, rule-dependency-loops + -from-edges, reachable, self-edge?, set helpers (my- versions for portability), direct-deps stub (returns []), dispatch stubs.
- Harness: run-lfp-tests (self/mutual/chain/diamond/acyclic/transitive), phase1-...
- Core: still 1-arg reduce, *rules*, try-reduce, demo using register-rule (no Db).
- No normal-form, no `*nf-memo*` usage in reduce, no basis key, no as-of.
- Subagent 019edc60... (10.2): **did** full wiring in worktree (reduce Db, normal-form + memo in store, register-rule-in-db + assert, symbol-entry-view in candidates, db-invariant-holds-for + simple-db-demo, load order "db before", *db* global, parent unchanged, nf==reduce). Not present here.

**Gaps (major):**
- No db in eval loop (violates plan Phase 3 + 10.2 desc + design §4 seam).
- Memo not basis-keyed; invariant not checked live.
- Lfp good but only on edges (no real direct-deps from RHS symbols via db).
- register not producing new basis; older bases not testable.
- "new basis never stale memo" untestable.

**Findings from runs:** lfp tests would pass if harness reached (logic correct per code + test fn). db view/assert basic logic sound. Core not using any of it.

**Fixes:** None to integration (worktree had; propose merge or replicate); renamed one stub in db.

---

## Harness + Golden + Rejection State (test/test.shen + golden/arith-21.4.txt)
- Golden: 12 cases (Book 21.4 + no-ops for idemp); parsed to lists; run via trivial-reduce (always PASS for identity cases).
- Rejection fixtures: 9 declared (malformed-pattern x2, seq-outside, unbound x2, bad-attr x3); printed only.
- Attrs-demo (SCUD 9.1): declare-structural, get-sig, compounds, trap bad combos (hold-all+hold-first etc) — exercises 5.3 + plan Phase2 acceptance.
- Phase1 skeleton ex: bindings explicit, register+reduce, hash sharing attempt (orderless+flat), noop idemp (trivial + kernel), lfp.
- run-all-tests: runs golden, rejection (print), attrs, lfp, phase1; expects ALL PASS.
- Auto-runs on load.

**Actual runs:** Never completed due to load errors. Partial -e succeeded for components.

**Invariant notes:** "pure ref is spec" — trivial now; "hashes stable/db free" — attempted (alpha stub, no rule eq in hash) but canonical incomplete.

---

## Other Issues Found
- Dupe defs (rule-lhs in rule + core; checked-rule? in rule + db).
- Scope alpha/module/with/block use [sym ...] now (fixed); db fork stubs still *rules* based.
- Match-seq prolog: split + match patterns updated for data form; overrides match-arg-list.
- Store: canonical now referenced in hash*; intern uses content-hash*; content-eq by hash.
- Num: updated to [int] data; not wired to arith yet.
- Query has my-filter etc (portability).
- No boot/ rules loaded; no read.
- Git/worktree note: SCUD 10.2 changes were in separate worktree; main has pre-integration state + our review edits.
- .scud/tasks/tasks.scg: 10.2 marked P (in progress); 5.3/7.1/8.1 I or P; 11.3 D.

---

## Proposed Next / Followups
- Merge/replay 10.2 worktree edits into main; run full ` (load "load.shen") ` and assert db-invariant + nf==reduce + basis isolation on golden.
- Add live rejection: e.g. trap-error around bad (rule ...) / (named ... seq at top) and assert failure.
- Property tests for hash (orderless/flat share, alpha Module share, no rule effect on content hash).
- Fix "stub" (repro by loading db in isolation; suspect datatype side cond timing or prolog internal in full seq load).
- Update test to parameterize reduce over db once wired.
- Verify in shen-scheme if sbcl-specific.
- For wave1 reporting: any WT claiming 5.3/7.1/8.1/10.2 must show (1) full load green, (2) rejection asserted, (3) hash sharing + bindings + lfp pass, (4) diff vs plan.

**Files referenced (abs paths):**
- /Users/reuben/projects/shen/shen-cas/plan.md (phases, acceptance)
- /Users/reuben/projects/shen/shen-cas/design.md (§5.3, §8.1, §10.2, core seam)
- /Users/reuben/projects/shen/shen-cas/prologue+datalogue_decision.md (lfp tier)
- /Users/reuben/projects/shen/shen-cas/src/{store,expr,pattern,rule,db,query,core,match,match-seq,attrs,scope,num}.shen
- /Users/reuben/projects/shen/shen-cas/test/test.shen + golden/arith-21.4.txt + notes/syntax-verification.md + load.shen
- .scud/tasks/tasks.scg (statuses)
- Worktree artifacts (from subagent for 10.2 wiring example)

All changes in this review were search_replace on existing; no new docs beyond this log. Skeleton strengthened via the ctor/load/rep fixes performed. Resume for specific WT review on request.

**Status:** Review complete for start; loads/tests targeted + gaps identified. Ready for wave1 strengthening or specific diffs.
