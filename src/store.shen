\\ store.shen - content-addressed term store (Phase 1 core)
\\ Merkle content hashes + interning + O(1) equality (per notes/syntax-verification.md task 4)
\\ Hash choice: portable recursive Shen (hash ... 1000000007) after canonicalization.
\\ No basis/memo/rule-driven equality yet.
\\ Structural signatures (Orderless/Flat/OneIdentity) are immutable creation facts.
\\ Attrs canonical (flat flatten + orderless sort by content-hash) integrated into
\\ content-hash path (via canonical-arg-hashes in compound case) per SCUD 5.2/9.2 stub.

(datatype content-hash
  H : number;
  ________________
  [ch H] : content-hash;)

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

(define alpha-canonicalize
  E -> E)   \\ stub (tied to binders); scope.shen redefines for Module/With alpha-renaming before hash.
            \\ Alpha-equivalent Module/With bodies therefore share content hashes.

(define content-hash*
  [sym S] -> [ch (hash-atom "sym" S)]
  S -> [ch (hash-atom "sym" S)] where (symbol? S)
  [int N] -> [ch (hash-atom "int" N)]
  [H | Args] -> (let Hh (content-hash* H)
                     Ah (canonical-arg-hashes H Args)
                     [ch (hash-compound (unwrap-ch Hh) (map unwrap-ch Ah))])
  _ -> [ch (hash-atom "other" 0)])

(define content-hash
  E -> (content-hash* (alpha-canonicalize E)))

(define unwrap-ch
  [ch N] -> N)

\\ Canonical constructors (consult sigs for Orderless/Flat via content-hash/canonical-arg-hashes)
(define make-sym
  S -> [sym S])

(define make-int
  N -> [int N])

(define make-compound
  H Args -> [H | Args])

(define cas-intern
  E -> (let Canon (alpha-canonicalize E)
            H (content-hash* Canon)
            (intern-lookup (unwrap-ch H) (value *intern-table*))))

(define cas-intern!
  E -> (let Canon (alpha-canonicalize E)
            H (content-hash* Canon)
            Key (unwrap-ch H)
            Found (intern-lookup Key (value *intern-table*))
            (if (cons? Found)
                (hd (tl Found))   \\ return the already-interned node for this content-hash (sharing)
                (let Node Canon
                     _ (set *intern-table* (intern-store Key Node (value *intern-table*)))
                     Node))))

(define content-eq
  A B -> (= (content-hash A) (content-hash B)))

\\ Structural sig registry (immutable after first use; 5.3)
(set *structural-sigs* [])

(define declare-structural-sig
  Sym Attrs -> (if (assoc Sym (value *structural-sigs*))
                   (error "structural sig already declared for ~A" Sym)
                   (set *structural-sigs* [[Sym | Attrs] | (value *structural-sigs*)])))

(define get-structural-sig
  Sym -> (assoc Sym (value *structural-sigs*)))

\\ --- Structural sig helpers for canonicalization (Orderless/Flat affect hash only in Phase 1 skeleton) ---
\\ Per notes/syntax-verification.md §4 and design §5.1: sigs are immutable creation facts;
\\ content hash must be stable and db-independent. Compare via str names to avoid load-order free-var issues.
(define structural-sig-contains-name?
  Sym Name -> (let Sig (get-structural-sig Sym)
                   (and (cons? Sig)
                        (element? Name (map (/. A (str A)) (tl Sig))))))

(define has-flat?
  Sym -> (structural-sig-contains-name? Sym "flat"))

(define has-orderless?
  Sym -> (structural-sig-contains-name? Sym "orderless"))

(define sym?
  X -> (and (cons? X) (symbol? (hd X)) (= (str (hd X)) "sym")))

(define sym-name
  X -> (hd (tl X)) where (sym? X)
  _ -> (error "sym-name: not a sym"))

(define headed-by-sym?
  S X -> (and (cons? X)
              (let Hd (hd X)
                (and (sym? Hd) (= (sym-name Hd) S)))))

\\ Return list of content-hash values for args, with Flat inlining and Orderless sorting applied when sig present.
(define canonical-arg-hashes
  H Args ->
    (if (sym? H)
        (let S (sym-name H)
             Raw (if (has-flat? S)
                     (flatten-args-for-hash S Args)
                     (map content-hash Args))
             (if (has-orderless? S)
                 (sort-hashes Raw)
                 Raw))
        (map content-hash Args)))

(define flatten-args-for-hash
  S [] -> []
  S [A | Rest] ->
    (if (headed-by-sym? S A)
        (append (flatten-args-for-hash S (tl A))
                (flatten-args-for-hash S Rest))
        (cons (content-hash A) (flatten-args-for-hash S Rest))))

(define sort-hashes
  Hs -> (sort-hashes-by (/. Ha Hb (<= (unwrap-ch Ha) (unwrap-ch Hb))) Hs))

(define sort-hashes-by
  _ [] -> []
  Pred [H | Hs] -> (insert-by Pred H (sort-hashes-by Pred Hs)))

(define insert-by
  _ X [] -> [X]
  Pred X [Y | Ys] -> (if (Pred X Y)
                         [X Y | Ys]
                         [Y | (insert-by Pred X Ys)]))

\\ --- normal-form memo: content-hash + basis keyed (SCUD 10.2) ---
(set *normal-form-cache* [])

(define nf-cache-key
  CH BH -> [(unwrap-ch CH) BH])

(define nf-lookup
  Key -> (assoc Key (value *normal-form-cache*)))

(define nf-store!
  Key Val -> (set *normal-form-cache* (adjoin [Key Val] (value *normal-form-cache*))))

(output "store.shen loaded (Merkle hash + attrs flat/orderless canonical in content-hash path + nf memo).~%")