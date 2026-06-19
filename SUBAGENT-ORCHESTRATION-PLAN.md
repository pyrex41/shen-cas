# Subagent Orchestration Plan for shen-cas

**Purpose**: Execute the full shen-cas CAS (per plan.md + design.md + sketch.md + ADR in prologue) using massive parallel subagents (spawn_subagent + worktree isolation + implementer/reviewer pairs + background verification) while respecting the SCUD DAG in .scud/tasks/tasks.scg.

**Date of this plan**: 2026-06-18 (continuation of prior wave execution)

## 1. Review Summary (plan.md + tasks.scg + reality)

### plan.md Key Points
- Goal: small, statically-checked, Mathematica-inspired term rewriting kernel. Move CAS bugs from runtime to definition-time rejection.
- Pure-Shen reference evaluator is the spec. All backends must be observationally equivalent.
- Guiding: definition-time checking thesis; structural attrs (Flat/Orderless/OneIdentity) immutable signatures (affect hash pre-construction, db-independent); Prolog only for matching; content-addressed store early.
- Phased:
  - Phase 0: Harness + golden + syntax verification.
  - Phase 1: Content store + expr + patterns (reserved ctors) + checked-rule + first-order match + naive reduce. Rejections for malformed, seq-outside-arg, unbound RHS.
  - Phase 2: Attrs (structural vs control + consistency) + store canonical (Orderless sort, Flat flatten) + match-seq (Prolog) + match-ac + full eval.
  - Phase 3: Immutable db (datoms, basis, pure assert, fork) + normal-form memo (content+basis key) + query dispatch.
  - Phase 4: Dispatch index + cold relations (covers?, unbound-vars, attr-conflicts, oneid-no-unary) + lfp + loops + warn.
  - Phase 5: Scoping (Module/With alpha, Block=db fork).
  - Phase 6: Bootstrap CAS (arith, control-flow, Book 21.4 corpus).
  - Phase 7: Typed reader/printer (defcc or descent; never emit unchecked trees).
  - Phase 8: Backend seam + equivalence harness (post MVP).
- Cross-phase test matrix (static rejection, golden, matcher props, AC/seq invariants, store/basis/memo, analysis, scoping, reader, backend equiv).
- MVP done when: checked rules only reach db; small algebra simplifies correctly; Flat+Orderless on Plus/Times; seq via Prolog; immutable basis db; basis-safe memo; Block isolation; typed reader safe; full suite vs pure ref.

### .scud/tasks/tasks.scg Structure
- @nodes with id, title, status (D/P/I/X), complexity, priority.
- Hierarchical (parents/children): 5:5.1-5.3, 7:7.1-7.2, 8:8.1-8.2, 9:9.1-9.2, 10:10.1-10.2, 11:11.1-11.3, 12:12.1-12.2, 13:13.1-13.2, 14:14.1-14.2.
- @edges (dependent -> dep) enforce topological order.
- @agents suggest tier (builder/planner, fast/standard/smart).
- @details give precise per-task spec + acceptance.
- Current (from scud): ~10/15 top-level D (66%), many subs P (5.2,7.2,8.1,8.2,11.2,13.2,14.1,14.2,15) or I (5.3,7.1,9.2), some X (active cross).
- Waves (scud waves) identify ready parallel sets (deps satisfied + pending).

### Current Code Reality (vs SCUD/plan)
- Store (5.x): Merkle ch, intern, content-hash* (partial canonical-arg-hashes via sigs), cas-intern!, structural-sigs registry (declare/get, has-flat/orderless), content-eq. Good bones; canonical not 100% pre-hash on all paths in every state; 5.2/5.3 marked P/I but partially advanced.
- Expr (6): datatype with [sym X], [int N], [H|Args]; ctors via cas-intern!.
- Pattern (7): seq-pattern + pattern datatypes (reserved blank/named/etc ctors returning tagged lists), compound-pattern (seqs in args), extract-bindings (partial/stub per 7.2 P).
- Rule (8.1 P): rule ctor, free-symbols, phase1-globals, bindings-cover?, checked-rule datatype with side-cond, register-rule (asserts to *db*). Partially complete.
- Match (8.2 P): first-order match + substitute; match-arg-list override hook for seq; some/unwrap. Naive reduce in core.
- Attrs (9.1 D): structural vs control split, consistent?, declare-structural (routes to store sig), valid-attrs datatype. Good.
- Db (10.1 D): list-of-datoms "immutable", empty-db, assert-*, symbol-entry-view, db-basis (stub Merkle), fork stubs. 10.2 D claims integration (core uses dispatch + *db*, normal-form memo key (ch,bh) in some paths, rule reg via assert).
- Query (11): lfp + reach-step + join + direct-deps (from db datoms + RHS heads) + rule-dependency-loops + from-edges helpers + dispatch cache stub + dispatch-candidates (11.1 D). 11.2 P (cold: covers?, unbound-vars, attr-conflicts, oneid-no-unary + warn.shen) still pending.
- Core: reduce (Db-aware via rules-for-expr/dispatch), try-reduce, normal-form (memo), demo paths. Some db integration present post prior.
- Boot/arith (13.1 D): declares structural + multiple register-rule for +0, *1, folding, etc. (uses named+blank forms). 13.2 P for control-flow/expanded corpus.
- Scope (12 D?): gensym, alpha rename hooks for store, Block fork stubs.
- Match-seq/ac: partial (prolog-match-arg-list started, match-ac stub commented in load.shen).
- Harness (test/test.shen + golden): golden-cases (hardcoded, some surface), trivial-reduce path dominant, attrs-demo, run-lfp-tests (enhanced with pairs + real db loops), rejection-fixtures (declarative only, not live enforced yet), phase1 property attempts (hash sharing etc). Many enhancements from prior reviewers. Full real reduce + live rejection + roundtrips not yet green end-to-end.
- Load: brittle (order: store/expr/pattern/db/rule/attrs/query/match/core/...; match-ac often disabled; ctor "not legitimate" / side-cond issues on full load; prolog patterns).
- Git: clean main; prior worktrees (many 019edc... IDs) cleaned/merged via cherry + manual port + harness fixes. Commits show heavy prior subagent activity (11.x, 10.2, 13.1, reviewers).

