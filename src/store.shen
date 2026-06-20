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

\\ --- Portable, order-sensitive string hash (pure Shen) ---
\\ The host port's `hash` builtin is NOT a safe content-hash basis: on some ports
\\ (e.g. ShenScript) it is an order-INSENSITIVE sum of char codes, so any two
\\ strings that are permutations of each other collide (hash "Sinx" = hash "xSin").
\\ Because content-eq is hash-keyed and compound hashes are built from concatenated
\\ substrings, such collisions silently corrupt the intern table, the Orderless
\\ canonical sort, and the rule dispatch index -- making guarded calculus rules
\\ misfire. We therefore compute content hashes with a self-contained polynomial
\\ rolling hash (base 31, large prime modulus) that depends ONLY on portable
\\ string primitives (pos/tlstr/string->n) and integer +,-,*,< -- identical on
\\ every Shen port, well-distributed, and order-sensitive.
\\
\\ The modulus is taken by bounded subtraction (no float division / no floor
\\ builtin, which are not portable): after each step the accumulator is < prime,
\\ so (Acc*31 + code) < 31*prime + maxcode and at most ~31 subtractions restore it.
(define cas-hash-prime -> 1000000007)

\\ N mod prime by greedy power-of-two subtraction. After each rolling step the
\\ accumulator is < prime, so (Acc*31 + code) < 31*prime; subtracting the
\\ descending multiples 16p,8p,4p,2p,p removes it in <=5 steps (vs ~31 for plain
\\ repeated subtraction) -- still pure integer ops, no float/floor.
(define cas-sub-while
  N M -> (if (>= N M) (cas-sub-while (- N M) M) N))

(define cas-hash-mod
  N -> (let P (cas-hash-prime)
            N1 (cas-sub-while N (* 16 P))
            N2 (cas-sub-while N1 (* 8 P))
            N3 (cas-sub-while N2 (* 4 P))
            N4 (cas-sub-while N3 (* 2 P))
            (cas-sub-while N4 P)))

(define cas-str-hash
  S -> (cas-str-hash-loop S 5381))

(define cas-str-hash-loop
  "" Acc -> Acc
  S Acc -> (cas-str-hash-loop (tlstr S)
                              (cas-hash-mod (+ (* Acc 31) (string->n (pos S 0))))))

\\ --- Hash per task-4 policy (notes/syntax-verification.md), pure-Shen basis ---
(define portable-atom-string
  Tag Val -> (cn (str Tag) (if (symbol? Val) (str Val) (str Val))))

(define hash-atom
  Tag Val -> (cas-str-hash (portable-atom-string Tag Val)))

\\ comma-separated so distinct arg-hash sequences cannot concatenate to the same
\\ string (e.g. [1,23] vs [12,3] both -> "123" without a separator).
(define hash-compound-args
  [] -> ""
  [X | Xs] -> (cn (str X) (cn "," (hash-compound-args Xs))))

(define hash-compound
  H ArgHashes -> (cas-str-hash (cn (str H) (cn "|" (hash-compound-args ArgHashes)))))

(define alpha-canonicalize
  E -> E)   \\ stub (tied to binders); scope.shen redefines for Module/With alpha-renaming before hash.
            \\ Alpha-equivalent Module/With bodies therefore share content hashes.

\\ 17e: rationals get a distinct "rat" hash tag (folds N and D). make-rat collapses
\\ D=1 to [int N], so a [rat N D] hash can never collide with an [int N] hash.
(define content-hash*
  [sym S] -> [ch (hash-atom "sym" S)]
  S -> [ch (hash-atom "sym" S)] where (symbol? S)
  [int N] -> [ch (hash-atom "int" N)]
  [rat N D] -> [ch (cas-str-hash (cn "rat" (cn (str N) (cn "/" (str D)))))]
  [H | Args] -> (let Hh (content-hash* H)
                     Ah (canonical-arg-hashes H Args)
                     [ch (hash-compound (unwrap-ch Hh) (map (/. X (unwrap-ch X)) Ah))])
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
            (if (assoc-hit? Found)
                (hd (tl Found))
                (let Node Canon
                     _ (set *intern-table* (intern-store Key Node (value *intern-table*)))
                     Node))))

(define content-eq
  A B -> (= (content-hash A) (content-hash B)))

\\ Structural sig registry (immutable after first use; 5.3)
(set *structural-sigs* [])

(define assoc-hit?
  X -> (if (cons? X) (not (empty? X)) false))

(define sig-present?
  Sym -> (assoc-hit? (assoc Sym (value *structural-sigs*))))

(define declare-structural-sig
  Sym Attrs -> (if (sig-present? Sym)
                   (error "structural sig already declared for ~A" Sym)
                   (do (set *structural-sigs* [[Sym | Attrs] | (value *structural-sigs*)])
                       true)))

(define get-structural-sig
  Sym -> (assoc Sym (value *structural-sigs*)))

(define ensure-structural-sig
  Sym -> (if (sig-present? Sym)
             true
             (declare-structural-sig Sym [])))

\\ --- Structural sig helpers for canonicalization (Orderless/Flat affect hash only in Phase 1 skeleton) ---
\\ Per notes/syntax-verification.md §4 and design §5.1: sigs are immutable creation facts;
\\ content hash must be stable and db-independent. Compare via str names to avoid load-order free-var issues.
(define structural-sig-contains-name?
  Sym Name -> (let Sig (get-structural-sig Sym)
                   (if (sig-present? Sym)
                       (element? Name (map (/. A (str A)) (tl Sig)))
                       false)))

(define has-flat?
  Sym -> (structural-sig-contains-name? Sym "flat"))

(define has-orderless?
  Sym -> (structural-sig-contains-name? Sym "orderless"))

(define sym?
  [sym S] -> true where (symbol? S)
  X -> false)

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
                     (map (/. A (content-hash A)) Args))
             (if (has-orderless? S)
                 (sort-hashes Raw)
                 Raw))
        (map (/. A (content-hash A)) Args)))

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