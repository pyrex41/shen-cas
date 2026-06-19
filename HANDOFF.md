# Handoff

Date: 2026-06-18

## Current State

The repo is a Shen CAS kernel prototype: a Mathematica-inspired term rewriting system with content hashes, checked rules, structural attributes, sequence/AC matching, an immutable db skeleton, arithmetic/simplification, and early symbolic differentiation.

The current main tree loads and the test harness passes on `shen-go`.

Use this port:

```sh
/Users/reuben/projects/shen/shen-go/shen
```

Run:

```sh
python3 - <<'PY'
import subprocess
p = subprocess.run(
    ['/Users/reuben/projects/shen/shen-go/shen'],
    input='(load "load.shen")\n',
    text=True,
    capture_output=True,
    timeout=25,
    cwd='/Users/reuben/projects/shen/shen-cas',
)
print(p.stdout)
print(p.stderr)
PY
```

Expected current result:

- `Golden: 12/12 passed`
- `ALL PASS`

The harness also exercises SCUD 16-20 paths: evaluator sequence, exact rationals, sequence matching, AC matching, guards/predicates, simplification, and symbolic differentiation.

## Work Completed In This Session

- Fixed `load.shen` runtime blockers on `shen-go`.
- Standardized several higher-order uses to lambdas because this Shen port does not apply bare function names as values in those contexts.
- Made the backend seam route by tag via `reduce-via` / `normal-form-via`, avoiding unsupported returned-function application.
- Added a small compatibility `filter` helper in `src/db.shen`.
- Reworked DB basis hashing to use recursive `basis-token` instead of `(str ...)` on pair/list objects.
- Removed invalid `Flat` structural declaration from `Minus`.
- Ensured arithmetic bootstrap is idempotent via `boot-declare-structural`.
- Kept `match-ac.shen` and `match-seq.shen` loadable in the correct override order.
- Verified the full harness with `shen-go`.
- Reviewed the current work after later subagent progress and identified remaining correctness issues below.

## Important Files

- `plan.md`: phased implementation plan.
- `.scud/tasks/tasks.scg`: task graph and status.
- `design.md`, `sketch.md`, `prologue+datalogue_decision.md`: design context.
- `load.shen`: top-level loader, load order is significant.
- `test/test.shen`: full harness, auto-runs on load.
- `src/core.shen`: evaluator and backend seam.
- `src/match.shen`, `src/match-seq.shen`, `src/match-ac.shen`: first-order, sequence, and AC matching.
- `src/rule.shen`: rule construction/registration and binding coverage.
- `src/store.shen`: content hashing and structural signatures.
- `src/db.shen`, `src/query.shen`, `src/warn.shen`: db and analysis layer.
- `boot/arith.shen`, `boot/simplify.shen`, `boot/elemfun.shen`, `boot/calculus.shen`: bootstrap rule libraries.

## Review Findings To Fix Next

### P0: repeated pattern variables are unsound

`src/match.shen` currently allows conflicting repeated bindings.

Observed probe:

```shen
(match [[sym Fdup] (named x (blank)) (named x (blank))]
       [[sym Fdup] [int 1] [int 2]])
```

This returns a successful match with both `x -> 1` and `x -> 2`, and a rule like `Fdup[x_, x_] -> x` rewrites `Fdup[1,2]` to `1`.

Fix: when matching `[named Name P]`, if `Name` is already bound, require `content-eq` between the old value and the new value. Otherwise return `match-none`.

Add regression tests:

- `f[x_, x_]` matches `f[1,1]`.
- `f[x_, x_]` does not match `f[1,2]`.
- Sequence bindings should obey the same repeated-name rule.

### P0: malformed rules can enter the DB

`checked-rule?` in `src/rule.shen` is only a tag/shape check:

```shen
(define checked-rule?
  [rule Lhs Rhs] -> true
  X -> false)
```

Observed probe:

```shen
(register-rule [rule [int 1] [int 2]])
```

This succeeds and increments the DB rule count.

Fix: make `checked-rule?` validate:

- LHS is a pattern.
- RHS is an expr.
- `bindings-cover?` is true.

Or split the predicates into `rule-shape?` and strict `checked-rule?`.

Add live rejection tests for malformed rules.

### P1: structural signature policy drift

Current tests intentionally allow hashing a compound before declaring the head `Flat`/`Orderless`, then declaring the structural attrs later. That contradicts the earlier invariant that structural attrs are immutable creation facts consulted before construction/hash.

Choose and encode one policy:

- Recommended: first construction/hash freezes an empty structural signature, and later structural declaration fails.
- Alternative: require explicit symbol declaration before any construction/hash and reject undeclared structural heads.

Update `test/test.shen` SCUD 16a accordingly.

### P1: rejection tests are fixtures only

`run-rejection-tests` currently prints fixture names and returns `true`. The green harness does not prove malformed patterns, seq-outside-arg, unbound RHS, or bad attrs are rejected by live code.

Convert these to `trap-error` assertions against real constructors, `register-rule`, and reader paths.

## Notes On Current Harness

The harness is broad and useful, but a green `ALL PASS` currently does not prove the static-checking thesis because the rejection fixtures are not live and malformed rules can still register.

Current known expected warning during passing run:

- `bindings-cover? failed unbound: [y]` appears as an intentional negative fixture.
- `WARNING: *max-eval-steps* exceeded...` appears in the loop termination test.
- Int64 overflow warnings appear in rationals/overflow tests.

## Git / Workspace Notes

At last check, the main source tree showed no tracked diffs, but there were untracked artifacts:

- `.claude/tracking/`
- `.claude/workflows/`
- `.worktrees/`
- `SKELETON_REVIEW.md`
- `SUBAGENT-ORCHESTRATION-PLAN.md`

This `HANDOFF.md` is newly added and untracked.

Do not assume `SKELETON_REVIEW.md` reflects the latest code; it was stale relative to the current green SCUD 16-20 harness.

## Suggested Next Step

Fix the two P0 issues first:

1. Enforce repeated-name binding consistency in matcher/substitution.
2. Make `checked-rule?` semantically strict and add live rejection tests.

Then revisit the structural signature policy and convert rejection fixtures into executable tests.
