# Buildout Plan — Gaussian Moments & Symbolic Option Skew

**Status:** proposed (design for review; no code yet)
**Owner:** Reuben Brooks
**Oracle:** Sinclair & Brooks, *The Skewness and Kurtosis of European Options* (SSRN 2956161).
The paper's equations 2, 5, 8, 12, 13, 14 and Appendix A are the golden targets.
The original **Mathematica notebooks** (to be supplied) become the exact input/output
corpus that gates each wave.

---

## 0. Goal

Make shen-cas **symbolically evaluate the integrals that define the option moments**
— i.e. integrals of `payoff(S_T)^n` against the lognormal/normal density — into closed
form in the normal CDF `N(·)`, then assemble and simplify the skewness/kurtosis
expressions. Today every one of these stays inert (verified 2026-06-20; see
[memory: bsm-skew-paper-benchmark]).

This is **not** general symbolic integration (no Risch, no general quadrature). It is a
single, tightly-bounded family driven by one lemma, in the same sound / table-driven /
gated spirit as the existing `D` and `Integrate` libraries.

---

## 1. The master lemma (why this is bounded, not open-ended)

With `φ(z) = (1/√(2π)) e^{-z²/2}` the standard normal PDF and `N` its CDF (`N'=φ`):

```
∫_{-∞}^{∞} e^{βz} φ(z) dz = e^{β²/2}                     (full line — the MGF)
∫_{a}^{∞}  e^{βz} φ(z) dz = e^{β²/2} · N(β − a)          (half line — THE lemma)
```

Proof is "complete the square in the exponent": `βz − z²/2 = −(z−β)²/2 + β²/2`.

**Everything in Appendix A follows from this.** For a European call,
`S_T = S e^{(r−σ²/2)T + σ√T z}`, the payoff `max(S_T−X,0)` turns the integral into a
half-line integral with lower limit `z* = −d₂`, and binomial expansion of `(S_T−X)^n`
produces a finite sum of terms `S^k X^{n−k} e^{k(r−σ²/2)T} ∫_{z*}^∞ e^{kσ√T z} φ(z) dz`.
Applying the lemma to each term:

