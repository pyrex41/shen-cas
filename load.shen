\\ shen-cas top-level loader
\\ Usage: (load "load.shen") from repo root (adjust paths for your Shen)

(load "src/store.shen")
(load "src/expr.shen")
(load "src/pattern.shen")
(load "src/num.shen")
\\ (load "src/attrs.shen")   ; in progress by agent
(load "src/rule.shen")
(load "src/match.shen")
(load "src/core.shen")
(load "src/match-seq.shen")
\\ (load "src/match-ac.shen") ; not yet
\\ (load "src/db.shen")       ; in progress by agent
\\ (load "src/query.shen")
\\ (load "src/scope.shen")
\\ (load "src/warn.shen")
\\ (load "src/read.shen")
\\ (load "src/print.shen")

\\ Bootstrap rules (later)
\\ (load "boot/arith.shen")
\\ etc.

(princ "shen-cas loaded (skeleton). See plan.md and test.shen.~%")
(load "test/test.shen")
