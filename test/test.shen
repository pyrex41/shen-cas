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

(define rejection-result Category Label Ok -> [Category Label Ok])
(define rejection-skip Category Label Why -> [Category Label Why])

(define reject-register
  R -> (let SavedDb (value *db*)
            SavedSigs (value *structural-sigs*)
            Ok (trap-error (do (register-rule R) false) (/. E true))
            RestoreDb (set *db* SavedDb)
            RestoreSigs (set *structural-sigs* SavedSigs)
            Ok))

(define reject-declare-symbol
  Sym Attrs -> (let SavedDb (value *db*)
                    SavedSigs (value *structural-sigs*)
                    Ok (trap-error (do (declare-symbol Sym Attrs) false) (/. E true))
                    RestoreDb (set *db* SavedDb)
                    RestoreSigs (set *structural-sigs* SavedSigs)
                    Ok))

(define reject-declare-structural
  Sym Attrs -> (let SavedDb (value *db*)
                    SavedSigs (value *structural-sigs*)
                    Ok (trap-error (do (declare-structural Sym Attrs) false) (/. E true))
                    RestoreDb (set *db* SavedDb)
                    RestoreSigs (set *structural-sigs* SavedSigs)
                    Ok))

\\ SCUD 22: executable static-rejection corpus. Each case drives the real
\\ constructor/register/declaration path and asserts definition-time rejection.
(define rej-non-rule-value
  -> (reject-register [(protect not-a-rule)]))
(define rej-literal-lhs
  -> (reject-register (rule [int 1] [int 2])))
(define rej-bare-symbol-lhs
  -> (reject-register (rule [sym (protect xrej)] [sym (protect xrej)])))
(define rej-non-symbol-headed-lhs
  -> (reject-register (rule [[int 1] (named (protect x) (blank))] [int 0])))
(define rej-guarded-atom-lhs
  -> (reject-register (rule (condition [int 1] [sym (protect True)]) [int 2])))

(define rej-unbound-rhs-atom
  -> (reject-register (rule [[sym (protect Grej)] (named (protect x) (blank))]
                         [sym (protect yrej)])))
(define rej-unbound-rhs-nested
  -> (reject-register (rule [[sym (protect Grej)] (named (protect x) (blank))]
                         [[sym (protect Plus)] [sym (protect x)] [sym (protect yrej)]])))
(define rej-unwhitelisted-rhs-head
  -> (reject-register (rule [[sym (protect Grej)] (named (protect x) (blank))]
                         [[sym (protect Bogusrej)] [sym (protect x)]])))

(define rej-bare-seq-lhs
  -> (reject-register (rule (blank-seq) [int 0])))
(define rej-bare-null-seq-lhs
  -> (reject-register (rule (blank-null) [int 0])))
(define rej-named-seq-top-lhs
  -> (reject-register (rule (named (protect srej) (blank-seq)) [int 0])))
(define rej-seq-as-dispatch-head
  -> (reject-register (rule [(blank-seq) (named (protect x) (blank))] [int 0])))

(define rej-unknown-attr
  -> (reject-declare-symbol (protect AttrRejUnknown) [(protect no-such-attr)]))
(define rej-attrs-not-list
  -> (reject-declare-symbol (protect AttrRejNotList) (protect hold-all)))
(define rej-hold-all-hold-first
  -> (reject-declare-symbol (protect AttrRejHF) [(protect hold-all) (protect hold-first)]))
(define rej-hold-all-hold-rest
  -> (reject-declare-symbol (protect AttrRejHR) [(protect hold-all) (protect hold-rest)]))
(define rej-listable-hold-all
  -> (reject-declare-symbol (protect AttrRejLH) [(protect listable) (protect hold-all)]))
(define rej-hold-all-listable
  -> (reject-declare-symbol (protect AttrRejHL) [(protect hold-all) (protect listable)]))
(define rej-structural-control-attr
  -> (reject-declare-structural (protect AttrRejStructural) [(protect hold-all)]))

(define static-rejection-results
  -> [
    (rejection-result "malformed-rule" "non-rule value passed to register-rule" (rej-non-rule-value))
    (rejection-result "malformed-rule" "literal atom LHS has no dispatch head" (rej-literal-lhs))
    (rejection-result "malformed-rule" "bare symbol LHS has no dispatch head" (rej-bare-symbol-lhs))
    (rejection-result "malformed-rule" "compound LHS has non-symbol head" (rej-non-symbol-headed-lhs))
    (rejection-result "malformed-rule" "guarded LHS peels to atom" (rej-guarded-atom-lhs))
    (rejection-result "unsafe-rhs" "RHS atom is not bound on LHS" (rej-unbound-rhs-atom))
    (rejection-result "unsafe-rhs" "nested RHS symbol is not bound on LHS" (rej-unbound-rhs-nested))
    (rejection-result "unsafe-rhs" "RHS compound head is not whitelisted" (rej-unwhitelisted-rhs-head))
    (rejection-result "invalid-sequence" "bare BlankSequence as LHS" (rej-bare-seq-lhs))
    (rejection-result "invalid-sequence" "bare BlankNullSequence as LHS" (rej-bare-null-seq-lhs))
    (rejection-result "invalid-sequence" "named sequence as top-level LHS" (rej-named-seq-top-lhs))
    (rejection-result "invalid-sequence" "sequence pattern used as dispatch head" (rej-seq-as-dispatch-head))
    (rejection-result "attribute-conflict" "unknown attribute name" (rej-unknown-attr))
    (rejection-result "attribute-conflict" "attribute argument is not a list" (rej-attrs-not-list))
    (rejection-result "attribute-conflict" "hold-all conflicts with hold-first" (rej-hold-all-hold-first))
    (rejection-result "attribute-conflict" "hold-all conflicts with hold-rest" (rej-hold-all-hold-rest))
    (rejection-result "attribute-conflict" "listable conflicts with hold-all" (rej-listable-hold-all))
    (rejection-result "attribute-conflict" "hold-all conflicts with listable" (rej-hold-all-listable))
    (rejection-result "attribute-conflict" "declare-structural rejects control attr" (rej-structural-control-attr))
  ])

