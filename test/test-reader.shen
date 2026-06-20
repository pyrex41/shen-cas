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

(define parser-fuzz-case
  [Label S] ->
    (let E (parse-expr-string S)
         Printed (print-expr E)
         E2 (parse-expr-string Printed)
         Ok (content-eq E2 E)
         (do (if (not Ok)
                 (output "  FUZZ FAIL ~A: ~A -> ~A printed ~A reparsed ~A~%"
                         Label S E Printed E2)
                 true)
             Ok))
  X -> (do (output "  FUZZ malformed case: ~A~%" X) false))

(define parser-printer-fuzz-cases
  -> [
    \\ atoms, whitespace, and exact rational literals
    ["atom-symbol" "alpha"]
    ["atom-symbol-digits" "x12"]
    ["atom-int-zero" "0"]
    ["atom-int-large" "123456"]
    ["atom-neg-int" "-42"]
    ["rat-basic" "1/2"]
    ["rat-normalize" "6/4"]
    ["rat-int-normalize" "4/2"]
    ["rat-negative" "-3/4"]
    ["rat-paren-negative" "(-3)/4"]
    \\ decimal literals parse to EXACT rationals (0.2 -> 1/5) and round-trip
    \\ structurally through the printer (which renders them as N/D).
    ["dec-half" "0.5"]
    ["dec-leading-dot" ".25"]
    ["dec-int-part" "1.5"]
    ["dec-trailing-zeros" "0.50"]
    ["dec-many-digits" "3.14159"]
    ["dec-neg" "-0.5"]
    ["dec-implicit-symbol" "0.2x"]
    ["dec-implicit-int-symbol" "50000x0.2"]
    ["dec-times" "0.5*x"]
    ["whitespace" " ( a + b ) * c "]

    \\ precedence and associativity
    ["prec-plus-times" "a+b*c"]
    ["prec-times-plus" "a*b+c"]
    ["prec-paren-times" "(a+b)*c"]
    ["assoc-plus-left" "a+b+c"]
    ["assoc-times-left" "a*b*c"]
    ["assoc-div-left" "a/b/c"]
    ["assoc-div-right-paren" "a/(b/c)"]
    ["assoc-power-right" "x^y^z"]
    ["assoc-power-left-paren" "(x^y)^z"]
    ["power-product-base" "(a*b)^c"]
    ["power-sum-exp" "x^(a+b)"]
    ["power-neg-exp" "x^-2"]
    ["power-rat-exp-positive" "x^(1/2)"]
    ["power-rat-exp" "x^(-1/2)"]

    \\ unary minus and subtraction edge cases
    ["unary-symbol" "-x"]
    ["unary-power" "-x^2"]
    ["unary-power-paren-base" "(-x)^2"]
    ["unary-paren-sum" "-(x+y)"]
    ["unary-app" "-Sin[x]"]
    ["unary-product" "-x*y"]
    ["unary-implicit-coeff" "-2x"]
    ["sub-int" "x-1"]
    ["sub-symbol" "x-y"]
    ["sub-product" "x-y*z"]
    ["sub-coeff-implicit" "x-2y"]
    ["sub-paren" "x-(y+z)"]

    \\ implicit multiplication
    ["implicit-num-symbol" "2x"]
    ["implicit-num-paren" "3(x+1)"]
    ["implicit-paren-paren" "(x+1)(x-1)"]
    ["implicit-symbol-paren" "x(y+1)"]
    ["implicit-app-symbol" "Sin[x]y"]
    ["implicit-app-paren" "f[x](y+1)"]
    ["implicit-chain" "2x(y+1)"]
    ["implicit-before-power" "2x^2"]

    \\ Divide syntax versus rational literal syntax
    ["divide-symbols" "a/b"]
    ["divide-sum-denom" "a/(b+c)"]
    ["divide-sum-numer" "(a+b)/c"]
    ["divide-app" "f[x]/g[y]"]
    ["divide-rat-times-symbol" "1/2*x"]
    ["divide-symbol-int" "x/2"]
    ["divide-int-symbol" "2/x"]

    \\ function applications, including empty, nested, and multi-arg calls
    ["app-empty" "f[]"]
    ["app-one" "f[x]"]
    ["app-multi" "f[x,y,z]"]
    ["app-nested" "f[g[x],h[y,z]]"]
    ["app-expr-args" "f[x+1,2*y,z^2]"]
    ["app-rational-arg" "f[1/2*x,-3/4]"]
    ["app-nested-power" "Sin[x]^2"]
    ["app-calculus-shape" "D[Sin[x^2],x]"]
    ["app-solve-shape" "Solve[x^2-1==0,x]"]

    \\ equality syntax (reader currently supports == as Equal)
    ["eq-symbols" "x==y"]
    ["eq-plus-times" "x+1==2*y"]
    ["eq-power" "x^2==1"]
    ["eq-paren-left" "(x+1)==(y+2)"]
    ["eq-nested-left" "(x==y)==z"]
    ["eq-in-app" "Solve[x^2-5*x+6==0,x]"]
  ])

