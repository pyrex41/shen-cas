#!/usr/bin/env python3
"""Wave 4 skew oracle (independent of the symbolic engine).

European put on a lognormal underlying with log ~ Normal(a, b^2):
  P = (k - S)^+   but the engine's "moment" integrates (k - S)^x over S in (0, k)
  E[P^x] = exp(-x r T) * integral_0^k (k - S)^x * lognormal_pdf(S; a, b) dS
  skew   = (m3 - 3 m1 m2 + 2 m1^3) / (m2 - m1^2)^1.5

These oracle constants are pasted into test/test-multipoly.shen (mp-skew-close?).
Run: python3 scripts/wave4_skew_check.py
"""
import math
import numpy as np

trap = getattr(np, "trapezoid", None) or np.trapz


def moment(x, k, a, b, r, T, npts=4_000_000):
    S = np.linspace(1e-7, k, npts)
    pdf = np.exp(-(np.log(S) - a) ** 2 / (2 * b * b)) / (b * math.sqrt(2 * math.pi) * S)
    return math.exp(-x * r * T) * trap(((k - S) ** x) * pdf, S)


def skew(k, a, b, r, T):
    m1, m2, m3 = moment(1, k, a, b, r, T), moment(2, k, a, b, r, T), moment(3, k, a, b, r, T)
    var = m2 - m1 * m1
    return (m3 - 3 * m1 * m2 + 2 * m1 ** 3) / var ** 1.5


if __name__ == "__main__":
    sets = [
        ("set #1", 2.0, -1 / 50, 3 / 20, 1 / 100, 1.0),
        ("set #2", 3.0, 1 / 20, 1 / 4, 1 / 50, 1.0),
    ]
    for name, k, a, b, r, T in sets:
        print(f"{name}: k={k} a={a} b={b} r={r} T={T}  skew={skew(k, a, b, r, T):.8f}")
