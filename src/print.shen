\\ print.shen - round-trippable printer (SCUD 16 Wave A)
\\ (print-expr E) : expr -> string  such that for every supported E,
\\   (content-eq (parse-expr-string (print-expr E)) E) holds.
\\ Minimal parens by precedence: Plus(1) < Times/Divide(2) < Power(3); Power right-assoc.
\\ Depends on: expr.shen (datatypes), pattern recognizers (pattern.shen), read.shen ctors.
\\ Loaded by load.shen AFTER read.shen.

\\ precedence of an expr's top operator (atoms/apps bind tightest = 100)
(define expr-prec
  [sym _] -> 100
  [int _] -> 100
  [rat _ _] -> 100
  E -> (if (op-headed? "Equal" E) 0
           (if (op-headed? "Plus" E) 1
               (if (op-headed? "Times" E) 2
                   (if (op-headed? "Divide" E) 2
                       (if (op-headed? "Power" E) 3
                           100))))))   \\ generic app head[..] binds tight

\\ true if E is a compound headed by [sym Name] with >= 2 args (real infix shape)
(define op-headed?
  Name [H | Args] -> (and (sym? H)
                          (and (= (sym-name H) (intern Name))
                               (>= (length Args) 2)))
  _ _ -> false)

\\ wrap S in parens iff Inner precedence < Need
(define paren-if
  Need Inner S -> (if (< Inner Need) (@s "(" (@s S ")")) S))

(define print-expr
  [int N] -> (str N)
  [rat N D] -> (@s (str N) (@s "/" (str D)))
  [sym S] -> (str S)
  \\ patterns (LHS / standalone)
  E -> (print-pattern E) where (or (named? E) (or (blank? E) (or (blank-seq? E) (blank-null-seq? E))))
  \\ infix operators (Plus renders subtraction; Times renders leading minus)
  E -> (print-equal E) where (op-headed? "Equal" E)
  E -> (print-plus E) where (op-headed? "Plus" E)
  E -> (print-times E) where (op-headed? "Times" E)
  E -> (print-divide E) where (op-headed? "Divide" E)
  E -> (print-power E) where (op-headed? "Power" E)
  \\ generic application head[a,b,...]
  [H | Args] -> (@s (print-expr H) (@s "[" (@s (print-args Args) "]")))
  E -> (error "print-expr: unsupported ~A" E))

\\ left-assoc n-ary infix: a Op b Op c.  LeftNeed/RightNeed are the precedences
\\ a child must MEET (else parens). For left-assoc, left child needs Prec, right needs Prec+1.
(define print-infix
  Op Prec LeftNeed RightNeed [_ | Args] -> (join-infix Op Prec LeftNeed RightNeed Args))

(define join-infix
  Op _ LeftNeed _ [A] -> (paren-if LeftNeed (expr-prec A) (print-expr A))
  Op Prec LeftNeed RightNeed [A | Rest] ->
    (@s (paren-if LeftNeed (expr-prec A) (print-expr A))
        (@s Op (join-infix Op Prec RightNeed RightNeed Rest))))

\\ --- signed printing (mutual inverse of read.shen negate) ---
\\ The numeric coefficient of a Times can sit at ANY position (Orderless hash-sort),
\\ so we extract it for display: coeff first, with sign, then the other factors.
(define numeric-neg?
  [int N] -> (< N 0)
  [rat N _] -> (< N 0)
  _ -> false)

(define times-coeff
  [_ | Args] -> (find-coeff Args))
(define find-coeff
  [] -> [int 1]
  [A | Rest] -> (if (numeric? A) A (find-coeff Rest)))

(define times-others
  [_ | Args] -> (drop-first-numeric Args))
(define drop-first-numeric
  [] -> []
  [A | Rest] -> (if (numeric? A) Rest [A | (drop-first-numeric Rest)]))

(define negate-num
  [int N] -> [int (* -1 N)]
  [rat N D] -> [rat (* -1 N) D])

\\ a term is "negative" if it is a negative number or a Times whose coefficient is negative
(define neg-coeff?
  [int N] -> (< N 0)
  [rat N _] -> (< N 0)
  E -> (if (op-headed? "Times" E) (numeric-neg? (times-coeff E)) false))

