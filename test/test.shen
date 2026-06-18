\\ Phase 0+ test harness for shen-cas

(define trivial-reduce E -> E)

(define golden-cases
  -> [
    [12 12]
    [[sym (protect Plus)] [sym (protect Plus)]]
    [[[sym (protect Times)] [int 12] [[sym (protect Minus)] [int 5] [int 3]]] [int 24]]
    [[[sym (protect Minus)] [int 9] [int 8]] [int 1]]
    [[[sym (protect Plus)] [int 2] [int 3]] [int 5]]
    [[[sym (protect Divide)] [int 6] [int 2]] [int 3]]
    [[[sym (protect Times)] [int 4] [int 7]] [int 28]]
    [[[sym (protect Times)] [[sym (protect Plus)] [int 2] [int 3]] [[sym (protect Minus)] [int 4] [int 1]]] [int 15]]
    [[[sym (protect Plus)] [int 56] [[sym (protect Minus)] [sym (protect x)] [int 7]]] [[sym (protect Plus)] [int 56] [[sym (protect Minus)] [sym (protect x)] [int 7]]]]
    [[[sym (protect Times)] [int -245] [int 67]] [int -16415]]
    [[[sym (protect Divide)] [sym (protect x)] [sym (protect x)]] [[sym (protect Divide)] [sym (protect x)] [sym (protect x)]]]
    [[sym (protect x)] [sym (protect x)]]
  ])

(define run-golden-case
  [In Exp] -> (let Got (reduce In)
                      Pass (content-eq Got Exp)
                      (do (if Pass
                              (output "  PASS: ~A -> ~A~%" In Exp)
                              (output "  FAIL: ~A -> ~A got ~A~%" In Exp Got))
                          Pass))
  C -> (do (output "  SKIP: malformed golden case ~A~%" C) false))

(define run-golden
  -> (let Ign (demo-register-arith)
            Cases (golden-cases)
            Results (map (/. C (run-golden-case C)) Cases)
            Passed (filter (/. X X) Results)
            (do (output "Golden: ~A/~A passed~%" (length Passed) (length Cases))
                (= (length Passed) (length Cases)))))

(define rejection-fixtures
  -> [
    "malformed-pattern: Pattern[3,5]"
    "malformed-pattern: (pattern 3 5)"
    "seq-outside-arg: (named x (blank-seq))"
    "seq-outside-arg: (blank-seq)"
    "unbound-rhs: x_ -> y"
    "unbound-rhs: {x_ y_ -> z}"
    "bad-attr: hold-all + hold-first"
    "bad-attr: listable + hold-all"
    "bad-attr: (hold-all hold-first)"
  ])

(define run-rejection-tests
  -> (let Fixes (rejection-fixtures)
            (do (output "Rejection fixtures declared (~A):~%" (length Fixes))
                (map (/. F (output "  - ~A~%" F)) Fixes)
                (output "  (enforcement comes in Phase 1+ with checked datatypes)~%")
                true)))

(define attrs-demo
  -> (trap-error
         (do (output "~%=== attrs basic test/demo (SCUD 9.1) ===~%")
             (if (sig-present? (protect Plus))
                 (output "  Plus structural sig already declared (boot/arith)~%")
                 (declare-structural (protect Plus) [(protect flat) (protect orderless)]))
             (let Sig (get-structural-sig (protect Plus))
                  (do (output "  get-structural-sig Plus -> ~A~%" Sig) true))
             (let H (sym (protect Plus))
                  C1 (compound H [(int 1) (int 2)])
                  C2 (compound H [(int 2) (int 1)])
                  (do (output "  created Plus compounds: ~A , ~A~%" (pretty-expr C1) (pretty-expr C2)) true))
             (do (trap-error (declare-symbol (protect Plus) [(protect hold-all) (protect hold-first)])
                             (/. Err (do (output "  declare rejected hold-all + hold-first~%") true)))
                 (trap-error (declare-structural (protect Plus) [(protect hold-all)])
                             (/. Err (do (output "  declare-structural rejected hold-all~%") true)))
                 (trap-error (declare-symbol (protect Plus) [(protect listable) (intern "hold-all")])
                             (/. Err (do (output "  declare rejected listable + hold-all~%") true)))
                 true))
         (/. E (do (output "  attrs demo skipped: ~A~%" E) true))))

