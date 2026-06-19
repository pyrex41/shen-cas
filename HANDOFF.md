# Handoff

Date: 2026-06-18

## Final State

The active branch is `cas-evaluator-buildout`.

At the time this note was refreshed, the branch was clean and 13 commits ahead of `main`, with:

- `aa3321e` - docs: mark evaluator buildout complete (SCUD 16-22 + P0 fixes)
- `23cb26a` - [SCUD 22] Wave 6: executable rejection fixtures + calculus corpus showcase
- `26dd034` - fix(P0): sound matcher + strict rule registration
- `ceecf12` - [SCUD 21] Wave 5: bounded symbolic integration in `boot/calculus.shen`
- `53c3b51` - [SCUD 20] Wave 4 symbolic differentiation
- `efc272c` - [SCUD 19] Wave 3 simplify
- `8166885` - [SCUD 17] fix saturating int64 arithmetic hang
- `2248a62` - [SCUD 17] Wave 1 evaluator + sound matching + exact rationals
- `5a63f09` - [SCUD 16] Wave 0 correctness gate

The project loads cleanly with no redefinition noise on `shen-go`.

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
- No redefinition noise

## What Shipped

All seven evaluator buildout waves landed on `cas-evaluator-buildout`.

| Wave | SCUD | What shipped |
| --- | --- | --- |
| 0 - Correctness gate | 16 | Structural signature policy hardening, checked-rule de-duplication, real tag-dispatch backend seam, strict-and/load hygiene, control attributes stored in the db. |
| 1 - Evaluator | 17 | Full ordered evaluation sequence, wired arithmetic (`Plus[7,8] -> 15`), exact rationals, sound sequence matching, sound AC matching, and deletion of old lookup-table arithmetic rules. |
| 2 - Matcher prerequisites | 18 | `ptest`, condition tests that reduce before truth checking, and wired predicates `SameQ`, `UnsameQ`, `FreeQ`, `NumberQ`, and related helpers. |
| 3 - Simplify | 19 | Identity, zero, and power simplification rules, `Simplify`/collect-like-terms, idempotence checks, and evaluator fuel caps. |
| 4 - Differentiation | 20 | `D` rule library for linearity, product, quotient normalization, power, and chain rules over elementary functions. |
| 5 - Integration | 21 | Bounded symbolic integration: exact table, linearity, u-substitution, depth-capped integration by parts, and inert behavior for unknown/out-of-scope forms. |
| 6 - Corpora | 22 | Executable rejection fixtures and calculus showcase corpus. |

## Thesis-Critical Fixes

Two soundness bugs surfaced during review and are now fixed and verified in `26dd034`.

### P0-1: repeated pattern variables

Non-linear patterns now bind consistently:

- `f[x_, x_]` matches `f[1,1]`.
- `f[x_, x_]` does not match `f[1,2]`.
- Orderless and sequence search backtrack on binding conflicts instead of accepting contradictory bindings.

This fixes the earlier bug where a repeated binding could silently rewrite `Fdup[1,2]` to `1`.

### P0-2: strict checked rules

`checked-rule?` now rejects malformed rule shapes at registration time.

The previously accepted bad form is now rejected:

```shen
[rule [int 1] [int 2]]
```

Rules must have a compound LHS and pass the checked-rule/binding coverage surface before they enter the db.

## Additional Hardening

- `8166885` fixed an arithmetic overflow hang: saturating int64 arithmetic now aborts before entering rational normalization/gcd paths that could hang.
- Executable rejection fixtures now exist; they are no longer print-only placeholders.
- The old review concern that `ALL PASS` could be vacuous is substantially addressed by live rejection, matcher, evaluator, simplification, differentiation, and integration corpus checks.
- Session artifacts are cleaned/ignored; `git status` was clean before this handoff refresh.

## Important Files

- `plan.md`: phased implementation plan.
- `.scud/tasks/tasks.scg`: task graph and status.
- `design.md`, `sketch.md`, `prologue+datalogue_decision.md`: design context.
- `load.shen`: top-level loader; load order is significant.
- `test/test.shen`: full harness; auto-runs on load.
- `src/core.shen`: ordered evaluator, fuel guards, and backend seam.
- `src/match.shen`, `src/match-seq.shen`, `src/match-ac.shen`: first-order, sequence, and AC matching.
- `src/rule.shen`: checked rule construction/registration and binding coverage.
- `src/store.shen`: content hashing and structural signatures.
- `src/db.shen`, `src/query.shen`, `src/warn.shen`: db and analysis/warning layer.
- `src/calc-helpers.shen`: wired predicates and `Simplify` helpers.
- `src/num.shen`: exact integers/rationals and arithmetic overflow handling.
- `boot/arith.shen`, `boot/simplify.shen`, `boot/elemfun.shen`, `boot/calculus.shen`: bootstrap CAS rule libraries.

## Honest Caveat

The differentiation and integration corpora are real and pass the current checks, including the differentiate-back style checks for the integration subset. The integration subsystem is intentionally bounded: it returns expressions inert/unevaluated outside the supported table, linearity, u-substitution, and depth-capped integration-by-parts patterns. For example, an unsupported form such as `Integrate[Sin[x^2], x]` should remain inert by design.

## Open Decision

Everything is on `cas-evaluator-buildout`. It has not been merged into `main` or pushed by this note.

Next decision:

1. Merge `cas-evaluator-buildout` into `main`.
2. Push `cas-evaluator-buildout` as a branch for review.
3. Leave it on the branch for now.

Do not merge or push without an explicit request.
