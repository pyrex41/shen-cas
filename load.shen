\\ shen-cas top-level loader
\\ Usage: (load "load.shen") from repo root (adjust paths for your Shen)

(load "src/expr.shen")
(load "src/pattern.shen")
(load "src/num.shen")
(load "src/db.shen")
(load "src/rule.shen")
(load "src/attrs.shen")
(load "src/query.shen")
(load "src/warn.shen")
(load "src/match.shen")
(load "src/core.shen")
(load "src/scope.shen")
(load "src/match-seq.shen")
(load "src/match-ac.shen")  \\ 9.2 complete: Orderless perm + Flat flatten + blowup warning + match-compound integration (Prolog)
\\ (load "src/scope.shen")
\\ (load "src/read.shen")
\\ (load "src/print.shen")

\\ Bootstrap rules (later)
\\ (load "boot/arith.shen")
\\ etc.

(output "shen-cas loaded (skeleton). See plan.md and test.shen.~%")
(load "test/test.shen")
