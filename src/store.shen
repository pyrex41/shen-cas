\\ store.shen - content-addressed term store (Phase 1 core)
\\ Merkle content hashes + interning + O(1) equality
\\ No basis/memo/rule-driven equality yet (added later).
\\ Structural signatures (for Orderless/Flat later) stubbed as immutable.

\\ Content hash representation (skeleton; replace with stable portable impl)
\\ For now: a simple structure-based "hash" that is deterministic and
\\ supports O(1) structural equality via interned identity or value compare.
\\ TODO (5.1): choose real portable hash (Shen hash + tree or string digest).

(datatype content-hash
  H : string;
  ________________
  (ch H) : content-hash;)

\\ Intern table stub: hash -> interned node (association list for skeleton)
(set *intern-table* [])

(define intern-lookup
  H Table -> (assoc H Table))

(define intern-store
  H Node Table -> (adjoin [H Node] Table))

\\ Canonical constructors (will consult structural sig later)
(define make-sym
  S -> (sym S))   \\ later: hash + intern

(define make-int
  N -> (int N))

(define make-compound
  H Args -> [H | Args])  \\ later: compute hash, canonicalize per sig, intern

\\ Public API skeleton (design §5.1 + tasks 5/5.1/5.2)
(define content-hash
  (sym S) -> (ch (cn "sym:" (str S)))
  (int N) -> (ch (cn "int:" (str N)))
  [H | Args] -> (let ArgHs (map content-hash Args)
                     (ch (cn "c:" (cn (str (content-hash H)) (str ArgHs))))))

(define intern
  E -> (let H (content-hash E)
            (intern-lookup H (value *intern-table*))))

(define intern!
  E -> (let H (content-hash E)
            Node E   \\ simplified: the expr itself for skeleton
            _ (set *intern-table* (intern-store H Node (value *intern-table*)))
            Node))

(define content-eq
  A B -> (= (content-hash A) (content-hash B)))   \\ O(1) after real hash + intern

\\ Structural signature registry stub (5.3 later; immutable after first use)
(set *structural-sigs* [])

(define declare-structural-sig
  Sym Attrs -> (if (element? Sym (value *structural-sigs*))
                   (error "structural sig already declared for ~A" Sym)
                   (set *structural-sigs* [[Sym | Attrs] | (value *structural-sigs*)])))

(define get-structural-sig
  Sym -> (assoc Sym (value *structural-sigs*)))

(princ "store.shen skeleton loaded (hash/intern/eq + sig stub).~%")