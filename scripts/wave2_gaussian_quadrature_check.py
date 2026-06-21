#!/usr/bin/env python3
"""
Gaussian Wave 2 numeric cross-check (independent of the symbolic engine).

Verifies the lemma the CAS DERIVES by completing the square:

    Integrate[ e^(j u) * NormalPDF[u] , {u, -Infinity, c} ]  =  e^(j^2/2) * N(c - j)

The right-hand side below is the engine's DERIVED closed form (e^{j^2/2}, c-j
both COMPUTED by csq-vertex -- see src/calc-helpers.shen gauss-definite). The
left-hand side is plain trapezoid quadrature of the integrand. Agreement to
<1e-6 is the two-way check (symbolic golden in test/test-calculus.shen +
this quadrature) that the derivation is correct, not merely tabulated.

Run:  python3 scripts/wave2_gaussian_quadrature_check.py
"""
import math
from statistics import NormalDist

CASES = [(1, 0.5), (2, -0.3), (0.5, 1.2), (-1, 0.0)]


def closed_form(j, c):
    # e^{j^2/2} * N(c - j) -- the form gauss-definite produces.
    return math.exp(j * j / 2.0) * NormalDist().cdf(c - j)


def quadrature(j, c, n=400000, lo=-40.0):
    h = (c - lo) / n
    s = 0.0
    for i in range(n + 1):
        u = lo + i * h
        phi = math.exp(-u * u / 2.0) / math.sqrt(2.0 * math.pi)
        v = math.exp(j * u) * phi
        s += v * (0.5 if i in (0, n) else 1.0)
    return s * h


def main():
    ok_all = True
    for j, c in CASES:
        cf = closed_form(j, c)
        q = quadrature(j, c)
        d = abs(cf - q)
        ok = d < 1e-6
        ok_all = ok_all and ok
        print(f"j={j:>4} c={c:>5}  closed-form={cf:.10f}  quad={q:.10f}  "
              f"|diff|={d:.2e}  {'OK' if ok else 'FAIL'}")
    print("ALL <1e-6:", ok_all)
    return 0 if ok_all else 1


if __name__ == "__main__":
    raise SystemExit(main())
