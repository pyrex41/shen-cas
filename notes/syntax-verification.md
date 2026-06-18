# 4th Edition Shen Syntax Verification (Phase 0 / SCUD task 4)

**Date:** 2026-06-18 (task 4 complete)
**Status:** Actionable; re-verify forms in running 4th-ed Shen before Phase 1 datatype impl.

**Sources:** 
- `book_of_shen_cas_relevant.md` (curated excerpts p.274 21.4 + p.288 Ch.22 + Ch.25 p.345)
- `grok_review.md`
- `design.md` (risks §10, datatype §3/5.1, numeric/hash)
- `sketch.md` (assumed forms)
- `The_Book_of_Shen_4th_Edition.md` (for cross-check; OCR artifacts noted)
- `plan.md` (Phase 0 tasks)

**Caveat:** All `(datatype ...)`, `defcc`, and sequent syntax must be re-checked against a printed/PDF 4th edition (or clean runtime load) before writing `expr.shen`/`pattern.shen`/`rule.shen`. OCR in excerpts has artifacts (¥ for Y, missing brackets, "protog", broken arrows).

## 1. Verified Forms (exact usage from 4th ed.)

### (datatype ...) sequent rules with `verified` side conditions

Book style (p.274 `expr` concrete datatype + okexpr; p.288 `t`/`f`):

```
(datatype expr

(number? X)- verified >> X= number.

P.: verified, Q : verified >> R:

(end P Q) verified >> R:

number:

X expr:

if (not (element? X [-* /+))

symbol:

X expr:

(fr. Op) : (number —> number > number):

X: expr: Y expr.

[X Op Y]: expr)
```

```
X:okexpr
X : expr)
```

```
(datatype t

if (not (element? T [~ v & => <=> e! all]))

T : symbol:
_______________
T : t
)

(datatype f

F it T : (list t):     ; OCR: "F it T: (list t):" — likely "F : (list t)" or similar
______________________
F : f
)
```

**Sequent forms observed:**
- `Premise1, Premise2 >> Conclusion : type`  (or bare type)
- `(pred X)- verified >> Conclusion`
- `if (boolean-shen-expr)` as a premise guard (inline)
- `Var : type:` or bare `number:`
- Verified facts promote via `- verified` or `P.: verified`

Side conditions can invoke user predicates (see §4); they are expected to reduce to `verified` (i.e. normal-form `true`).

### Side conditions calling user predicates (e.g. bindings-cover)

Sketch form (used for `checked-rule`):

```
(datatype rewrite-rule
    LHS : pattern;
    RHS : expr;
    (bindings-cover LHS RHS);
    _________________________
    (rule LHS RHS) : checked-rule;
)
```

Book supports `(pred ...)` or `if (pred ...)` in premises. No verbatim `bindings-cover` example in CAS/YACC excerpts, but the mechanism ("user predicates as side conditions", "verified") is identical to `number?` / `element?` usage. See risk in design §10.

### `defprolog` + `(prolog? ...)` + `when` / `is` / `bind` / `return`

Confirmed exact (Ch.25 p.357+):

```
(defprolog woman
martha <--
joan <-- ;)
```

```
(prolog? (woman martha))
; true

(prolog? (woman X))
; true

(prolog? (woman X) (return X))
; martha

(prolog? (findall X (woman X) Y) (return Y))
; [martha joan]
```

- `defprolog` replaces `define`; clauses end with `;`
- Pattern matching only on lists.
- `return` terminates with value.
- `when (boolean)` : guard test.
- `is Var (shen-expr)` : unify Var with eval of expr.
- `bind Var Val` : when first arg known to be var.
- Repeated vars: occurs-check unification.
- Used exactly for sequence/AC in sketch §7.2–7.3 (`match-arg-list`, `split`, `permutation`, `select`).

### Typed YACC: `defcc` / `==>` producing typed terms

From p.288+ (Montague + Ch.22):

```
(defcc <sent>
{ (list t) ==> f }
<np> <vp> == (<np> <vp>) : )
```

- Type signature: `{ input-type ==> output-type }` (note `==>` not `->`).
- Rule: `nonterm ... == semantic-action :`
- Semantic actions are higher-order (lambdas), use `gensym` for hygiene on binders (e.g. quantifiers `[e! ...]`, `[al ...]`).
- Nonterminals `<foo>`, terminals as literals or variables.
- Compilation (yacc-syntax etc.) turns into typed Shen; parse failures explicit.

See also `defcc <term> N := N where (number? N):` etc. (p. ~300 examples).