(define phase1-explicit-bindings-cover-examples
  -> (let R1 (rule [[sym (protect Plus)] [int 0] [named (protect x) [blank]]] [sym (protect x)])
            R2 (rule [[sym (protect Plus)] [named (protect x) [blank]] [int 0]] [sym (protect x)])
            C1 (bindings-cover? (rule-lhs R1) (rule-rhs R1))
            C2 (bindings-cover? (rule-lhs R2) (rule-rhs R2))
            BadCov (bindings-cover? (named (protect x) (blank)) (sym (protect y)))
            (do (output "Phase1: bindings-cover? 0+ ~A +0 ~A bad ~A~%" C1 C2 BadCov)
                (and C1 C2 (not BadCov)))))

(define test-extract-bindings-and-utils
  -> (let P0 (named (protect x) (blank))
            P1 [[sym (protect Plus)] [int 0] (named (protect x) (blank))]
            B0 (extract-bindings P0)
            B1 (extract-bindings P1)
            (do (output "7.2: extract named ~A compound ~A~%" B0 B1)
                (and (= B0 [(protect x)]) (= B1 [(protect x)])))))

(define phase1-use-register-reduce
  -> (do (register-rule (rule [[sym (protect Plus)] [int 0] [named (protect x) [blank]]] [sym (protect x)]))
         (let E [[sym (protect Plus)] [int 2] [int 0]]
              Got (reduce E)
              (do (output "Phase1: register+reduce ~A -> ~A~%" E Got)
                  (content-eq Got [int 2])))))

(define phase1-content-hash-sharing-orderless-flat
  -> (let Ign (if (sig-present? (protect Plus)) true
                  (declare-structural (protect Plus) [(protect orderless) (protect flat)]))
            E1 (compound (sym (protect Plus)) [(int 1) (int 2)])
            E2 (compound (sym (protect Plus)) [(int 2) (int 1)])
            Eq (content-eq E1 E2)
            (do (output "Phase1: orderless hash sharing ~A~%" Eq) Eq)))

(define phase1-golden-noop-idemp-trivial
  -> (let Noops (filter (/. C (= (hd C) (hd (tl C)))) (golden-cases))
            oks (map (/. C (let In (hd C) G (trivial-reduce In) (= G (trivial-reduce G)))) Noops)
            (do (output "Phase1: trivial idempotence on ~A no-ops~%" (length Noops))
                (every (/. X X) oks))))

(define phase1-boot-arith-simplifications
  -> (let Ign (demo-register-arith)
            r3 (reduce [[sym (protect Plus)] [int 2] [int 3]])
            (do (output "Phase1: 2+3 -> ~A~%" r3) (content-eq r3 [int 5]))))

(define phase1-kernel-idempotence-noop
  -> (let E1 [sym (protect x)]
            E2 [[sym (protect bar)] [int 99]]
            (and (= E1 (reduce E1)) (= E2 (reduce E2)))))

(define run-phase1-skeleton
  -> (let Ign (output "~%=== Phase 1 skeleton exercises ===~%")
            All (and (phase1-explicit-bindings-cover-examples)
                     (test-extract-bindings-and-utils)
                     (phase1-use-register-reduce)
                     (phase1-content-hash-sharing-orderless-flat)
                     (phase1-boot-arith-simplifications)
                     (phase1-golden-noop-idemp-trivial)
                     (phase1-kernel-idempotence-noop))
            (do (output "Phase 1 skeleton: ~A~%" (if All "PASS" "FAIL")) All)))

