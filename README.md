# shen-cas

A statically checked, Mathematica-inspired term-rewriting kernel in Shen.

**Status:** Early implementation (Phase 0 harness + structure).

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
