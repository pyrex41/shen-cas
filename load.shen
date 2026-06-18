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
(load "src/match-ac.shen")
\\ (load "src/match-seq.shen")  \\ deferred: prolog seq match needs boolean-hardening
(load "src/core.shen")
(load "src/scope.shen")
(load "src/read.shen")

(output "shen-cas loaded (skeleton). See plan.md and test.shen.~%")
(load "test/test.shen")