**Gaps to close for MVP**:
- Finish canonical ctors/5.2 + sigs so hashes stable+sharing for Orderless/Flat pre any rules.
- extract-bindings complete + full 7.2.
- 8.x: ensure first-order match + reduce fully wired, bindings gate strong, naive reduce idempotent on golden via real path.
- 11.2: covers?, unbound, attr-conflicts, oneid-no-unary (plain Shen over db/symbol-entry-view), + warn.shen surface at reg time.
- Full integration: real reduce used in golden/harness; live static rejections (load/registration traps or datatype enforcement).
- 13.2 + 14.x + 15.
- Load health as cross-cutting (partial loads + targeted tests + ctor hygiene).
- Full matrix (seq/AC props, basis isolation, no-stale-memo, reader safety).

Invariants (never weaken in any subagent):
- Pure ref evaluator = spec (design §4).
- Hashes db-independent (structural sigs + alpha only; rule equalities never folded).
- Seq patterns only in arg position.
- Structural attrs immutable after first construction/use.
- Accumulate-only db; fork isolation (parent unchanged).
- Checked rules only; bindings-cover at definition/registration time.
- (normal-form Db E) == (reduce Db E); new basis never stale.
- Dispatch over-approx only (never misses matchable rule).

## 2. Subagent Orchestration Principles

**Volume + Parallelism First**
- Use `scud waves` (and scud next) as primary signal for ready independent work.
- Spawn many subagents concurrently (target 6-12+ active + bg monitors).
- Prefer fine-grained when edges allow (use scud expand on complex P tasks).
- Non-strict: safe to advance non-overlapping later-wave work (e.g. reader experiments, corpus expansion, extra property tests, load-doctor) while earlier finish.

