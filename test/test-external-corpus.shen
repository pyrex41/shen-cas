\\ test-external-corpus.shen
\\ Curated external CAS corpus seeds.
\\
\\ Sources:
\\ - Rubi MathematicaSyntaxTestSuite, MIT License.
\\   https://github.com/RuleBasedIntegration/MathematicaSyntaxTestSuite
\\ - SymPy, New BSD License.
\\   https://github.com/sympy/sympy
\\
\\ This file intentionally adapts a small supported slice instead of importing a
\\ foreign harness wholesale. See notes/external-corpora.md for import policy.
\\
\\ POLICY (per project owner): every feature the kernel actually implements gets a
\\ live pass/inert case with a SOUND oracle; everything not yet implemented is
\\ marked 'unsupported' (skipped, tracked as the compatibility frontier). Oracles:
\\   integrate/pass  : Simplify[D[Integrate[f,x],x] - f] == 0   (differentiate-back)
\\   integrate/inert : head of Integrate[f,x] is still Integrate (Rubi bare-f form)
\\   solve/pass      : every returned root substituted back into the eqn reduces to 0
\\   <algebra>/pass  : reduce(Input) content-eq reduce(Expected)  (canonical, orderless-invariant)
\\   <op>/inert      : reduce leaves the expression unevaluated (a no-op)
\\   parser/pass     : print-expr o parse-expr-string round-trips

(define external-case
  Source Feature Mode Label Input Expected -> [external-case Source Feature Mode Label Input Expected])

(define ext-ok -> (protect ok))
(define ext-fail -> (protect fail))
(define ext-skip -> (protect skip))

(define ext-x -> [sym (intern "x")])
(define ext-d-head -> [sym (protect D)])
(define ext-int-head -> [sym (protect Integrate)])
(define ext-simplify-head -> [sym (protect Simplify)])
(define ext-equal-head? [sym S] -> (= (str S) "Equal") _ -> false)
(define ext-list-head?  [sym S] -> (= (str S) "List")  _ -> false)

(define ext-d
  E -> [(ext-d-head) E (ext-x)])

(define ext-integral
  F -> [(ext-int-head) F (ext-x)])

(define ext-simplify
  E -> (reduce [(ext-simplify-head) E]))

\\ Property oracle for integration cases: Simplify[D[Integrate[f,x],x] - f] == 0
(define ext-integrates-back?
  F -> (let R (reduce (ext-integral F))
            Back (ext-simplify [[sym (protect Plus)]
                                (ext-d R)
                                [[sym (protect Times)] [int -1] F]])
            (content-eq Back [int 0])))

(define ext-integral-inert?
  F -> (= (head (reduce (ext-integral F))) (ext-int-head)))

\\ exact: reduce BOTH sides and compare canonically. content-eq is orderless-
\\ invariant (Plus/Times), so any correct equivalent of Expected is accepted.
(define ext-exact-reduction?
  Input Expected -> (content-eq (reduce (parse-expr-string Input))
                                (reduce (parse-expr-string Expected))))

\\ stays-inert: reduce(Input) is a no-op. For a Simplify[E] wrapper we compare
\\ against reduce(E) (Simplify is always consumed); otherwise against Input itself.
(define ext-stays-inert?
  Input -> (let In (parse-expr-string Input)
                (ext-noop? In)))
(define ext-noop?
  [H Arg] -> (if (ext-is-simplify? H)
                 (content-eq (reduce [H Arg]) (reduce Arg))
                 (content-eq (reduce [H Arg]) [H Arg]))
  In -> (content-eq (reduce In) In))
(define ext-is-simplify?
  [sym S] -> (= (str S) "Simplify")
  _ -> false)

\\ solve oracle: reduce to a List of roots; substitute each root back into the
\\ equation's polynomial (L-R, or E for E==0) and require it reduces to 0.
(define ext-solve-ok?
  Input -> (let In (parse-expr-string Input)
                Sol (reduce In)
                (if (not (ext-list-head? (head Sol)))
                    false
                    (let EQ (hd (tl In))
                         V (hd (tl (tl In)))
                         P (ext-poly-of EQ)
                         Roots (tl Sol)
                         (ext-all-roots-zero? P V Roots)))))