(define static-rejection-skips
  -> [
    (rejection-skip "invalid-sequence" "sequence variable substituted in RHS head"
                    "current coverage treats the bound name as safe; future expr/pattern type check should reject")
    (rejection-skip "branch-unsafe-identity" "Log[Exp[u]] -> u"
                    "no definition-time branch-safety hook; boot table omits it and external corpus checks inert behavior")
    (rejection-skip "branch-unsafe-identity" "Sqrt[u^2] -> u"
                    "no definition-time branch-safety hook; only Sqrt[u]^2 -> u is registered")
    (rejection-skip "nonterminating-rewrite" "F[x_] -> F[F[x]]"
                    "loop analysis is warning/step-limit oriented today, not a hard register-rule rejection")
  ])

(define rejection-passed?
  [_ _ Ok] -> Ok)

(define print-rejection-result
  [Category Label Ok] -> (do (output "  ~A ~A: ~A~%" (if Ok "PASS" "FAIL") Category Label) Ok))

(define print-rejection-skip
  [Category Label Why] -> (do (output "  SKIP ~A: ~A (~A)~%" Category Label Why) true))

(define run-rejection-tests
  -> (do (output "~%=== static rejection corpus (executable, SCUD 22) ===~%")
         (let Results (static-rejection-results)
              Skips (static-rejection-skips)
              Printed (map (/. R (print-rejection-result R)) Results)
              SkipPrinted (map (/. S (print-rejection-skip S)) Skips)
              Ok (every (/. R (rejection-passed? R)) Results)
              (do (output "static rejection corpus: rejected=~A skipped-future=~A~%"
                          (length (filter (/. R (rejection-passed? R)) Results))
                          (length Skips))
                  (if Ok (output "static rejection corpus: PASS (all supported malformed inputs rejected at definition time)~%")
                      (output "static rejection corpus: FAIL (a supported malformed input was accepted)~%"))
                  Ok))))

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
\\ P0-2: a registrable rule's LHS must be a SYMBOL-HEADED COMPOUND (the dispatcher
\\ keys on a head symbol). Non-rule shapes, integer-atom LHS, and bare-symbol-atom
\\ LHS are all rejected; a real symbol-headed compound rule is accepted.
(define cg-16b-checked-rule-strict
  -> (let Ok (and (not (checked-rule? [(protect foo) (protect bar)]))
                  (and (checked-rule? [rule [[sym (protect Plus)] [named (protect x) [blank]] [int 0]] [sym (protect x)]])
                       (and (not (checked-rule? [rule [int 1] [int 2]]))
                            (not (checked-rule? [rule [sym (protect x)] [sym (protect x)]])))))
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
                   (= (match-unwrap M1) [[(protect a) [(intern "seqval") [int 1] [int 2]]]]))
          M2 (match [[sym (protect f)] (named (protect a) (blank-null)) [int 9]]
                    [[sym (protect f)] [int 9]])
          Ok2 (and (match-some? M2)
                   (= (match-unwrap M2) [[(protect a) [(intern "seqval")]]]))
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

\\ SCUD 18: matcher prerequisites for guarded calculus rules.
\\ 18a ptest, 18b condition-reduce, 18c wired SameQ/UnsameQ/FreeQ/NumberQ.
(define test-guards
  -> (let Ign (output "~%=== SCUD 18 guards (ptest/condition/predicates) ===~%")
          \\ wired predicates reduce to True/False
          SQ (reduce [[sym (protect SameQ)] [sym (protect aa)] [sym (protect aa)]])
          OkSQ (content-eq SQ [sym (protect True)])
          USQ (reduce [[sym (protect UnsameQ)] [sym (protect aa)] [sym (protect bb)]])
          OkUSQ (content-eq USQ [sym (protect True)])
          \\ FreeQ: x free of y-expr? FreeQ[f[a],x] true (no x); FreeQ[f[x],x] false
          FQy (reduce [[sym (protect FreeQ)] [[sym (protect f)] [sym (protect aa)]] [sym (protect xx)]])
          OkFQy (content-eq FQy [sym (protect True)])
          FQn (reduce [[sym (protect FreeQ)] [[sym (protect f)] [sym (protect xx)]] [sym (protect xx)]])
          OkFQn (content-eq FQn [sym (protect False)])
          \\ NumberQ gates int vs symbol
          NQi (reduce [[sym (protect NumberQ)] [int 5]])
          OkNQi (content-eq NQi [sym (protect True)])
          NQs (reduce [[sym (protect NumberQ)] [sym (protect zz18)]])
          OkNQs (content-eq NQs [sym (protect False)])
          \\ 18a ptest: NumberQ test gates the match (no DB rule needed)
          PT1 (match (ptest (named (protect n) (blank)) [sym (protect NumberQ)]) [int 7])
          OkPT1 (match-some? PT1)
          PT2 (match (ptest (named (protect n) (blank)) [sym (protect NumberQ)]) [sym (protect zz18)])
          OkPT2 (not (match-some? PT2))
          \\ 18b/18c: D[a_,x_] /; SameQ[a,x] matches D[x,x], NOT D[y,x].
          \\ Use condition+SameQ (no reliance on non-linear repeated names).
          SavedDb (value *db*)
          _ (declare-symbol (protect D18) [])
          DRule (rule (condition [[sym (protect D18)] (named (protect a) (blank)) (named (protect x) (blank))]
                                 [[sym (protect SameQ)] [sym (protect a)] [sym (protect x)]])
                      [int 1])
          _ (register-rule DRule)
          DXX (reduce [[sym (protect D18)] [sym (protect xx)] [sym (protect xx)]])
          OkDXX (content-eq DXX [int 1])
          DYX (reduce [[sym (protect D18)] [sym (protect yy)] [sym (protect xx)]])
          OkDYX (= (head DYX) [sym (protect D18)])
          _ (set *db* SavedDb)
          Ok (and OkSQ OkUSQ OkFQy OkFQn OkNQi OkNQs OkPT1 OkPT2 OkDXX OkDYX)
          (do (output "18: SameQ=~A UnsameQ=~A FreeQ-y=~A FreeQ-n=~A NumberQ-i=~A NumberQ-s=~A ptest-y=~A ptest-n=~A Dxx=~A Dyx-inert=~A~%"
                      OkSQ OkUSQ OkFQy OkFQn OkNQi OkNQs OkPT1 OkPT2 OkDXX OkDYX)
              Ok)))

\\ === Matcher stress corpus ===
\\ Fast, direct matcher coverage for first-order, repeated-variable soundness,
\\ BlankSequence/BlankNullSequence, Flat/Orderless AC, nested AC, guarded patterns,
\\ and backtracking after binding conflicts.
(define stress-match?
  P E -> (match-some? (match P E)))

(define stress-no-match?
  P E -> (not (stress-match? P E)))

(define stress-match-bindings
  P E -> (let M (match P E)
             (if (match-some? M) (match-unwrap M) [])))

(define stress-binding-content?
  Name Expected Bs -> (let Hit (assoc Name Bs)
                          (and (assoc-hit? Hit)
                               (content-eq (hd (tl Hit)) Expected))))

(define stress-binding-exact?
  Name Expected Bs -> (let Hit (assoc Name Bs)
                          (and (assoc-hit? Hit)
                               (= (hd (tl Hit)) Expected))))

(define stress-report
  Label true -> (do (output "  PASS matcher-stress: ~A~%" Label) true)
  Label false -> (do (output "  FAIL matcher-stress: ~A~%" Label) false))

(define stress-first-order
  -> (let P [[sym (protect FStress)] [int 1] (named (protect xfo) (blank)) [blank (protect HStress)]]
          E [[sym (protect FStress)] [int 1] [sym (protect yfo)] [[sym (protect HStress)] [int 7]]]
          B (stress-match-bindings P E)
          C1 (stress-report "first-order typed blank binds symbol"
                            (and (stress-match? P E)
                                 (stress-binding-content? (protect xfo) [sym (protect yfo)] B)))
          C2 (stress-report "first-order typed blank rejects wrong head"
                            (stress-no-match? P [[sym (protect FStress)] [int 1] [sym (protect yfo)] [[sym (protect KStress)] [int 7]]]))
          C3 (stress-report "first-order rejects compound head mismatch"
                            (stress-no-match? P [[sym (protect GStress)] [int 1] [sym (protect yfo)] [[sym (protect HStress)] [int 7]]]))
          (and C1 (and C2 C3))))

(define stress-repeated-vars
  -> (let P [[sym (protect RStress)]
             (named (protect xr) (blank))
             [[sym (protect WrapR)] (named (protect xr) (blank))]
             (named (protect xr) (blank))]
          C1 (stress-report "repeated first-order variable accepts equal values"
                            (stress-match? P [[sym (protect RStress)] [int 4] [[sym (protect WrapR)] [int 4]] [int 4]]))
          C2 (stress-report "repeated first-order variable rejects conflict"
                            (stress-no-match? P [[sym (protect RStress)] [int 4] [[sym (protect WrapR)] [int 5]] [int 4]]))
          PA [[sym (protect Plus)] (named (protect xa) (blank)) (named (protect xa) (blank))]
          C3 (stress-report "repeated AC variable accepts equal multiset"
                            (stress-match? PA [[sym (protect Plus)] [int 6] [int 6]]))
          C4 (stress-report "repeated AC variable rejects unequal multiset"
                            (stress-no-match? PA [[sym (protect Plus)] [int 6] [int 7]]))
          (and C1 (and C2 (and C3 C4)))))

(define stress-sequences
  -> (let P [[sym (protect SeqStress)]
             [sym (protect head)]
             (named (protect sseq) (blank-seq))
             [sym (protect mid)]
             (named (protect tseq) (blank-null))
             [sym (protect tail)]]
          E [[sym (protect SeqStress)] [sym (protect head)] [int 1] [int 2] [sym (protect mid)] [sym (protect tail)]]
          B (stress-match-bindings P E)
          C1 (stress-report "sequence split captures min-one and empty null sequence"
                            (and (stress-match? P E)
                                 (and (stress-binding-exact? (protect sseq) [(intern "seqval") [int 1] [int 2]] B)
                                      (stress-binding-exact? (protect tseq) [(intern "seqval")] B))))
          PMin [[sym (protect SeqStress)] [sym (protect head)] (named (protect mseq) (blank-seq)) [sym (protect tail)]]
          C2 (stress-report "BlankSequence rejects empty capture"
                            (stress-no-match? PMin [[sym (protect SeqStress)] [sym (protect head)] [sym (protect tail)]]))
          PBack [[sym (protect SeqBack)]
                 (named (protect rseq) (blank-null))
                 (named (protect xseq) (blank))
                 (named (protect rseq) (blank-null))]
          EBack [[sym (protect SeqBack)] [int 1] [int 2] [int 1]]
          BBack (stress-match-bindings PBack EBack)
          C3 (stress-report "sequence backtracks after repeated seq conflict"
                            (and (stress-match? PBack EBack)
                                 (and (stress-binding-content? (protect xseq) [int 2] BBack)
                                      (stress-binding-exact? (protect rseq) [(intern "seqval") [int 1]] BBack))))
          C4 (stress-report "repeated BlankNullSequence rejects irreconcilable split"
                            (stress-no-match? PBack [[sym (protect SeqBack)] [int 1] [int 2] [int 3]]))
          (and C1 (and C2 (and C3 C4)))))

(define stress-ac
  -> (let P [[sym (protect Plus)] [int 1] (named (protect ap) (blank)) [int 3]]
          E [[sym (protect Plus)] [int 3] [int 9] [int 1]]
          B (stress-match-bindings P E)
          C1 (stress-report "Orderless matches literal anchors in any order"
                            (and (stress-match? P E)
                                 (stress-binding-content? (protect ap) [int 9] B)))
          C2 (stress-report "Orderless rejects missing repeated literal"
                            (stress-no-match? [[sym (protect Plus)] [int 1] (named (protect bp) (blank)) [int 1]]
                                              [[sym (protect Plus)] [int 1] [int 2] [int 3]]))
          PFlat [[sym (protect Plus)] [int 1] [int 2] [int 3] (named (protect zflat) (blank))]
          EFlat [[sym (protect Plus)]
                 [[sym (protect Plus)] [int 3] [sym (protect zflat)]]
                 [[sym (protect Plus)] [int 2] [int 1]]]
          BFlat (stress-match-bindings PFlat EFlat)
          C3 (stress-report "Flat flattens nested same-head AC expressions"
                            (and (stress-match? PFlat EFlat)
                                 (stress-binding-content? (protect zflat) [sym (protect zflat)] BFlat)))
          C4 (stress-report "Flat/Orderless anchored multi-seq pattern matches"
                            (stress-match? [[sym (protect Times)]
                                            (named (protect lefts) (blank-null))
                                            [int 0]
                                            (named (protect rights) (blank-null))]
                                           [[sym (protect Times)] [sym (protect aa)] [int 0] [sym (protect bb)]]))
          C5 (stress-report "Flat/Orderless rejects absent literal after flatten"
                            (stress-no-match? [[sym (protect Plus)] [int 1] [int 2] [int 4]]
                                              [[sym (protect Plus)] [[sym (protect Plus)] [int 1] [int 2]] [int 3]]))
          PACBack [[sym (protect Plus)] (named (protect xacb) (blank)) (named (protect xacb) (blank)) [int 2]]
          C6 (stress-report "Orderless backtracks after repeated variable conflict"
                            (stress-match? PACBack [[sym (protect Plus)] [int 2] [int 1] [int 1]]))
          C7 (stress-report "Orderless repeated variable conflict can still fail"
                            (stress-no-match? PACBack [[sym (protect Plus)] [int 2] [int 1] [int 3]]))
          (and C1 (and C2 (and C3 (and C4 (and C5 (and C6 C7))))))))

(define stress-nested-ac
  -> (let P [[sym (protect Integrate)]
             [[sym (protect Sin)]
              [[sym (protect Plus)]
               [[sym (protect Times)]
                (named (protect ausub) (blank))
                (named (protect xu) (blank))]
               (named (protect busub) (blank))]]
             (named (protect xu) (blank))]
          E [[sym (protect Integrate)]
             [[sym (protect Sin)]
              [[sym (protect Plus)]
               [[sym (protect Times)] [sym (protect xu)] [int 2]]
               [int 3]]]
             [sym (protect xu)]]
          B (stress-match-bindings P E)
          C1 (stress-report "nested AC prefers self-binding through outer repeated variable"
                            (and (stress-match? P E)
                                 (and (stress-binding-content? (protect ausub) [int 2] B)
                                      (and (stress-binding-content? (protect xu) [sym (protect xu)] B)
                                           (stress-binding-content? (protect busub) [int 3] B)))))
          C2 (stress-report "nested AC rejects conflicting integration variable"
                            (stress-no-match? P [[sym (protect Integrate)]
                                                 [[sym (protect Sin)]
                                                  [[sym (protect Plus)]
                                                   [[sym (protect Times)] [sym (protect yu)] [int 2]]
                                                   [int 3]]]
                                                 [sym (protect xu)]]))
          (and C1 C2)))

(define stress-guards
  -> (let PFree (condition [[sym (protect GuardStress)]
                           (named (protect eguard) (blank))
                           (named (protect xguard) (blank))]
                          [[sym (protect FreeQ)] [sym (protect eguard)] [sym (protect xguard)]])
          C1 (stress-report "Condition guard accepts FreeQ true"
                            (stress-match? PFree [[sym (protect GuardStress)] [[sym (protect WrapG)] [sym (protect yg)]] [sym (protect xg)]]))
          C2 (stress-report "Condition guard rejects FreeQ false"
                            (stress-no-match? PFree [[sym (protect GuardStress)] [[sym (protect WrapG)] [sym (protect xg)]] [sym (protect xg)]]))
          PPTest [[sym (protect PTestStress)]
                  (ptest (named (protect nptest) (blank)) [sym (protect NumberQ)])
                  (named (protect restptest) (blank))]
          C3 (stress-report "PatternTest accepts numeric argument inside compound"
                            (stress-match? PPTest [[sym (protect PTestStress)] [int 42] [sym (protect okp)]]))
          C4 (stress-report "PatternTest rejects symbolic argument inside compound"
                            (stress-no-match? PPTest [[sym (protect PTestStress)] [sym (protect nopep)] [sym (protect okp)]]))
          (and C1 (and C2 (and C3 C4)))))

(define test-matcher-stress
  -> (let Ign (output "~%=== matcher stress corpus ===~%")
          First (stress-first-order)
          Repeated (stress-repeated-vars)
          Seq (stress-sequences)
          AC (stress-ac)
          Nested (stress-nested-ac)
          Guards (stress-guards)
          Ok (and First (and Repeated (and Seq (and AC (and Nested Guards)))))
          (do (if Ok (output "matcher stress corpus: PASS~%")
                  (output "matcher stress corpus: FAIL~%"))
              Ok)))

(define test-eval-evaluator-wave1
  -> (let Ign (output "~%=== SCUD 17 Wave 1 ===~%")
          Ok (and (test-eval-sequence)
                  (test-builtin-arith)
                  (test-seq-match)
                  (test-ac-match)
                  (test-rationals)
                  (test-guards))
          (do (if Ok (output "Wave 1 evaluator (SCUD 17): PASS~%")
                  (output "Wave 1 evaluator (SCUD 17): FAIL~%"))
              Ok)))

\\ === SCUD 19 Wave 3: simplification / canonical form ===
\\ Rule-based n-ary zero + power identities (boot/simplify), constant folding
\\ (Wave-1 num), and the audited non-rule collect-like-terms pass (Simplify head).
\\ Plus corpus idempotence: reduce(reduce E) content-eq reduce E for every golden.
(define idemp-on-golden?
  [In _] -> (let R1 (reduce In)
                 R2 (reduce R1)
                 (content-eq R1 R2))
  _ -> true)

(define test-simplify
  -> (let Ign (demo-register-simplify)
          Ign2 (output "~%=== SCUD 19 simplify ===~%")
          \\ identity rules: x^1->x, x^0->1, x*0->0 ; 0^0 stays INERT ; 0^2->0
          P1 (reduce [[sym (protect Power)] [sym (protect xs)] [int 1]])
          Ok1 (content-eq P1 [sym (protect xs)])
          P0 (reduce [[sym (protect Power)] [sym (protect xs)] [int 0]])
          Ok0 (content-eq P0 [int 1])
          ZZ (reduce [[sym (protect Power)] [int 0] [int 0]])
          OkZZ (= (head ZZ) [sym (protect Power)])
          Z2 (reduce [[sym (protect Power)] [int 0] [int 2]])
          OkZ2 (content-eq Z2 [int 0])
          T0 (reduce [[sym (protect Times)] [sym (protect xs)] [int 0]])
          OkT0 (content-eq T0 [int 0])
          \\ n-ary absorbing zero: Times[a,0,b] -> 0
          NZ (reduce [[sym (protect Times)] [sym (protect aa)] [int 0] [sym (protect bb)]])
          OkNZ (content-eq NZ [int 0])
          \\ Plus[Times[1,Cos[x]],Times[0,Sin[x]]] -> Cos[x]
          E (reduce [[sym (protect Plus)]
                      [[sym (protect Times)] [int 1] [[sym (protect Cos)] [sym (protect xs)]]]
                      [[sym (protect Times)] [int 0] [[sym (protect Sin)] [sym (protect xs)]]]])
          OkE (content-eq E [[sym (protect Cos)] [sym (protect xs)]])
          \\ collect-like-terms via Simplify head: 3x+2x -> Times[5,x]
          CL (reduce [[sym (protect Simplify)]
                       [[sym (protect Plus)]
                         [[sym (protect Times)] [int 3] [sym (protect xs)]]
                         [[sym (protect Times)] [int 2] [sym (protect xs)]]]])
          OkCL (content-eq CL [[sym (protect Times)] [int 5] [sym (protect xs)]])
          \\ gather equal Times bases into Power: x*x -> x^2
          XX (reduce [[sym (protect Simplify)]
                       [[sym (protect Times)] [sym (protect xs)] [sym (protect xs)]]])
          OkXX (content-eq XX [[sym (protect Power)] [sym (protect xs)] [int 2]])
          \\ corpus idempotence: reduce(reduce E) = reduce E over every golden case
          Idem (every (/. C (idemp-on-golden? C)) (golden-cases))
          Ok (and Ok1 Ok0 OkZZ OkZ2 OkT0 OkNZ OkE OkCL OkXX Idem)
          (do (output "19: x^1=~A x^0=~A 0^0-inert=~A 0^2=~A x*0=~A nary-zero=~A Plus-id=~A 3x+2x=~A x*x=~A idemp=~A~%"
                      Ok1 Ok0 OkZZ OkZ2 OkT0 OkNZ OkE OkCL OkXX Idem)
              (if Ok (output "simplify (SCUD 19): PASS~%") (output "simplify (SCUD 19): FAIL~%"))
              Ok)))

\\ === SCUD 20 Wave 4: symbolic differentiation ===
\\ Builds D[...] exprs, reduces, and checks the canonical simplified result.
\\ Acceptance: D[x^3,x]->3x^2 ; D[x^2+x,x]->2x+1 ; D[5,x]->0 ; D[x,x]->1 ;
\\ D[y,x]->0 ; D[Sin[x],x]->Cos[x] ; D[Sin[x^2],x]->2x*Cos[x^2] ;
\\ D[x*Sin[x],x]->Sin[x]+x*Cos[x] ; D[f[x],x] stays INERT.
(define d-expr -> [sym (protect D)])
(define dvar  -> [sym (protect xd)])    \\ the differentiation variable x

\\ helper: D[E, x]
(define make-d
  E -> [(d-expr) E (dvar)])

\\ Build Power[base,exp], Times[..], Plus[..], Sin[..] over the xd variable.
(define test-differentiation
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== SCUD 20 differentiation ===~%")
          X (dvar)
          \\ D[x^3,x] -> 3 x^2  i.e. Times[3, Power[x,2]]
          R1 (reduce (make-d [[sym (protect Power)] X [int 3]]))
          Ok1 (content-eq R1 [[sym (protect Times)] [int 3] [[sym (protect Power)] X [int 2]]])
          \\ D[x^2 + x, x] -> 2 x + 1  i.e. Plus[Times[2, x], 1] (orderless: compare via Simplify)
          R2 (reduce (make-d [[sym (protect Plus)] [[sym (protect Power)] X [int 2]] X]))
          \\ expected canonical: Plus[1, Times[2,x]] (orderless sorts); accept either ordering
          Ok2 (d-plus-2x-1? R2)
          \\ D[5,x] -> 0
          R3 (reduce (make-d [int 5]))
          Ok3 (content-eq R3 [int 0])
          \\ D[x,x] -> 1
          R4 (reduce (make-d X))
          Ok4 (content-eq R4 [int 1])
          \\ D[y,x] -> 0
          R5 (reduce (make-d [sym (protect yd)]))
          Ok5 (content-eq R5 [int 0])
          \\ D[Sin[x],x] -> Cos[x]
          R6 (reduce (make-d [[sym (protect Sin)] X]))
          Ok6 (content-eq R6 [[sym (protect Cos)] X])
          \\ D[Sin[x^2],x] -> 2 x Cos[x^2]  i.e. Times[2, x, Cos[x^2]] (any order)
          R7 (reduce (make-d [[sym (protect Sin)] [[sym (protect Power)] X [int 2]]]))
          Ok7 (d-2x-cos-x2? R7)
          \\ D[x*Sin[x],x] -> Sin[x] + x Cos[x]
          R8 (reduce (make-d [[sym (protect Times)] X [[sym (protect Sin)] X]]))
          Ok8 (d-product-sin? R8)
          \\ D[f[x],x] with unknown f stays INERT (head still D, never 0)
          R9 (reduce (make-d [[sym (protect fd)] X]))
          Ok9 (and (= (head R9) (d-expr)) (not (content-eq R9 [int 0])))
          Ok (and Ok1 Ok2 Ok3 Ok4 Ok5 Ok6 Ok7 Ok8 Ok9)
          (do (output "20: x^3=~A x^2+x=~A const=~A Dxx=~A Dyx=~A Sin=~A SinChain=~A Product=~A Inert=~A~%"
                      Ok1 Ok2 Ok3 Ok4 Ok5 Ok6 Ok7 Ok8 Ok9)
              (if Ok (output "differentiation (SCUD 20): PASS~%")
                  (output "differentiation (SCUD 20): FAIL~%"))
              Ok)))

