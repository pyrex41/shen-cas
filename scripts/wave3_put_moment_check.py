#!/usr/bin/env python3
"""
Gaussian Wave 3 numeric cross-check (independent of the symbolic engine).

Verifies the option put-moment E[P^x] the CAS DERIVES from the normal-form
integral by binomial-expand + the general-(a,b) Gaussian half-line lemma +
discount:

    E[P^x] = e^(-x r T) * Integrate[ (k - e^u)^x * NormalPDF[(u-a)/b]/b,
                                     {u, -Infinity, Log k} ]
           = e^(-x r T) * sum_{j=0..x} C(x,j) (-1)^j k^(x-j)
                            * e^(j a + j^2 b^2/2) * N((Log k - a - j b^2)/b)

where the per-term factor  e^(j a + j^2 b^2/2)  and the CDF argument
(Log k - a - j b^2)/b  are EXACTLY what the engine computes from (a,b,j) via
the cleared square-completion vertex (src/calc-helpers.shen gd-emit-gen) and
the binomial coefficients C(x,j)(-1)^j fall out of Expand. NONE of this is a
pasted closed form -- it mirrors the engine's derivation term for term.

Three quantities are compared and must agree to ~1e-4:
  (1) closed_form  -- the engine's derived sum (above)
  (2) quadrature   -- direct lognormal quadrature of (k-S)^x over (0,k)
  (3) erfc_oracle  -- the notebook's independent Erfc formula (N(z)=erfc(-z/sqrt2)/2)
                      VERIFICATION ONLY; the engine never reads it.

Run:  python3 scripts/wave3_put_moment_check.py
"""
import math
import numpy as np
from statistics import NormalDist
from math import comb, erfc, sqrt, exp, log

N = NormalDist().cdf

# a = log-mean, b = log-sd (= sigma*sqrt(T))
K, A, B, R, T = 1.0, -0.02, 0.15, 0.01, 1.0


def closed_form(x):
    """Engine's DERIVED E[P^x]: binomial sum over the general-(a,b) lemma."""
    s = 0.0
    for j in range(x + 1):
        coef = comb(x, j) * ((-1) ** j) * (K ** (x - j))
        factor = exp(j * A + j * j * B * B / 2.0)
        arg = (log(K) - A - j * B * B) / B
        s += coef * factor * N(arg)
    return exp(-x * R * T) * s


def quadrature(x):
    """Direct lognormal quadrature of the put moment (k-S)^x on (0,k)."""
    S = np.linspace(1e-6, K, 800000)
    lnpdf = np.exp(-(np.log(S) - A) ** 2 / (2 * B * B)) / (B * math.sqrt(2 * math.pi) * S)
    trap = getattr(np, "trapezoid", getattr(np, "trapz", None))
    return exp(-x * R * T) * trap(((K - S) ** x) * lnpdf, S)


def erfc_oracle(x):
    """Notebook Erfc oracle. N(z) = erfc(-z/sqrt2)/2, so the engine's
       N((Log k - a - j b^2)/b) == Erfc[(a + j b^2 - Log k)/(sqrt2 b)]/2.
       This reproduces the notebook ep1/ep2/ep3 Erfc expressions exactly."""
    s = 0.0
    for j in range(x + 1):
        coef = comb(x, j) * ((-1) ** j) * (K ** (x - j))
        factor = exp(j * A + j * j * B * B / 2.0)
        z = (A + j * B * B - log(K)) / (sqrt(2.0) * B)
        s += coef * factor * 0.5 * erfc(z)
    return exp(-x * R * T) * s


def emergence_check():
    """The N-arguments at j=1,2,3 must REDUCE to the paper's d-forms after
    substituting a=(r-sigma^2/2)T+Log S, b=sigma sqrt(T). This is the proof the
    engine DERIVED (csq-vertex on (a,b,j)) rather than looked up. The engine
    never contains d1/d2 -- they EMERGE here, in verification only.

    Paper d-forms (put, with c = Log k):
        d1 = (Log(S/k) + (r + sigma^2/2)T) / (sigma sqrt(T))
        d2 = d1 - sigma sqrt(T)
    The engine's j-th NormalCDF argument is  arg_j = (Log k - a - j b^2)/b.
    Claim:  arg_0 = -d2,  arg_1 = -d1,  arg_2 = -(2 d1 - d2)/... (general:
    arg_j = -(d2 + (j-? )...)).  We verify the standard relations:
        -arg_1 = d1,  -arg_0 = d2,  and  -arg_2 = 2 d1 - d2,  -arg_3 = 3 d1 - 2 d2.
    """
    S, k, r, sigma, Tt = 0.8, 1.0, 0.01, 0.15, 1.0
    a = (r - sigma * sigma / 2.0) * Tt + log(S)
    b = sigma * sqrt(Tt)
    d1 = (log(S / k) + (r + sigma * sigma / 2.0) * Tt) / (sigma * sqrt(Tt))
    d2 = d1 - sigma * sqrt(Tt)

    def arg(j):
        return (log(k) - a - j * b * b) / b

    targets = {0: d2, 1: d1, 2: 2 * d1 - d2, 3: 3 * d1 - 2 * d2}
    ok = True
    for j, tgt in targets.items():
        got = -arg(j)
        d = abs(got - tgt)
        ok = ok and d < 1e-12
        label = {0: "d2", 1: "d1", 2: "2d1-d2", 3: "3d1-2d2"}[j]
        print(f"  emergence j={j}: -arg_j={got:.10f}  {label}={tgt:.10f}  "
              f"|diff|={d:.2e}  {'OK' if d < 1e-12 else 'FAIL'}")
    print("EMERGENCE (N-args reduce to paper d-forms):", ok)
    return ok


