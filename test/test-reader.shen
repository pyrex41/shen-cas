\\ test-reader.shen - SCUD 16 Wave A reader/printer round-trip tests.
\\ Asserts BOTH directions on a corpus:
\\   forward : (parse-expr-string S) content-eq expected-expr
\\   round   : (parse-expr-string (print-expr (parse-expr-string S))) content-eq (parse-expr-string S)
\\ Plus a rule corpus that parses to a CHECKED rule via register-rule.
\\ Does not touch Golden or any existing test.

\\ forward parse check + structural round-trip via the printer
(define rt-case
  Label S Expected ->
    (let E (parse-expr-string S)
         FwdOk (content-eq E Expected)
         Printed (print-expr E)
         E2 (parse-expr-string Printed)
         RtOk (content-eq E2 E)
         Ok (and FwdOk RtOk)
         (do (if (not Ok)
                 (output "  RT FAIL ~A: ~A -> ~A (printed ~A reparsed-eq=~A fwd=~A)~%"
                         Label S E Printed RtOk FwdOk)
                 true)
             Ok)))

\\ pattern round-trip: print then reparse via the PATTERN parser.
(define rt-pat
  Label P ->
    (let Printed (print-expr P)
         P2 (parse-pattern-string Printed)
         Ok (content-eq P2 P)
         (do (if (not Ok)
                 (output "  RT-PAT FAIL ~A: ~A printed ~A reparsed ~A~%" Label P Printed P2)
                 true)
             Ok)))

(define run-reader-printer-tests
  -> (let Ign (output "~%=== SCUD 16 reader/printer round-trip ===~%")
          \\ ints (including negative), rationals, symbols
          C1 (rt-case "int" "42" [int 42])
          C2 (rt-case "neg" "-5" [int -5])
          \\ a numeric-literal quotient is a rational literal: "3/2" parses to [rat 3 2]
          \\ and round-trips exactly (printer renders [rat N D] back to "N/D").
          C3 (rt-case "rat" "3/2" (make-rat 3 2))
          C3b (= (print-expr (make-rat 3 2)) "3/2")
          \\ rational literals normalize at read time
          C3c (content-eq (parse-expr-string "6/4") (make-rat 3 2))
          C3d (content-eq (parse-expr-string "4/2") [int 2])
          C4 (rt-case "sym" "x" [sym (intern "x")])
          \\ applications
          C5 (rt-case "app1" "f[x]" [[sym (intern "f")] [sym (intern "x")]])
          C6 (rt-case "app-nested" "f[g[x],y]"
                      [[sym (intern "f")] [[sym (intern "g")] [sym (intern "x")]] [sym (intern "y")]])
          \\ precedence: a+b*c -> Plus[a, Times[b,c]]
          C7 (rt-case "prec1" "a+b*c"
                      [[sym (intern "Plus")] [sym (intern "a")]
                        [[sym (intern "Times")] [sym (intern "b")] [sym (intern "c")]]])
          \\ a*b+c -> Plus[Times[a,b], c]
          C8 (rt-case "prec2" "a*b+c"
                      [[sym (intern "Plus")]
                        [[sym (intern "Times")] [sym (intern "a")] [sym (intern "b")]]
                        [sym (intern "c")]])
          \\ power right-assoc: x^y^z -> Power[x, Power[y,z]]
          C9 (rt-case "pow-rassoc" "x^y^z"
                      [[sym (intern "Power")] [sym (intern "x")]
                        [[sym (intern "Power")] [sym (intern "y")] [sym (intern "z")]]])
          \\ parens force grouping: (a+b)*c -> Times[Plus[a,b], c]
          C10 (rt-case "parens" "(a+b)*c"
                       [[sym (intern "Times")]
                         [[sym (intern "Plus")] [sym (intern "a")] [sym (intern "b")]]
                         [sym (intern "c")]])
          \\ implicit multiplication: 2a -> Times[2, a]
          C11 (rt-case "implicit-mult" "2a"
                       [[sym (intern "Times")] [int 2] [sym (intern "a")]])
          \\ division: a/b -> Divide[a,b]
          C12 (rt-case "divide" "a/b"
                       [[sym (intern "Divide")] [sym (intern "a")] [sym (intern "b")]])
          \\ patterns x_ / x__ / x___ (round-trip only; build via reader pattern ctors)
          C13 (rt-pat "blank" (named-pat (intern "x") (blank-pat)))
          C14 (rt-pat "blank-seq" (named-pat (intern "x") (blank-seq-pat)))
          C15 (rt-pat "blank-null" (named-pat (intern "x") (blank-null-pat)))
          \\ rule f[x_]:=x+1 parses to a checked rule and registers through the gate
          R (parse-rule-string "f[x_]:=x+1")
          RegOk (trap-error (do (register-rule R) true) (/. E false))
          C16 RegOk
          Ok (every (/. X X) [C1 C2 C3 C3b C3c C3d C4 C5 C6 C7 C8 C9 C10 C11 C12 C13 C14 C15 C16])
          (do (output "16RT: int=~A neg=~A rat=~A rat-print=~A rat-norm=~A rat-int=~A sym=~A app=~A nested=~A prec1=~A prec2=~A pow=~A parens=~A imult=~A div=~A x_=~A x__=~A x___=~A rule-reg=~A~%"
                      C1 C2 C3 C3b C3c C3d C4 C5 C6 C7 C8 C9 C10 C11 C12 C13 C14 C15 C16)
              (if Ok (output "reader/printer (SCUD 16): PASS~%")
                  (output "reader/printer (SCUD 16): FAIL~%"))
              Ok)))
