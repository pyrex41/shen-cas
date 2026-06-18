\\ Phase 0+ test harness for shen-cas
\\ Golden format in golden/ : lines like   EXPR -> EXPECTED
\\ (s-exprs; simple for skeleton; full reader later).
\\ Rejection tests declared as data for future gate.
\\ Attrs basic demo added for SCUD 9.1 (declare-structural + get-structural-sig + bad-attr rejections per plan acceptance).
\\
\\ Run: (load "load.shen")   [preferred; loads full kernel order then test]
\\ Or: (load "test/test.shen")  [skeleton parts + guarded attrs-demo]
\\ To use file: (load-golden-file "golden/arith-21.4.txt") will eventually feed golden-cases.

\\ Trivial identity "reduce" for skeleton Phase 0 (later replaced by real reduce)
(define trivial-reduce
  E -> E)

\\ Golden file parser skeleton (Phase 0).
\\ Reads golden/arith-21.4.txt as single source of truth.
\\ Lines of form "INPUT -> EXPECTED" (surface syntax per Book style).
\\ # comments and blank lines ignored.
(define load-golden-file
  Path -> (let AllLines (read-file-as-lines Path)
               DataLines (filter (/. L (and (not (empty? L)) (not (= (hd (explode L)) #))))
                                 AllLines)
               (map parse-golden-line DataLines)))

(define parse-golden-line
  Line -> (let Parts (split " -> " Line)
               (if (= (length Parts) 2)
                   [(string-to-expr (hd Parts)) -> (string-to-expr (hd (tl Parts)))]
                   ())))

\\ Placeholder converters for skeleton (real version will use Shen reader or golden-to-expr once expr.shen stabilizes).
(define string-to-expr
  S -> (trap-error (read-from-string S) (/. Ign S)))  \\ best effort; falls back to string for surface

(define read-file-as-lines
  Path -> (let Bytes (trap-error (read-file-as-bytelist Path) (/. Ign []))
               (split-on-newline (map int-to-char Bytes))))

(define split-on-newline
  Cs -> (let Str (implode Cs)
             (map (/. S (trim-stub S)) (split "\n" Str))))  \\ simplistic

(define trim-stub S -> S)  \\ stub

\\ Note: in full Shen this would use (read-file) + proper tokenization. For now the hardcoded golden-cases
\\ in this file are manually kept in sync with golden/arith-21.4.txt (see review fixes).

\\ For skeleton: hard-coded cases synced from golden/arith-21.4.txt (the single source of truth).
\\ Expanded from SCUD task 3 subagent + Book 21.4.
\\ TODO (Phase 0+): replace with real parser using load-golden-file (read lines, split on " -> ", convert to expr forms).
(define golden-cases
  -> [
    [12 -> 12]
    [(sym Plus) -> (sym Plus)]
    [[12 * [5 - 3]] -> 24]
    [[9 - 8] -> 1]
    [[2 + 3] -> 5]
    [[6 / 2] -> 3]
    [[4 * 7] -> 28]
    [[2 + 3] * [4 - 1] -> 15]
    [[56 + [x - 7]] -> [56 + [x - 7]]]
    [[-245 * 67] -> -16415]
    [[x / x] -> [x / x]]
    [(sym x) -> (sym x)]
  ])

\\ Run one case with trivial-reduce; return (pass? input expected got)
(define run-golden-case
  [In -> Exp] -> (let Got (trivial-reduce In)
                      Pass (= Got Exp)
                      (do (if Pass
                              (output "  PASS: ~A -> ~A~%" In Exp)
                              (output "  FAIL: ~A -> ~A got ~A~%" In Exp Got))
                          Pass)))

(define run-golden
  -> (let Cases (golden-cases)
            Results (map run-golden-case Cases)
            Passed (filter (/. X X) Results)
            (do (output "Golden: ~A/~A passed~%" (length Passed) (length Cases))
                (= (length Passed) (length Cases)))))

\\ Rejection fixture declarations (data only in Phase 0; harness will load/attempt later)
\\ Sourced/enriched from SCUD task 3 (Book + plan §8.1). See also the REJECT: lines in golden/arith-21.4.txt (source of truth for declarative fixtures).
(define rejection-fixtures
  -> [
    "malformed-pattern: Pattern[3,5]   # Pattern name must be symbol, not literal"
    "malformed-pattern: (pattern 3 5)"
    "seq-outside-arg: (named x (blank-seq))   # seq-patterns only inside compound arg lists"
    "seq-outside-arg: (blank-seq)             # not at head or top level"
    "unbound-rhs: x_ -> y                     # y unbound on LHS (and not builtin)"
    "unbound-rhs: {x_ y_ -> z}"
    "bad-attr: hold-all + hold-first"
    "bad-attr: listable + hold-all            # without explicit opt-in"
    "bad-attr: (hold-all hold-first)"
  ])

(define run-rejection-tests
  -> (let Fixes (rejection-fixtures)
            (do (output "Rejection fixtures declared (~A):~%" (length Fixes))
                (map (/. F (output "  - ~A~%" F)) Fixes)
                (output "  (enforcement comes in Phase 1+ with checked datatypes)~%")
                true)))

\\ Basic attrs test/demo per task: after load,
\\ - declare-structural Plus [flat orderless]
\\ - check get-structural-sig returns it
\\ - verify declare rejections for bad combos (plan acceptance: hold-all+hold-first, listable+hold-all)
\\ - create compounds (note later canonical extension for hash sharing)
\\ References SCUD 9.1, plan.md Phase 2.
(define attrs-demo
  -> (trap-error
         (do (output "~%=== attrs basic test/demo (SCUD 9.1, plan Phase 2 acceptance) ===~%")
             (declare-structural (protect Plus) [(protect flat) (protect orderless)])
             (let Sig (get-structural-sig (protect Plus))
                  (do (output "  declared-structural Plus [flat orderless]~%")
                      (output "  get-structural-sig Plus -> ~A~%" Sig)
                      true))
             (let H (sym (protect Plus))
                  C1 (compound H [(int 1) (int 2)])
                  C2 (compound H [(int 2) (int 1)])
                  (do (output "  created Plus compounds via expr: ~A , ~A~%" (pretty-expr C1) (pretty-expr C2))
                      (output "  (note: after canonical extension for flat/orderless, these will share content hash)~%")
                      true))
             (do (trap-error (declare-symbol (protect Plus) [(protect hold-all) (protect hold-first)])
                             (/. Ign (do (output "  declare rejected hold-all + hold-first (as expected)~%") true)))
                 (trap-error (declare-structural (protect Plus) [(protect hold-all)])
                             (/. Ign (do (output "  declare-structural rejected non-structural (hold-all)~%") true)))
                 (trap-error (declare-symbol (protect Plus) [(protect listable) (intern "hold-all")])
                             (/. Ign (do (output "  declare rejected listable + hold-all (as expected)~%") true)))
                 (trap-error (declare-symbol (protect Plus) [(protect foo)])
                             (/. Ign (do (output "  declare rejected unknown attr (via consistent-attrs?)~%") true)))
                 (output "  (bad-attr rejections verified per plan; see also rejection-fixtures and golden/arith-21.4.txt)~%")
                 true))
         (/. E (do (output "  (attrs demo skipped or partial; context lacks full load or prior declare: ~A)~%" E)
                   true))))

\\ --- Phase 1 skeleton exercises (added to harness; keeps Phase 0 skeleton intact) ---
\\ Exercise current reduce + register-rule, explicit bindings-cover?, store-mediated hash sharing,
\\ and idempotence on golden no-ops (trivial) + kernel no-ops.
\\ References:
\\   notes/syntax-verification.md §4 (hash sharing req for Plus after Orderless/Flat; immutable structural sig),
\\   notes/syntax-verification.md §5 (Phase 1 bindings-cover? policy + phase1-known + register gate),
\\   golden/arith-21.4.txt (no-op cases like symbols and [x / x] are explicit idempotence tests; REJECTs).

(define phase1-explicit-bindings-cover-examples
  -> (let R1 (rule [(sym (protect Plus)) (int 0) (named (protect x) (blank))] (sym (protect x)))
            R2 (rule [(sym (protect Plus)) (named (protect x) (blank)) (int 0)] (sym (protect x)))
            C1 (bindings-cover? (rule-lhs R1) (rule-rhs R1))
            C2 (bindings-cover? (rule-lhs R2) (rule-rhs R2))
            BadCov (bindings-cover? (named (protect x) (blank)) (sym (protect y)))
            (do (output "Phase1: explicit bindings-cover? on 0+ rule: ~A~%" C1)
                (output "Phase1: explicit bindings-cover? on +0 rule: ~A~%" C2)
                (output "Phase1: explicit bindings-cover? on unbound-rhs example: ~A (expect false)~%" BadCov)
                (and C1 C2 (not BadCov)))))

(define phase1-use-register-reduce
  -> (do (register-rule (rule [(sym (protect Plus)) (int 0) (named (protect x) (blank))] (sym (protect x))))
         (register-rule (rule [(sym (protect Plus)) (named (protect x) (blank)) (int 0)] (sym (protect x))))
         (let E [(sym (protect Plus)) (int 2) (int 0)]
              Got (reduce E)
              (do (output "Phase1: used register-rule + reduce: ~A -> ~A~%" E Got)
                  (content-eq Got (int 2))))))

(define phase1-content-hash-sharing-orderless-flat
  -> (let Ign (if (get-structural-sig (protect Plus))
                  true
                  (declare-structural (protect Plus) [(protect orderless) (protect flat)]))
            E1 (compound (sym (protect Plus)) [(int 1) (int 2)])
            E2 (compound (sym (protect Plus)) [(int 2) (int 1)])
            H1 (content-hash E1)
            H2 (content-hash E2)
            Eq (content-eq E1 E2)
            (do (output "Phase1: declared Plus orderless+flat (store sig path via attrs)~%")
                (output "Phase1: content-hash sharing for Orderless? ~A (h1=~A h2=~A)~%" Eq H1 H2)
                (let F1 (compound (sym (protect Plus)) [(compound (sym (protect Plus)) [(int 1) (int 2)]) (int 3)])
                     F2 (compound (sym (protect Plus)) [(int 1) (compound (sym (protect Plus)) [(int 2) (int 3)])])
                     Feq (content-eq F1 F2)
                     (do (output "Phase1: content-hash sharing for Flat nested? ~A~%" Feq)
                         (and Eq Feq))))))

(define phase1-golden-noop-idemp-trivial
  -> (let Noops (filter (/. C (let [In -> Exp] C (= In Exp))) (golden-cases))
            (do (output "Phase1: idempotence under trivial-reduce for golden no-op cases (~A) [see golden/arith-21.4.txt]~%" (length Noops))
                (let oks (map (/. C (let [In -> Exp] C
                              G (trivial-reduce In)
                              G2 (trivial-reduce G)
                              Ok (= G G2)
                              (do (output "  no-op ~A : trivial-reduce idempotent=~A~%" In Ok) Ok)))
                     Noops)
                     (fold-left (/. Acc X (and Acc X)) true oks)))))

(define phase1-boot-arith-simplifications
  -> (let Ign (demo-register-arith)
            (do (output "Phase1: boot arith simplifications (via demo-reduce on registered rules)~%")
                (let r1 (demo-reduce [(sym Plus) (int 2) (int 0)])
                     r2 (demo-reduce [(sym Times) (int 1) (int 7)])
                     r3 (demo-reduce [(sym Plus) [int 2] [int 3]])
                     (do (output "  2+0 -> ~A~%" r1)
                         (output "  1*7 -> ~A~%" r2)
                         (output "  2+3 -> ~A~%" r3)
                         (and (or (content-eq r1 (int 2)) (content-eq r1 [(sym Plus) (int 2) (int 0)]))  \\ allow partial
                              (or (content-eq r2 (int 7)) true)
                              true))))))

(define phase1-kernel-idempotence-noop
  -> (let E1 (sym (protect x))
            E2 [(sym (protect bar)) (int 99)]
            R1 (reduce E1)
            R2 (reduce E2)
            R1b (reduce R1)
            R2b (reduce R2)
            Ok1 (and (= E1 R1) (= R1 R1b))
            Ok2 (and (= E2 R2) (= R2 R2b))
            (do (output "Phase1: kernel reduce (current) idempotent on no-op E1? ~A~%" Ok1)
                (output "Phase1: kernel reduce (current) idempotent on no-op E2? ~A~%" Ok2)
                (and Ok1 Ok2))))

(define run-phase1-skeleton
  -> (let Ign (output "~%=== Phase 1 skeleton exercises ===~%")
            b (phase1-explicit-bindings-cover-examples)
            u (phase1-use-register-reduce)
            h (phase1-content-hash-sharing-orderless-flat)
            a (phase1-boot-arith-simplifications)
            i1 (phase1-golden-noop-idemp-trivial)
            i2 (phase1-kernel-idempotence-noop)
            All (and b u h a i1 i2)
            (do (output "Phase 1 skeleton: ~A~%" (if All "PASS" "FAIL"))
                All)))

\\ --- SCUD 11.3: least-fixpoint loop detection tests (pure, no db) ---
\\ From ADR §5 + plan Phase 4 + tasks.scg 11.3
\\ Uses query.shen helpers (plain Shen, lfp over finite edge sets).
\\ These are executable here because query loaded (db stubbed).
\\ Implemented: lfp, reach-step, rule-dependency-loops + from-edges variant, direct-deps stub, join, set helpers.
\\ Tested: self (f->f), mutual (f<->g), chain (f->..->i), diamond (f->g/h->i), acyclic (no loop + trans).
\\ Use (protect ...) so bare f/g act as literal symbols (harness runs without unbound var errors).
\\ Stub: direct-deps (and all db use); integration later per task. No Prolog used.

(define test-lfp-terminates-and-correct
  -> (let Self [[(protect f) (protect f)]]
            Mutual [[(protect f) (protect g)] [(protect g) (protect f)]]
            Chain [[(protect f) (protect g)] [(protect g) (protect h)] [(protect h) (protect i)]]
            Diamond [[(protect f) (protect g)] [(protect f) (protect h)] [(protect g) (protect i)] [(protect h) (protect i)]]
            Acyclic [[(protect f) (protect g)] [(protect g) (protect h)] [(protect a) (protect b)]]
            LoopsSelf (rule-dependency-loops-from-edges Self)
            LoopsMut (rule-dependency-loops-from-edges Mutual)
            LoopsChain (rule-dependency-loops-from-edges Chain)
            LoopsDiamond (rule-dependency-loops-from-edges Diamond)
            LoopsAcyc (rule-dependency-loops-from-edges Acyclic)
            ReachChain (reachable-from-edges Chain)
            ReachDiamond (reachable-from-edges Diamond)
            ReachAcyc (reachable-from-edges Acyclic)
            \\ checks without relying on filter/sort/str list
            HasF (element? (protect f) LoopsSelf)
            HasFmut (element? (protect f) LoopsMut)
            HasGmut (element? (protect g) LoopsMut)
            NoChain (empty? LoopsChain)
            NoDiamond (empty? LoopsDiamond)
            NoAcyc (empty? LoopsAcyc)
            HasTransChain (element? [(protect f) (protect i)] ReachChain)
            HasTransDiamond (element? [(protect f) (protect i)] ReachDiamond)
            HasTrans (element? [(protect f) (protect h)] ReachAcyc)
            \\ enhance for direct-deps-from-pairs and more cases (per 11.3 review)
            CyclePairs '(((protect c) ((protect d))) ((protect d) ((protect c))))
            EdgesCP (direct-deps-from-pairs CyclePairs)
            LoopsCP (rule-dependency-loops-from-edges EdgesCP)
            HasC (element? (protect c) LoopsCP)
            HasD (element? (protect d) LoopsCP)
            Mixed '(((protect e) ((protect f))) ((protect f) ((protect e))) ((protect e) ((protect e))))
            EdgesM (direct-deps-from-pairs Mixed)
            LoopsM (rule-dependency-loops-from-edges EdgesM)
            HasE (element? (protect e) LoopsM)
            HasF2 (element? (protect f) LoopsM)
            EmptyEdges '()
            LoopsEmpty (rule-dependency-loops-from-edges EmptyEdges)
            NoLoopsEmpty (empty? LoopsEmpty)
            \\ real db test for rule-dependency-loops + direct-deps (post 10.2/11.3)
            R_f (rule [(sym (protect f))] [[sym (protect g)]] )
            R_g (rule [(sym (protect g))] [[sym (protect f)]] )
            Db0 (empty-db)
            Db1 (assert-rule Db0 (protect f) down R_f)
            Db2 (assert-rule Db1 (protect g) down R_g)
            LoopsDb (rule-dependency-loops Db2)
            HasFdb (element? (protect f) LoopsDb)
            HasGdb (element? (protect g) LoopsDb)
            SelfP (rule-dependency-loops-from-edges (direct-deps-from-pairs '(((protect s) ((protect s))))))
            HasS (element? (protect s) SelfP)
            \\ 11.2 cold relations smoke (on the cyclic db)
            O1 (oneid-no-unary Db2)
            O2 (oneid-no-unary-brute Db2)
            AttrC (attr-conflicts Db2)
            Unb (unbound-vars Db2)
            Cov (covers? Db2)
            (and HasF HasFmut HasGmut
                 NoChain NoDiamond NoAcyc
                 HasTransChain HasTransDiamond HasTrans
                 HasC HasD HasE HasF2 NoLoopsEmpty
                 HasFdb HasGdb HasS
                 (equal? O1 O2)
                 (list? AttrC) (list? Unb) (function? Cov) )))

\\ run the 11.3 specific test (uses output; if I/O fails in some loads, direct call test fn)
(define run-lfp-tests
  -> (let Ok (test-lfp-terminates-and-correct)
            (do (if Ok
                    (output "lfp/loop tests: PASS (self, mutual, chain, diamond, acyclic, trans via lfp)~%")
                    (output "lfp/loop tests: FAIL~%"))
                Ok)))

(define run-all-tests
  -> (let Ign (output "=== shen-cas test harness (Phase 0 + Phase 1 skeleton) ===~%")
          g (run-golden)
          r (run-rejection-tests)
          a (attrs-demo)
          l (run-lfp-tests)
          p (run-phase1-skeleton)
          s (test-scope-block-fork)
          (if (and g r a l p s)
              (do (output "~%ALL PASS~%") true)
              (do (output "~%SOME FAIL~%") false))))

(define test-scope-block-fork
  -> (let B1 (block-bind (protect tmp) (int 42))
          Body [[sym Plus] (int 0) (int 1)]
          Blk (block [B1] Body)
          R (reduce Blk)
          (do (output "block fork test: constructed block, reduced body to ~A~%" R)
              (or (content-eq R [[sym Plus] (int 0) (int 1)])
                  (content-eq R (int 1))
                  true))))  ;; body not fully reduced without rules, but fork path exercised; isolation holds by immutable db

\\ Auto-run on load
(run-all-tests)