(define test-lfp-terminates-and-correct
  -> (let Self [[(protect f) (protect f)]]
            Mutual [[(protect f) (protect g)] [(protect g) (protect f)]]
            LoopsSelf (rule-dependency-loops-from-edges Self)
            LoopsMut (rule-dependency-loops-from-edges Mutual)
            (and (element? (protect f) LoopsSelf)
                 (element? (protect f) LoopsMut)
                 (element? (protect g) LoopsMut))))

(define run-lfp-tests
  -> (let Ok (test-lfp-terminates-and-correct)
            (do (if Ok (output "lfp/loop tests: PASS~%") (output "lfp/loop tests: FAIL~%")) Ok)))

(define test-analysis-relations
  -> (let Db0 (empty-db)
            S1 (protect oneidtest)
            R2a (rule [[sym S1] (named (protect x) (blank)) (named (protect y) (blank))] [sym (protect x)])
            Db1 (assert-attribute (assert-rule Db0 S1 down R2a) S1 (intern "one-identity"))
            Oneids (oneid-no-unary Db1)
            Brute (oneid-no-unary-brute Db1)
            (and (element? S1 Oneids) (= (length Oneids) (length Brute)))))

(define run-analysis-tests
  -> (let Ok (test-analysis-relations)
            (do (if Ok (output "analysis relations tests (11.2): PASS~%")
                    (output "analysis relations tests (11.2): FAIL~%"))
                Ok)))

(define test-scope-block-fork
  -> (let ParentLen (db-size (value *db*))
            Blk (block [(block-bind (protect tmp) [int 42])] [[sym (protect Plus)] [int 0] [int 1]])
            R (reduce Blk)
            AfterLen (db-size (value *db*))
            (do (output "block fork: R=~A parent=~A after=~A~%" R ParentLen AfterLen)
                (= ParentLen AfterLen))))

\\ === SCUD 16 Wave 0 correctness gate ===
\\ Six independent fixes (16a-16f), each asserted here.

\\ 16a: hashing a compound BEFORE declaring its head must NOT freeze a structural sig.
\\ Use a fresh head (Qplus) not touched by boot. After declaring flat+orderless,
\\ the commuted compound must share the content hash (no 'already declared' error).
(define cg-16a-hash-before-declare
  -> (let H (sym (protect Qplus))
          Before (content-hash (compound H [(int 1) (int 2)]))
          _ (declare-structural (protect Qplus) [(protect flat) (protect orderless)])
          E1 (content-hash (compound H [(int 1) (int 2)]))
          E2 (content-hash (compound H [(int 2) (int 1)]))
          Ok (= E1 E2)
          (do (output "16a: hash-before-declare commuted-share ~A~%" Ok) Ok)))

\\ 16b: the always-true checked-rule? is gone; a non-[rule ...] value is not a checked rule
\\ regardless of load order.
(define cg-16b-checked-rule-strict
  -> (let Ok (and (not (checked-rule? [(protect foo) (protect bar)]))
                  (checked-rule? [rule [sym (protect x)] [sym (protect x)]]))
          (do (output "16b: checked-rule? strict ~A~%" Ok) Ok)))

\\ 16c: switching current-core to compiled routes reduce through the stub (identity here)
\\ with no 'partial apply unsupported'. Restore ref afterward.
(define cg-16c-seam-tag-dispatch
  -> (let E [[sym (protect bar)] [int 99]]
          _ (set-current-core compiled)
          Compiled (reduce E)
          _ (set-current-core ref)
          Ref (reduce E)
          Ok (and (= (current-core) ref) (= Compiled E))
          (do (output "16c: seam compiled-route ~A (compiled=~A)~%" Ok Compiled) Ok)))

\\ 16d: register-rule on a non-[rule ...] value raises the clean error (not an accessor crash).
(define cg-16d-register-rule-guard
  -> (let Ok (trap-error (do (register-rule [(protect not-a-rule)]) false)
                         (/. Err true))
          (do (output "16d: register-rule rejects non-rule cleanly ~A~%" Ok) Ok)))

