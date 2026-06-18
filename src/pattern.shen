\\ pattern.shen - pattern / seq-pattern language (Phase 1)
\\ Distinguishes patterns from exprs.
\\ Reserved constructors to prevent literal exprs from masquerading as patterns.
\\ Seq patterns only allowed in argument position of compounds.
\\ extract-bindings for rule checking.

(load "src/store.shen")
(load "src/expr.shen")

\\ --- Datatypes (following sketch + compound-pattern rules) ---

(datatype seq-pattern
  _________________________
  (blank-seq) : seq-pattern;

  ______________________________
  (blank-null-seq) : seq-pattern; )

(datatype pattern
  E : expr;
  _____________
  E : pattern;

  ____________________
  (blank) : pattern;

  H : symbol;
  _______________________
  (blank H) : pattern;

  Name : symbol; P : pattern;
  ____________________________
  (named Name P) : pattern;

  P : pattern; Test : expr;
  ______________________________________
  (condition P Test) : pattern;

  P : pattern; F : symbol;
  _________________________________
  (ptest P F) : pattern;

  P1 : pattern; P2 : pattern;
  ________________________________
  (alt P1 P2) : pattern; )

(datatype pat-or-seq
  P : pattern;
  ________________
  P : pat-or-seq;

  S : seq-pattern;
  ________________
  S : pat-or-seq; )

(datatype compound-pattern
  H : pattern; Args : (list pat-or-seq);
  _______________________________________
  [H | Args] : pattern; )

\\ Reserved pattern heads (distinct from expr symbols so (Pattern ...) etc. can't be confused with literal exprs)
\\ Constructors use cons + intern to produce canonical list forms (avoids [] ctor analysis issues):
\\   (cons (intern "blank") ()) | (cons (intern "blank") (cons H ()))
\\   (cons (intern "blank-seq") ()) etc.
\\   (cons (intern "named") (cons N (cons P ()))) 
(define blank -> (cons (intern "blank") ()))
(define blank-seq -> (cons (intern "blank-seq") ()))
(define blank-null -> (cons (intern "blank-null-seq") ()))
(define named N P -> (cons (intern "named") (cons N (cons P ()))))
(define condition P T -> (cons (intern "condition") (cons P (cons T ()))))
(define ptest P F -> (cons (intern "ptest") (cons P (cons F ()))))
(define alt P1 P2 -> (cons (intern "alt") (cons P1 (cons P2 ()))))

\\ Note: compound patterns are lists [H | Args] (H pattern-or-expr, Args pat-or-seq).
\\ Datatype enforces seq only in arg lists. Runtime forms are lists.

\\ --- Pattern recognizers (supporting extract, match, future covers) ---
\\ Use hd/tl + intern for robustness (no list pattern ctor syntax on tags)

(define blank?
  X -> (and (cons? X) (= (hd X) (intern "blank"))))

(define blank-typed?
  X -> (and (cons? X) (= (hd X) (intern "blank")) (cons? (tl X))))

(define named?
  X -> (and (cons? X) (= (hd X) (intern "named")) (= (length X) 3)))

(define named-name
  X -> (if (named? X) (hd (tl X)) (error "named-name: not a named form ~A" X)))

(define named-subpattern
  X -> (if (named? X) (hd (tl (tl X))) (error "named-subpattern: not a named form ~A" X)))

(define seq-pattern?
  X -> (or (blank-seq? X) (blank-null-seq? X)))

(define blank-seq?
  X -> (and (cons? X) (= (hd X) (intern "blank-seq"))))

(define blank-null-seq?
  X -> (and (cons? X) (= (hd X) (intern "blank-null-seq"))))

(define condition?
  X -> (and (cons? X) (= (hd X) (intern "condition")) (cons? (tl X))))

(define ptest?
  X -> (and (cons? X) (= (hd X) (intern "ptest")) (cons? (tl X))))

(define alt?
  X -> (and (cons? X) (= (hd X) (intern "alt")) (cons? (tl X))))

(define tagged-pattern-form?
  X -> (or (named? X) (blank? X) (blank-typed? X) (condition? X) (ptest? X) (alt? X) (seq-pattern? X))
  _ -> false)

(define expr-form?
  P -> (and (cons? P) (element? (hd P) [(intern "sym") (intern "int") (intern "real") (intern "str")]))
  _ -> false)

(define compound-pattern?
  P -> (and (cons? P)
            (not (tagged-pattern-form? P))
            (not (expr-form? P)))
  _ -> false)

(define compound-pattern-head
  P -> (if (compound-pattern? P) (hd P) (error "compound-pattern-head: not ~A" P)))

(define compound-pattern-args
  P -> (if (compound-pattern? P) (tl P) (error "compound-pattern-args: not ~A" P)))

(define alt-left
  P -> (if (alt? P) (hd (tl P)) (error "alt-left ~A" P)))

(define alt-right
  P -> (if (alt? P) (hd (tl (tl P))) (error "alt-right ~A" P)))

(define condition-pattern
  P -> (if (condition? P) (hd (tl P)) (error "condition-pattern ~A" P)))

(define ptest-pattern
  P -> (if (ptest? P) (hd (tl P)) (error "ptest-pattern ~A" P)))

(define pattern?
  P -> (or (blank? P)
           (blank-typed? P)
           (named? P)
           (condition? P)
           (ptest? P)
           (alt? P)
           (compound-pattern? P)
           (expr-form? P)))

\\ --- Binding extraction (collect named from patterns; handle compounds/seqs per datatype) ---
\\ Names from (named Name sub) + recursive from sub (so match's inner bindings covered).
\\ Unnamed seq [blank-seq] etc and literals contribute nothing.
\\ Compound recurses head + all arg elements (named-seq caught via named?).

(define extract-bindings
  P -> (if (named? P)
           (cons (named-name P) (extract-bindings (named-subpattern P)))
           (if (compound-pattern? P)
               (append (extract-bindings (compound-pattern-head P))
                       (mapcan extract-bindings (compound-pattern-args P)))
               (if (alt? P)
                   (append (extract-bindings (alt-left P)) (extract-bindings (alt-right P)))
                   (if (condition? P)
                       (extract-bindings (condition-pattern P))
                       (if (ptest? P)
                           (extract-bindings (ptest-pattern P))
                           []))))))

\\ --- Binding list helpers (for bindings-cover? and later Datalog covers?) ---
(define my-remove
  X L -> (if (cons? L)
             (if (= X (hd L))
                 (my-remove X (tl L))
                 (cons (hd L) (my-remove X (tl L))))
             []))

(define dedup
  L -> (if (cons? L)
           (cons (hd L) (dedup (my-remove (hd L) (tl L))))
           []))

(define unique-bindings
  Binds -> (dedup Binds))

(define bindings
  P -> (unique-bindings (extract-bindings P)))

(define has-bindings?
  P -> (not (empty? (extract-bindings P))))

\\ --- Integration with store (patterns are also content-addressable in later phases) ---
\\ For Phase 1 we keep them as ordinary structures but can intern if desired.

(princ "pattern.shen loaded (datatypes + reserved ctors + robust extract-bindings + pattern utilities).~%")