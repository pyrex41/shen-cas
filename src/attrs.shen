\\ attrs.shen - structural vs control attributes, consistency checks, explicit declaration syntax (SCUD 9.1)
\\ Clean module per design.md, sketch.md §5, plan.md Phase 2.
\\
\\ Structural attributes (immutable; part of symbol's creation-time signature;
\\   affect content canonicalization in store before hashing; never flipped):
\\     flat, orderless, one-identity
\\
\\ Control / evaluation attributes (freely mutable facts in later db):
\\     hold-all, hold-first, hold-rest, listable
\\
\\ consistent? enforces:
\\   - reject hold-all + (hold-first | hold-rest)
\\   - reject listable + hold-all (no opt-in in this phase)
\\ OneIdentity-without-unary-rule is *not* rejected here (Phase 4 analysis/warning).
\\
\\ Declaration form:
\\   (declare-symbol Sym [flat orderless])
\\   registers structural attrs (only) by calling store's declare-structural-sig stub.
\\   Control attrs are validated for consistency but not written to structural sig.
\\
\\ No evaluation, hold logic, or rule integration yet.

\\ (load "src/store.shen")  ; rely on load.shen order (store before attrs); redundant load contributes to ctor noise

\\ --- Attribute classification (symbols for clean list syntax [flat orderless ...]) ---

(define structural-attributes
  -> [(intern "flat") (intern "orderless") (intern "one-identity")])

(define control-attributes
  -> [(intern "hold-all") (intern "hold-first") (intern "hold-rest") (intern "listable")])

(define attribute?
  A -> (or (element? A (structural-attributes))
           (element? A (control-attributes))))

(define structural-attribute?
  A -> (element? A (structural-attributes)))

(define control-attribute?
  A -> (element? A (control-attributes)))

\\ --- Consistency checks (local, per-sketch §5; extensible point) ---

(define consistent?
  \\ hold-all incompatible with hold-first / hold-rest
  A Rest -> (not (or (element? (intern "hold-first") Rest)
                     (element? (intern "hold-rest") Rest)))
             where (= A (intern "hold-all"))
  \\ listable + hold-all rejected (no opt-in yet)
  A Rest -> (not (element? (intern "hold-all") Rest))
             where (= A (intern "listable"))
  \\ default: ok (flat/orderless/one-identity freely combine with each other and control except above)
  _ _ -> true)

(define consistent-attrs?
  [] -> true
  [A | AS] -> (and (attribute? A)
                   (consistent? A AS)
                   (consistent-attrs? AS)))

(define list?
  [] -> true
  [X | Xs] -> true
  X -> false)

(define attrs-filter
  _ [] -> []
  F [X | Xs] -> (if (F X) [X | (attrs-filter F Xs)] (attrs-filter F Xs)))

(define every
  _ [] -> true
  F [X | Xs] -> (and (F X) (every F Xs)))

(define valid-attrs?
  AS -> (and (list? AS)
             (every (/. A (attribute? A)) AS)
             (consistent-attrs? AS)))

\\ --- Datatypes (following sketch §5 for future sequent use; side conditions supported) ---

(datatype attribute
  __________________________
  flat : attribute;
  __________________________
  orderless : attribute;
  __________________________
  one-identity : attribute;
  __________________________
  hold-all : attribute;
  __________________________
  hold-first : attribute;
  __________________________
  hold-rest : attribute;
  __________________________
  listable : attribute; )

(datatype valid-attrs
  ________________________
  [] : valid-attrs;
  A : attribute; AS : valid-attrs;
  (consistent? A AS);
  ________________________________
  [A | AS] : valid-attrs; )

\\ --- 16f: control attributes reach the db ---
\\ Structural attrs stay in the content-hash sig (invariant 1); control attrs
\\ (hold-all/hold-first/hold-rest/listable) are asserted as datoms into *db* so the
\\ evaluator gets a Hold/Listable signal via head-attrs/holds-*?/listable? (invariant 3).

(define register-control-attrs
  Sym [] -> Sym
  Sym [A | AS] ->
    (do (if (control-attribute? A)
            (set *db* (assert-attribute (value *db*) Sym A))
            true)
        (register-control-attrs Sym AS)))

\\ --- Explicit symbol declaration (calls into store structural sig stub) ---

(define declare-symbol
  \\ Sym: the head symbol (e.g. Plus)
  \\ Attrs: list of attribute symbols e.g. [flat orderless]
  \\ Only structural attrs are passed to declare-structural-sig (immutable sig).
  \\ Full Attrs list is consistency-checked here.
  \\ Returns Sym on success; errors on inconsistency or bad input.
  Sym Attrs ->
    (if (not (list? Attrs))
        (error "declare-symbol: second arg must be a list of attributes, got ~A" Attrs)
        (if (consistent-attrs? Attrs)
            (let Struct (attrs-filter (/. A (structural-attribute? A)) Attrs)
                 _ (if (empty? Struct)
                       true
                       (declare-structural-sig Sym Struct))
                 _ (register-control-attrs Sym Attrs)
                 Ign (trap-error (warn-on-attribute-declaration Sym) (/. Err true))
                 Sym)
            (error "declare-symbol: inconsistent attributes for ~A: ~A~%  (rejected combinations: hold-all+hold-{first,rest}, listable+hold-all)" Sym Attrs))))

\\ Convenience: declare only structural attrs (sugar, still validates)
(define declare-structural
  Sym StructAttrs ->
    (if (every (/. A (structural-attribute? A)) StructAttrs)
        (declare-symbol Sym StructAttrs)
        (error "declare-structural: non-structural attrs supplied for ~A: ~A" Sym StructAttrs)))

(output "attrs.shen loaded (structural/control split + consistent? + declare-symbol via store sig).~%")