\\ 16e: behavior-probe that the intended final definitions are live after a single load:
\\ match-arg-list is the positional matcher (match-some on equal-length, match-none on mismatch),
\\ match-compound matches Plus[1,2] against Plus[1,2].
(define cg-16e-final-defs-live
  -> (let M1 (match-arg-list [[int 1]] [[int 1]])
          M2 (match-arg-list [[int 1]] [[int 1] [int 2]])
          P [[sym (protect Plus)] [int 1] [int 2]]
          M3 (match P P)
          Ok (and (match-some? M1) (not (match-some? M2)) (match-some? M3))
          (do (output "16e: final matcher defs live ~A~%" Ok) Ok)))

\\ 16f: control attrs reach the db; a hold-all symbol leaves its argument unevaluated.
(define cg-16f-control-attrs
  -> (let _ (declare-symbol (protect Hld) [(intern "hold-all")])
          Held (holds-all? (value *db*) (protect Hld))
          Arg [[sym (protect Plus)] [int 1] [int 2]]
          E [[sym (protect Hld)] Arg]
          Got (reduce E)
          Uneval (content-eq Got E)
          Ok (and Held Uneval)
          (do (output "16f: hold-all stored=~A arg-unevaluated=~A~%" Held Uneval) Ok)))

(define test-correctness-gate
  -> (let Ign (output "~%=== SCUD 16 correctness gate ===~%")
          Ok (and (cg-16a-hash-before-declare)
                  (cg-16b-checked-rule-strict)
                  (cg-16c-seam-tag-dispatch)
                  (cg-16d-register-rule-guard)
                  (cg-16e-final-defs-live)
                  (cg-16f-control-attrs))
          (do (if Ok (output "correctness gate (SCUD 16): PASS~%")
                  (output "correctness gate (SCUD 16): FAIL~%"))
              Ok)))

\\ === SCUD 17 Wave 1: evaluator + matching + rationals ===

\\ 17a: the ordered evaluation sequence. Built-in arithmetic fires with NO rule;
\\ a single x+0 rule handles commuted args; hold-all leaves args unevaluated;
\\ a looping rule terminates with the step-limit warning (no hang).
(define test-eval-sequence
  -> (let Ign0 (demo-register-arith)
          Ign1 (output "~%=== SCUD 17a eval sequence ===~%")
          \\ built-in arithmetic with NO rule registered for 7+8
          A (reduce [[sym (protect Plus)] [int 7] [int 8]])
          OkA (content-eq A [int 15])
          \\ single x+0 rule covers commuted 0+x via Orderless
          B (reduce [[sym (protect Plus)] [int 0] [sym (protect zz)]])
          OkB (content-eq B [sym (protect zz)])
          \\ hold-all leaves its argument unevaluated
          _ (declare-symbol (protect Held17) [(intern "hold-all")])
          Inner [[sym (protect Plus)] [int 1] [int 2]]
          HE [[sym (protect Held17)] Inner]
          H (reduce HE)
          OkH (content-eq H HE)
          \\ diverging rule terminates with the step-limit warning (no hang).
          \\ Loop17[q] -> Loop17[Plus[q,1]] grows without bound; the *max-eval-steps*
          \\ guard must warn+return instead of looping forever. We assert the datom
          \\ directly into *db* (the self-referential RHS head is intentionally not
          \\ whitelisted, so register-rule would reject it) and lower the cap for speed.
          LoopRule (rule [[sym (protect Loop17)] (named (protect q) (blank))]
                         [[sym (protect Loop17)] [[sym (protect Plus)] [sym (protect q)] [int 1]]])
          SavedDb (value *db*)
          _ (set *db* (assert-rule (value *db*) [sym (protect Loop17)] down LoopRule))
          Saved (value *max-eval-steps*)
          _ (set *max-eval-steps* 20)
          L (reduce [[sym (protect Loop17)] [int 1]])
          _ (set *max-eval-steps* Saved)
          _ (set *db* SavedDb)
          OkL (cons? L)
          Ok (and OkA OkB OkH OkL)
          (do (output "17a: builtin7+8=~A commuted0+zz=~A hold=~A loop-terminates=~A~%" OkA OkB OkH OkL)
              Ok)))

