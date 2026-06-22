\\ test-multipoly.shen - Wave 4 goldens: multivariate normal form, Together,
\\ Cancel, sample-invariance, and the Variance/Skew numeric oracle cross-check.
\\ Loaded by load.shen BEFORE test/test.shen; run-multipoly-tests is wired into
\\ run-all-tests. The float math + skew evaluator here is TEST-ONLY: it never
\\ touches the rule engine; it only EVALUATES an already-assembled symbolic Skew.

\\ ============================================================================
\\ Small expr builders (interned heads).
\\ ============================================================================
(define mp-sym S -> [sym (intern S)])
(define mp-pow B E -> [[sym (protect Power)] B E])
(define mp-tim Xs -> [[sym (protect Times)] | Xs])
(define mp-plu Xs -> [[sym (protect Plus)] | Xs])
(define mp-divx N D -> [[sym (protect Divide)] N D])
(define mp-neg X -> [[sym (protect Times)] [int -1] X])
(define mp-ncdf A -> [[sym (protect NormalCDF)] A])
(define mp-simp E -> (reduce [[sym (protect Simplify)] E]))
(define mp-tog E -> (reduce [[sym (protect Together)] E]))
(define mp-can E -> (reduce [[sym (protect Cancel)] E]))

(define mp-report
  Name Ok -> (do (if Ok (output "  PASS ~A~%" Name) (output "  FAIL ~A~%" Name)) Ok))

(define mp-all-true?  [] -> true  [false | _] -> false  [_ | Xs] -> (mp-all-true? Xs))

\\ ============================================================================
\\ MUST: multivariate polynomial identities -> 0 (all inert at HEAD pre-Wave-4).
\\ ============================================================================
(define mp-must-1   \\ (S^2-X^2)-(S-X)(S+X) -> 0
  -> (content-eq
       (mp-simp (mp-plu [(mp-plu [(mp-pow (mp-sym "S") [int 2]) (mp-neg (mp-pow (mp-sym "X") [int 2]))])
                  (mp-neg (mp-tim [(mp-plu [(mp-sym "S") (mp-neg (mp-sym "X"))])
                                   (mp-plu [(mp-sym "S") (mp-sym "X")])]))]))
       [int 0]))

(define mp-must-2   \\ (x+y)^2 - (x^2+2xy+y^2) -> 0
  -> (content-eq
       (mp-simp (mp-plu [(mp-pow (mp-plu [(mp-sym "x") (mp-sym "y")]) [int 2])
                  (mp-neg (mp-pow (mp-sym "x") [int 2]))
                  (mp-neg (mp-tim [[int 2] (mp-sym "x") (mp-sym "y")]))
                  (mp-neg (mp-pow (mp-sym "y") [int 2]))]))
       [int 0]))

(define mp-must-3   \\ (a+b+c)^2 - (a^2+b^2+c^2+2ab+2ac+2bc) -> 0
  -> (content-eq
       (mp-simp (mp-plu [(mp-pow (mp-plu [(mp-sym "a") (mp-sym "b") (mp-sym "c")]) [int 2])
                  (mp-neg (mp-pow (mp-sym "a") [int 2]))
                  (mp-neg (mp-pow (mp-sym "b") [int 2]))
                  (mp-neg (mp-pow (mp-sym "c") [int 2]))
                  (mp-neg (mp-tim [[int 2] (mp-sym "a") (mp-sym "b")]))
                  (mp-neg (mp-tim [[int 2] (mp-sym "a") (mp-sym "c")]))
                  (mp-neg (mp-tim [[int 2] (mp-sym "b") (mp-sym "c")]))]))
       [int 0]))

(define mp-must-opaque   \\ (NCDF[a]+NCDF[b])^2 - NCDF[a]^2 - 2 NCDF[a]NCDF[b] - NCDF[b]^2 -> 0
  -> (content-eq
       (mp-simp (mp-plu [(mp-pow (mp-plu [(mp-ncdf (mp-sym "a")) (mp-ncdf (mp-sym "b"))]) [int 2])
                  (mp-neg (mp-pow (mp-ncdf (mp-sym "a")) [int 2]))
                  (mp-neg (mp-tim [[int 2] (mp-ncdf (mp-sym "a")) (mp-ncdf (mp-sym "b"))]))
                  (mp-neg (mp-pow (mp-ncdf (mp-sym "b")) [int 2]))]))
       [int 0]))

