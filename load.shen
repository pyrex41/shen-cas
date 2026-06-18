\\ shen-cas top-level loader
\\ Usage: (load "load.shen") from repo root (adjust paths for your Shen)

\\ expr loads store (its only loader); every other module relies on this order
\\ rather than re-loading its deps (16e reload hygiene).
(load "src/expr.shen")
(load "src/pattern.shen")
(load "src/num.shen")
(load "src/db.shen")
(load "src/rule.shen")
(load "src/attrs.shen")
(load "src/query.shen")
(load "src/warn.shen")
\\ Matcher override order is load-order significant; LAST definition of
\\ match-compound / match-arg-list wins: match (first-order) -> match-seq (sequences)
\\ -> match-ac (Orderless/Flat). match-seq is deferred until Wave 1 (17c).
(load "src/match.shen")
\\ (load "src/match-seq.shen")  \\ deferred (Wave 1 / SCUD 17c): prolog seq match needs option-type rewrite
(load "src/match-ac.shen")
(load "src/core.shen")
(load "src/scope.shen")
(load "src/read.shen")

(output "shen-cas loaded (skeleton). See plan.md and test.shen.~%")
(load "test/test.shen")