\\ expr.shen - expr datatype + canonical constructors (Phase 1)
\\ All construction goes through store for sharing + hash identity.

(load "src/store.shen")

(datatype expr
  X : symbol;
  _______________
  (sym X) : expr;

  N : number;
  _______________
  (int N) : expr;

  H : expr; Args : (list expr);
  ______________________________
  [H | Args] : expr; )

(define sym
  S -> (intern! (make-sym S)))   \\ via store (stubbed)

(define int
  N -> (intern! (make-int N)))

(define compound
  H Args -> (intern! (make-compound H Args)))

(define pretty-expr
  (sym S) -> S
  (int N) -> N
  [H | Args] -> [(pretty-expr H) | (map pretty-expr Args)]
  E -> E)

(princ "expr.shen loaded (datatypes + store constructors).~%")