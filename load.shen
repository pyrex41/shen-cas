\\ shen-cas top-level loader
\\ Usage: (load "load.shen") from repo root (adjust paths for your Shen)

(load "src/store.shen")   \\ will grow
(load "src/expr.shen")
(load "src/pattern.shen")
(load "src/rule.shen")
(load "src/attrs.shen")
(load "src/match.shen")
(load "src/match-seq.shen")
(load "src/match-ac.shen")
(load "src/db.shen")
(load "src/query.shen")
(load "src/core.shen")
(load "src/scope.shen")
(load "src/warn.shen")
(load "src/read.shen")
(load "src/print.shen")

\\ Bootstrap rules (later)
\\ (load "boot/arith.shen")
\\ etc.

(princ "shen-cas loaded (skeleton). See plan.md and test.shen.~%")