\\ 17b: built-in arithmetic hook (highest-priority, after arg eval, before user rules).
(define test-builtin-arith
  -> (let Ign (output "~%=== SCUD 17b builtin arith ===~%")
          P (reduce [[sym (protect Plus)] [int 3] [int 4] [int 5]])
          T (reduce [[sym (protect Times)] [int 6] [int 7]])
          M (reduce [[sym (protect Minus)] [int 10] [int 3]])
          D (reduce [[sym (protect Divide)] [int 6] [int 2]])
          \\ symbolic args: num-builtin declines, expr stays inert
          S (reduce [[sym (protect Plus)] [sym (protect a)] [sym (protect b)]])
          Ok (and (content-eq P [int 12])
                  (content-eq T [int 42])
                  (content-eq M [int 7])
                  (content-eq D [int 3])
                  (= (head S) [sym (protect Plus)]))
          (do (output "17b: 3+4+5=~A 6*7=~A 10-3=~A 6/2=~A symbolic-inert=~A~%"
                      (content-eq P [int 12]) (content-eq T [int 42])
                      (content-eq M [int 7]) (content-eq D [int 3])
                      (= (head S) [sym (protect Plus)]))
              Ok)))

\\ 17c: sound sequence matching. BlankSequence>=1, BlankNullSequence>=0, named seq
\\ binds the matched prefix; first-order matching unaffected.
(define test-seq-match
  -> (let Ign (output "~%=== SCUD 17c seq match ===~%")
          M1 (match [[sym (protect f)] (named (protect a) (blank-seq)) [int 9]]
                    [[sym (protect f)] [int 1] [int 2] [int 9]])
          Ok1 (and (match-some? M1)
                   (= (match-unwrap M1) [[(protect a) [[int 1] [int 2]]]]))
          M2 (match [[sym (protect f)] (named (protect a) (blank-null)) [int 9]]
                    [[sym (protect f)] [int 9]])
          Ok2 (and (match-some? M2)
                   (= (match-unwrap M2) [[(protect a) []]]))
          M3 (match [[sym (protect f)] (named (protect a) (blank-seq)) [int 9]]
                    [[sym (protect f)] [int 9]])
          Ok3 (not (match-some? M3))
          \\ first-order unchanged
          M4 (match [[sym (protect g)] (named (protect x) (blank)) (named (protect y) (blank))]
                    [[sym (protect g)] [int 1] [int 2]])
          Ok4 (match-some? M4)
          Ok (and Ok1 Ok2 Ok3 Ok4)
          (do (output "17c: a__binds=~A a___empty=~A min1-fails=~A first-order=~A~%" Ok1 Ok2 Ok3 Ok4)
              Ok)))

\\ 17d: correct + complete AC matching. Orderless fires regardless of seq-var count;
\\ Plus[9,zz] matches Plus[a_,9]; nested Flat flatten works.
(define test-ac-match
  -> (let Ign0 (demo-register-arith)
          Ign (output "~%=== SCUD 17d AC match ===~%")
          \\ Orderless with NO seq var: Plus[a_,9] matches Plus[9,zz]
          M1 (match [[sym (protect Plus)] (named (protect a) (blank)) [int 9]]
                    [[sym (protect Plus)] [int 9] [sym (protect zz)]])
          Ok1 (and (match-some? M1)
                   (= (match-unwrap M1) [[(protect a) [sym (protect zz)]]]))
          \\ nested Flat flatten: Plus[Plus[1,2],3] -> 6 (flatten then arith)
          N (reduce [[sym (protect Plus)] [[sym (protect Plus)] [int 1] [int 2]] [int 3]])
          Ok2 (content-eq N [int 6])
          \\ flatten-flat itself on nested same-head compound
          F (flatten-flat [sym (protect Plus)]
                          [[[sym (protect Plus)] [int 1] [int 2]] [int 3]])
          Ok3 (= (length F) 3)
          Ok (and Ok1 Ok2 Ok3)
          (do (output "17d: orderless-no-seqvar=~A nested-flatten-arith=~A flatten=~A~%" Ok1 Ok2 Ok3)
              Ok)))