\\ ============================================================================
\\ MUST idempotence + sample-invariance + NEGATIVE control (gate has teeth).
\\ ============================================================================
(define mp-simplify-idem?
  E -> (let S1 (mp-simp E) (content-eq (mp-simp S1) S1)))

(define mp-simplify-corpus
  -> [(mp-pow (mp-plu [(mp-sym "S") (mp-sym "X")]) [int 2])
      (mp-pow (mp-plu [(mp-sym "a") (mp-sym "b") (mp-sym "c")]) [int 3])
      (mp-pow (mp-plu [(mp-ncdf (mp-sym "a")) (mp-ncdf (mp-sym "b"))]) [int 2])])

(define mp-corpus-ok?
  [] -> true
  [E | Es] -> (if (and (mp-simplify-idem? E) (sample-invariant? E (mp-simp E)))
                  (mp-corpus-ok? Es) false))

\\ NEGATIVE: a deliberately-wrong rewrite (drop the cross term) must FAIL the
\\ sample-invariance gate -- proving the gate is not vacuous.
(define mp-neg-control?
  -> (let Orig (mp-pow (mp-plu [(mp-sym "x") (mp-sym "y")]) [int 2])
          Wrong (mp-plu [(mp-pow (mp-sym "x") [int 2]) (mp-pow (mp-sym "y") [int 2])])
          (not (sample-invariant? Orig Wrong))))

\\ ============================================================================
\\ CORE: multivariate Together goldens (head Divide, value-equivalent in all
\\ generators) + prove-zero rational.
\\ ============================================================================
\\ rational-equivalence by sample-invariance over all generators.
(define mp-tog-1?   \\ Together[1/x+1/y] = (x+y)/(x*y)
  -> (let R (mp-tog (mp-plu [(mp-divx [int 1] (mp-sym "x")) (mp-divx [int 1] (mp-sym "y"))]))
          Active (not (content-eq (head-of R) [sym (protect Together)]))
          (and Active (sample-invariant?
                        (mp-plu [(mp-divx [int 1] (mp-sym "x")) (mp-divx [int 1] (mp-sym "y"))]) R))))

(define mp-tog-2?   \\ Together[1/(S-X)+1/(S+X)] value-equivalent
  -> (let Orig (mp-plu [(mp-divx [int 1] (mp-plu [(mp-sym "S") (mp-neg (mp-sym "X"))]))
                        (mp-divx [int 1] (mp-plu [(mp-sym "S") (mp-sym "X")]))])
          R (mp-tog Orig)
          Active (not (content-eq (head-of R) [sym (protect Together)]))
          (and Active (sample-invariant? Orig R))))

(define mp-tog-3?   \\ Together[a/b+c/d] value-equivalent (four distinct generators)
  -> (let Orig (mp-plu [(mp-divx (mp-sym "a") (mp-sym "b")) (mp-divx (mp-sym "c") (mp-sym "d"))])
          R (mp-tog Orig)
          Active (not (content-eq (head-of R) [sym (protect Together)]))
          (and Active (sample-invariant? Orig R))))

(define mp-tog-zero?   \\ Together[1/x-1/x] -> 0
  -> (content-eq (mp-tog (mp-plu [(mp-divx [int 1] (mp-sym "x")) (mp-neg (mp-divx [int 1] (mp-sym "x")))]))
                 [int 0]))

(define mp-tog-provezero?   \\ Simplify[Together[1/x+1/y]-(x+y)/(x*y)] -> 0
  -> (let T (mp-tog (mp-plu [(mp-divx [int 1] (mp-sym "x")) (mp-divx [int 1] (mp-sym "y"))]))
          (content-eq (mp-simp (mp-plu [T (mp-neg (mp-divx (mp-plu [(mp-sym "x") (mp-sym "y")])
                                                          (mp-tim [(mp-sym "x") (mp-sym "y")])))]))
                      [int 0])))

