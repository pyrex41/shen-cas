\\ store.shen - content-addressed term store (Phase 1 core)
\\ Merkle content hashes + interning + O(1) equality (per notes/syntax-verification.md task 4)
\\ Hash choice: portable recursive Shen (hash ... 1000000007) after canonicalization.
\\ No basis/memo/rule-driven equality yet.
\\ Structural signatures (Orderless/Flat/OneIdentity) are immutable creation facts.

(datatype content-hash
  H : number;
  ________________
  (ch H) : content-hash;)

(set *intern-table* [])

(define intern-lookup
  H Table -> (assoc H Table))

(define intern-store
  H Node Table -> (adjoin [H Node] Table))

\\ --- Hash per task-4 policy (notes/syntax-verification.md) ---
(define portable-atom-string
  Tag Val -> (cn (str Tag) (if (symbol? Val) (str Val) (str Val))))

(define hash-atom
  Tag Val -> (hash (portable-atom-string Tag Val) 1000000007))

(define hash-compound
  H ArgHashes -> (hash (cn (str H) (fold-left cn "" (map str ArgHashes))) 1000000007))

(define content-hash
  (sym S) -> (ch (hash-atom "sym" S))
  (int N) -> (ch (hash-atom "int" N))
  [H | Args] -> (let Hh (content-hash H)
                     Ah (map content-hash Args)
                     (ch (hash-compound (unwrap-ch Hh) (map unwrap-ch Ah)))))

(define unwrap-ch
  (ch N) -> N)

\\ Canonical constructors (later consult sigs for Orderless/Flat before hashing)
(define make-sym
  S -> (sym S))

(define make-int
  N -> (int N))

(define make-compound
  H Args -> [H | Args])

(define intern
  E -> (let H (content-hash E)
            (intern-lookup (unwrap-ch H) (value *intern-table*))))

(define intern!
  E -> (let H (content-hash E)
            Node E
            _ (set *intern-table* (intern-store (unwrap-ch H) Node (value *intern-table*)))
            Node))

(define content-eq
  A B -> (= (content-hash A) (content-hash B)))

\\ Structural sig registry (immutable after first use; 5.3)
(set *structural-sigs* [])

(define declare-structural-sig
  Sym Attrs -> (if (element? Sym (value *structural-sigs*))
                   (error "structural sig already declared for ~A" Sym)
                   (set *structural-sigs* [[Sym | Attrs] | (value *structural-sigs*)])))

(define get-structural-sig
  Sym -> (assoc Sym (value *structural-sigs*)))

(princ "store.shen loaded (Merkle hash per task-4 policy, intern, eq, sig stub).~%")