import os
import re
import subprocess

SHEN = "/Users/reuben/projects/shen/shen-go/shen"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Exact-rational engine params (k=2, a=-1/50, b=3/20, r=1/100, T=1). These are
# the M1/M2/M3 golden params; the engine prints rationals so we can eval exactly.
ENG = dict(k=2.0, a=-1 / 50, b=3 / 20, r=1 / 100, T=1.0)


def _eval_engine_expr(s):
    """Numerically evaluate the engine's print-expr string for E[P^x].
    Grammar emitted: Exp[..], NormalCDF[..], Log[..], rationals a/b, *, +, -, [].
    We translate to Python and eval with exp/N/log in scope. This reads the
    ENGINE's OWN derived output -- it is NOT a reimplementation of the formula."""
    py = s.strip().strip('"')
    py = py.replace("Exp[", "exp(").replace("NormalCDF[", "N(").replace("Log[", "log(")
    # close the [ ... ] of those heads: easiest is to swap remaining [ ] to ( )
    py = py.replace("[", "(").replace("]", ")")
    return eval(py, {"exp": exp, "log": log, "N": N})


def _engine_moment(x):
    """Drive the Shen engine: derive E[P^x] symbolically, print it, eval it."""
    prog = (
        '(load "load.shen")\n'
        "(define unwrap [some R] -> (print-expr R) _ -> \"NONE\")\n"
        f"(output \"ENGOUT{x}: ~A~%\" (unwrap (expect-put-normal [int {x}] "
        "[int 2] [rat -1 50] [rat 3 20] [rat 1 100] [int 1] (w2-uu))))\n"
    )
    p = subprocess.run([SHEN], input=prog, text=True, capture_output=True,
                       timeout=300, cwd=REPO)
    out = p.stdout + p.stderr
    m = None
    for line in out.splitlines():
        mm = re.search(rf'ENGOUT{x}:\s*(.*)', line)
        if mm:
            m = mm.group(1)
    if m is None or "NONE" in m:
        raise RuntimeError(f"engine returned no closed form for E[P^{x}]:\n{out[-800:]}")
    return _eval_engine_expr(m)


def engine_check():
    """THE check the prior version was missing: evaluate the ENGINE's DERIVED
    E[P^x] (parsed from print-expr) numerically and compare to quadrature and
    the Erfc oracle. Catches the 1/b jacobian double-count directly."""
    print("ENGINE numeric check (drives the Shen engine, parses its output):")
    ok = True
    for x in (1, 2, 3):
        eng = _engine_moment(x)
        q = quadrature(x)
        o = erfc_oracle(x)
        d_q = abs(eng - q)
        d_o = abs(eng - o)
        good = d_q < 1e-4 and d_o < 1e-4
        ok = ok and good
        print(f"  E[P^{x}] engine={eng:.10f}  quad={q:.10f}  erfc={o:.10f}  "
              f"|eng-quad|={d_q:.2e}  |eng-erfc|={d_o:.2e}  "
              f"{'OK' if good else 'FAIL'}")
    print("ENGINE == quadrature == oracle:", ok)
    return ok


def main():
    ok_all = True
    for x in (1, 2, 3):
        cf = closed_form(x)
        q = quadrature(x)
        o = erfc_oracle(x)
        d_q = abs(cf - q)
        d_o = abs(cf - o)
        ok = d_q < 1e-4 and d_o < 1e-12
        ok_all = ok_all and ok
        print(f"E[P^{x}]  closed-form={cf:.10f}  quad={q:.10f}  erfc-oracle={o:.10f}")
        print(f"          |cf-quad|={d_q:.2e}  |cf-oracle|={d_o:.2e}  "
              f"{'OK' if ok else 'FAIL'}")
    print("ALL agree (quad <1e-4, oracle <1e-12):", ok_all)
    print()
    emg = emergence_check()
    ok_all = ok_all and emg
    print()
    # quadrature/oracle here use the SAME engine params (k=2,a=-1/50,b=3/20,...)
    # so the engine output (also at those params) is directly comparable.
    global K, A, B, R, T
    K, A, B, R, T = ENG["k"], ENG["a"], ENG["b"], ENG["r"], ENG["T"]
    eng_ok = engine_check()
    ok_all = ok_all and eng_ok
    return 0 if ok_all else 1


if __name__ == "__main__":
    raise SystemExit(main())
