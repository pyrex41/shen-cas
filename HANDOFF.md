# Handoff

## Scope expansion + portable hash + in-environment oracle (2026-06-20)

Branch: `claude/shen-cas-scope-positioning-1fmzo8`.

### Portable content hash (cross-port soundness fix)

`content-eq` is hash-keyed, and the host port's `hash` builtin is **not** a safe
basis for it. On ShenScript (Shen-for-JavaScript) `hash` is an order-INSENSITIVE
char sum (`hash "Sinx" == hash "xSin"`), so distinct expressions collide and the
intern table / Orderless sort / dispatch index silently corrupt — guarded
calculus rules then misfire. `store.shen` now computes content hashes with a
self-contained polynomial rolling hash (base 31, large-prime modulus by bounded
power-of-two subtraction — no float/floor), identical and well-distributed on
every Shen port. This also makes genuine cross-port (bifrost) agreement possible.

### Running the suite with no native Shen (ShenScript oracle)

GitHub access is not required. The kernel + full harness run under the
`shen-script` npm package with only Node:

```sh
cd scripts && npm install shen-script@^0.17
cd .. && ulimit -s unlimited && node --stack-size=60000 scripts/shenscript-run.js
```

The CAS evaluator is deeply recursive, so the large `--stack-size` (≈ the 256 MB
the native ports use) is required. Expected tail: `ALL PASS`. The pure-Shen hash
makes the heavy corpus/series phase slow (several minutes) but it completes.

### New capability layers (SymPy-guided breadth, all SOUND > COMPLETE)

Each new builtin returns a result only on its exact domain and otherwise declines
([none]) so the head stays inert — never a wrong/float answer.

- **Elementary & number-theory functions** (`src/numfun.shen`,
  `test/test-numfun.shen`): `Abs Sign Floor Ceiling Round IntegerPart
  FractionalPart Mod Quotient GCD LCM Factorial Binomial Max Min`.
- **Number theory** (`src/numfun.shen`, `test/test-numtheory.shen`): `EvenQ OddQ
  Divisible CoprimeQ PrimeQ NextPrime Prime Fibonacci PowerMod` (bounded
  primality/sequences so they never hang; decline beyond the bound).
- **Elementary differential library** (`boot/elemfun.shen`, `boot/calculus.shen`,
  `test/test-elemlib.shen`): reciprocal-trig + hyperbolic + inverse-hyperbolic
  heads `Cot Csc Sinh Cosh Tanh Coth Sech Csch ArcSinh ArcCosh ArcTanh` with
  exact values, chain-aware derivative rules, and the sound integrals
  ∫Sinh=Cosh, ∫Cosh=Sinh (incl. linear-argument u-substitution). Verified by
  direct `Simplify[D[F]-expected]==0` and differentiate-back.

- **Rational-function integration** (`src/calc-helpers.shen`,
  `test/test-ratint.shen`): for a `Divide[N,D]` integrand — (1) Cancel-then-
  integrate reducible ratios (`(x+1)/(x^2-1) -> Log[x-1]`); (2) quadratic
  denominator, numerator deg ≤ 1: irreducible → complete-the-square →
  `Log + ArcTan` (`1/(x^2+2x+2) -> ArcTan[x+1]`), two distinct rational roots →
  cover-up partial fractions → two `Log`s (`1/(x^2-1)`), the latter verified
  un-foolably by `N == a*(A1 (x-r2) + A2 (x-r1))`. Higher-degree denominators stay
  inert. The test uses a numeric differentiate-back oracle (sample points), which
  verifies Log/ArcTan antiderivatives that Simplify-based diff-back cannot reduce.

- **Partial-fraction integration** (`src/calc-helpers.shen`,
  `test/test-pfrac.shen`): generalizes the rational integrator from "denominator
  degree 2" to denominators with one or more distinct **simple** rational roots
  plus a leftover factor that is a constant or a single **irreducible** quadratic
  (polynomial long division first for improper inputs). Cover-up residues
  `A_r = N(r)/D'(r)` give the `Log[x-r]` terms; the leftover quadratic reuses the
  complete-the-square `Log + ArcTan` path. Examples: `1/(x^3-x) -> -Log[x] +
  (1/2)Log[x-1] + (1/2)Log[x+1]`, `1/(x^3+1) -> (1/3)Log[x+1] - (1/6)Log[x^2-x+1]
  + ArcTan piece`. Every result is verified un-foolably by recombining the
  partial fractions over the common denominator and matching the numerator to N;
  a disc<0 guard keeps repeated/real-root leftovers from misfiring. Degree ≥ 3
  leftovers stay inert. The test uses a self-contained float differentiate-back
  oracle (the ArcTan answer carries `Sqrt[3/4]`, which `reduce` cannot fold).

- **Trigonometric integration** (`boot/calculus.shen`, `test/test-trigint.shen`):
  `register-rule` antiderivatives over the bare variable — `Sec^2 -> Tan`,
  `Csc^2 -> -Cot`, `Sec*Tan -> Sec`, `Csc*Cot -> -Csc`, `Sin*Cos -> (1/2)Sin^2`,
  and power-reduction `Sin^2 -> x/2 - (1/2)Sin*Cos`, `Cos^2 -> x/2 +
  (1/2)Sin*Cos`. The first five verify by Simplify-based differentiate-back; the
  Sin^2/Cos^2 pair (which would need the Pythagorean identity) are checked by
  content-eq against the hand-verified closed form. Product patterns bind both
  factor arguments and guard `And[SameQ,SameQ]` so the Orderless arg order is
  irrelevant.

### Performance: reduce + content-hash memos

`store.shen` memoizes compound content hashes (bucketed table, native-`hash`
bucket index for distribution only, structural-`=` match, cleared on every
structural-sig declaration so it is never stale) and short-circuits `content-eq`
with `=`. `core.shen` adds a per-outermost-reduction memo of `reduce`/
`normal-form` (content-hash keyed; cleared at the outermost entry via the
`*reducing* guard so nested wired-builtin reduces SHARE it; disabled inside Block
forks; guards reset on any escaping error). Interactive reductions are ~3x
faster (the suite reaches the corpus at ~134s vs ~280s); the full harness is
~563s vs ~668s (it is dominated by the reduction-bound differentiate-back
corpus, whose distinct per-case reductions clear the per-call cache).

New RHS heads are whitelisted in `src/rule.shen` (`phase1-globals`); new test
files are wired into `load.shen` and `run-all-tests`.

---

## Final State (prior handoff, 2026-06-18)

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