\\ ============================================================================
\\ STRETCH: multivariate Cancel goldens + NEGATIVE inertness + non-regression.
\\ ============================================================================
(define mp-can-eq?
  Orig Want -> (let R (mp-can Orig) (content-eq R Want)))

(define mp-can-1?   \\ Cancel[(S^2-X^2)/(S-X)] = X+S (canonical sort)
  -> (sample-invariant?
       (mp-divx (mp-plu [(mp-pow (mp-sym "S") [int 2]) (mp-neg (mp-pow (mp-sym "X") [int 2]))])
                (mp-plu [(mp-sym "S") (mp-neg (mp-sym "X"))]))
       (mp-can (mp-divx (mp-plu [(mp-pow (mp-sym "S") [int 2]) (mp-neg (mp-pow (mp-sym "X") [int 2]))])
                        (mp-plu [(mp-sym "S") (mp-neg (mp-sym "X"))])))))

(define mp-can-1-active?
  -> (let R (mp-can (mp-divx (mp-plu [(mp-pow (mp-sym "S") [int 2]) (mp-neg (mp-pow (mp-sym "X") [int 2]))])
                             (mp-plu [(mp-sym "S") (mp-neg (mp-sym "X"))])))
          (content-eq (head-of R) [sym (protect Plus)])))

(define mp-can-mono?   \\ Cancel[(ab+ac)/a] = b+c
  -> (let Orig (mp-divx (mp-plu [(mp-tim [(mp-sym "a") (mp-sym "b")]) (mp-tim [(mp-sym "a") (mp-sym "c")])])
                        (mp-sym "a"))
          R (mp-can Orig)
          (and (content-eq (head-of R) [sym (protect Plus)]) (sample-invariant? Orig R))))

(define mp-can-neg?   \\ Cancel[(S^2-X^2)/(S-Y)] stays INERT (no false cancellation)
  -> (let R (mp-can (mp-divx (mp-plu [(mp-pow (mp-sym "S") [int 2]) (mp-neg (mp-pow (mp-sym "X") [int 2]))])
                             (mp-plu [(mp-sym "S") (mp-neg (mp-sym "Y"))])))
          (content-eq (head-of R) [sym (protect Cancel)])))

(define mp-can-nonreg?   \\ Cancel[(x^2-1)/(x-1)] = x+1 still via univariate path
  -> (let R (mp-can (mp-divx (mp-plu [(mp-pow (mp-sym "x") [int 2]) [int -1]])
                             (mp-plu [(mp-sym "x") [int -1]])))
          (and (content-eq (head-of R) [sym (protect Plus)])
               (sample-invariant? (mp-divx (mp-plu [(mp-pow (mp-sym "x") [int 2]) [int -1]])
                                           (mp-plu [(mp-sym "x") [int -1]])) R))))

\\ ============================================================================
\\ TEST-ONLY float math (pure Shen; never touches the engine). Used solely to
\\ EVALUATE the already-assembled symbolic Skew at concrete params and compare
\\ to an independent quadrature oracle (constants precomputed by
\\ scripts/wave4_skew_check.py).
\\ ============================================================================
(define f-pi -> 3.14159265358979323846)

(define f-exp-series
  X N Term Sum K -> (if (= K N) Sum (let T2 (* Term (/ X K)) (f-exp-series X N T2 (+ Sum T2) (+ K 1)))))
(define f-exp  X -> (f-exp-series X 80 1.0 1.0 1))

(define f-sqrt-iter
  X G N -> (if (= N 0) G (f-sqrt-iter X (* 0.5 (+ G (/ X G))) (- N 1))))
(define f-sqrt  X -> (if (< X 1.0e-300) 0.0 (f-sqrt-iter X (+ X 1.0) 80)))

\\ ln(x) = 2*atanh((x-1)/(x+1)); converges for x>0.
(define f-ln-atanh
  Y2 Term Sum K -> (if (> K 200) Sum
                      (let T2 (* Term Y2) (f-ln-atanh Y2 T2 (+ Sum (/ T2 (+ (* 2 K) 1))) (+ K 1)))))
