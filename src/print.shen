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
  E -> (if (op-headed? "Plus" E) 1
           (if (op-headed? "Times" E) 2
               (if (op-headed? "Divide" E) 2
                   (if (op-headed? "Power" E) 3
                       100)))))   \\ generic app head[..] binds tight

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
  \\ infix operators
  E -> (print-infix "+" 1 1 2 E) where (op-headed? "Plus" E)
  E -> (print-infix "*" 2 2 3 E) where (op-headed? "Times" E)
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

\\ Divide is binary, left-assoc, prec 2.  a/b
(define print-divide
  [_ A B] -> (@s (paren-if 2 (expr-prec A) (print-expr A))
                 (@s "/" (paren-if 3 (expr-prec B) (print-expr B)))))

\\ Power is binary, RIGHT-assoc, prec 3.  a^b ; left child needs prec 4 (so a^b prints a, but (a^b)^c parens left).
(define print-power
  [_ A B] -> (@s (paren-if 4 (expr-prec A) (print-expr A))
                 (@s "^" (paren-if 3 (expr-prec B) (print-expr B)))))

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
