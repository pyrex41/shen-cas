# shen-cas

A statically checked, Mathematica-inspired term-rewriting kernel in Shen.

**Status:** Skeleton complete (content store, checked rules, immutable datom db, dispatch index,
scoping, backend seam — SCUD 1–15). Currently being grown from a lookup-table skeleton into a genuine
evaluator with symbolic differentiation and bounded integration (see *How this was built*).

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

3. **Grok — first pass on the SCUD tasks.** Grok took the first implementation pass across the SCUD
   task breakdown, building out the skeleton subsystems and recording its review in
   [`grok_review.md`](grok_review.md).

4. **Graph-page review (first human pass).** The DAG was reviewed through a graph/visualization page,
   walking the tasks node by node to check coverage and ordering.

5. **GPT-5 — review and plan improvement.** GPT-5 reviewed the state of the work and the plan and
   tightened it.

6. **Subagent orchestration.** Implementation tasks ran as parallel subagents in isolated git
   worktrees, each verified against the harness before integration into `main` — see
   [`SUBAGENT-ORCHESTRATION-PLAN.md`](SUBAGENT-ORCHESTRATION-PLAN.md). This produced the skeleton
   through SCUD 1–15, recorded in [`SKELETON_REVIEW.md`](SKELETON_REVIEW.md).

7. **Claude Code — review and the evaluator buildout workflow.** A code review of the running skeleton
   found that the green test bar hid real gaps (`reduce` was a rule-lookup table rather than an
   evaluator, Orderless matching was inert, Flat flattening was silently broken, the backend seam was
   bypassed, and two correctness gates passed only by load-order luck). That review fed a new plan to
   fix the issues and grow the kernel into a real evaluator with symbolic differentiation and a bounded
   integration subset. The plan is being executed by a **harness-gated, wave-by-wave workflow**: each
   wave is implemented in dependency order, gated on the full test harness passing, then verified by a
   parallel adversarial review fan-out (one reviewer on the hard invariants, one on acceptance + Shen
   portability) before the next wave begins, on the `cas-evaluator-buildout` branch.
