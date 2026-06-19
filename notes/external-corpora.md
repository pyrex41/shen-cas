# External CAS Test Corpora

This project uses external CAS suites as curated test inputs, not as wholesale
foreign harnesses. Imported cases should keep source metadata close to the data,
and runners should distinguish supported behavior from intentionally inert or
known-unsupported behavior.

## Primary Sources

### Rubi MathematicaSyntaxTestSuite

- Source: https://github.com/RuleBasedIntegration/MathematicaSyntaxTestSuite
- License: MIT License
- Intended use here: integration stress cases.
- Import policy: start with small elementary subsets and verify by property:
  `Simplify[D[Integrate[f,x],x] - f] == 0`.

Rubi's full suite is far beyond the current bounded integrator. Unsupported
cases should be recorded as unsupported or inert rather than treated as failures.

### SymPy

- Source: https://github.com/sympy/sympy
- License: New BSD License
- Intended use here: algebra, simplification, parser/printer, and canonical-form
  edge cases.
- Import policy: curate small expression pairs into this project's internal
  syntax. Avoid assuming SymPy's exact printed form is our normal form.

## Case Modes

- `pass`: current kernel should satisfy the check.
- `inert`: current kernel should leave the expression unevaluated by design.
- `unsupported`: useful future case, intentionally skipped by the runner.
- `parser`: parser/printer round-trip case.
- `oracle`: optional future case checked against an external oracle, not part of
  the deterministic default harness.

## Optional Cross-Oracle Workflow

`scripts/oracle_corpus.py` is an opt-in helper for growing the curated corpus
without making Python, SymPy, Rubi, or a particular Shen executable part of the
default harness. Its default mode only classifies candidate cases and requires
the Python standard library:

```sh
python3 scripts/oracle_corpus.py
```

The sample candidate file is `scripts/oracle-cases.sample.json`. Each case
declares its `source`, `feature`, `mode`, Shen input string, and optionally a
`sympy_expr` used by oracle comparison. Candidate modes map to the default Shen
corpus policy:

- `pass`: reduce in Shen, compute the corresponding SymPy oracle, and compare
  mathematical equivalence for the supported fragment.
- `inert`: reduce in Shen and check that the expression keeps the same outer
  head, showing the kernel declined the case safely.
- `unsupported`: list the case as frontier coverage but do not execute it.

To run the optional comparison, install SymPy separately and point the script at
a Shen executable if it is not at the local development default:

```sh
SHEN=/path/to/shen python3 scripts/oracle_corpus.py --compare-sympy
```

The comparison path loads the kernel modules and calculus boot rules directly;
it does not call `load.shen` or participate in the default harness.

This comparison deliberately covers only conservative fragments (`simplify`,
`expand`, `factor`, `diff`, and `integrate`) where the script has a small,
explicit translation into SymPy. More complex Rubi/SymPy material should first
enter the sample file as `unsupported` or `inert`. Once a candidate is trusted,
rewrite it as a Shen-native case in `test/test-external-corpus.shen` with a
project-owned oracle and keep the external source metadata.

## Coverage Policy

Every feature the kernel actually implements has a live `pass` (or `inert`) case
with a sound oracle; everything not yet implemented is marked `unsupported`
(skipped, tracked as the frontier). As a feature lands, flip its frontier cases
to `pass`/`inert` and re-run the full harness. Oracles by feature:

- `integrate`/`pass`: differentiate-back, `Simplify[D[Integrate[f,x],x] - f] == 0`.
- `solve`/`pass`: every returned root substituted back into the equation reduces to 0.
- `expand`/`factor`/`cancel`/`together`/`series`/`diff`/`simplify` `pass`:
  `reduce(Input)` content-eq `reduce(Expected)` (canonical, orderless-invariant).
- `<op>`/`inert`: `reduce` leaves the expression unevaluated (a no-op).
- `parser`/`pass`: `print-expr` o `parse-expr-string` round-trips.

## Grouping Policy

External cases are still stored as simple `external-case` records, but the
default runner now wraps them in `external-case-group` buckets. Group names are
stable, grep-friendly labels such as `Rubi/integrate-trig`,
`Rubi/integrate-rational`, `SymPy/simplify-assumptions`, `SymPy/series`,
`SymPy/limits`, `SymPy/solve`, and `SymPy/parser`.

`unsupported` cases remain skip-before-parse entries. That keeps the default
harness deterministic while allowing frontier syntax that the reader or kernel
does not support yet. When a category is implemented, ungate only that bucket's
cases by changing individual modes to `pass` or `inert` and adding a sound
oracle expectation where needed.

## Current Seed Shape

The default harness runs every case that matches the current kernel and quietly
counts the skipped frontier. Current coverage (run the full harness for live numbers):

- Rubi (62 cases, 35 active): elementary integration `pass` cases (powers,
  polynomials, trig/exp table, by-parts `x*Exp[x]`), linear-argument
  u-substitution, and a few rational/radical cases the current kernel can prove
  by differentiate-back. The active inert group covers integrands the bounded
  integrator declines quickly. Frontier buckets are `integrate-trig`,
  `integrate-rational`, `integrate-radicals`, `integrate-inverse-trig`,
  `integrate-special`, and `integrate-piecewise-definite`.
- SymPy (82 cases, 61 active): arithmetic/rational normalization, `Expand`,
  `Factor`, `Cancel`, `Together`, `Solve` (linear/quadratic/factorable cubic),
  differentiation (incl. `Tan`/`Log`/chain), `Series` (Exp/Sin), `Limit`
  (`Sin[x]/x`), parser/printer round-trips, inert simplification identities, and
  inert integration checks. Frontier buckets include `solve`, `series`,
  `limits`, `parser`, `simplify-assumptions`, and
  `matrix-piecewise-special`.

## License Notes

Permissive corpora such as Rubi, SymPy, and SymEngine can be vendored in curated
form as long as license notices are retained. GPL/LGPL suites such as Maxima,
Sage, and Symja are useful references, but derived test files should not be
vendored without an explicit repository licensing decision.