\\ positive version of a negative term (so "-" + pos-of(T) reparses to T)
(define pos-of
  [int N] -> [int (* -1 N)]
  [rat N D] -> [rat (* -1 N) D]
  E -> (rebuild-times (negate-num (times-coeff E)) (times-others E)))

\\ build a Times with the coefficient first; drop a unit coefficient
(define rebuild-times
  [int 1] [F] -> F
  [int 1] Others -> [(times-head-sym) | Others]
  C Others -> [(times-head-sym) C | Others])
(define times-head-sym -> [sym (intern "Times")])

\\ Equal is binary, prec 0 (loosest).  L==R ; children (Plus and tighter) need no
\\ parens since they all bind tighter than Equal.
(define print-equal
  [_ A B] -> (@s (paren-if 1 (expr-prec A) (print-expr A))
                 (@s "==" (paren-if 1 (expr-prec B) (print-expr B)))))

\\ Plus printed with subtraction: Plus[a, -b, ...] -> a-b-...
(define print-plus
  [_ | Args] -> (pp-terms Args true))
(define pp-terms
  [] _ -> ""
  [A | Rest] First ->
    (let Neg (neg-coeff? A)
         Body (if Neg (print-addend (pos-of A)) (print-addend A))
         Sign (if First (if Neg "-" "") (if Neg "-" "+"))
         (@s Sign (@s Body (pp-terms Rest false)))))

\\ an addend needs parens only if it is itself a Plus (prec < 2)
(define print-addend
  A -> (paren-if 2 (expr-prec A) (print-expr A)))

\\ Times: coefficient first (with sign), then the other factors joined by '*'
(define print-times
  E -> (let C (times-coeff E)
            Others (times-others E)
            (if (numeric-neg? C)
                (@s "-" (print-times-body (negate-num C) Others))
                (print-times-body C Others))))
(define print-times-body
  [int 1] Others -> (print-product Others)
  C Others -> (@s (print-expr C) (@s "*" (print-product Others))))
(define print-product
  [] -> ""
  [F] -> (paren-if 3 (expr-prec F) (print-expr F))
  [F | Rest] -> (@s (paren-if 3 (expr-prec F) (print-expr F)) (@s "*" (print-product Rest))))

\\ Divide is binary, left-assoc, prec 2.  a/b
(define print-divide
  [_ A B] -> (@s (paren-if 2 (expr-prec A) (print-expr A))
                 (@s "/" (paren-if 3 (expr-prec B) (print-expr B)))))

\\ Power is binary, RIGHT-assoc, prec 3.  a^b ; left child needs prec 4 (so a^b prints a, but (a^b)^c parens left).
\\ Rational exponents must be parenthesized: x^(1/2), not x^1/2 (= (x^1)/2).
(define print-power
  [_ A B] -> (@s (paren-if 4 (expr-prec A) (print-expr A))
                 (@s "^" (print-power-exponent B))))

(define print-power-exponent
  [rat N D] -> (@s "(" (@s (print-expr [rat N D]) ")"))
  B -> (paren-if 3 (expr-prec B) (print-expr B)))

(define print-args
  [] -> ""
  [A] -> (print-expr A)
  [A | Rest] -> (@s (print-expr A) (@s "," (print-args Rest))))

\\ patterns:  Name_ / Name__ / Name___ , bare _ , named subpattern.
(define print-pattern
  P -> (if (named? P)
           (print-named (named-name P) (named-subpattern P))
           (if (blank? P) "_"
               (if (blank-seq? P) "__"
                   (if (blank-null-seq? P) "___"
                       (error "print-pattern: ~A" P))))))

(define print-named
  Name Sub -> (@s (str Name) (blank-suffix Sub)))

(define blank-suffix
  Sub -> (if (blank? Sub) "_"
             (if (blank-seq? Sub) "__"
                 (if (blank-null-seq? Sub) "___"
                     (error "blank-suffix: ~A" Sub)))))

(output "print.shen loaded (round-trippable printer).~%")
