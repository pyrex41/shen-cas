# shen-cas

A statically checked, Mathematica-inspired term-rewriting kernel in Shen.

**Status:** Working evaluator. On top of the skeleton (content store, checked rules, immutable datom db,
dispatch index, scoping, backend seam — SCUD 1–15), the kernel now has a genuine ordered evaluation
sequence with wired arithmetic, exact rationals, sound sequence/AC matching, a simplifier, **symbolic
differentiation**, and a **bounded symbolic integration** subset (SCUD 16–22, on the
`cas-evaluator-buildout` branch). Rule registration is statically checked at definition time, and the
rejection suite is executable. Harness: `Golden: 12/12 passed`, `ALL PASS`. See *How this was built*.

See [plan.md](plan.md) for the full roadmap, phases, module layout, and verification strategy.

See [.scud/tasks/tasks.scg](.scud/tasks/tasks.scg) for the live SCUD DAG (use `scud` CLI).

Core value: move common CAS rule bugs (malformed patterns, unbound RHS, bad attrs, etc.) from runtime surprises to definition-time rejection via Shen's sequent-calculus datatypes.

Pure-Shen reference evaluator is the specification.

## Quick Start (once built)

```shen
(load "load.shen")
# or equivalent
```

Run tests via the harness in test.shen.

## Layout

- src/ (or root modules): store.shen, expr.shen, ...
- test/ : test.shen harness
- golden/ : `input -> expected` cases
- notes/ : syntax verification, decisions
- boot/ : bootstrap rule libraries
- plan.md + design.md + sketch.md for specs

## How this was built

This kernel was built through a multi-stage, multi-model pipeline rather than written by hand top to
bottom. The stages, in order:

1. **Design documents.** The architecture was specified first, in prose, before any code:
   - [`plan.md`](plan.md) — roadmap, phases, module layout, MVP acceptance.
   - [`design.md`](design.md) — the kernel spec: content-addressing, immutable datom db, evaluation
     core seam, attribute model, matcher.
   - [`sketch.md`](sketch.md) — concrete Shen sketches of each subsystem.
   - [`prologue+datalogue_decision.md`](prologue+datalogue_decision.md) — ADR-001: the tiered
     Prolog-for-matching / native-indexing-and-`lfp`-for-analysis decision.
   - [`notes/syntax-verification.md`](notes/syntax-verification.md) — Phase-0 verification of Shen
     datatype syntax and the locked hashing/numeric policies.
   - [`book_of_shen_cas_relevant.md`](book_of_shen_cas_relevant.md) — distilled Book-of-Shen features
     the design leans on.

2. **SCUD task DAG.** The work was decomposed into a dependency graph of tasks in
   [`.scud/tasks/tasks.scg`](.scud/tasks/tasks.scg) (managed with the `scud` CLI: waves, next-task,
   status). Each task carried its own acceptance criteria and invariants.

3. **GPT-5 — review of the SCUD tasks (before implementation).** GPT-5 reviewed and tightened the SCUD
   task breakdown before any implementation pass began.

4. **Grok — first implementation pass.** Grok took the first pass at the SCUD tasks, building out the
   skeleton subsystems. Implementation ran as parallel subagents in isolated git worktrees, each
   verified against the harness before integration into `main` — see
   [`SUBAGENT-ORCHESTRATION-PLAN.md`](SUBAGENT-ORCHESTRATION-PLAN.md) and
   [`grok_review.md`](grok_review.md).

5. **GPT-5 — review of the implementation (after Grok).** GPT-5 then reviewed Grok's implementation
   and fixed a large number of issues so the kernel actually loaded and ran; the resulting skeleton
   state (SCUD 1–15) is captured in [`SKELETON_REVIEW.md`](SKELETON_REVIEW.md).

6. **Claude Code — review and the evaluator buildout workflow.** A code review of the running skeleton
   found that the green test bar hid real gaps (`reduce` was a rule-lookup table rather than an
   evaluator, Orderless matching was inert, Flat flattening was silently broken, the backend seam was
   bypassed, and two correctness gates passed only by load-order luck). That review fed a new plan to
   fix the issues and grow the kernel into a real evaluator with symbolic differentiation and a bounded
   integration subset. The plan was executed by a **harness-gated, wave-by-wave workflow** (SCUD 16–22):
   each wave implemented in dependency order, gated on the full test harness passing, then verified by a
   parallel adversarial review fan-out (one reviewer on the hard invariants, one on acceptance + Shen
   portability) before the next wave. The fan-out caught a post-fix arithmetic-overflow hang during Wave 1;
   a follow-up pass then fixed two thesis-critical soundness bugs the buildout surfaced — non-linear
   pattern variables (`f[x_,x_]` was matching `f[1,2]`) and lax rule registration (a non-symbol-headed
   LHS could enter the db) — and made the definition-time rejection suite executable. All on the
   `cas-evaluator-buildout` branch.