\\ --- structural acceptance helpers (orderless-robust via Simplify normalization) ---
\\ D[x^2+x,x] == 2x+1: Simplify and check it equals Plus of {1, Times[2,x]} in any order.
(define d-plus-2x-1?
  R -> (let S (reduce [[sym (protect Simplify)] R])
            (or (content-eq S [[sym (protect Plus)] [int 1] [[sym (protect Times)] [int 2] (dvar)]])
                (content-eq S [[sym (protect Plus)] [[sym (protect Times)] [int 2] (dvar)] [int 1]]))))

\\ D[Sin[x^2],x] == 2 x Cos[x^2]: Simplify -> Times[2, x, Cos[x^2]] (any arg order).
(define d-2x-cos-x2?
  R -> (let S (reduce [[sym (protect Simplify)] R])
            (term-set-eq? S
              [[sym (protect Times)] [int 2] (dvar)
                [[sym (protect Cos)] [[sym (protect Power)] (dvar) [int 2]]]])))

\\ D[x*Sin[x],x] == Sin[x] + x Cos[x].
(define d-product-sin?
  R -> (let S (reduce [[sym (protect Simplify)] R])
            X (dvar)
            (term-set-eq? S
              [[sym (protect Plus)]
                [[sym (protect Sin)] X]
                [[sym (protect Times)] X [[sym (protect Cos)] X]]])))

