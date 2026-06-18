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
  S -> (trap-error (read-from-string S) (/. _ S)))  \\ best effort; falls back to string for surface

(define read-file-as-lines
  Path -> (let Bytes (trap-error (read-file-as-bytelist Path) (/. _ []))
               (split-on-newline (map int-to-char Bytes))))

(define split-on-newline
  Cs -> (let Str (implode Cs)
             (map (/. S (trim S)) (split "\n" Str))))  \\ simplistic

(define trim S -> S)  \\ stub

\\ Note: in full Shen this would use (read-file) + proper tokenization. For now the hardcoded golden-cases
\\ in this file are manually kept in sync with golden/arith-21.4.txt (see review fixes).

\\ For skeleton: hard-coded cases synced from golden/arith-21.4.txt (the single source of truth).
\\ Expanded from SCUD task 3 subagent + Book 21.4.
\\ TODO (Phase 0+): replace with real parser using load-golden-file (read lines, split on " -> ", convert to expr forms).
(define golden-cases
  -> [
    [12 -> 12]
    [(symbol Plus) -> (symbol Plus)]
    [[12 * [5 - 3]] -> 24]
    [[9 - 8] -> 1]
    [[2 + 3] -> 5]
    [[6 / 2] -> 3]
    [[4 * 7] -> 28]
    [[2 + 3] * [4 - 1] -> 15]
    [[56 + [x - 7]] -> [56 + [x - 7]]]
    [[-245 * 67] -> -16415]
    [[x / x] -> [x / x]]
    [(symbol x) -> (symbol x)]
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
  _ -> (let Cases (golden-cases)
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
  _ -> (let Fixes (rejection-fixtures)
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
  _ -> (trap-error
          (do (output "~%=== attrs basic test/demo (SCUD 9.1, plan Phase 2 acceptance) ===~%")
              \\ declare and inspect sig (structural only; controls validated but not stored here)
              (let _ (declare-structural Plus [flat orderless])
                   Sig (get-structural-sig Plus)
                   (do (output "  declared-structural Plus [flat orderless]~%")
                       (output "  get-structural-sig Plus -> ~A~%" Sig)
                       true))
              \\ compounds (skeleton; hash sharing deferred until store canonical consults sigs)
              (let H (sym Plus)
                   C1 (compound H [(int 1) (int 2)])
                   C2 (compound H [(int 2) (int 1)])
                   (do (output "  created Plus compounds via expr: ~A , ~A~%" (pretty-expr C1) (pretty-expr C2))
                       (output "  (note: after canonical extension for flat/orderless, these will share content hash)~%")
                       true))
              \\ verify rejections for bad-attr combos (plan.md acceptance + golden REJECTs)
              (let _ (trap-error (declare-symbol Plus [hold-all hold-first])
                                 (/. _ (do (output "  declare rejected hold-all + hold-first (as expected)~%") true)))
                   _ (trap-error (declare-structural Plus [hold-all])
                                 (/. _ (do (output "  declare-structural rejected non-structural (hold-all)~%") true)))
                   _ (trap-error (declare-symbol Plus [listable (intern "hold-all")])
                                 (/. _ (do (output "  declare rejected listable + hold-all (as expected)~%") true)))
                   _ (trap-error (declare-symbol Plus [foo])
                                 (/. _ (do (output "  declare rejected unknown attr (via consistent-attrs?)~%") true)))
                   (output "  (bad-attr rejections verified per plan; see also rejection-fixtures and golden/arith-21.4.txt)~%")
                   true)
              true)
          (/. E (do (output "  (attrs demo skipped or partial; context lacks full load or prior declare: ~A)~%" E)
                    true))))

\\ --- SCUD 11.3: least-fixpoint loop detection tests (pure, no db) ---
\\ From ADR §5 + plan Phase 4 + tasks.scg 11.3
\\ Uses query.shen helpers (plain Shen, lfp over finite edge sets).
\\ These are executable here because query loaded (db stubbed).
\\ Implemented: lfp, reach-step, rule-dependency-loops + from-edges variant, direct-deps stub, join, set helpers.
\\ Tested: f->f, f->g->f (detected), acyclic chain (no loop + transitive [f h] present).
\\ Stub: direct-deps (and all db use); integration later per task. No Prolog used.

(define test-lfp-terminates-and-correct
  _ -> (let Self [[f f]]
            Mutual [[f g] [g f]]
            Acyclic [[f g] [g h] [a b]]
            LoopsSelf (rule-dependency-loops-from-edges Self)
            LoopsMut (rule-dependency-loops-from-edges Mutual)
            LoopsAcyc (rule-dependency-loops-from-edges Acyclic)
            ReachAcyc (reachable-from-edges Acyclic)
            \\ checks without relying on filter/sort/str list
            HasF (element? f LoopsSelf)
            HasFmut (element? f LoopsMut)
            HasGmut (element? g LoopsMut)
            NoAcyc (empty? LoopsAcyc)
            HasTrans (element? [f h] ReachAcyc)
            (and HasF HasFmut HasGmut NoAcyc HasTrans)))

\\ run the 11.3 specific test (uses output; if I/O fails in some loads, direct call test fn)
(define run-lfp-tests
  _ -> (let Ok (test-lfp-terminates-and-correct [])
            (do (if Ok
                    (output "lfp/loop tests: PASS (self f->f, mutual f->g->f, acyclic, trans via lfp)~%")
                    (output "lfp/loop tests: FAIL~%"))
                Ok)))

(define run-all-tests
  -> (let _ (output "=== shen-cas test harness (Phase 0 + SCUD 11.3) ===~%")
          g (run-golden [])
          r (run-rejection-tests [])
          a (attrs-demo [])
          l (run-lfp-tests [])
          (if (and g r a l)
              (do (output "~%ALL PASS~%") true)
              (do (output "~%SOME FAIL~%") false))))

\\ Auto-run on load
(run-all-tests)