**Isolation**
- Every impl subagent gets a dedicated git worktree: `git worktree add -b wt-scud-<id>-<uuidshort> .worktrees/wt-<id>`.
- Subagent prompt MUST instruct: `cd` into the worktree; edit only relevant files for this task; do not touch main.
- Reviewers can run on the WT branch or on produced commits/diffs (via main's fetch).

**Roles (specialize prompts)**
- Builder/implementer (per @agents tier: standard or smart).
- Reviewer (1-3 per impl): focus areas e.g. hash-invariants, db-isolation, match/seq/AC props, analysis soundness (covers etc vs brute), harness additions + green run, load-health.
- Specialists: "prolog-matcher", "reader-experimenter" (parallel defcc vs recursive descent), "corpus-author", "load-doctor" (sole job: make full load + harness exercise real paths cleanly), "property-tester" (generate/enhance matrix tests).
- Reconciler/integrator (rare; main usually does or small targeted sub).
- Verifier (post-integration on main): full matrix run.

**Prompt Discipline for Every Spawn**
- Paste: task id + full description from SCUD @details + relevant plan phase + design excerpts + notes/syntax-verification policies.
- List exact acceptance criteria from plan + SCUD.
- "Stay narrowly scoped to this deliverable. Do not refactor unrelated. Preserve load order compatibility."
- "Add or update tests (in test/ or inline) that demonstrate the acceptance."
- "Run targeted (load ...) + (trap-error ...) + specific fns; report output."
- Embed the invariants list above.
- "On completion: git status, produce clear commit message starting [SCUD <id>], or leave patch notes."
- For reviewers: "Read the diff or changed files + relevant prior code. Check ONLY the listed invariants + task acceptance. Report severity. Suggest minimal fixes."

**Mechanics (this orchestrator + tools)**
- Spawn via `spawn_subagent` (prompt rich, description short, background true for volume; capture subagent_id).
- Poll status/output: `get_command_or_subagent_output` (use block when waiting key results).
- Background monitors: `run_terminal_command` with `background:true` for `timeout 30s shen-sbcl ... -l load.shen` or targeted module tests; use `monitor` tool for streaming logs if desired. Kill via kill_command_or_subagent when done.
- Integration protocol (after success):
  1. From main: `git fetch <worktree-path-or-remote-ref>`.
  2. `git cherry-pick <sha>` (or `git diff <base>..<wt> | patch -p1` for uncommitted).
  3. Reconcile overlaps (use knowledge from all subs + prior SKELETON_REVIEW style).
  4. Run full/ targeted tests in main (bg or foreground).
  5. `scud set-status <id> done` (or in-progress/review as appropriate).
  6. `scud commit -m "[SCUD <id>] ..."` if it fits.
  7. Clean: `git worktree remove ...`; prune.
- Fail/recovery: capture full output, analyze, `spawn_subagent` with `resume_from: <prior-id>` + prompt "Incorporate these issues from run and review: <verbatim errors + reviewer points>. Fix and re-verify."
- Overlap handling (historical pattern): main manually ports logic from sub outputs + applies common fixes (ctor hygiene, load reorders, protect/compound, assoc guards, headed-by-sym, RHS sym vs expr, protect+compound in tests). Avoid re-running identical failing env.
- SCUD hygiene: after integration + green, advance status. Keep statuses honest (P items with partial code become "complete the acceptance criteria").
- Use `scud heavy` for hard cross-cutting design calls.
- Prefer raw spawn_subagent for volume/control (vs bundled execute-plan/implement unless doing a full PR DAG).

**Background + Verification Always**
- While subs run: multiple shen load attempts (partial paths first: store+expr+attrs; then +db+rule+query; full load).
- Exercise: attrs-demo, run-lfp-tests, phase1 hash/golden/idemp props, demo-reduce, specific cold relations once 11.2, reader experiments.
- Add `trap-error` + timeout + tail in harness calls for robustness.
- Post-wave: dedicated verifier subagents or main run of complete matrix.

**Parallelism Levers (beyond SCUD waves)**
- Test amplification independent (new golden cases, brute-force refs for seq splits / covers / oneid / loops / hash sharing, live rejection harness).
- Reader: two parallel agents (typed defcc YACC path + pure recursive descent) on separate WTs; main picks/integrates winner + roundtrips.
- Corpus: 13.2 + extra Book cases + control-flow (If) can proceed once core registration stable.
- Load-doctor swarm: one or more agents whose ONLY mission is ctor legitimacy, datatype ordering, minimal load.shen fixes, targeted test helpers.
- Warn.shen + integration of 11.2 can be separate from core 11.2 impl.
- Scope 12 polish + alpha tests if gaps.
- 15 backend seam early (parameterize current-core) even if perf deferred.
- Docs/notes updates as low-prio fillers.

## 3. Concrete Wave / Cluster Strategy

Use `scud waves` output as baseline. Opportunistic:

**Immediate Ready (example Wave 1 from last scud)**: 5.2, 7.2, 8.1, 11.2, 13.2, 14.1, 15 (plus any I that are ready to finish).

Suggested concurrent clusters (minimal file overlap):
- Cluster Store/Canonical (5.2 + 5.3 complete): 1 builder + 1 hash-invariants reviewer + load-doctor helper.
- Cluster Pattern/Rule First-Order (7.2 + 8.1): builder(s), bindings/matcher reviewer.
- Cluster Cold Analysis (11.2): builder (plain relations over db + symbol-entry-view + oneid brute compare), + analysis reviewer + warn integration.
- Cluster Corpus (13.2): corpus author (control flow If + algebra cases + idempotence), light harness touch.
- Cluster Reader Start (14.1): two parallel (YACC vs descent) + parse safety reviewer.
- 15 (backend harness) can start skeleton early (parameterize reduce/normal-form) in parallel if it doesn't conflict.
- Follow-on (after 8.1): 8.2 (matcher + naive reduce completion + golden via real path).
- Follow-on (after 14.1): 14.2 (printer + roundtrips).
- Always-on: load-doctor + property test expander + verifier.

**Per-Task Micro-Plan Template** (in spawn prompt + scud):
- Read full @details.
- Implement the narrow contract.
- Add 1+ executable test demonstrating it (prefer extension to existing run-* fns).
- Verify against plan Phase acceptance.
- For 11.2 specifically: covers? (LHS covers all cases?), unbound-vars, attr-conflicts (local+cross?), oneid-no-unary (matches brute set-diff or warning), using real db where possible.
- For canonical 5.2: constructors route intern + consult sigs; O(1) = via hash; identical structures share; post-Orderless/Flat declare, content-eq holds and nested Flat shares; no rule-driven in hash.
- Enforce in reviewers.

**After Each Cluster**:
- Integrate batch.
- Full load attempt + harness run (golden exercising real reduce, lfp, attrs, any new relations).
- Update SCUD.
- If red: dedicated fix subagent(s) or resume.

**MVP Final Swarm**:
- 3-5 verifiers on full suite + matrix.
- One "MVP checklist" agent that walks plan.md Appendix/Phase acceptance + cross-matrix and produces pass/fail report + any remaining stubs.
- scud stats 100%, final tagged commit.

## 4. Historical Lessons (to embed in every prompt + orchestrator behavior)

From SKELETON_REVIEW + prior subagent rollouts (019edc... series):
- Shen ctor/datatype load order is the #1 failure mode ("not a legitimate constructor", side-cond processing, arity). Fix pattern: standardize on `[sym S]` bracket lists everywhere in datatypes + ctors; define ctors before or carefully after datatype; move datatype decls early; use protect for globals; partial loads for verification.
- WTs disappear after completion: always capture full logic in sub output or commit in WT; main ports by reading outputs + applying.
- Harness was repeatedly the hero: reviewers forced golden assert real reduce, protect+compound fixes, headed-by-sym fix, restore missing phase1 tests. Always enhance harness as part of or immediately after impl.
- Over-approx dispatch ok; under-approx forbidden.
- lfp pure + terminates on cycles (self/mutual); test with direct-deps-from-pairs + real db rule loops.
- Orderless/Flat in boot + 0+x works only after canonical + match-ac + attrs full.
- Mixed reps (bare sym vs [sym S], named RHS expr vs pattern) caused silent passes; enforce sym forms and content.
- Main integration often requires small global hygiene (load order in load.shen, assoc vs element for sigs, filter local defs).
- Do not mark SCUD done until acceptance demonstrably passes (not just "code written").
- Background shen attempts + trap-error save time.

## 5. Tooling & Commands Reference (for orchestrator)

- SCUD: `scud warmup`, `scud waves`, `scud next`, `scud show <id>`, `scud set-status <id> <status>`, `scud commit -m "..."`, `scud stats`, `scud list --status pending`.
- Git isolation: `git worktree add ...`, `git fetch <wt>`, `git cherry-pick`, `git worktree remove`, `git prune`.
- Spawn: `spawn_subagent` (prompt=..., subagent_type or use default, background, resume_from).
- Observe: `get_command_or_subagent_output <id>`, run_terminal_command (bg for loads), monitor.
- Shen verification (examples):
  ```
  timeout 12s shen-sbcl 2>&1 << 'EOT' | tail -30
  (load "src/store.shen") (load "src/expr.shen") ...
  (do (demo-register-arith) (output "db size ~A~%" (db-size (value *db*))) ...)
  EOT
  ```
- Targeted: load subsets + call specific (attrs-demo []), (run-lfp-tests []), (run-phase1-...), (reduce ...).
- Kill stray: kill_command_or_subagent.

## 6. Risks & Mitigations

- Env/ctor fragility: load-doctor + partial loads + trap-error + standardize AST.
- Status drift: explicit sync step after every integration.
- Overlap: module-scoped tasks + main reconciliation gate.
- Long-running subs: background + periodic poll + timeout guards.
- "Works in WT, not main": always re-test full load + real paths post-cherry.
- Scope creep: strict "this SCUD id only" in prompts.

## 7. Immediate Next (to launch lots of subagents)

1. Re-sync SCUD reality (review each P/I vs code; decide "finish acceptance" tasks).
2. Launch load-doctor agent (cross-cutting, high value).
3. Launch current wave cluster (e.g. 5.2 canonical + 11.2 cold relations + 8.1 checked-rule polish + 7.2 extract + 13.2 corpus + reader starter) — 1 builder + reviewer each.
4. Background: 2-3 shen load/test monitors.
5. Poll, integrate successful, resume fails, advance waves.
6. Repeat until MVP green.

## 8. Success Definition for This Meta-Plan

- All SCUD nodes D.
- Full (load "load.shen") succeeds cleanly.
- Harness exercises real reduce/normal-form on golden + reports passes.
- Live static rejection for key cases.
- All plan Phase acceptance + cross-matrix green.
- Many (dozens) subagent runs (success + reviewer) visible in history.
- Clean main, documented.

**This plan is the blueprint. Execute by claiming waves via scud, spawning clusters via spawn_subagent (with worktrees), verifying via harness + bg shen, integrating, advancing.**

See also: plan.md, .scud/tasks/tasks.scg, design.md, notes/syntax-verification.md, SKELETON_REVIEW.md (historical), load.shen, test/test.shen.
