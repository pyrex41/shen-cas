\\ expr.shen - expr datatype + canonical constructors (Phase 1)
\\ All construction goes through store for sharing + hash identity.

(datatype expr
  X : symbol;
  _______________
  [sym X] : expr;

  N : number;
  _______________
  [int N] : expr;

  N : number; D : number;
  ________________________
  [rat N D] : expr;

  H : expr; Args : (list expr);
  ______________________________
  [H | Args] : expr; )

(load "src/store.shen")

(define sym
  S -> (cas-intern! (make-sym S)))   \\ via store (stubbed)

(define int
  N -> (cas-intern! (make-int N)))

(define compound
  H Args -> (cas-intern! (make-compound H Args)))

(define pretty-expr
  [sym S] -> S
  [int N] -> N
  [rat N D] -> [N / D]
  [H | Args] -> [(pretty-expr H) | (map (/. A (pretty-expr A)) Args)]
  E -> E)

(output "expr.shen loaded (datatypes + store constructors).~%")