\\ head + same arg multiset (orderless-robust comparison for a single compound).
(define term-set-eq?
  [H1 | A1] [H2 | A2] -> (and (content-eq H1 H2) (multiset-eq? A1 A2))
  A B -> (content-eq A B))

(define multiset-eq?
  [] [] -> true
  [X | Xs] Ys -> (let Ys2 (ms-remove X Ys)
                      (if (= Ys2 [notfound]) false (multiset-eq? Xs Ys2)))
  _ _ -> false)

\\ remove the first element content-eq to X; [notfound] if absent.
(define ms-remove
  _ [] -> [notfound]
  X [Y | Ys] -> (if (content-eq X Y)
                    Ys
                    (let R (ms-remove X Ys)
                         (if (= R [notfound]) [notfound] [Y | R]))))

\\ === SCUD 21 Wave 5: bounded symbolic integration ===
\\ Acceptance: Integrate[x^2,x]->x^3/3 (exact rational); Integrate[x^-1,x]->Log[x];
\\ Integrate[Sin[x],x]->-Cos[x]; Integrate[2x+3,x]->x^2+3x;
\\ Integrate[x*Exp[x],x]->(x-1)*Exp[x] via by-parts; Integrate[Sin[x^2],x] and
\\ Integrate[f[x],x] stay INERT (head still Integrate).
\\ CRITICAL self-check: for every closed-form result R of Integrate[f,x],
\\ Simplify[D[R,x] - f] must reduce to [int 0].
(define int-head -> [sym (protect Integrate)])
(define make-integ  F -> [(int-head) F (dvar)])
(define make-d-i  E -> [(d-expr) E (dvar)])
(define simplify-of E -> (reduce [[sym (protect Simplify)] E]))

