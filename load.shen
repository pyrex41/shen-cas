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
(load "src/match-seq.shen")  \\ SCUD 17c: prolog seq match (project option type)
(load "src/match-ac.shen")
\\ SCUD 18c: wired predicates (SameQ/UnsameQ/FreeQ/NumberQ) must load before
\\ core so core's try-builtin hook can call calc-builtin.
(load "src/calc-helpers.shen")
\\ Elementary & number-theory function layer (Abs/Sign/Floor/.../GCD/Factorial/...).
\\ calc-by-name (calc-helpers) dispatches here at reduce time; defs only need to be
\\ present before core loads, so load order after calc-helpers + num suffices.
(load "src/numfun.shen")
\\ SCUD 17 Wave B: polynomial normal form (Expand/PolynomialQ); needs num + store
\\ + calc-helpers' free-of?. calc-by-name only CALLS poly-expand/polynomial-q? at
\\ runtime, so load order after calc-helpers (defs live by reduce time) suffices.
(load "src/poly.shen")
\\ SCUD 18 Wave C: univariate polynomial algebra (PolynomialGCD/Cancel/Together/
\\ Factor); needs poly.shen + num.shen + calc-helpers' free-of?/free-symbols.
(load "src/polyalg.shen")
\\ SCUD 19 Wave D: solve polynomial equations in one var over Q (Solve / == reader);
\\ needs polyalg's coeff-vector bridge + Factor, num.shen, calc-helpers' free-of?.
(load "src/solve.shen")
\\ SCUD 20 Wave E: Taylor Series + Limit (Series / Limit heads); needs the D rule
\\ library (via core's boot), Expand/Cancel (polyalg), num.shen, calc-helpers'
\\ free-of?. series-builtin/limit-builtin are only CALLED at reduce time, so the
\\ defs being present before core loads suffices.
(load "src/series.shen")
(load "src/core.shen")
(load "src/scope.shen")
(load "src/read.shen")
(load "src/print.shen")

(output "shen-cas loaded (skeleton). See plan.md and test.shen.~%")
(load "test/test-calculus.shen")  \\ SCUD 22: defines run-calculus-tests (used by run-all-tests)
(load "test/test-reader.shen")    \\ SCUD 16 Wave A: defines run-reader-printer-tests
(load "test/test-poly.shen")      \\ SCUD 17 Wave B: defines run-poly-tests
(load "test/test-polyalg.shen")   \\ SCUD 18 Wave C: defines run-polyalg-tests
(load "test/test-solve.shen")     \\ SCUD 19 Wave D: defines run-solve-tests
(load "test/test-series.shen")    \\ SCUD 20 Wave E: defines run-series-tests
(load "test/test-numfun.shen")    \\ elementary & number-theory fns: defines run-numfun-tests
(load "test/test-elemlib.shen")   \\ recip-trig/hyperbolic/inverse-hyperbolic: defines run-elemlib-tests
(load "test/test-numtheory.shen") \\ number theory: defines run-numtheory-tests
(load "test/test-properties.shen") \\ Property-style checks beyond exact goldens
(load "test/test-external-corpus.shen")  \\ Rubi/SymPy corpus: defines run-external-corpus-tests
(load "test/test.shen")