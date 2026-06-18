\\ shen-cas top-level loader
\\ Usage: (load "load.shen") from repo root (adjust paths for your Shen)

(load "src/store.shen")
(load "src/expr.shen")
(load "src/pattern.shen")
(load "src/num.shen")
(load "src/rule.shen")
(load "src/attrs.shen")
(load "src/match.shen")
(load "src/core.shen")
(load "src/match-seq.shen")
\\ (load "src/match-ac.shen") ; not yet
\\ (load "src/db.shen")
\\ (load "src/query.shen")
\\ (load "src/scope.shen")
\\ (load "src/warn.shen")
\\ (load "src/read.shen")
\\ (load "src/print.shen")

\\ Bootstrap rules (later)
\\ (load "boot/arith.shen")
\\ etc.

(output "shen-cas loaded (skeleton). See plan.md and test.shen.~%")
(load "test/test.shen")