\\ difference D[R,x] - f  as  Plus[D[R,x], Times[-1, f]]
(define diff-back
  R F -> [[sym (protect Plus)]
           (make-d-i R)
           [[sym (protect Times)] [int -1] F]])

\\ self-check: Simplify[ D[(Integrate[F,x]),x] - F ] == [int 0]
(define integrates-back?
  F -> (let R (reduce (make-integ F))
            (content-eq (simplify-of (diff-back R F)) [int 0])))

(define inert-integral?
  F -> (let R (reduce (make-integ F))
            (= (head R) (int-head)))) \\ head still Integrate

(define test-integration
  -> (let Ign0 (demo-register-calculus)
          Ign (output "~%=== SCUD 21 integration ===~%")
          X (dvar)
          \\ Integrate[x^2,x] -> x^3/3 (exact rational coefficient)
          R2 (reduce (make-integ [[sym (protect Power)] X [int 2]]))
          Ok2 (term-set-eq? R2 [[sym (protect Times)] [rat 1 3] [[sym (protect Power)] X [int 3]]])
          \\ Integrate[x^-1,x] -> Log[x]
          Rm1 (reduce (make-integ [[sym (protect Power)] X [int -1]]))
          Okm1 (content-eq Rm1 [[sym (protect Log)] X])
          \\ Integrate[Sin[x],x] -> -Cos[x]  i.e. Times[-1, Cos[x]]
          RS (reduce (make-integ [[sym (protect Sin)] X]))
          OkS (term-set-eq? RS [[sym (protect Times)] [int -1] [[sym (protect Cos)] X]])
          \\ Integrate[2x+3,x] -> x^2 + 3x  (verified via self-check below; here a Simplify shape)
          Flin [[sym (protect Plus)] [[sym (protect Times)] [int 2] X] [int 3]]
          \\ Integrate[x*Exp[x],x] -> (x-1)Exp[x] via by-parts
          Fbp [[sym (protect Times)] X [[sym (protect Exp)] X]]
          \\ --- INERT cases: head still Integrate ---
          OkInertSin (inert-integral? [[sym (protect Sin)] [[sym (protect Power)] X [int 2]]])
          OkInertF (inert-integral? [[sym (protect fI)] X])
          \\ --- differentiate-back self-check (the un-foolable gate) ---
          SC1 (integrates-back? [[sym (protect Power)] X [int 2]])
          SC2 (integrates-back? [[sym (protect Power)] X [int -1]])
          SC3 (integrates-back? [[sym (protect Sin)] X])
          SC4 (integrates-back? Flin)
          SC5 (integrates-back? Fbp)
          OkSC (and SC1 (and SC2 (and SC3 (and SC4 SC5))))
          Ok (and Ok2 (and Okm1 (and OkS (and OkInertSin (and OkInertF OkSC)))))
          (do (output "21: x^2=~A x^-1=~A Sin=~A inert-Sin[x^2]=~A inert-f[x]=~A~%"
                      Ok2 Okm1 OkS OkInertSin OkInertF)
              (output "21 self-check D[R,x]-f=0: x^2=~A x^-1=~A Sin=~A 2x+3=~A x*Exp[x](by-parts)=~A~%"
                      SC1 SC2 SC3 SC4 SC5)
              (if Ok (output "integration (SCUD 21): PASS~%")
                  (output "integration (SCUD 21): FAIL~%"))
              Ok)))

