# Compiler/runtime experiment: a tabled logic slice

This is the first executable experiment for a separate compiler/runtime project.
`shen-cas` is its rewriting workload and reference semantics, not the entire
compiler. The current slice is `src/logic-table.shen`, loaded after `query.shen`.

## Contract implemented now

- Terms are ground `shen-cas` expressions (`[sym S]`, `[int N]`, `[rat N D]`,
  or compounds of ground expressions). Facts use `[logic-atom Name Args]`.
- A rule is `[logic-rule Head Body]`, where `Body` is a list of atoms.
  `[logic-var Name]` may occupy a whole argument slot in a rule or query.
- Rules are positive and range restricted: every variable in a head occurs
  in its body. Input facts must be ground. Rules may contain ground constants.
- `logic-table` computes a least fixed point of all rule answers. It stores
  each distinct ground answer once. Left-recursive relations and cycles reach
  a fixed point over this finite fragment; execution does not depend on
  depth-first Prolog's clause order.
- `logic-query` selects matching answers. A new set of facts/rules is an
  independent input, so old answers cannot leak across rule versions. The
  current resource guard is `*logic-max-facts*`, initially 10,000.

Example (with the kernel loaded):

```shen
(logic-query
  [[logic-atom edge [[sym a] [sym b]]]
   [logic-atom edge [[sym b] [sym c]]]]
  [[logic-rule [logic-atom path [[logic-var x] [logic-var y]]]
               [[logic-atom path [[logic-var x] [logic-var z]]]
                [logic-atom edge [[logic-var z] [logic-var y]]]]]
   [logic-rule [logic-atom path [[logic-var x] [logic-var y]]]
               [[logic-atom edge [[logic-var x] [logic-var y]]]]]]
  [logic-atom path [[sym a] [logic-var y]]])
```

This is a bottom-up tabled Datalog fragment. It is **not** a WAM, SLG
continuation engine, full Shen Prolog replacement, or a general term
rewriter. The strict syntax deliberately guarantees a finite set of possible
answers; arbitrary compound construction in rule heads would lose that
guarantee. Rule bodies are evaluated against each round's completed facts.

## Next compiler boundary

Introduce an explicit relation IR with validated predicate signatures,
term kinds, rule-set identity, and an effect classification. Compile the
same positive fragment to an indexed/semi-naive engine and check its answer
set against `logic-table`. Then add suspended tabled calls for a broader
Prolog fragment, preserving Shen's cut, occurs-check, and effect behavior
only where a conformance test establishes it. Keep the CAS's ordered,
nonconfluent reduction as a separate engine sharing term storage.

An optional Bend 2 or HVM experiment should accept a *closed, pure* CAS
subtree and a frozen rule basis, return an expression, and be judged against
the reference evaluator on results and total elapsed time, including
compilation and term conversion. It does not own tabling or ordered matching.

## Verification

Run the focused check with the repo's ShenScript runner:

```sh
node --stack-size=60000 scripts/shenscript-run.js \
  '(do (load "src/expr.shen") (load "src/query.shen") (load "src/logic-table.shen") (load "test/test-logic-table.shen") (run-logic-table-tests))'
```

The repository's full harness also loads this check through `load.shen` and
`run-all-tests`. Its existing suites may fail earlier and short-circuit.
