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

## Hash Representation

To be chosen in task 4/5.1: portable, stable Merkle (tag+value for atoms; head-hash + ordered arg-hashes for compounds).

Recommendation candidates (Shen-portable): simple recursive string or list-based hash (e.g. using Shen's `hash` or manual), or embed a small portable fn. Document choice + stability contract here.

## Structural Signature Immutability

`Orderless` / `Flat` / `OneIdentity` are symbol-creation facts only (affect canonicalization before hash). Never flip after first construction of a headed term.

## Phase 1 known-symbols for bindings-cover?

LHS-bound names + a small set of builtins/constants recognized in Phase 1 (expand when db.shen arrives).

## Corrections / Notes from Book

(See book_of_shen_cas_relevant.md for 21.4 `arith` / `walk` / `thrash` + p.288+ examples.)

Record any syntax deltas here before implementing `datatype` rules in code.

(Initial skeleton — expand during task 4.)