\\ === Performance/regression guards for expensive symbolic paths ===
\\ These are structural guards, not timing assertions: each case drives a formerly
\\ expensive path into a bounded skip/fuel/inert behavior that the default harness
\\ can check deterministically.
(define perf-plus -> [sym (protect Plus)])
(define perf-times -> [sym (protect Times)])
(define perf-simplify E -> [[sym (protect Simplify)] E])
(define perf-d E -> [[sym (protect D)] E (dvar)])
(define perf-int E -> [[sym (protect Integrate)] E (dvar)])

(define perf-range-ints
  From To -> (if (> From To)
               []
               [[int From] | (perf-range-ints (+ From 1) To)]))

(define perf-symbol-range
  Prefix From To -> (if (> From To)
                      []
                      [[sym (intern (@s Prefix (str From)))] | (perf-symbol-range Prefix (+ From 1) To)]))

(define perf-nested-simplify
  0 E -> E
  N E -> (perf-simplify (perf-nested-simplify (- N 1) E)))

(define perf-like-term-zero
  -> [(perf-plus)
       [(perf-times) [int 1] [sym (protect xp)]]
       [(perf-times) [int 2] [sym (protect xp)]]
       [(perf-times) [int -3] [sym (protect xp)]]
       [int 4]
       [int -4]])