(define ext-poly-of
  [H L R] -> (if (ext-equal-head? H)
                 [[sym (protect Plus)] L [[sym (protect Times)] [int -1] R]]
                 [H L R])
  EQ -> EQ)
(define ext-all-roots-zero?
  _ _ [] -> true
  P V [R | Rs] -> (if (content-eq (reduce (ext-subst V R P)) [int 0])
                      (ext-all-roots-zero? P V Rs)
                      false))
(define ext-subst
  V R [sym S] -> (if (content-eq V [sym S]) R [sym S])
  _ _ [int N] -> [int N]
  _ _ [rat N D] -> [rat N D]
  V R [H | Args] -> [(ext-subst V R H) | (ext-subst-list V R Args)]
  _ _ X -> X)
(define ext-subst-list
  _ _ [] -> []
  V R [A | As] -> [(ext-subst V R A) | (ext-subst-list V R As)])

(define ext-parser-roundtrip?
  Input -> (let In (parse-expr-string Input)
                Printed (print-expr In)
                Back (parse-expr-string Printed)
                (content-eq Back In)))

\\ ------------------------------------------------------------------------
\\ Dispatch. Rubi integration cases carry a BARE integrand as Input; all other
\\ cases carry a full (head-wrapped) expression.
\\ ------------------------------------------------------------------------
(define ext-run-case
  [external-case Source Feature Mode Label Input Expected] ->
    (cond
      ((= Mode (protect unsupported))
       (ext-skip))
      ((= Feature (protect parser))
       (ext-report Label "parser round-trip" Input (ext-parser-roundtrip? Input)))
      ((and (= Feature (protect integrate)) (= Source (protect rubi)))
       (if (= Mode (protect pass))
           (ext-report Label "Integrate differentiates back" Input (ext-integrates-back? (parse-expr-string Input)))
           (ext-report Label "Integrate inert" Input (ext-integral-inert? (parse-expr-string Input)))))
      ((= Mode (protect inert))
       (ext-report Label "stays inert" Input (ext-stays-inert? Input)))
      ((and (= Feature (protect solve)) (= Mode (protect pass)))
       (ext-report Label "roots satisfy equation" Input (ext-solve-ok? Input)))
      ((= Mode (protect pass))
       (ext-report Label "reduces to expected" Input (ext-exact-reduction? Input Expected)))
      (true
       (do (output "  FAIL ~A/~A: unknown corpus mode ~A for ~A~%" Source Feature Mode Label)
           (ext-fail))))
  X -> (do (output "  FAIL malformed external corpus case: ~A~%" X) (ext-fail)))

(define ext-report
  Label _ Input true  -> (do (output "  PASS ~A: ~A~%" Label Input) (ext-ok))
  Label What Input false -> (do (output "  FAIL ~A: ~A (~A)~%" Label Input What) (ext-fail)))

(define count-result
  _ [] -> 0
  K [X | Xs] -> (+ (if (= K X) 1 0) (count-result K Xs)))

(define run-corpus-group
  Name Cases -> (let Results (map (/. C (ext-run-case C)) Cases)
                     OkN (count-result (ext-ok) Results)
                     FailN (count-result (ext-fail) Results)
                     SkipN (count-result (ext-skip) Results)
                     Total (length Results)
                     Pass (= FailN 0)
                     (do (output "~A corpus: ok=~A fail=~A skip=~A total=~A~%" Name OkN FailN SkipN Total)
                         Pass)))

