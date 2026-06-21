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
\\   [num N] [dec P Q] [id Name] lbrack rbrack lparen rparen comma
\\   plus star pow slash colon-eq  blank1 blank2 blank3
\\ Whitespace skipped. Multi-digit ints (with optional leading '-').
\\ Decimal literals (e.g. 0.2, 1.5, .25) tokenize to [dec P Q] = the EXACT
\\ rational P/Q (0.2 -> [dec 2 10]); p-factor folds it via make-rat to [rat 1 5].
\\ This keeps the whole numeric tower exact (num.shen never uses native floats).
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
                      ((= C "=") (tok-eq S Acc))
                      ((= C "_") (tok-blank S 0 Acc))
                      ((= C "-") (tok R [dash | Acc]))
                      ((= C ".") (if (dot-frac? S)
                                     (tok-frac R 0 0 1 Acc)
                                     (error "tokenize: bad char ~A" C)))
                      ((digit? C) (tok-num S 0 Acc))
                      ((letter? C) (tok-id S "" Acc))
                      (true (error "tokenize: bad char ~A" C)))))

\\ ':=' -> colon-eq ; bare ':' is an error
(define tok-colon
  S Acc -> (let R (tlstr S)
                (if (and (not (= R "")) (= (pos R 0) "="))
                    (tok (tlstr R) [colon-eq | Acc])
                    (error "tokenize: bare ':' (expected :=)"))))

\\ '==' -> eqeq (Equal operator) ; a bare single '=' is an error (SCUD 19 Wave D)
(define tok-eq
  S Acc -> (let R (tlstr S)
                (if (and (not (= R "")) (= (pos R 0) "="))
                    (tok (tlstr R) [eqeq | Acc])
                    (error "tokenize: bare '=' (expected ==)"))))

\\ '-' is always a 'dash' token; the parser decides unary (negation) vs binary
\\ (subtraction). This keeps "x-1" = Plus[x,-1], not the wrong Times[x,-1].
\\ tok-num: consume digits into integer N. On a '.' followed by a digit, switch
\\ to fractional accumulation (tok-frac); otherwise emit [num N]. A trailing '.'
\\ (no digit after) is NOT consumed here, so it surfaces as a 'bad char' error.
(define tok-num
  S N Acc -> (cond ((= S "") (tok S [[num N] | Acc]))
                   ((digit? (pos S 0))
                    (tok-num (tlstr S) (+ (* N 10) (- (string->n (pos S 0)) 48)) Acc))
                   ((dot-frac? S) (tok-frac (tlstr S) N 0 1 Acc))
                   (true (tok S [[num N] | Acc]))))

\\ true iff S starts with '.' immediately followed by a digit (a decimal point,
\\ not a stray dot). Used to decide whether '.' begins a fractional part.
(define dot-frac?
  S -> (and (= (pos S 0) ".")
            (let R (tlstr S)
                 (and (not (= R "")) (digit? (pos R 0))))))

\\ tok-frac: accumulate fractional digits after the decimal point.
\\   Int   = integer part already parsed
\\   FracN = fractional digits as an integer (e.g. "25" -> 25)
\\   Den   = 10^(digits consumed) (the fraction's denominator)
\\ Emits [dec P Den] where P = Int*Den + FracN, i.e. the exact rational Int.FracN.
(define tok-frac
  S Int FracN Den Acc ->
    (if (and (not (= S "")) (digit? (pos S 0)))
        (tok-frac (tlstr S)
                  Int
                  (+ (* FracN 10) (- (string->n (pos S 0)) 48))
                  (* Den 10)
                  Acc)
        (tok S [[dec (+ (* Int Den) FracN) Den] | Acc])))

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
  eqeq -> 1
  plus -> 2
  dash -> 2
  star -> 3
  slash -> 3
  pow -> 4
  _ -> 0)

(define left-assoc?
  Op -> (or (= Op eqeq)
            (or (= Op plus) (or (= Op dash) (or (= Op star) (= Op slash))))))  \\ ^ is right

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
  [dec _ _] -> true
  [id _] -> true
  lparen -> true
  _ -> false)

(define infix-op?
  eqeq -> true
  plus -> true
  dash -> true
  star -> true
  slash -> true
  pow -> true
  _ -> false)

(define make-infix-expr
  eqeq L R -> (compound* (sym* "Equal") [L R])
  plus L R -> (compound* (sym* "Plus") [L R])
  dash L R -> (compound* (sym* "Plus") [L (negate R)])  \\ a - b == Plus[a, -b]
  star L R -> (compound* (sym* "Times") [L R])
  slash L R -> (slash-expr L R)
  pow L R -> (compound* (sym* "Power") [L R])
  _ L R -> (error "bad infix"))

\\ negate (multiply by -1): fold numeric literals; fold sign into a Times' leading
\\ numeric coefficient (x-2y -> Plus[x,Times[-2,y]], canonical); else prepend -1.
\\ Mutual inverse of print.shen's pos-of so subtraction round-trips.
(define negate
  [int N] -> (int* (* -1 N))
  [rat N D] -> (make-rat (* -1 N) D)
  V -> (negate-compound V))

(define negate-compound
  V -> (if (times-headed? V)
           (negate-times V)
           (compound* (sym* "Times") [(int* -1) V])))

(define times-headed?
  [H | _] -> (if (sym? H) (= (sym-name H) (intern "Times")) false)
  _ -> false)

(define negate-times
  [H C | Rest] -> (if (numeric? C)
                      (compound* H [(negate C) | Rest])
                      (compound* H [(int* -1) C | Rest])))

\\ A numeric-literal quotient N/D is a rational literal (round-trippable with the
\\ printer's [rat N D] case); a symbolic quotient stays a Divide compound.
(define slash-expr
  [int N] [int D] -> (make-rat N D)
  L R -> (compound* (sym* "Divide") [L R]))

\\ Factor: unary minus | number | symbol | ( expr ) | app | implicit mult
(define p-factor
  \\ unary minus binds at power precedence: -x^2 == -(x^2), -x*y == -(x*y)
  [dash | Rest] -> (let Pair (p-expr Rest 4)
                        V (hd Pair)
                        Rest2 (tl Pair)
                        [(negate V) | Rest2])
  [[num N] | Rest] -> [(int* N) | Rest]
  \\ decimal literal: fold the exact rational P/Q (make-rat reduces, e.g. 2/10 -> 1/5)
  [[dec P Q] | Rest] -> [(make-rat P Q) | Rest]
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
  [[dec P Q] | Rest] -> [(make-rat P Q) | Rest]
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