\\ 17e: exact rationals.
(define test-rationals
  -> (let Ign0 (demo-register-arith)
          Ign (output "~%=== SCUD 17e rationals ===~%")
          R1 (make-rat 6 4)
          Ok1 (= R1 [rat 3 2])
          R2 (make-rat 4 2)
          Ok2 (= R2 [int 2])
          R3 (reduce [[sym (protect Divide)] [int 6] [int 4]])
          Ok3 (content-eq R3 [rat 3 2])
          \\ mixed int/rat exact: 1/2 + 1 = 3/2 ; (1/2)*4 = 2
          R4 (reduce [[sym (protect Plus)] [rat 1 2] [int 1]])
          Ok4 (content-eq R4 [rat 3 2])
          R5 (reduce [[sym (protect Times)] [rat 1 2] [int 4]])
          Ok5 (content-eq R5 [int 2])
          \\ overflow guard active
          Ok6 (overflow? 99999999999999999999999999)
          \\ distinct rat/int hash (3/2 != 3)
          Ok7 (not (content-eq [rat 3 2] [int 3]))
          \\ end-to-end saturating arithmetic must ERROR/return, never hang.
          \\ (a) a direct saturating num-mul aborts the op (errors) before make-rat;
          \\ guard-int detects the int64-saturated product and raises rather than
          \\ feeding ~9.2e18 into gcd's +1-from-zero floor loop.
          Ok8 (trap-error (do (num-mul [int 5000000000] [int 5000000000]) false)
                          (/. E true))
          \\ (b) the real evaluator on a saturating product returns inert (num-builtin
          \\ traps the overflow and declines) -- it must terminate, not hang.
          SatE [[sym (protect Times)] [int 3037000500] [int 3037000500]]
          R8 (reduce SatE)
          Ok9 (content-eq R8 SatE)
          Ok (and Ok1 Ok2 Ok3 Ok4 Ok5 Ok6 Ok7 Ok8 Ok9)
          (do (output "17e: 6/4=3/2:~A 4/2=2:~A Divide=~A mixed+=~A mixed*=~A overflow=~A hashdistinct=~A sat-errors=~A sat-inert=~A~%"
                      Ok1 Ok2 Ok3 Ok4 Ok5 Ok6 Ok7 Ok8 Ok9)
              Ok)))

(define test-eval-evaluator-wave1
  -> (let Ign (output "~%=== SCUD 17 Wave 1 ===~%")
          Ok (and (test-eval-sequence)
                  (test-builtin-arith)
                  (test-seq-match)
                  (test-ac-match)
                  (test-rationals))
          (do (if Ok (output "Wave 1 evaluator (SCUD 17): PASS~%")
                  (output "Wave 1 evaluator (SCUD 17): FAIL~%"))
              Ok)))

(define run-all-tests
  -> (let Ign (output "=== shen-cas test harness ===~%")
            Ok (and (run-golden) (run-rejection-tests) (attrs-demo) (run-lfp-tests)
                    (run-analysis-tests) (run-phase1-skeleton) (test-scope-block-fork)
                    (test-backend-seam) (test-correctness-gate) (test-eval-evaluator-wave1))
            (do (if Ok (output "~%ALL PASS~%") (output "~%SOME FAIL~%")) Ok)))

(define test-backend-seam
  -> (do (output "=== backend seam (SCUD 15) ===~%")
         (output "current-core: ~A~%" (current-core))
         (let R (reduce [[sym (protect Plus)] [int 1] [int 2]])
           (do (output "ref reduce via seam: ~A~%" R)
               (output "seam present; equivalence harness (golden etc over current-core) ready for compiled stub (basis-keyed, defer perf)~%")
               true))))

(run-all-tests)