(define rubi-integration-cases
  -> [
    \\ Supported elementary integration slice, checked by differentiate-back.
    (external-case (protect rubi) (protect integrate) (protect pass) "constant" "1" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "constant-5" "5" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "constant-negative" "-3" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "linear-variable" "x" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "linear-plus-constant" "x+1" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "power-2" "x^2" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "power-3" "x^3" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "power-4" "x^4" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "reciprocal" "x^-1" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "negative-power" "x^-2" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "sin" "Sin[x]" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "cos" "Cos[x]" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "exp" "Exp[x]" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "linear-polynomial" "2*x+3" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "quadratic-plus-linear" "x^2+x" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "quadratic-polynomial" "3*x^2+2*x+1" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "rational-coefficient-linear" "1/2*x" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "scaled-power" "3*x^2" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "scaled-sin" "2*Sin[x]" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "scaled-cos" "2*Cos[x]" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "scaled-exp" "3*Exp[x]" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "by-parts-x-exp" "x*Exp[x]" "")
    \\ Current inert frontier: the kernel declines these safely (head stays Integrate).
    (external-case (protect rubi) (protect integrate) (protect inert) "fresnel-shape" "Sin[x^2]" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "unknown-function" "ExtUnknown[x]" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "sin-squared" "Sin[x]^2" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "exp-quadratic" "Exp[x^2]" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "rational-quadratic" "1/(1+x^2)" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "log" "Log[x]" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "tan" "Tan[x]" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "x-log-x" "x*Log[x]" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "sin-cos-product" "Sin[x]*Cos[x]" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "shifted-reciprocal" "1/(x+1)" "")
    (external-case (protect rubi) (protect integrate) (protect inert) "sqrt-x" "Sqrt[x]" "")
    \\ Linear-argument u-substitution (wired integrate-linear-usub), diff-back verified.
    (external-case (protect rubi) (protect integrate) (protect pass) "linear-arg-sin" "Sin[2*x+3]" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "linear-arg-cos" "Cos[2*x+3]" "")
    (external-case (protect rubi) (protect integrate) (protect pass) "linear-arg-exp" "Exp[2*x+3]" "")
    \\ Frontier: not yet implemented (skipped). Flip to pass/inert as features land.
    (external-case (protect rubi) (protect integrate) (protect unsupported) "sin-cubed" "Sin[x]^3" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "cos-squared" "Cos[x]^2" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "sec-squared" "Sec[x]^2" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "exp-sin-product" "Exp[x]*Sin[x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "exp-cos-product" "Exp[x]*Cos[x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "atan-shape" "1/(1+x^2)" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "rational-linear-over-quadratic" "x/(1+x^2)" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "partial-fraction" "(x+1)/(x^2-1)" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "inverse-sqrt-x" "1/Sqrt[x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "sqrt-linear" "Sqrt[1+x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "x-sqrt-linear" "x*Sqrt[1+x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "inverse-trig-asin" "ArcSin[x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "inverse-trig-atan" "ArcTan[x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "erf" "Erf[x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "gamma" "Gamma[x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "bessel" "BesselJ[0,x]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "piecewise" "Piecewise[{{x,x>0},{-x,x<0}}]" "")
    (external-case (protect rubi) (protect integrate) (protect unsupported) "definite-gaussian" "Integrate[Exp[-x^2],{x,-Infinity,Infinity}]" "")
  ])

(define sympy-algebra-cases
  -> [
    \\ Arithmetic / rational normalization (exact reduction).
    (external-case (protect sympy) (protect simplify) (protect pass) "integer-add" "2+3" "5")
    (external-case (protect sympy) (protect simplify) (protect pass) "integer-product" "2*3*4" "24")
    (external-case (protect sympy) (protect simplify) (protect pass) "integer-power" "2^3" "8")
    (external-case (protect sympy) (protect simplify) (protect pass) "parenthesized-power" "(2+3)^2" "25")
    (external-case (protect sympy) (protect simplify) (protect pass) "rational-normalize" "6/4" "3/2")
    (external-case (protect sympy) (protect simplify) (protect pass) "rational-add" "1/2+1" "3/2")
    (external-case (protect sympy) (protect simplify) (protect pass) "rational-mul" "1/2*4" "2")
    (external-case (protect sympy) (protect simplify) (protect pass) "nested-arith" "2*(3+4)" "14")
    (external-case (protect sympy) (protect simplify) (protect pass) "add-zero-right" "x+0" "x")
    (external-case (protect sympy) (protect simplify) (protect pass) "add-zero-left" "0+x" "x")
    (external-case (protect sympy) (protect simplify) (protect pass) "add-zero-nary" "0+x+y" "x+y")
    (external-case (protect sympy) (protect simplify) (protect pass) "mul-one-right" "x*1" "x")
    (external-case (protect sympy) (protect simplify) (protect pass) "mul-one-left" "1*x" "x")
    (external-case (protect sympy) (protect simplify) (protect pass) "mul-one-nary" "2*1*x" "2*x")
    (external-case (protect sympy) (protect simplify) (protect pass) "mul-zero" "x*0" "0")
    (external-case (protect sympy) (protect simplify) (protect pass) "mul-zero-nary" "2*x*0" "0")
    (external-case (protect sympy) (protect simplify) (protect pass) "power-one" "x^1" "x")
    (external-case (protect sympy) (protect simplify) (protect pass) "power-zero" "x^0" "1")
    (external-case (protect sympy) (protect simplify) (protect pass) "zero-positive-power" "0^2" "0")
    (external-case (protect sympy) (protect simplify) (protect pass) "simplify-x-plus-x" "Simplify[x+x]" "2*x")
    (external-case (protect sympy) (protect simplify) (protect pass) "collect-like-terms" "Simplify[3*x+2*x]" "5*x")
    (external-case (protect sympy) (protect simplify) (protect pass) "collect-three-terms" "Simplify[2*x+3*x+4*x]" "9*x")
    (external-case (protect sympy) (protect simplify) (protect pass) "times-to-power" "Simplify[x*x]" "x^2")
    (external-case (protect sympy) (protect simplify) (protect pass) "times-to-power-cubed" "Simplify[x*x*x]" "x^3")
    (external-case (protect sympy) (protect simplify) (protect inert) "zero-to-zero" "0^0" "")
    \\ Expand (exact reduction; orderless-invariant).
    (external-case (protect sympy) (protect expand) (protect pass) "expand-binomial-2" "Expand[(x+1)^2]" "1+2*x+x^2")
    (external-case (protect sympy) (protect expand) (protect pass) "expand-binomial-3" "Expand[(x+y)^3]" "x^3+3*x^2*y+3*x*y^2+y^3")
    (external-case (protect sympy) (protect expand) (protect pass) "expand-product" "Expand[(2*x-3)*(x+5)]" "2*x^2+7*x-15")
    \\ Factor (exact; product form is orderless-invariant).
    (external-case (protect sympy) (protect factor) (protect pass) "factor-difference-squares" "Factor[x^2-1]" "(x-1)*(x+1)")
    (external-case (protect sympy) (protect factor) (protect pass) "factor-repeated-root" "Factor[x^2-2*x+1]" "(x-1)*(x-1)")
    (external-case (protect sympy) (protect factor) (protect pass) "factor-common-monomial" "Factor[x^3-x]" "x*(x+1)*(x-1)")
    \\ Cancel / Together (exact).
    (external-case (protect sympy) (protect cancel) (protect pass) "cancel-rational" "Cancel[(x^2-1)/(x-1)]" "x+1")
    (external-case (protect sympy) (protect together) (protect pass) "together-rationals" "Together[1/x+1/(x+1)]" "(2*x+1)/(x^2+x)")
    \\ Solve (substitute-back oracle).
    (external-case (protect sympy) (protect solve) (protect pass) "solve-linear" "Solve[x-3==0,x]" "")
    (external-case (protect sympy) (protect solve) (protect pass) "solve-quadratic" "Solve[x^2-5*x+6==0,x]" "")
    (external-case (protect sympy) (protect solve) (protect pass) "solve-cubic-factorable" "Solve[x^3-x==0,x]" "")
    \\ Differentiation (exact).
    (external-case (protect sympy) (protect diff) (protect pass) "diff-tan" "D[Tan[x],x]" "Sec[x]^2")
    (external-case (protect sympy) (protect diff) (protect pass) "diff-log" "D[Log[x],x]" "x^-1")
    (external-case (protect sympy) (protect diff) (protect pass) "diff-composed-log" "D[Log[1+x^2],x]" "2*x*(1+x^2)^-1")
    (external-case (protect sympy) (protect diff) (protect pass) "diff-arctan" "D[ArcTan[x],x]" "(1+x^2)^-1")
    (external-case (protect sympy) (protect diff) (protect pass) "diff-arcsin" "D[ArcSin[x],x]" "(1-x^2)^(-1/2)")
    (external-case (protect sympy) (protect diff) (protect pass) "diff-arccos" "D[ArcCos[x],x]" "-(1-x^2)^(-1/2)")
    (external-case (protect sympy) (protect diff) (protect pass) "diff-sec" "D[Sec[x],x]" "Sec[x]*Tan[x]")
    \\ Series (exact, exact rational coefficients).
    (external-case (protect sympy) (protect series) (protect pass) "series-exp" "Series[Exp[x],x,5]" "1+x+1/2*x^2+1/6*x^3+1/24*x^4+1/120*x^5")
    (external-case (protect sympy) (protect series) (protect pass) "series-sin" "Series[Sin[x],x,7]" "x-1/6*x^3+1/120*x^5-1/5040*x^7")
    \\ Limit (exact value).
    (external-case (protect sympy) (protect limit) (protect pass) "limit-sinx-over-x" "Limit[Sin[x]/x,x,0]" "1")
    \\ Parser / printer round-trips.
    (external-case (protect sympy) (protect parser) (protect pass) "nested-app" "f[g[x],y]" "")
    (external-case (protect sympy) (protect parser) (protect pass) "multi-arg-app" "f[x,y,z]" "")
    (external-case (protect sympy) (protect parser) (protect pass) "precedence-parens" "(a+b)*c" "")
    (external-case (protect sympy) (protect parser) (protect pass) "implicit-multiplication" "2a" "")
    (external-case (protect sympy) (protect parser) (protect pass) "division" "a/b" "")
    (external-case (protect sympy) (protect parser) (protect pass) "subtraction-symbol" "x-y" "")
    (external-case (protect sympy) (protect parser) (protect pass) "unary-power" "-x^2" "")
    (external-case (protect sympy) (protect parser) (protect pass) "subtraction-coeff" "x-2*y" "")
    (external-case (protect sympy) (protect parser) (protect pass) "right-assoc-power" "x^y^z" "")
    (external-case (protect sympy) (protect parser) (protect pass) "equation" "x^2==1" "")
    \\ Simplify identities we do NOT implement: the kernel safely leaves them as-is.
    (external-case (protect sympy) (protect simplify) (protect inert) "trig-pythagorean" "Simplify[Sin[x]^2+Cos[x]^2]" "")
    (external-case (protect sympy) (protect simplify) (protect inert) "log-exp-cancel" "Simplify[Log[Exp[x]]]" "")
    (external-case (protect sympy) (protect simplify) (protect inert) "sqrt-square" "Simplify[Sqrt[x^2]]" "")
    \\ Integration we do NOT implement: declines safely (head stays Integrate).
    (external-case (protect sympy) (protect integrate) (protect inert) "integrate-log" "Integrate[Log[x],x]" "")
    (external-case (protect sympy) (protect integrate) (protect inert) "integrate-tan" "Integrate[Tan[x],x]" "")
    \\ Frontier: no head/concept yet (skipped; may not even parse).
    (external-case (protect sympy) (protect simplify) (protect unsupported) "abs-square" "Simplify[Abs[x]^2]" "")
    (external-case (protect sympy) (protect limit) (protect unsupported) "limit-at-infinity" "Limit[1/x,x,Infinity]" "")
    (external-case (protect sympy) (protect matrix) (protect unsupported) "matrix-determinant" "Det[{{a,b},{c,d}}]" "")
    (external-case (protect sympy) (protect assumptions) (protect unsupported) "positive-sqrt-square" "Refine[Sqrt[x^2],x>0]" "")
    (external-case (protect sympy) (protect piecewise) (protect unsupported) "piecewise-fold" "Piecewise[{{x,x>0},{0,True}}]" "")
    (external-case (protect sympy) (protect special) (protect unsupported) "gamma-shift" "Simplify[Gamma[x+1]/Gamma[x]]" "")
    (external-case (protect sympy) (protect special) (protect unsupported) "bessel-derivative" "D[BesselJ[0,x],x]" "")
  ])

(define run-external-corpus-tests
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== external CAS corpus seeds (Rubi + SymPy) ===~%")
          RubiOk (run-corpus-group "Rubi" (rubi-integration-cases))
          SympyOk (run-corpus-group "SymPy" (sympy-algebra-cases))
          Ok (and RubiOk SympyOk)
          (do (if Ok
                  (output "external corpus seeds: PASS~%")
                  (output "external corpus seeds: FAIL~%"))
              Ok)))

(output "test-external-corpus.shen loaded (Rubi + SymPy corpus seeds).~%")