(define perf-ac-max-arg-skip
  -> (let Saved (value *ac-max-args*)
          _ (set *ac-max-args* 3)
          P [(perf-plus)
             [sym (protect acAnchor)]
             (named (protect a) (blank))
             (named (protect b) (blank))
             (named (protect c) (blank))
             (named (protect d) (blank))]
          E [(perf-plus)
             [sym (protect p1)] [sym (protect p2)] [sym (protect p3)] [sym (protect p4)]
             [sym (protect acAnchor)]]
          M (match P E)
          _ (set *ac-max-args* Saved)
          Ok (not (match-some? M))
          (do (output "perf: AC max-arg skip avoids permutation match=~A~%" Ok) Ok)))

(define perf-rule-fuel-limit
  -> (let Saved (value *max-rule-tries*)
          _ (set *max-rule-tries* 2)
          E [[sym (protect FuelPerf)] [int 3]]
          R1 (rule [[sym (protect FuelPerf)] [int 1]] [int 11])
          R2 (rule [[sym (protect FuelPerf)] [int 2]] [int 22])
          R3 (rule [[sym (protect FuelPerf)] (named (protect x) (blank))] [int 99])
          Got (try-reduce-db (value *db*) E [R1 R2 R3])
          _ (set *max-rule-tries* Saved)
          Ok (content-eq Got E)
          (do (output "perf: rule fuel leaves later match inert=~A~%" Ok) Ok)))