- the scalar factors collapse to `e^{k²σ²T/2}` (→ the paper's `e^{Tσ²}`, `e^{3σ²T}` factors)
- the CDF arguments `kσ√T + d₂` collapse to exactly `d₁` (k=1), `2d₁−d₂` (k=2),
  `3d₁−2d₂` (k=3) — matching eqs 2, 5, 8 term for term.

**Worked check (E[C], eq. 2):**
`∫_{−d₂}^∞ (S e^{(r−σ²/2)T+σ√T z} − X) φ(z) dz = S e^{rT} N(d₁) − X N(d₂)`, and the paper's
discounted `E[C] = S N(d₁) − e^{−rT} X N(d₂)` is the `e^{−rT}·` multiple. ✓ (re-derived by hand)

So the engine needs: (a) a named `N`/`φ`, (b) the ability to represent a half-line
definite integral, (c) recognize `poly(e^{cz})·φ(z)` and apply the lemma per binomial
term. No general integration anywhere.

---

## 2. Soundness model

The existing integral gate `integ-diffback-ok?` (`src/calc-helpers.shen:885`) checks
`reduce[Simplify[D[R,V] − F]] == 0`. That gate is for **indefinite** integrals and does
not apply to a definite integral (whose value is a number/expression, not an
antiderivative). We replace it with an equally exact gate for this family:

- **Gate G1 (lemma application):** every emitted term is the lemma applied to a matched
  `e^{βz}φ(z)` factor. The lemma is an exact identity, so a term is committed only when
  the match is structurally exact (β read off as an exact rational/symbolic coefficient,
  limit `a` read off exactly). Any non-matching integrand → inert. Mirrors how
  `apart-builtin` gates on an exact coeff-vector recombination, not on `Simplify`.
- **Gate G2 (differentiation rules):** `D[N[u],x] → φ[u] D[u,x]` etc. are ordinary
  table rules; they inherit the existing registration-time `bindings-cover?` check once
  `N`/`φ` are whitelisted. No new soundness surface.

Net: wrong inputs stay inert; nothing is ever returned incorrectly. Same guarantee as
the rest of the kernel.

---

## 3. Surface syntax / new heads

- `NormalCDF[z]` — standard normal CDF, displays as `N` (paper notation). `Erf` optional
  as the lower primitive; `NormalCDF` is the user-facing head.
- `NormalPDF[z]` — standard normal PDF, displays as `φ`.
- Definite integral form `Integrate[f, {x, a, b}]` (Mathematica iterator syntax), with
  `a`/`b` allowing `Infinity` / `-Infinity`. Reader + printer + `calc-by-name` extend to
  the 2-arg-iterator shape.
- Optional sugar `GaussExpect[expr, z]` ≡ `Integrate[expr·NormalPDF[z], {z,-∞,∞}]` for
  ergonomics, but the engine keys off the integral form so it stays general.

All new heads added to `phase1-globals` (`src/rule.shen:17`) so rules emitting them pass
the static binding check.

---

## 4. Waves

Each wave is gated on the **full harness staying green** (`run-all-tests`, Golden 12/12,
every corpus `fail=0`) plus its own new golden cases, then an adversarial review fan-out
before the next wave — same protocol as the existing CAS buildout.

### Wave 1 — Normal CDF / PDF special functions  *(small, self-contained)*
- Add `NormalCDF`, `NormalPDF`, (`Erf`) to `phase1-globals`.
- Differentiation rules in `boot/calculus.shen` (same `register-rule`/`rule` shape as the
  `Sin`/`ArcTan` entries at lines 112–163):
  - `D[NormalCDF[u],x] → NormalPDF[u] · D[u,x]`
  - `D[NormalPDF[u],x] → −u · NormalPDF[u] · D[u,x]`
  - (`D[Erf[u],x] → (2/√π) e^{−u²} D[u,x]` if `Erf` is included)
- Printer: `NormalCDF`→`N[...]`, `NormalPDF`→`φ[...]`.
- **Unlocks:** BSM **Greeks** (Δ, vega, θ, …) once `d₁,d₂` are written as functions of
  `S,σ,T`. Today `D[S·N[d1],S] → N[d1]` (chain term dropped: `d1` opaque, `N` unknown);
  after Wave 1, with `d1=d1(S)`, the `φ(d₁)·∂d₁/∂S` term survives.
- **Golden:** `D[NormalCDF[x],x] = NormalPDF[x]`; a full ATM call Δ once notebooks confirm
  the exact `d₁` form used.

### Wave 2 — Gaussian-moment engine  *(moderate; the keystone — "evaluate the integral")*

**PRINCIPLE: derive, don't tabulate.** The engine must *reach* the closed form by a
chain of sound rewrites — exactly the steps a person does by hand. The notebook outputs
(`notes/notebooks/*.inputs.txt`) are **verification oracles ONLY**: we check the engine's
self-derived result agrees with them. No `Erf`/closed-form is ever entered into a rule.
The binomial coefficients `(1,−2,1)`, `(1,−3,3,−1)` and the argument shifts `+j b²` are
NOT data in any table — they fall out of steps 2 and 4 below.

For `E[Pˣ] = e^{−xrT} ∫₀ᵏ (k−S)ˣ · LogNormalPDF(S; a, b) dS`, the analytic chain is:

| Step | Rewrite | Status |
|---|---|---|
| 1. Substitution `S=eᵘ` | `∫ f(S)·LogNormalPDF(S;a,b) dS → ∫ f(eᵘ)·NormalPDF(u;a,b) du`, limits `(0,k)→(−∞,Log k)` | new rule, mechanical |
| 2. Binomial expansion | `(k−eᵘ)ˣ → Σⱼ C(x,j)(−1)ʲ k^{x−j} e^{ju}` | **have** (`poly-expand`) |
| 3. Linearity of `∫` | push integral through the finite sum | **have** |
| 4. Gaussian half-line lemma | `∫_{−∞}^{c} e^{ju}·NormalPDF(u;a,b) du`  →(complete the square)→  `e^{ja+j²b²/2}·NormalCDF((c−a−jb²)/b)` | ⭐ the one new primitive |
| 5. Back-substitute & simplify | restore `a=(r−σ²/2)T+Log S`, `b=σ√T`; `d₁,d₂` emerge by algebra | Wave 3/4 |

**Step 4 is itself derived, not a magic answer.** It decomposes into two honest, reusable
operations:
- **complete-the-square** on the exponent `ju − (u−a)²/2b²  →  −(u−(a+jb²))²/2b² + (ja+j²b²/2)`
  — a general symbolic operation worth having on its own;
- **`∫ NormalPDF = NormalCDF`** — the *definition* of the CDF, i.e. the Wave-1 `N'=φ` rule
  run as an antiderivative. ("The CDF is an integral; evaluate it symbolically" = recognize
  this antiderivative, nothing tabulated.)

Implementation: a `gauss-integrate` builtin in `src/calc-helpers.shen`, dispatched from
`calc-by-name` on the definite form `Integrate[_, {u,a,b}]` whose integrand is
`e^{linear(u)} · NormalPDF(u; …)` (after step 1). It runs steps 2–4 as rewrites and lets
the existing fixpoint simplify the rest. Each emitted term is gated by G1 (exact structural
match of the `e^{ju}·NormalPDF` factor and exact square-completion coefficients); anything
else stays inert.

- **Unlocks:** eqs 2, 5, 8, 12, 13, 14 — `E[C]`, `E[C²]`, `E[C³]`, `E[P]`, `E[P²]`,
  `E[P³]` in closed `N(dᵢ)` form, **derived**. This is the stated goal.
- **Golden (oracle = notebooks, for VERIFICATION):** engine's self-derived output must
  match each of eqs 2,5,8,12,13,14, checked two ways — symbolic equality after Simplify,
  and numeric agreement at sample `{S,k,r,σ,T}` points.

### Wave 3 — Moment → skew/kurtosis assembly  *(small)*
- `Skew[C] = (E[C³] − 3E[C]E[C²] + 2E[C]³) / Var[C]^{3/2}`, `Var = E[C²] − E[C]²`,
  via substitution (eqs 6–7, 10–11). Kurtosis analogously (needs `E[C⁴]` — Wave 2
  already produces it; the paper omits `E[C⁴]` for clarity but it's the same lemma).
- Output is **mathematically correct but not yet compact** (a large unsimplified
  rational in `S,X,r,T,σ,N(dᵢ)`).
- **Golden:** numeric agreement with the paper's worked example (ATM 1y call, σ=50%,
  r=0 → skew ≈ 3.31) by evaluating both symbolic forms at the same point.

### Wave 4 — Multivariate rational normal form  *(large; the only general-purpose piece)*
- Generalize `Together`/`Cancel`/`Apart`/collect from univariate-over-ℚ to **multivariate**
  (treat `N(dᵢ)`, `e^{σ²T}`, etc. as opaque generators). This is what turns the Wave-3
  output into the compact Appendix-A expressions Mathematica prints.
- Independent value beyond this paper: unlocks multivariate `Simplify` generally
  (currently `Together[1/x+1/y]`, `Cancel[(S²−X²)/(S−X)]` are inert).
- **Golden:** the three Appendix-A formulas (put, call, straddle skew) reproduced in
  compact form.
- **Honesty:** Waves 1–3 already deliver the *mathematics*; Wave 4 is cosmetic
  (Mathematica's `FullSimplify`) and is the genuinely large effort. It can be deferred
  without blocking the symbolic-integration goal.

### (Optional) Wave 5 — Kelly-fraction solve & skew→0 limit
- The paper also solves eq. 31 (quadratic in `f` with symbolic coeffs → needs the
  quadratic formula with `Sqrt`) and takes the skew→0 limit (eqs 30–33). Both currently
  inert (`Solve[a f²−b f+m==0,f]`, `Solve[f²−2==0,f]`). Separable follow-on; lower
  priority than the moment integrals.

---

## 5. Notebooks → golden corpus (VERIFICATION ORACLES ONLY)

**Hard rule: the notebooks are oracles, never source.** The engine must *derive* every
result via the Wave-2 rewrite chain; the notebook outputs only confirm it arrived at the
right place. No closed-form `Erf`/`N` expression from a notebook is ever encoded into a
rule, table, or special case — doing so would reduce the engine back to a lookup table,
which is precisely what this project exists to avoid.

Extracted to `notes/notebooks/*.inputs.txt` (5 notebooks). The keystone
`Deriving_Put_Expectation_with_Integrals` gives:
- the exact integral form (`expectationPutX[x] := e^{−xrT} ∫₀ᵏ (k−S)ˣ·LogNormalPDF(S;a,b) dS`),
- its self-consistency check `ep1paper = k e^{−rT} N(d) − S N(d−σ√T)` (the paper form), and
- the `x=1,2,3` outputs in `Erfc` (≡ `N` via `N(z)=½Erfc(−z/√2)`) — the verification targets.
- the convergence to `d = σ√T/2 + Log(e^{−rT}k/S)/(σ√T)` (= `−d₂`).

Wire these as new **frontier** buckets in `test/test-external-corpus.shen` (feature-filtered
corpus at `corpus-feature-cases`, line 175): `gaussian-moment`, `normal-cdf-diff`,
`option-skew`. Each case stores the input AND the oracle output; the test asserts the
engine's *derived* output matches (symbolically post-Simplify, and numerically at sample
points). Until a wave lands, its cases sit in the skip/frontier tier (line 235).

---

## 6. Risk register

| Risk | Mitigation |
|---|---|
| Definite-integral head ramifies through reader/printer/core | Wave 2 keeps `{x,a,b}` iterator isolated to a new `calc-by-name` branch; indefinite path untouched |
| Lemma mis-fires on a non-Gaussian integrand | Gate G1: commit only on exact structural match of `e^{βz}φ(z)`; else inert |
| Wave 4 multivariate normal form is large/unbounded | It's optional for the integration goal; Waves 1–3 stand alone and are correct without it |
| Surface syntax diverges from the notebooks | Defer final syntax lock until notebooks supplied; plan keys engine off structure, not sugar |

---

## 7. Sequencing recommendation

Build **1 → 2 → 3** to reach the stated goal (symbolically evaluated moment integrals +
correct skew). Treat **4** as a separate, independently-valuable project (general
multivariate simplify) pursued when the compact printed form matters. **5** is an optional
tangent. Each wave: implement → full harness green + new goldens → adversarial review →
next.
