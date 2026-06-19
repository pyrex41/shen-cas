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

## Current Seed Shape

The default harness runs every case that matches the current kernel and quietly
counts the skipped frontier. Current coverage (run the full harness for live numbers):

- Rubi (54 cases, ~33 active): elementary integration `pass` cases (powers,
  polynomials, trig/exp table, by-parts `x*Exp[x]`) and `inert` cases for
  integrands the bounded integrator declines (Fresnel/`Sin[x^2]`, `Log`, `Tan`,
  `1/(1+x^2)`, `1/(x+1)`, `Sqrt[x]`, ...). Frontier (skipped): linear-argument
  u-substitution, trig powers, rational functions, radicals, inverse trig,
  special functions, piecewise, definite integrals.
- SymPy (64 cases, ~57 active): arithmetic/rational normalization, `Expand`,
  `Factor`, `Cancel`, `Together`, `Solve` (linear/quadratic/factorable cubic),
  differentiation (incl. `Tan`/`Log`/chain), `Series` (Exp/Sin), `Limit`
  (`Sin[x]/x`), and parser/printer round-trips. Frontier (skipped): trig/abs
  `Simplify` identities, limits at infinity, matrices, assumptions, piecewise,
  and special functions.

## License Notes

Permissive corpora such as Rubi, SymPy, and SymEngine can be vendored in curated
form as long as license notices are retained. GPL/LGPL suites such as Maxima,
Sage, and Symja are useful references, but derived test files should not be
vendored without an explicit repository licensing decision.
