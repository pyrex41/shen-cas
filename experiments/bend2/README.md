# Bend 2 closed-subtree experiment

This probes the optional backend boundary in
[`notes/compiler-runtime-slice.md`](../../notes/compiler-runtime-slice.md).
It is a runnable equivalence check for a deliberately small fragment:
balanced, ground CAS `Plus` trees with positive `[int N]` leaves, whose sum
fits `U32`. It does not translate general CAS rules or run tabled logic.

The bridge builds one tree, writes the same tree as a Shen CAS expression and
as a Bend 2 `Expr` value, checks and compiles Bend 2 to JavaScript, runs the
generated program, loads the CAS kernel without the test harness, reduces the
CAS expression, and compares integer results. Bend 2 is checked out separately
and is never copied into this repository.

## Reproduce

Tested with Bend 2 source commit
[`95317d952c8fe5be18ef49f916b2a57250cfb0aa`](https://github.com/bendlang/bend/commit/95317d952c8fe5be18ef49f916b2a57250cfb0aa),
Bun 1.4.2, Node, and the repo's `shen-script` dependency. Clone Bend 2 at
that revision and install Bun according to its own documentation. From this
repository's root, after `cd scripts && npm install`:

```sh
ulimit -s unlimited
node experiments/bend2/bridge.mjs /path/to/bun /path/to/bend/bend2/main.ts 4
node experiments/bend2/bridge.mjs /path/to/bun /path/to/bend/bend2/main.ts 6
```

The first case contains 31 nodes and returns `[int 16]` / `16`. The second
contains 127 nodes and returns `[int 64]` / `64`. For larger trees, pass depths
8, 10, 12, or 14 (511, 2,047, 8,191, or 32,767 nodes respectively):

```sh
node experiments/bend2/bridge.mjs /path/to/bun /path/to/bend/bend2/main.ts 14
```

The script exits nonzero
on a checker, compiler, process, or equivalence failure. It uses a temporary
directory and removes generated programs afterward. Depth is capped at 14.

## Observed on one workspace run

| Case | Bend check | Emit JS | Launch JS | Bend total with bridge | CAS cold load + eval | CAS eval after load |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 31 nodes | 116 ms | 137 ms | 60 ms | ~313 ms | 7,572 ms | 13 ms |
| 127 nodes | 117 ms | 134 ms | 59 ms | ~310 ms | 7,891 ms | 50 ms |
| 511 nodes | 135 ms | 159 ms | 63 ms | 357 ms | 7,735 ms | 232 ms |
| 2,047 nodes | 137 ms | 162 ms | 62 ms | 362 ms | 10,152 ms | 1,052 ms |
| 8,191 nodes | 177 ms | 235 ms | 80 ms | 496 ms | 18,285 ms | 5,114 ms |
| 32,767 nodes | 350 ms | 601 ms | 162 ms | 1,120 ms | 54,745 ms | 23,813 ms |

The bridge generation took 0–7 ms in these cases. These timings are single
observations, not a benchmark: the CAS
column measures an in-process evaluation, the Bend run column includes a new
Node process, and Bend's check and emission compile a specialized closed
program. The cold CAS column includes compiling/loading many Shen modules.
The large case is evidence that this *specific compiled JS expression
evaluator* can complete a closed addition tree faster than this pure Shen CAS
path. It is not evidence about general rewrite rules, tabled logic, native
parallelism, or a reusable offload backend. The generated JS constructs an
expression and runs the recursive `eval` function (checked by inspecting the
511-node output); the compiler does not merely emit the final number in that
case. Each Bend case still specializes a newly compiled program to the input
tree, while the CAS interprets its input and performs general-purpose rewrite
bookkeeping. The last case generated ~213 KB of Bend source and ~979 KB of JS.

The JS backend successfully executes the translated fragment. The Bend 2 C
emitter also produced a C file, but the workspace has GCC rather than Clang;
GCC rejects the generated `musttail` attribute. Native or parallel backend
performance therefore remains unmeasured.

## Decision boundary

For the small expressions, per-expression compilation is much more expensive
than CAS evaluation after loading. At 32,767 nodes, even the full Bend check,
emission, and launched run was substantially shorter on this one run. A
plausible backend would compile
a reusable, closed *program fragment* once and amortize conversion over many
large evaluations, with a native or GPU target and a well-defined return
format. Before adding a production backend, measure that workload against
the CAS reference and an optimized native rewrite path, and test nonconfluent
rule priority, rule-basis changes, larger integer types, sharing, and failure
semantics explicitly. This experiment establishes only that a pure bounded
subtree can cross the proposed boundary and return an equivalent result.
