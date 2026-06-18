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
(define blank      _   -> (blank))
(define blank-seq  _   -> blank-seq)     ; return the symbol tag (fixed non-recursive)
(define blank-null _   -> blank-null-seq)
(define named      N P -> (list 'named N P))  ; explicit tag list for named (to support seq sub)
(define condition  P T -> (condition P T))
(define ptest      P F -> (ptest P F))
(define alt        P1 P2 -> (alt P1 P2))

\\ Note: compound patterns are just lists whose elements are pat-or-seq.
\\ We rely on the datatype rules above for static checking when using sequents.

\\ --- Binding extraction (stub for Phase 1, sufficient for bindings-cover) ---

(define extract-bindings
  [(list 'named) Name _] -> [Name]   ; updated for list tag ctor
  (named Name _) -> [Name]           ; keep for compatibility
  [H | Args] -> (append (extract-bindings H)
                        (mapcan (fn extract-bindings) (filter pattern? Args)))
  _ -> [])

(define pattern?
  P -> (or (blank? P) (blank-typed? P) (named? P) (compound-pattern? P) (condition? P) (ptest? P) (alt? P)))

(define blank? (blank) -> true ; _ -> false)
(define blank-typed? [(blank) _] -> true ; _ -> false)   \\ simplistic
(define named? [(list 'named) _ _] -> true ; _ -> false)  ; updated for list tag
(define compound-pattern? [H | _] -> (and (pattern? H) true) where (not (symbol? H)) ; _ -> false)
(define condition? [(condition) _ _] -> true ; _ -> false)
(define ptest? [(ptest) _ _] -> true ; _ -> false)
(define alt? [(alt) _ _] -> true ; _ -> false)

\\ Simple recognizers for compound heads
(define compound-pattern-head
  [H | _] -> H)

\\ --- Integration with store (patterns are also content-addressable in later phases) ---
\\ For Phase 1 we keep them as ordinary structures but can intern if desired.

(princ "pattern.shen loaded (datatypes + reserved ctors + extract-bindings stub).~%")