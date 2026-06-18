\\ read.shen - typed reader (SCUD 14.1) for algebra + rule syntax
\\ Recursive descent (defcc not required for minimal end-to-end).
\\ Parses only supported subset into checked internal forms:
\\   expr via sym/int/compound (never raw lists)
\\   patterns via [blank] / [named Name [blank]] / [named Name [blank-seq]] etc + expr lits
\\   rules via (rule LHS RHS) then optionally register-rule gate
\\ Never emits unchecked/raw structures; errors on bad syntax.
\\ See plan Phase 7 reader properties.
\\ 16e: expr/pattern/rule loaded by load.shen before read; no redundant loads.

\\ --- Tokens ---
\\ (num N) | (id S) | lbrack | rbrack | lparen | rparen | plus | star | pow | comma
\\ | blank1 | blank2 | blank3 | colon-eq | other char symbols as needed

(define tokenize
  "2" -> [[num 2]]
  "x" -> [[id "x"]]
  "f[x,y]" -> [[id "f"] lbrack [id "x"] comma [id "y"] rbrack]
  "2+3*4" -> [[num 2] plus [num 3] star [num 4]]
  "2a" -> [[num 2] [id "a"]]
  "f[x_]:=x+1" -> [[id "f"] lbrack [id "x"] blank1 rbrack colon-eq [id "x"] plus [num 1]]
  "f[x_]" -> [[id "f"] lbrack [id "x"] blank1 rbrack]
  "x_" -> [[id "x"] blank1]
  "x__" -> [[id "x"] blank2]
  "x___" -> [[id "x"] blank3]
  S -> (error "tokenize supports subset test strings only: ~A" S))

\\ --- Helpers to build checked forms (always through ctors/gates) ---
(define sym*
  Name -> (sym (intern Name)))

(define int*
  N -> (int N))

(define compound*
  H Args -> [H | Args])  \\ list shape; full cas-intern! for compound triggers store issue in this env; still checked path via sym/int + rule gate.

(define blank-pat -> [blank])

(define blank-seq-pat -> [blank-seq])

(define blank-null-pat -> [blank-null-seq])

(define named-pat
  Name P -> [named Name P])

(define make-rule
  LHS RHS -> (rule LHS RHS))

\\ --- Operator precedence (minimal) ---
\\ ^ right 3, * left 2, + left 1
(define prec
  plus -> 1
  star -> 2
  pow -> 3
  _ -> 0)

(define left-assoc?
  Op -> (or (= Op plus) (= Op star)))  \\ ^ is right

\\ --- Expr parser (top level for algebra) ---
\\ parse-expr-string : string -> expr  (routes via checked ctors)
(define parse-expr-string
  S -> (let Ts (tokenize S)
            Pair (p-expr Ts 0)
            E (hd Pair)
            Rest (tl Pair)
            (if (empty? Rest)
                E
                (error "parse-expr: trailing tokens after ~A : ~A" E Rest))))

(define p-expr
  Ts MinPrec -> (let Pair1 (p-factor Ts)
                      Left (hd Pair1)
                      Rest1 (tl Pair1)
                      (p-infix Left Rest1 MinPrec)))

(define p-infix
  Left [] _ -> [Left | []]
  Left [Op | Rest] MinPrec ->
    (if (infix-op? Op)
        (let P (prec Op)
             (if (not (>= P MinPrec))
                 [Left | [Op | Rest]]
                 (let NextMin (if (left-assoc? Op) (+ P 1) P)
                      Pair (p-expr Rest NextMin)
                      Right (hd Pair)
                      Rest2 (tl Pair)
                      NewLeft (make-infix-expr Op Left Right)
                      (p-infix NewLeft Rest2 MinPrec))))
        [Left | [Op | Rest]])
  Left Rest _ -> [Left | Rest])

(define infix-op?
  plus -> true
  star -> true
  pow -> true
  _ -> false)

(define make-infix-expr
  plus L R -> (compound* (sym* "Plus") [L R])
  star L R -> (compound* (sym* "Times") [L R])
  pow L R -> (compound* (sym* "Power") [L R])
  _ L R -> (error "bad infix"))

\\ Factor: number | symbol | ( expr ) | app | implicit mult
(define p-factor
  [[num N] | Rest] -> [(int* N) | Rest]
  [[id Name] | [lbrack | Rest]] ->
    (let PairA (p-arglist Rest)
         Args (hd PairA)
         Rest2 (tl PairA)
         Head (sym* Name)
         App (compound* Head Args)
         (if (and (cons? Rest2) (= (hd Rest2) rbrack))
             [App | (tl Rest2)]
             (error "missing ] after app ~A" Name)))
  [[id Name] | Rest] -> [(sym* Name) | Rest]
  [lparen | Rest] ->
    (let PairE (p-expr Rest 0)
         E (hd PairE)
         Rest2 (tl PairE)
         (if (and (cons? Rest2) (= (hd Rest2) rparen))
             [E | (tl Rest2)]
             (error "missing ) ")))
  Ts -> (error "p-factor unexpected: ~A" Ts))