(define f-ln  X -> (let Y (/ (- X 1.0) (+ X 1.0)) (* 2.0 (f-ln-atanh (* Y Y) Y Y 1))))

\\ erf(x) = 2/sqrt(pi) * sum_{n>=0} (-1)^n x^(2n+1)/(n!(2n+1))
(define f-erf-series
  X2 Term Sum N -> (if (> N 200) Sum
                      (let NT (* Term (/ (- 0.0 X2) N))
                           (f-erf-series X2 NT (+ Sum (/ NT (+ (* 2 N) 1))) (+ N 1)))))
(define f-erf  X -> (* (/ 2.0 (f-sqrt (f-pi))) (f-erf-series (* X X) X X 1)))
(define f-ncdf X -> (* 0.5 (+ 1.0 (f-erf (/ X (f-sqrt 2.0))))))

\\ x^y for real y via exp(y*ln x) (x>0); integer y handled exactly by repeat.
(define f-ipow  B 0 -> 1.0  B N -> (if (< N 0) (/ 1.0 (f-ipow B (- 0 N))) (* B (f-ipow B (- N 1)))))
(define f-rpow  B Y -> (f-exp (* Y (f-ln B))))

\\ float of a numeric literal.
(define f-num
  [int N] -> (* N 1.0)
  [rat N D] -> (/ (* N 1.0) (* D 1.0)))

\\ ---- the test-only float evaluator over the assembled Skew expr ----
(define f-head-name  [sym S] -> (str S)  _ -> "")

(define f-eval
  [int N]   -> (* N 1.0)
  [rat N D] -> (/ (* N 1.0) (* D 1.0))
  [H | Args] -> (f-eval-head (f-head-name H) Args)
  _ -> (error "f-eval: unhandled atom"))

(define f-eval-head
  "Plus"  Args -> (f-sum Args 0.0)
  "Times" Args -> (f-prod Args 1.0)
  "Power" [B E] -> (f-eval-pow B E)
  "Exp"   [A] -> (f-exp (f-eval A))
  "Log"   [A] -> (f-ln (f-eval A))
  "NormalCDF" [A] -> (f-ncdf (f-eval A))
  "NormalPDF" [A] -> (let Z (f-eval A) (* (/ 1.0 (f-sqrt (* 2.0 (f-pi)))) (f-exp (* -0.5 (* Z Z)))))
  Name _ -> (error "f-eval-head: unhandled head"))

(define f-eval-pow
  B [int E] -> (f-ipow (f-eval B) E)
  B [rat N D] -> (f-rpow (f-eval B) (/ (* N 1.0) (* D 1.0)))
  B E -> (f-rpow (f-eval B) (f-eval E)))

(define f-sum  [] Acc -> Acc  [A | As] Acc -> (f-sum As (+ Acc (f-eval A))))
(define f-prod [] Acc -> Acc  [A | As] Acc -> (f-prod As (* Acc (f-eval A))))

(define f-abs  X -> (if (< X 0.0) (- 0.0 X) X))

\\ ============================================================================
\\ GOAL: assemble Skew via skew-put at two param sets; evaluate the symbolic
\\ result with the test-only float evaluator; compare to the quadrature oracle.
\\   set #1: k=2, a=-1/50, b=3/20, r=1/100, T=1  -> oracle skew -0.45591927
\\   set #2: k=3, a= 1/20, b=1/4,  r=1/50,  T=1  -> oracle skew -0.77694793
\\ Also: head=some for Variance/Skew at both sets; symbolic order x -> [none].
\\ ============================================================================
(define mp-skew-engine
  K A B R T -> (let SK (skew-put [int 1] K A B R T (mp-sym "u"))
                    (mp-skew-val SK)))

(define mp-skew-val
  [some E] -> (f-eval E)
  [none] -> [none])

(define mp-skew-close?
  K A B R T Oracle -> (let V (mp-skew-engine K A B R T)
                           (if (= V [none]) false (< (f-abs (- V Oracle)) 1.0e-4))))

