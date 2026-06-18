\\ attrs.shen - structural vs control attributes + consistency (Phase 2)
\\ Structural attrs (Flat, Orderless, OneIdentity) are immutable symbol-creation facts
\\ (see notes/syntax-verification.md task 4 + design §5.1).
\\ They affect store canonicalization before hashing.
\\ Control attrs (Hold*) are mutable db facts.

\\ Attribute datatype
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

\\ valid-attrs with consistency
(datatype valid-attrs
  ________________________
  (attrs []) : valid-attrs;

  A : attribute;
  AS : valid-attrs;
  (consistent? A AS);
  __________________________
  (attrs [A | AS]) : valid-attrs; )

(define consistent?
  hold-all (attrs AS) -> (not (or (element? hold-first AS) (element? hold-rest AS)))
  listable (attrs AS) -> (not (element? hold-all AS))   \\ requires explicit opt-in if wanted
  _ _ -> true)

\\ Declaration (structural ones are immutable)
(set *declared-attrs* [])

(define declare-attrs
  Sym AttrList ->
    (let VA (attrs AttrList)
         (if (valid-attrs? VA)   \\ simplistic
             (do (set *declared-attrs* [[Sym | AttrList] | (value *declared-attrs*)])
                 (if (or (element? flat AttrList) (element? orderless AttrList) (element? one-identity AttrList))
                     (declare-structural-sig Sym AttrList)   \\ calls into store
                     true))
             (error "inconsistent attrs for ~A" Sym))))

(define get-attrs
  Sym -> (assoc Sym (value *declared-attrs*)))

(princ "attrs.shen (structural immutable + consistency) loaded.~%")