**Direct use for Phase 6:** surface syntax → already-typed `expr` / `checked-rule`.

### Gensym hygiene + list/number handling

- `(gensym v) : t` axiom for fresh symbols in datatypes.
- `number?`, `element?`, `variable?`, list decomp in rules (common in `t`/`f` and `expr`).
- `name?` etc. defined as ordinary `define` outside, called from datatypes/recognizers.

## 2. Numeric Policy (Phase 1 — confirmed locked)

- **Exact integers only:** `(int N)` atoms; N is Shen integer (bignum capable in host but treated exact).
- No rationals, floats, complex in Phase 1 `expr`.
- `(number? X)` used in book datatypes — in Phase 1 restrict to ints (later `num.shen` gate).
- Centralize **all** numeric ops (+ - * / etc., comparisons) behind `num.shen`.
  - Affects: content-hash stability (int str rep), arith bootstrap rules (Phase 5), future HVM (fixed-width).
- Golden corpus (arith-21.4.txt) and 21.4 examples use integer literals only.

Policy locked per design §3 and plan Phase 0/1. Revisit post-Phase 2.

## 3. Hash Representation / Algorithm (chosen)

**Portable content-hash (Merkle, stable, Shen-pure):**

Every `expr` / `pattern` (and later rules) has a content-hash computed **after** canonicalization.

**Representation:** integer (key for intern table / future datoms).

**Algorithm (recursive, post-canonical):**

```
Atom:     [Tag Val]      → (hash (portable-atom-string Tag Val) 1000000007)
Compound: [H | ArgHashes] → (hash (cn (str H-hash)
                                     (fold-left cn "" (map str ArgHashes)))
                                  1000000007)
```

- `portable-atom-string`: `(cn (str Tag) (if (symbol? Val) (str Val) (str Val)))` or equivalent fixed printer. Never uses `*print*` state.
- `hash` = Shen primitive `(hash E N) → 1..N` (deterministic for same input within one Shen impl).
- Order of arg-hashes is the *canonical* (post-Orderless sort / Flat flatten) order.
- Alpha: binders (Module/With) renamed to canonical form (de Bruijn or fresh gensym sequence) *before* hash.

**Interning:** content-store table maps hash (or (hash, canonical-rep) for safety) → interned node. Construction always interns.

**Justification (portability + stability):**

- 100% pure Shen; no FFI, no external digest (sha etc. unavailable portably).
- Deterministic serialization + Shen hash → same structure always yields same hash (within impl).
- Merkle property: hash depends only on children → structural sharing, O(1) `=`.
- Stable w.r.t. rule db / basis (rule equalities never affect content hash).
- Low collision risk for kernel use (internal table can chain on collision).
- Future-proof: if cross-Shen-impl hash variance appears, swap impl of `hash-expr` for pure-arithmetic portable hash (e.g. FNV-1a over bytes of canonical sexpr) without API change.
- Alternatives evaluated:
  - Full canonical sexpr string as key: collision-free, simple. Rejected for Phase 1: heavier (strings vs ints), slower for large terms; numeric keys preferred for datom basis hashes later.
  - Raw Shen structure as key (rely on `=` + put/get): works for interning but provides no stable serializable "name" for db/memo keys across bases.
- Centralized in `store.shen`; `num.shen` only for arith (not hashing).

**Contract:** Hash of E is invariant under reordering that is licensed by structural attrs at creation time; independent of any loaded rules.

## 4. Immutable Structural-Signature Rule

`Orderless` / `Flat` / `OneIdentity` are **symbol-creation facts** (structural signature), not mutable db facts.

- Affect canonicalization (sort args; flatten nested; reduce [f x]→x) **before** any content-hash is computed.
- Declared once (explicit attr form or first construction of headed term).
- **Immutable after first construction:** flipping them would retroactively change hashes of all prior terms using that head → corrupts sharing, intern table, memos, basis hashes.
- In `store.shen` / `attrs.shen`: structural attrs are recorded in a one-way creation record; canonical fns consult an immutable view.
- Evaluation attrs (`HoldAll`, `HoldFirst`, `HoldRest`, `Listable`) **are** mutable facts (in db); never participate in content hash.
- If ever support "change structural attr", it must be accompanied by full content-store + memo flush and new basis (unsupported in Phase 1/2).

Test requirement (Phase 1): `Plus[a b]` and `Plus[b a]` share hash (after declaring Plus Orderless); nested Flat shares; rule-driven `x+0→x` does **not** change content hash of original.

## 5. Phase 1 known-symbol policy for `bindings-cover?`