(define run-parser-printer-fuzz-corpus
  -> (let Ign (output "~%=== parser/printer deterministic corpus ===~%")
          Cases (parser-printer-fuzz-cases)
          Results (map (/. C (parser-fuzz-case C)) Cases)
          Passed (filter (/. X X) Results)
          Ok (= (length Passed) (length Cases))
          (do (output "parser/printer corpus: ~A/~A passed~%" (length Passed) (length Cases))
              (if Ok (output "parser/printer deterministic corpus: PASS~%")
                  (output "parser/printer deterministic corpus: FAIL~%"))
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
          \\ decimal literals parse to exact rationals: 0.5 -> 1/2, .25 -> 1/4,
          \\ 1.5 -> 3/2, and 0.2 reduces to 1/5 at read time.
          Cd1 (rt-case "dec-half" "0.5" (make-rat 1 2))
          Cd2 (content-eq (parse-expr-string ".25") (make-rat 1 4))
          Cd3 (content-eq (parse-expr-string "1.5") (make-rat 3 2))
          Cd4 (content-eq (parse-expr-string "0.2") (make-rat 1 5))
          \\ -0.5 -> -1/2 ; trailing zeros normalize (0.50 -> 1/2)
          Cd5 (content-eq (parse-expr-string "-0.5") (make-rat -1 2))
          Cd6 (content-eq (parse-expr-string "0.50") (make-rat 1 2))
          \\ implicit multiplication accepts a decimal coefficient: 0.2x -> Times[1/5, x]
          \\ (parse is binary/nested; the evaluator does the numeric folding, not the reader).
          Cd7 (content-eq (parse-expr-string "0.2x")
                          [[sym (intern "Times")] (make-rat 1 5) [sym (intern "x")]])
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
          \\ subtraction (binary minus): a - b == Plus[a, negate b]
          C12a (rt-case "sub-int" "x-1"
                        [[sym (intern "Plus")] [sym (intern "x")] [int -1]])
          C12b (rt-case "sub-sym" "a-b"
                        [[sym (intern "Plus")] [sym (intern "a")]
                          [[sym (intern "Times")] [int -1] [sym (intern "b")]]])
          \\ sign folds into a Times coefficient: x - 2y == Plus[x, Times[-2,y]]
          C12c (rt-case "sub-coeff" "x-2*y"
                        [[sym (intern "Plus")] [sym (intern "x")]
                          [[sym (intern "Times")] [int -2] [sym (intern "y")]]])
          \\ unary minus binds at power precedence: -x^2 == -(x^2)
          C12d (rt-case "unary-pow" "-x^2"
                        [[sym (intern "Times")] [int -1]
                          [[sym (intern "Power")] [sym (intern "x")] [int 2]]])
          \\ patterns x_ / x__ / x___ (round-trip only; build via reader pattern ctors)
          C13 (rt-pat "blank" (named-pat (intern "x") (blank-pat)))
          C14 (rt-pat "blank-seq" (named-pat (intern "x") (blank-seq-pat)))
          C15 (rt-pat "blank-null" (named-pat (intern "x") (blank-null-pat)))
          \\ rule f[x_]:=x+1 parses to a checked rule and registers through the gate
          R (parse-rule-string "f[x_]:=x+1")
          RegOk (trap-error (do (register-rule R) true) (/. E false))
          C16 RegOk
          FuzzOk (run-parser-printer-fuzz-corpus)
          Ok (every (/. X X) [C1 C2 C3 C3b C3c C3d Cd1 Cd2 Cd3 Cd4 Cd5 Cd6 Cd7
                              C4 C5 C6 C7 C8 C9 C10 C11 C12
                              C12a C12b C12c C12d C13 C14 C15 C16 FuzzOk])
          (do (output "16RT: int=~A neg=~A rat=~A rat-print=~A rat-norm=~A rat-int=~A dec=~A/~A/~A/~A/~A/~A/~A sym=~A app=~A nested=~A prec1=~A prec2=~A pow=~A parens=~A imult=~A div=~A sub-int=~A sub-sym=~A sub-coeff=~A unary-pow=~A x_=~A x__=~A x___=~A rule-reg=~A~%"
                      C1 C2 C3 C3b C3c C3d Cd1 Cd2 Cd3 Cd4 Cd5 Cd6 Cd7 C4 C5 C6 C7 C8 C9 C10 C11 C12 C12a C12b C12c C12d C13 C14 C15 C16)
              (if Ok (output "reader/printer (SCUD 16): PASS~%")
                  (output "reader/printer (SCUD 16): FAIL~%"))
              Ok)))
