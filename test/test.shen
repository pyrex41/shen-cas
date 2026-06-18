\\ Phase 0+ test harness for shen-cas
\\ Golden format in golden/ : lines like   EXPR -> EXPECTED
\\ (s-exprs; simple for skeleton; full reader later).
\\ Rejection tests declared as data for future gate.
\\
\\ Run: (load "test/test.shen")
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

(define run-all-tests
  -> (let _ (output "=== shen-cas test harness (Phase 0) ===~%")
          g (run-golden [])
          r (run-rejection-tests [])
          (if (and g r)
              (do (output "~%PASS~%") true)
              (do (output "~%FAIL~%") false))))

\\ Auto-run on load
(run-all-tests)