In Phase 1 (pre-`db.shen`):

```
(define bindings-cover?
  LHS RHS ->
    (let Bound (extract-bindings LHS)
         Free  (free-symbols RHS)
         Known (append Bound (phase1-known-symbols))
         (subset? Free Known)))
```

**Policy:** Free symbols (S from `(sym S)` in RHS) are covered if:
- Appeared as a named binding on LHS, **or**
- Belong to the Phase-1 known-globals whitelist.

**Phase 1 whitelist (small, expand later):**

```
(define phase1-known-symbols ->
  [Plus Times Power Subtract Divide   ; from 21.4 + arith bootstrap
   0 1                               ; integer "constants" (as symbols? careful: ints are (int N))
   ; plus any kernel heads needed for expr construction in tests
   ])
```

Notes:
- `extract-bindings` / `free-symbols` (sketch §4) are pure Shen; reused verbatim by Datalog `covers` later.
- Int constants are `(int N)` not `(sym 0)`; free-symbols only collects from `sym`.
- If a RHS contains a bare user symbol that is not a pattern var and not whitelisted, reject (catches real unbound-var bugs).
- **Fallback for side-condition:** If Shen 4th datatype cannot accept `(bindings-cover LHS RHS)` (or `(bindings-cover? ...)` verified) directly as premise, implement check inside `register-rule` (or equivalent in Phase 1) before any db assert. Still definition-time; "nothing ill-formed reaches the database."

When `db.shen` + query arrives (Phase 2/3): replace whitelist with live query over registered symbols for the basis.

## 6. Corrections / Notes / 4th-ed Deltas (vs. sketch assumed syntax)

**Sketch (assumed 3rd-ed style) vs. Book 4th-ed excerpts:**

Sketch datatypes (expr, pattern, rewrite-rule, ...):

```
(datatype expr
    X : symbol;
    _______________
    (sym X) : expr;
    ...
    (bindings-cover LHS RHS);
    _________________________
    (rule LHS RHS) : checked-rule;)
```

4th-ed (p.274/288):

- No `;` after premises in shown excerpts.
- Uses `>>` , `:` bare, `if (...)` inline, `(pred)- verified >>` , `P.: verified, Q : verified >> R:`
- Conclusions often `X= type` or `X : type` or just `type:` 
- Bar separators (`___`) may be present but OCR-mangled or optional.
- `defcc` explicitly shows `{type ==> type}` prefix (sketch omitted in high-level).

**No deltas for:**
- `defprolog` / `prolog?` / `return` / `when` / `is` syntax — exact match to sketch usage.
- Role of `gensym` for hygiene.
- `number?` / list handling in datatypes.

**Action before Phase 1:**
- When transcribing `expr` / `pattern` / `compound-pattern` / `checked-rule` / `valid-attrs` into code, prefer 4th-ed surface forms shown in book excerpts.
- Add a tiny self-test: `(datatype toy ... (my-pred X) verified >> ... )` once harness loads.
- If bindings-cover side-cond rejected by checker, switch to registration-gate + keep datatype rule minimal.
- Record runtime results here: <pending load of actual Shen 4th>.

## 7. Actionable Implementation Notes (for store/expr/pattern/rule)

- `store.shen`: implement `content-hash`, intern, canonicalize (alpha + structural sig only in Phase 1).
- `expr.shen`: `(datatype expr ...)` in 4th-ed style; constructors call store.
- `pattern.shen`: split `pattern` / `seq-pattern` load-bearing; use verified style.
- `rule.shen`: `extract-bindings`, `free-symbols`, `bindings-cover?` (with phase1-known), registration gate.
- `num.shen`: stub for `(int N)` only; `+` etc. wrappers.
- Tests: exercise hash sharing for Orderless/Flat; rejection of unbound RHS using the policy; idempotence of trivial reduce.
- All hashes / canonical forms must be **db-independent**.

## 8. Open Items / Risks (carry to Phase 1)

- Actual 4th-ed acceptance of user predicate side-cond `(bindings-cover ...)` (design §10).
- `hash` determinism + collision behaviour across Shen ports (sbcl vs scheme vs ...).
- Exact sequent punctuation (>> vs = vs bare) — match runtime.
- `prolog?` pushing typed pattern values — ensure no ill-typed fabrication at Prolog boundary.

**End of task 4 documentation.** Ready for Phase 1 (content store + datatypes + non-seq matcher).

See also: design.md §5.1 (canonicalization), §10 (risks); plan.md (Phase 0 acceptance + open Qs); grok_review.md (alignment).