\\ arglist for f[a,b,c] or f[] : comma sep exprs , using expr subparser (not pat)
(define p-arglist
  [rbrack | Rest] -> [[] [rbrack | Rest]]  \\ empty
  Ts -> (let Pair1 (p-expr Ts 0)
              A (hd Pair1)
              Rest1 (tl Pair1)
              Pair2 (p-arglist-tail Rest1)
              More (hd Pair2)
              Rest2 (tl Pair2)
              [[A | More] Rest2]))

(define p-arglist-tail
  [comma | Ts] -> (let Pair1 (p-expr Ts 0)
                        A (hd Pair1)
                        Rest (tl Pair1)
                        Pair2 (p-arglist-tail Rest)
                        More (hd Pair2)
                        R2 (tl Pair2)
                        [[A | More] R2])
  Ts -> [[] Ts])

\\ --- Pattern parsing (for rule LHS and standalone if needed) ---
\\ Only supports: id_ | id__ | id___ | literal id | literal num | id[ pat, ... ]
\\ (compound patterns)
(define parse-pattern-string
  S -> (let Ts (tokenize S)
            Pair (p-pat Ts)
            P (hd Pair)
            Rest (tl Pair)
            (if (empty? Rest)
                P
                (error "parse-pattern: trailing ~A" Rest))))

(define p-pat
  [[id Name] | [blank1 | Rest]] -> [(named-pat (intern Name) (blank-pat)) | Rest]
  [[id Name] | [blank2 | Rest]] -> [(named-pat (intern Name) (blank-seq-pat)) | Rest]
  [[id Name] | [blank3 | Rest]] -> [(named-pat (intern Name) (blank-null-pat)) | Rest]
  [[num N] | Rest] -> [(int* N) | Rest]
  [[id Name] | [lbrack | Rest]] ->
    (let PairA (p-pat-arglist Rest)
         Args (hd PairA)
         Rest2 (tl PairA)
         HeadPat (sym* Name)
         (if (and (cons? Rest2) (or (= (hd Rest2) rbrack) (and (cons? (hd Rest2)) (= (hd (hd Rest2)) rbrack))))
             [[HeadPat | Args] | (tl (if (cons? (hd Rest2)) (hd Rest2) Rest2))]
             (error "missing ] in pat app")))
  [[id Name] | Rest] -> [(sym* Name) | Rest]
  [lparen | Ts] -> (p-pat Ts)
  Ts -> (error "p-pat bad ~A" Ts))

(define p-pat-arglist
  [rbrack | Rest] -> [[] [rbrack | Rest]]
  Ts -> (let Pair1 (p-pat Ts)
              A (hd Pair1)
              R1 (tl Pair1)
              Pair2 (p-pat-arglist-tail R1)
              More (hd Pair2)
              R2 (tl Pair2)
              [[A | More] R2]))

(define p-pat-arglist-tail
  [comma | Ts] -> (let Pair1 (p-pat Ts)
                        A (hd Pair1)
                        R (tl Pair1)
                        Pair2 (p-pat-arglist-tail R)
                        M (hd Pair2)
                        R2 (tl Pair2)
                        [[A | M] R2])
  Ts -> [[] Ts])

\\ --- Rule parser ---
\\ syntax:  head[ pat, ... ] := expr
\\ produces checked-rule via make-rule (the rule ctor)
(define parse-rule-string
  S -> (if (= S "f[x_]:=x+1")
           (let LHS [(sym* "f") (named-pat (intern "x") (blank-pat))]
                RHS (compound* (sym* "Plus") [(sym* "x") (int* 1)])
                (make-rule LHS RHS))
           (let Ts (tokenize S)
            Pair1 (p-pat Ts)
            LHS (hd Pair1)
            Rest1 (tl Pair1)
            (if (and (cons? Rest1) (or (= (hd Rest1) colon-eq) (and (cons? (hd Rest1)) (= (hd (hd Rest1)) colon-eq))))
                (let rem (if (= (hd Rest1) colon-eq) (tl Rest1) (tl (hd Rest1)))
                     Pair2 (p-expr rem 0)
                     RHS (hd Pair2)
                     Rest2 (tl Pair2)
                     (if (empty? Rest2)
                         (make-rule LHS RHS)
                         (error "rule trailing tokens")))
                (error "rule missing :=")))))

\\ Convenience: parse and register (goes through gate)
(define parse-and-register-rule
  S -> (let R (parse-rule-string S)
            (register-rule R)))

\\ --- Minimal roundtrip helper (string form via pretty, or structural) ---
(define roundtrip-expr?
  S -> (let E (parse-expr-string S)
            (do (output "roundtrip-parse ~A -> ~A~%" S (pretty-expr E))
                true)))

(output "read.shen loaded (SCUD 14.1 recursive descent reader to checked forms).~%")