\\ same numeric check but over an ALREADY-ASSEMBLED skew [some E]/[none], so the
\\ moments are derived once and reused (the moment derivation is the costly step).
(define mp-skew-val-close?
  SK Oracle -> (let V (mp-skew-val SK)
                    (if (= V [none]) false (< (f-abs (- V Oracle)) 1.0e-4))))

(define mp-var-head-some?
  K A B R T -> (= (head-of (variance-put [int 1] K A B R T (mp-sym "u"))) some))

(define mp-skew-head-some?
  K A B R T -> (= (head-of (skew-put [int 1] K A B R T (mp-sym "u"))) some))

\\ INERTNESS contract: Skew/Variance decline ([none]) whenever ANY underlying
\\ moment fails to derive. We exercise the sp/vp gates directly with a [none]
\\ moment (the exact decline path) rather than feeding symbolic a,b -- which the
\\ Wave-3 derivation handles but is intentionally NOT compacted here (it blows up
\\ reduce, per the Wave-3 notes; the GOAL compaction is run at NUMERIC params).
(define mp-skew-symbolic-inert?
  -> (and (= (sp [none] [none] [none]) [none])
          (and (= (sp [some [int 1]] [some [int 1]] [none]) [none])
               (= (vp [some [int 1]] [none]) [none]))))

\\ ---- STRUCTURAL (oracle check only): numerator is a fully collected
\\ sum-of-monomials in the generators -- NO residual Power-of-Plus node, and
\\ idempotent under poly-expand. NOT compared to any hand-written polynomial.
(define mp-num-of-skew
  [some [_ Num _]] -> [some Num]   \\ Times[Num, Power[Var,3/-2]]
  _ -> [none])

(define mp-no-pow-of-plus?
  [sym _] -> true
  [int _] -> true
  [rat _ _] -> true
  [[sym S] Base Exp] -> (if (= (str S) "Power")
                            (if (mp-is-plus? Base) false
                                (and (mp-no-pow-of-plus? Base) (mp-no-pow-of-plus? Exp)))
                            (mp-children-ok? [[sym S] Base Exp]))
  [H | Args] -> (mp-children-ok? [H | Args])
  _ -> true)

(define mp-is-plus?  [[sym S] | _] -> (= (str S) "Plus")  _ -> false)

(define mp-children-ok?
  [_ | Args] -> (mp-list-no-pop? Args))
(define mp-list-no-pop?
  [] -> true  [A | As] -> (if (mp-no-pow-of-plus? A) (mp-list-no-pop? As) false))

(define mp-skew-structural?
  K A B R T -> (mp-struct-check (mp-num-of-skew (skew-put [int 1] K A B R T (mp-sym "u")))))

(define mp-struct-check
  [some Num] -> (and (mp-no-pow-of-plus? Num) (content-eq (poly-expand Num) Num))
  [none] -> false)