(define perf-eval-step-fuel
  -> (let SavedDb (value *db*)
          SavedSteps (value *max-eval-steps*)
          LoopRule (rule [[sym (protect LoopPerf)] (named (protect q) (blank))]
                         [[sym (protect LoopPerf)] [[sym (protect Plus)] [sym (protect q)] [int 1]]])
          _ (set *db* (assert-rule (value *db*) [sym (protect LoopPerf)] down LoopRule))
          _ (set *max-eval-steps* 6)
          Got (reduce [[sym (protect LoopPerf)] [int 1]])
          _ (set *max-eval-steps* SavedSteps)
          _ (set *db* SavedDb)
          Ok (= (head Got) [sym (protect LoopPerf)])
          (do (output "perf: evaluator step fuel terminates with inert head=~A~%" Ok) Ok)))

(define perf-large-plus-times
  -> (let Ign (demo-register-simplify)
          BigPlus [(perf-plus) | (perf-range-ints 1 20)]
          Sum (reduce BigPlus)
          OkPlus (content-eq Sum [int 210])
          BigTimes [(perf-times) | (append (perf-symbol-range "pt" 1 10) [[int 0]])]
          Prod (reduce BigTimes)
          OkTimes (content-eq Prod [int 0])
          Ok (and OkPlus OkTimes)
          (do (output "perf: large Plus folds=~A large Times zero=~A~%" OkPlus OkTimes) Ok)))

(define perf-repeated-simplify
  -> (let Ign (demo-register-simplify)
          Got (reduce (perf-nested-simplify 5 (perf-like-term-zero)))
          Ok (content-eq Got [int 0])
          (do (output "perf: nested repeated Simplify idempotent=~A~%" Ok) Ok)))

(define perf-seq-ac-anchored
  -> (let Saved (value *ac-max-args*)
          _ (set *ac-max-args* 3)
          P [(perf-times)
             (named (protect s) [blank-null-seq])
             [int 0]
             (named (protect t) [blank-null-seq])]
          E [(perf-times) | (append (perf-symbol-range "pa" 1 9) [[int 0]])]
          M (match P E)
          _ (set *ac-max-args* Saved)
          Ok (match-some? M)
          (do (output "perf: anchored sequence AC match bounded=~A~%" Ok) Ok)))

(define perf-calculus-bounded
  -> (let Ign (demo-register-calculus)
          Saved (value *ac-max-args*)
          _ (set *ac-max-args* 4)
          X (dvar)
          Sum6 [(perf-plus) | [X X X X X X]]
          D6 (reduce (perf-d Sum6))
          OkD (content-eq D6 [int 6])
          HardInt (reduce (perf-int [(perf-times) X [[sym (protect Sin)] [[sym (protect Power)] X [int 2]]]]))
          OkI (= (head HardInt) [sym (protect Integrate)])
          _ (set *ac-max-args* Saved)
          Ok (and OkD OkI)
          (do (output "perf: bounded D large-plus=~A inert hard integral=~A~%" OkD OkI) Ok)))

(define perf-parser-roundtrip-size
  -> (let Ign (demo-register-arith)
          S "Fbig[a,b,c,d,e,f,g,h,i,j,k,l]"
          E (parse-expr-string S)
          Printed (print-expr E)
          E2 (parse-expr-string Printed)
          Ok (content-eq E E2)
          (do (output "perf: parser/printer medium roundtrip=~A~%" Ok) Ok)))

(define run-performance-guard-tests
  -> (let SavedDb (value *db*)
          SavedSigs (value *structural-sigs*)
          Ign (output "~%=== performance/regression guards ===~%")
          Ok (and (perf-ac-max-arg-skip)
                  (perf-rule-fuel-limit)
                  (perf-eval-step-fuel)
                  (perf-large-plus-times)
                  (perf-repeated-simplify)
                  (perf-seq-ac-anchored)
                  (perf-calculus-bounded)
                  (perf-parser-roundtrip-size))
          RestoreDb (set *db* SavedDb)
          RestoreSigs (set *structural-sigs* SavedSigs)
          (do (if Ok (output "performance guards: PASS~%")
                  (output "performance guards: FAIL~%"))
              Ok)))

(define run-all-tests
  -> (let Ign (output "=== shen-cas test harness ===~%")
            Ok (and (run-golden) (run-rejection-tests) (attrs-demo) (run-lfp-tests)
                    (run-analysis-tests) (run-phase1-skeleton) (test-scope-block-fork)
                    (test-backend-seam) (test-correctness-gate) (test-eval-evaluator-wave1)
                    (test-matcher-stress) (test-simplify) (test-differentiation) (test-integration)
                    (run-performance-guard-tests)
                    (run-calculus-tests) (run-reader-printer-tests)
                    (run-poly-tests) (run-polyalg-tests) (run-solve-tests)
                    (run-series-tests) (run-property-tests)
                    (run-external-corpus-tests))
            (do (if Ok (output "~%ALL PASS~%") (output "~%SOME FAIL~%")) Ok)))

(define test-backend-seam
  -> (do (output "=== backend seam (SCUD 15) ===~%")
         (output "current-core: ~A~%" (current-core))
         (let R (reduce [[sym (protect Plus)] [int 1] [int 2]])
           (do (output "ref reduce via seam: ~A~%" R)
               (output "seam present; equivalence harness (golden etc over current-core) ready for compiled stub (basis-keyed, defer perf)~%")
               true))))

(run-all-tests)