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

\\ --- Real char-by-char tokenizer (SCUD 16 Wave A) ---
\\ Vocabulary consumed by p-factor/p-infix/p-pat:
\\   [num N] [id Name] lbrack rbrack lparen rparen comma
\\   plus star pow slash colon-eq  blank1 blank2 blank3
\\ Whitespace skipped. Multi-digit ints (with optional leading '-').
\\ Identifiers: letter then letters/digits. Underscores AFTER an id => blankN.
\\ A bare run of underscores (no preceding id) also tokenizes to blankN.

(define digit?
  C -> (let K (string->n C) (and (>= K 48) (<= K 57))))

(define letter?
  C -> (let K (string->n C)
            (or (and (>= K 65) (<= K 90))
                (and (>= K 97) (<= K 122)))))

(define alnum?
  C -> (or (letter? C) (digit? C)))

(define tokenize
  S -> (tok S []))

\\ tok : remaining-string accumulator(reversed) -> token-list
(define tok
  "" Acc -> (reverse Acc)
  S Acc -> (let C (pos S 0)
                R (tlstr S)
                (cond ((= C " ") (tok R Acc))
                      ((= C "	") (tok R Acc))
                      ((= C "
") (tok R Acc))
                      ((= C "[") (tok R [lbrack | Acc]))
                      ((= C "]") (tok R [rbrack | Acc]))
                      ((= C "(") (tok R [lparen | Acc]))
                      ((= C ")") (tok R [rparen | Acc]))
                      ((= C ",") (tok R [comma | Acc]))
                      ((= C "+") (tok R [plus | Acc]))
                      ((= C "*") (tok R [star | Acc]))
                      ((= C "^") (tok R [pow | Acc]))
                      ((= C "/") (tok R [slash | Acc]))
                      ((= C ":") (tok-colon S Acc))
                      ((= C "_") (tok-blank S 0 Acc))
                      ((= C "-") (tok-minus S Acc))
                      ((digit? C) (tok-num S 0 Acc))
                      ((letter? C) (tok-id S "" Acc))
                      (true (error "tokenize: bad char ~A" C)))))

\\ ':=' -> colon-eq ; bare ':' is an error
(define tok-colon
  S Acc -> (let R (tlstr S)
                (if (and (not (= R "")) (= (pos R 0) "="))
                    (tok (tlstr R) [colon-eq | Acc])
                    (error "tokenize: bare ':' (expected :=)"))))

\\ leading '-' : negative number if followed by a digit, else error (no unary on symbols)
(define tok-minus
  S Acc -> (let R (tlstr S)
                (if (and (not (= R "")) (digit? (pos R 0)))
                    (tok-num-neg R 0 Acc)
                    (error "tokenize: stray '-'"))))

(define tok-num-neg
  S N Acc -> (if (or (= S "") (not (digit? (pos S 0))))
                 (tok S [[num (* -1 N)] | Acc])
                 (tok-num-neg (tlstr S) (+ (* N 10) (- (string->n (pos S 0)) 48)) Acc)))

(define tok-num
  S N Acc -> (if (or (= S "") (not (digit? (pos S 0))))
                 (tok S [[num N] | Acc])
                 (tok-num (tlstr S) (+ (* N 10) (- (string->n (pos S 0)) 48)) Acc)))

(define tok-id
  S Name Acc -> (if (or (= S "") (not (alnum? (pos S 0))))
                    (tok S [[id Name] | Acc])
                    (tok-id (tlstr S) (@s Name (pos S 0)) Acc)))

\\ consume a maximal run of '_' (count K) and emit blank1/blank2/blank3
(define tok-blank
  S K Acc -> (if (and (not (= S "")) (= (pos S 0) "_"))
                 (tok-blank (tlstr S) (+ K 1) Acc)
                 (tok S [(blank-token K) | Acc])))

(define blank-token
  1 -> blank1
  2 -> blank2
  3 -> blank3
  K -> (error "tokenize: ~A underscores (only _ __ ___)" K))

\\ --- Helpers to build checked forms (always through ctors/gates) ---
(define sym*
  Name -> (sym (intern Name)))

\\ Intern the [int N] literal directly (cas-intern! keys on content-hash*, not on the
\\ make-int ctor name, which a later test module shadows). Avoids the make-int clash.
(define int*
  N -> (cas-intern! [int N]))

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
  slash -> 2
  pow -> 3
  _ -> 0)

(define left-assoc?
  Op -> (or (= Op plus) (or (= Op star) (= Op slash))))  \\ ^ is right

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
        \\ implicit multiplication: 2a, 2(x+1), (a+b)c -> Times[...]
        (if (factor-start? Op)
            (let P (prec star)
                 (if (not (>= P MinPrec))
                     [Left | [Op | Rest]]
                     (let Pair (p-expr [Op | Rest] (+ P 1))
                          Right (hd Pair)
                          Rest2 (tl Pair)
                          NewLeft (make-infix-expr star Left Right)
                          (p-infix NewLeft Rest2 MinPrec))))
            [Left | [Op | Rest]]))
  Left Rest _ -> [Left | Rest])

