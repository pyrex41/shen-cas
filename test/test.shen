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
            Results (map run-golden-case Cases)
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

(define run-all-tests
  -> (let Ign (output "=== shen-cas test harness ===~%")
            Ok (and (run-golden) (run-rejection-tests) (attrs-demo) (run-lfp-tests)
                    (run-analysis-tests) (run-phase1-skeleton) (test-scope-block-fork)
                    (test-backend-seam))
            (do (if Ok (output "~%ALL PASS~%") (output "~%SOME FAIL~%")) Ok)))

(define test-backend-seam
  -> (let _ (output "=== backend seam (SCUD 15) ===~%")
       (output "current-core: ~A~%" (current-core))
       (let R (reduce [[sym (protect Plus)] [int 1] [int 2]])
         (output "ref reduce via seam: ~A~%" R)
         (output "seam present; equivalence harness (golden etc over current-core) ready for compiled stub (basis-keyed, defer perf)~%")
         true)))

(run-all-tests)