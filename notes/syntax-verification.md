# 4th Edition Shen Syntax Verification (Phase 0)

**Date:** 2026-06-18 (initial)

**Source:** The Book of Shen 4th ed. excerpts in book_of_shen_cas_relevant.md + grok_review.md

## Verified Forms (re-check against printed/PDF before Phase 1 use)

- `(datatype ...)` sequent rules with `verified` side conditions.
- Side conditions calling user predicates (e.g. `(bindings-cover LHS RHS)`).
- `defprolog` + `(prolog? ... (return ...))` + `when` / `is` / `bind`.
- Typed YACC: `defcc` / `==>` producing typed terms.
- Gensym hygiene patterns.
- `number?`, list handling in datatypes.

## Numeric Policy (Phase 1)

Exact integers only (`(int N)`). Rationals postponed.
Centralize all numeric ops in `num.shen` (affects hash stability + HVM later).

## Hash Representation (Phase 1 decision)

Portable stable Merkle:
- Atom: (tag . value) e.g. (int . N) or (sym . S) hashed.
- Compound: (head-hash . (list-of-arg-hashes)) — order matters except after Orderless/Flat canonicalization (applied before hash for declared symbols).

Recommendation: use Shen's built-in hash where available + manual tree walk to a string or integer; or pure list structure fingerprint for determinism across runs. Avoid floating point. Record the exact primitive in store.shen.

Stability contract: same structure + same structural attrs => identical hash. Independent of rule db / basis / evaluation.

(See store.shen 5.1 for impl.)

## Structural Signature Immutability

`Orderless` / `Flat` / `OneIdentity` are symbol-creation facts only (affect canonicalization before hash). Never flip after first construction of a headed term.

## Phase 1 known-symbols for bindings-cover?

LHS-bound names + a small set of builtins/constants recognized in Phase 1 (expand when db.shen arrives).

## Corrections / Notes from Book

(See book_of_shen_cas_relevant.md for 21.4 `arith` / `walk` / `thrash` + p.288+ examples.)

Record any syntax deltas here before implementing `datatype` rules in code.

(Initial skeleton — expand during task 4.)