\\ ============================================================================
\\ Driver.
\\ ============================================================================
(define run-multipoly-tests
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== Wave 4 multivariate normal form / Together / Cancel / Skew ===~%")
          \\ MUST
          M1 (mp-report "Simplify[(S^2-X^2)-(S-X)(S+X)] -> 0" (mp-must-1))
          M2 (mp-report "Simplify[(x+y)^2-(x^2+2xy+y^2)] -> 0" (mp-must-2))
          M3 (mp-report "Simplify[(a+b+c)^2-expansion] -> 0" (mp-must-3))
          MO (mp-report "Simplify[opaque (NCDF[a]+NCDF[b])^2-...] -> 0" (mp-must-opaque))
          MI (mp-report "Simplify idempotent + sample-invariant on corpus" (mp-corpus-ok? (mp-simplify-corpus)))
          MN (mp-report "NEGATIVE: dropped-cross-term FAILS sample-invariance" (mp-neg-control?))
          \\ CORE
          T1 (mp-report "Together[1/x+1/y] -> (x+y)/(x*y)" (mp-tog-1?))
          T2 (mp-report "Together[1/(S-X)+1/(S+X)] equivalent" (mp-tog-2?))
          T3 (mp-report "Together[a/b+c/d] equivalent" (mp-tog-3?))
          TZ (mp-report "Together[1/x-1/x] -> 0" (mp-tog-zero?))
          TP (mp-report "Simplify[Together[1/x+1/y]-(x+y)/(x*y)] -> 0" (mp-tog-provezero?))
          \\ STRETCH
          C1 (mp-report "Cancel[(S^2-X^2)/(S-X)] -> S+X (active+equivalent)"
                (and (mp-can-1?) (mp-can-1-active?)))
          CM (mp-report "Cancel[(ab+ac)/a] -> b+c (monomial)" (mp-can-mono?))
          CN (mp-report "NEGATIVE: Cancel[(S^2-X^2)/(S-Y)] stays inert" (mp-can-neg?))
          CR (mp-report "NON-REG: Cancel[(x^2-1)/(x-1)] -> x+1 (univariate path)" (mp-can-nonreg?))
          \\ cheap inertness contract (exercises sp/vp gates with [none], no moment derivation)
          SI (mp-report "Skew/Variance with [none] moment -> [none] (inert)" (mp-skew-symbolic-inert?))
          Ok (mp-all-true? [M1 M2 M3 MO MI MN T1 T2 T3 TZ TP C1 CM CN CR SI])
          (do (if Ok (output "multipoly (Wave 4): PASS~%") (output "multipoly (Wave 4): FAIL~%"))
              Ok)))

\\ ============================================================================
\\ HEAVY end-to-end Variance/Skew verification. NOT wired into run-all-tests: it
\\ re-derives E[P^1..3] (the costly gated Gaussian integration) at two param sets
\\ and assembles + numerically checks the skew against the quadrature oracle. Run
\\ ON DEMAND via (run-multipoly-skew-tests) -- same split rationale as the external
\\ scripts/wave3_put_moment_check.py / wave4_skew_check.py numeric cross-checks.
\\ PERF: derive the 3 moments ONCE per set and assemble skew+variance from them.
\\ ============================================================================
(define run-multipoly-skew-tests
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== Wave 4 Variance/Skew assembly (heavy; on-demand) ===~%")
          M1a (moment 1 [int 2] [rat -1 50] [rat 3 20] [rat 1 100] [int 1] (mp-sym "u"))
          M2a (moment 2 [int 2] [rat -1 50] [rat 3 20] [rat 1 100] [int 1] (mp-sym "u"))
          M3a (moment 3 [int 2] [rat -1 50] [rat 3 20] [rat 1 100] [int 1] (mp-sym "u"))
          SKA1 (sp M1a M2a M3a)
          VPA1 (vp M1a M2a)
          M1b (moment 1 [int 3] [rat 1 20] [rat 1 4] [rat 1 50] [int 1] (mp-sym "u"))
          M2b (moment 2 [int 3] [rat 1 20] [rat 1 4] [rat 1 50] [int 1] (mp-sym "u"))
          M3b (moment 3 [int 3] [rat 1 20] [rat 1 4] [rat 1 50] [int 1] (mp-sym "u"))
          SKA2 (sp M1b M2b M3b)
          VH1 (mp-report "Variance head=some (set #1)" (= (head-of VPA1) some))
          SH1 (mp-report "Skew head=some (set #1)" (= (head-of SKA1) some))
          SS1 (mp-report "Skew numerator fully collected (no Power-of-Plus, idempotent) set #1"
                 (mp-struct-check (mp-num-of-skew SKA1)))
          SK1 (mp-report "Skew numeric == quadrature oracle (set #1, ~1e-4)"
                 (mp-skew-val-close? SKA1 -0.45591927))
          SK2 (mp-report "Skew numeric == quadrature oracle (set #2, ~1e-4)"
                 (mp-skew-val-close? SKA2 -0.77694793))
          Ok (mp-all-true? [VH1 SH1 SS1 SK1 SK2])
          (do (if Ok (output "multipoly skew (Wave 4): PASS~%") (output "multipoly skew (Wave 4): FAIL~%"))
              Ok)))

(output "test-multipoly.shen loaded (Wave 4 goldens + on-demand skew oracle).~%")