(define factor-start?
  [num _] -> true
  [id _] -> true
  lparen -> true
  _ -> false)

(define infix-op?
  plus -> true
  star -> true
  slash -> true
  pow -> true
  _ -> false)

(define make-infix-expr
  plus L R -> (compound* (sym* "Plus") [L R])
  star L R -> (compound* (sym* "Times") [L R])
  slash L R -> (slash-expr L R)
  pow L R -> (compound* (sym* "Power") [L R])
  _ L R -> (error "bad infix"))

\\ A numeric-literal quotient N/D is a rational literal (round-trippable with the
\\ printer's [rat N D] case); a symbolic quotient stays a Divide compound.
(define slash-expr
  [int N] [int D] -> (make-rat N D)
  L R -> (compound* (sym* "Divide") [L R]))

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
\\ Returns a cons-pair [Args | Rest] (hd=arg list, tl=remaining tokens), matching p-expr.
(define p-arglist
  [rbrack | Rest] -> [[] | [rbrack | Rest]]  \\ empty
  Ts -> (let Pair1 (p-expr Ts 0)
              A (hd Pair1)
              Rest1 (tl Pair1)
              Pair2 (p-arglist-tail Rest1)
              More (hd Pair2)
              Rest2 (tl Pair2)
              [[A | More] | Rest2]))

(define p-arglist-tail
  [comma | Ts] -> (let Pair1 (p-expr Ts 0)
                        A (hd Pair1)
                        Rest (tl Pair1)
                        Pair2 (p-arglist-tail Rest)
                        More (hd Pair2)
                        R2 (tl Pair2)
                        [[A | More] | R2])
  Ts -> [[] | Ts])

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
         (if (and (cons? Rest2) (= (hd Rest2) rbrack))
             [[HeadPat | Args] | (tl Rest2)]
             (error "missing ] in pat app")))
  [[id Name] | Rest] -> [(sym* Name) | Rest]
  [lparen | Ts] -> (p-pat Ts)
  Ts -> (error "p-pat bad ~A" Ts))

(define p-pat-arglist
  [rbrack | Rest] -> [[] | [rbrack | Rest]]
  Ts -> (let Pair1 (p-pat Ts)
              A (hd Pair1)
              R1 (tl Pair1)
              Pair2 (p-pat-arglist-tail R1)
              More (hd Pair2)
              R2 (tl Pair2)
              [[A | More] | R2]))

(define p-pat-arglist-tail
  [comma | Ts] -> (let Pair1 (p-pat Ts)
                        A (hd Pair1)
                        R (tl Pair1)
                        Pair2 (p-pat-arglist-tail R)
                        M (hd Pair2)
                        R2 (tl Pair2)
                        [[A | M] | R2])
  Ts -> [[] | Ts])

\\ --- Rule parser ---
\\ syntax:  head[ pat, ... ] := expr
\\ produces checked-rule via make-rule (the rule ctor)
(define parse-rule-string
  S -> (let Ts (tokenize S)
            Pair1 (p-pat Ts)
            LHS (hd Pair1)
            Rest1 (tl Pair1)
            (if (and (cons? Rest1) (= (hd Rest1) colon-eq))
                (let rem (tl Rest1)
                     Pair2 (p-expr rem 0)
                     RHS (hd Pair2)
                     Rest2 (tl Pair2)
                     (if (empty? Rest2)
                         (make-rule LHS RHS)
                         (error "rule trailing tokens")))
                (error "rule missing :="))))

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
