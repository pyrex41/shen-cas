Toward a Statically Checked Term Rewriting Kernel in Shen
A design sketch for a Mathematica-inspired symbolic evaluator with extensible type-theoretic guarantees. 
A basis for future Computer Algebra System implementation.
license:public domain CC0
⸻
Abstract
Mathematica's evaluator is a term rewriting engine of unusual power and unusual fragility. Its power comes from a small set of primitives — expressions, pattern matching with sequence variables, rewriting to a fixed point, and attribute-controlled evaluation order — that compose to yield a general-purpose symbolic computation system. Its fragility comes from the fact that none of the invariants governing these primitives are checked statically: malformed rules, ill-typed attribute combinations, and scoping violations surface only at runtime, often far from their origin.
We sketch the design of a minimal Mathematica-inspired rewriting kernel implemented in Shen, a Lisp dialect whose sequent calculus type system allows the programmer to define domain-specific typing rules. The key insight is that Shen's extensible type checker can enforce invariants on rewrite rules, pattern well-formedness, attribute consistency, and evaluation contracts at definition time rather than at evaluation time, without sacrificing the homoiconicity and metaprogrammatic flexibility that make Lisp the natural host for a term rewriting system.
This paper is a design sketch, not a finished implementation. We focus on architecture, the type rule definitions that constitute the core intellectual contribution, and the places where Shen's specific capabilities resolve problems that are awkward or impossible in fixed-type-system languages.
⸻
1. Why Shen
1.1 The Representation Problem
A Mathematica expression is a tree: an atom (symbol, integer, string, real) or a compound node consisting of a head expression and an ordered list of argument expressions. In Mathematica's own notation, every compound expression has the form h[a1, a2, ..., an]. This is, up to syntax, an S-expression: (h a1 a2 ... an).
In Haskell or OCaml, this structure requires an algebraic data type definition:
type expr = Sym of string | Int of int | Real of float | Compound of expr * expr list
In any Lisp, including Shen, the representation is free. Expressions are the host language's data. (f a b c) is simultaneously valid Shen data and a representation of the Mathematica expression f[a, b, c]. No marshaling, no ADT boilerplate, no impedance mismatch between the language you write the evaluator in and the language whose expressions you are evaluating.
This is not a cosmetic advantage. A term rewriting system is fundamentally a program that manipulates programs. Homoiconicity means the evaluator, the rules it applies, and the expressions it transforms are all the same kind of thing. Shen macros can transform rule definitions at read time. The pattern matcher can be written in Shen's own pattern language. The evaluator manipulates the same lists the programmer sees. This collapses an entire layer of translation that, in ML-family languages, must be written and maintained explicitly.
1.2 The Typing Problem
Lisp's traditional weakness is the absence of static checking. In a complex evaluator with interacting subsystems — pattern matching, attributes, scoping, evaluation order — invariant violations produce bugs that are difficult to trace. A rule whose left-hand side is not a well-formed pattern, an attribute combination that is contradictory (HoldAll and Listable on a symbol whose definition assumes evaluated arguments), a Module binding list that contains a non-symbol — these are all errors that a type system could catch, if the type system knew about the domain.
Haskell's and OCaml's type systems do not know about the domain. They can enforce that an expression tree is structurally valid (the expr ADT), but they cannot enforce that a rewrite rule's left-hand side is a pattern rather than an arbitrary expression, or that a Flat symbol's matching semantics are consistent with its definition's arity assumptions. Those invariants live in a different logical layer than the host language's type system can express.
Shen's type system is a sequent calculus in which the programmer writes typing rules as logical propositions. The type checker is not fixed; it is a Prolog-like inference engine that applies user-defined rules. This means the invariants governing a Mathematica-style evaluator — well-formedness of patterns, consistency of attribute sets, scoping correctness — can be expressed as typing rules and checked at definition time.
1.3 The Matching Problem
Shen has a built-in Prolog subsystem accessible via (prolog?) and native pattern matching on lists and tuples. Mathematica's pattern matching involves structural unification with sequence variables (BlankSequence, matching a variable number of arguments), conditional patterns (PatternTest, Condition), and attribute-modified matching (Orderless requires matching modulo permutations; Flat requires matching modulo associativity). The Prolog subsystem provides backtracking search, which is essential for sequence variable matching and for the combinatorial exploration required by Orderless and Flat. No other Lisp variant ships with this capability built in.
⸻
2. Expression Representation
We represent expressions as tagged lists. Atoms carry a type tag; compounds are simply lists whose first element is the head.
\\ Atoms
(sym X)    \\ symbol atom, e.g. (sym Plus)
(int N)    \\ integer atom
(real R)   \\ real atom
(str S)    \\ string atom
\\ Compound expressions
\\ f[a, b, c] is represented as ((sym f) (int 1) (int 2) (int 3))
\\ Plus[x, y] is ((sym Plus) (sym x) (sym y))
A compound expression is a list [Head | Args] where Head is itself an expression and Args is a list of expressions. This means f[g[x]][y] is ((sym f) ((sym g) (sym x))) (sym y)) — head application composes naturally.
We define a Shen type for this:
(datatype expr
    X : symbol;
    _______________
    (sym X) : expr;
    N : number;
    _______________
    (int N) : expr;
    R : number;
    ________________
    (real R) : expr;
    S : string;
    _______________
    (str S) : expr;
    H : expr; Args : (list expr);
    ______________________________
    [H | Args] : expr;
)
This gives us static guarantees that anything typed as expr is structurally valid. Malformed trees like [(int 3) | not-a-list] are caught at definition time.
⸻
3. Patterns and Pattern Well-Formedness
Mathematica patterns are themselves expressions augmented with special heads: Blank, BlankSequence, BlankNullSequence, Pattern (for named bindings), Condition, PatternTest, and Alternatives. A critical invariant is that patterns are not arbitrary expressions — they have structural constraints:
A Pattern node must bind a symbol name to a sub-pattern, not an arbitrary expression to another arbitrary expression.
A Condition must wrap a pattern and a boolean-valued test expression.
A BlankSequence or BlankNullSequence can only appear at the argument level of a compound pattern, not as a standalone expression or as the head.
A PatternTest must contain a pattern and a function (a symbol or lambda), not a general expression.
In standard Mathematica, none of these are checked. Writing Pattern[3, 5] is legal syntax; it simply fails silently or matches incorrectly at runtime.
In Shen, we define a separate type pattern with rules that enforce well-formedness:
(datatype pattern
    \\ Any expression is trivially a literal pattern (matches itself)
    E : expr;
    _____________
    E : pattern;
    \\ Blank: matches any single expression
    ____________________
    (blank) : pattern;
    \\ Typed blank: matches any expression with the given head
    H : symbol;
    _______________________
    (blank H) : pattern;
    \\ Named pattern: binds a symbol to a sub-pattern
    Name : symbol; P : pattern;
    ____________________________
    (named Name P) : pattern;
    \\ Blank sequence: matches one or more expressions
    \\ Only valid in argument position (enforced separately)
    _________________________
    (blank-seq) : seq-pattern;
    \\ Blank null sequence: matches zero or more
    ______________________________
    (blank-null-seq) : seq-pattern;
    \\ Condition: pattern with a boolean guard
    P : pattern; Test : expr;
    ______________________________________
    (condition P Test) : pattern;
    \\ PatternTest: pattern with a predicate function
    P : pattern; F : symbol;
    _________________________________
    (ptest P F) : pattern;
    \\ Alternatives
    P1 : pattern; P2 : pattern;
    ________________________________
    (alt P1 P2) : pattern;
)
The key point is the distinction between pattern and seq-pattern. A seq-pattern (sequence pattern) can only appear inside the argument list of a compound pattern, not at the top level or as a head. We enforce this with a separate typing rule for compound patterns:
(datatype compound-pattern
    H : pattern; Args : (list pat-or-seq);
    _______________________________________
    [H | Args] : pattern;
    P : pattern;
    ________________
    P : pat-or-seq;
    S : seq-pattern;
    ________________
    S : pat-or-seq;
)
This means (named x (blank-seq)) is a type error — you cannot bind a name to a sequence pattern outside an argument list — which catches a real class of bugs that Mathematica silently accepts.
⸻
4. Rewrite Rules and Rule Validation
A rewrite rule is a pair of a pattern (left-hand side) and an expression (right-hand side). The fundamental invariant is that every named binding in the left-hand side pattern is available in the right-hand side, and the right-hand side does not reference names that the left-hand side does not bind.
(datatype rewrite-rule
    LHS : pattern;
    RHS : expr;
    (bindings-cover LHS RHS);
    _________________________
    (rule LHS RHS) : checked-rule;
)
The predicate (bindings-cover LHS RHS) is a type-level function that extracts the set of named bindings from LHS and verifies that every free symbol in RHS either appears in that set or is a globally defined symbol. This is expressible in Shen's sequent calculus because the type checker can call Shen functions as side conditions.
We implement the binding extraction:
(define extract-bindings
    \\ From a named pattern, collect the name
    (named Name _) -> [Name]
    \\ Recurse into compound patterns
    [H | Args] -> (append (extract-bindings H)
                          (mapcan (fn extract-bindings) Args))
    \\ Everything else binds nothing
    _ -> [])
And the coverage check:
(define free-symbols
    \\ A symbol reference in the RHS
    (sym S) -> [S]
    \\ Recurse into compound expressions
    [H | Args] -> (append (free-symbols H)
                          (mapcan (fn free-symbols) Args))
    _ -> [])
(define bindings-cover?
    LHS RHS -> (let Bound (extract-bindings LHS)
                    Free  (free-symbols RHS)
                    (subset? Free (append Bound (global-symbols)))))
The critical design decision is that bindings-cover is invoked by the type checker, not by a runtime validation pass. A rule definition with an unbound variable in the RHS is a type error, caught at the moment the rule is defined.
⸻
5. Attributes and Attribute Consistency
Each symbol in the system carries a set of attributes that modify evaluation and matching behavior. The attributes interact in ways that create constraints:
Flat and Orderless together imply that matching must consider all partitions of the argument list into groups, in all orderings. This is well-defined but combinatorially expensive. A symbol marked Flat + Orderless whose rules have more than a small number of sequence patterns will exhibit factorial blowup. We can warn about this statically.
HoldAll suppresses argument evaluation. A rule on a HoldAll symbol whose right-hand side calls evaluate on its arguments explicitly is not wrong, but it is a code smell — usually the programmer forgot the attribute or forgot to remove it. We can flag this.
Listable automatically threads a function over List arguments. If a symbol is both Listable and HoldAll, the threading happens before the hold takes effect in Mathematica, which is surprising. We can require explicit opt-in to this combination.
OneIdentity means f[x] is equivalent to x for pattern matching purposes. If a symbol has OneIdentity but no rules that match single-argument forms, the attribute has no effect and may indicate a mistake.
We encode these as a type for attribute sets with consistency checking:
(datatype attribute-set
    \\ An empty attribute set is valid
    ________________________
    (attrs []) : valid-attrs;
    \\ Adding an attribute to a valid set, if consistent
    A : attribute;
    AS : valid-attrs;
    (consistent? A AS);
    __________________________
    (attrs [A | AS]) : valid-attrs;
)
(datatype attribute
    __________________________
    hold-all : attribute;
    __________________________
    hold-first : attribute;
    __________________________
    hold-rest : attribute;
    __________________________
    flat : attribute;
    __________________________
    orderless : attribute;
    __________________________
    listable : attribute;
    __________________________
    one-identity : attribute;
)
The consistent? predicate encodes the constraint rules:
(define consistent?
    \\ HoldAll and HoldFirst/HoldRest are redundant
    hold-all (attrs AS) -> (not (or (element? hold-first AS)
                                    (element? hold-rest AS)))
    \\ Listable + HoldAll requires explicit acknowledgment
    listable (attrs AS) -> (not (element? hold-all AS))
    \\ Default: any attribute is consistent with any set
    _ _ -> true)
When a programmer writes (set-attributes Plus [flat orderless]), the type checker verifies that [flat orderless] is a valid-attrs before the definition is accepted.
⸻
6. The Symbol Table
The symbol table maps symbol names to their definitions: attribute sets, and ordered lists of rewrite rules categorized by kind.
(datatype symbol-entry
    OV : (list checked-rule);    \\ OwnValues
    DV : (list checked-rule);    \\ DownValues
    UV : (list checked-rule);    \\ UpValues
    AT : valid-attrs;
    __________________________________________
    (entry OV DV UV AT) : symbol-entry;
)
Because every component is independently typed — rules are checked-rule (pattern well-formedness and binding coverage verified), attributes are valid-attrs (consistency verified) — a symbol-entry is a compound guarantee: it is impossible to register an ill-formed rule or an inconsistent attribute set.
The global symbol table is a mutable association list:
(set *symbol-table* [])
(define register-symbol
    Name Entry -> (set *symbol-table*
                       [(Name Entry) | (value *symbol-table*)]))
Shen's set/value mechanism provides the mutable global state that a Mathematica-style evaluator inherently requires. Unlike Haskell, we do not need to thread state monads; unlike untyped Lisps, the entries we store are statically guaranteed to be well-formed.
⸻
7. The Pattern Matcher
The matcher takes a pattern and an expression and returns either a substitution (a list of name-expression bindings) or failure. Sequence patterns require backtracking over all possible ways to split the argument list.
7.1 Core Matching
(define match
    \\ Blank matches anything
    (blank) E -> (some [])
    \\ Typed blank: head must match
    (blank H) [[(sym H) | _] | _] -> (some [])
    (blank H) _ -> none
    \\ Named pattern: match the sub-pattern, add binding
    (named Name P) E -> (let R (match P E)
                             (if (some? R)
                                 (some [(Name E) | (unwrap R)])
                                 none))
    \\ Literal: expression must be equal
    E E -> (some [])
    \\ Compound: match head and arguments
    [PH | PArgs] [EH | EArgs] -> (match-compound PH PArgs EH EArgs)
    \\ Condition: match pattern, then check guard
    (condition P Test) E -> (let R (match P E)
                                (if (and (some? R)
                                         (eval-to-true? (substitute (unwrap R) Test)))
                                    R
                                    none))
    \\ Default: no match
    _ _ -> none)
7.2 Sequence Matching via Shen's Prolog Subsystem
The hardest part of Mathematica's pattern matching is BlankSequence and BlankNullSequence, which match variable-length subsequences of an argument list. This requires nondeterministic search over all ways to partition the argument list among the pattern elements.
Shen's (prolog?) form gives us backtracking search directly:
(define match-args-with-sequences
    \\ Use Shen's Prolog subsystem for nondeterministic splitting
    PatArgs ExprArgs ->
        (prolog?
            (match-arg-list PatArgs ExprArgs Bindings)
            (return Bindings)))
(defprolog match-arg-list
    \\ Base case: empty pattern matches empty args
    [] [] Bindings <-- (return (some Bindings));
    \\ Sequence pattern: try all splits
    [(blank-seq) | PRest] EArgs Bindings <--
        (split EArgs Front Back)
        (when (not (= Front [])))   \\ at least one element
        (match-arg-list PRest Back Bindings2)
        (return (some (append Bindings Bindings2)));
    \\ Null sequence: same but allows empty Front
    [(blank-null-seq) | PRest] EArgs Bindings <--
        (split EArgs Front Back)
        (match-arg-list PRest Back Bindings2)
        (return (some (append Bindings Bindings2)));
    \\ Named sequence: bind the name to the matched subsequence
    [(named Name (blank-seq)) | PRest] EArgs Bindings <--
        (split EArgs Front Back)
        (when (not (= Front [])))
        (match-arg-list PRest Back Bindings2)
        (return (some [(Name Front) | (append Bindings Bindings2)]));
    \\ Normal pattern element
    [P | PRest] [E | ERest] Bindings <--
        (is Result (match P E))
        (when (some? Result))
        (match-arg-list PRest ERest
            (append Bindings (unwrap Result)));
)
\\ Prolog predicate to split a list at all possible positions
(defprolog split
    L [] L <--;
    [X | Rest] [X | Front] Back <-- (split Rest Front Back);
)
This is where Shen's unique combination of features pays off most dramatically. The same logic in Haskell would require explicit list monad or LogicT transformer usage. In OCaml, manual continuation-passing or a backtracking monad. In Prolog, the backtracking is free but the typed structure is missing. Shen gives us both: typed patterns flowing into a Prolog-backed search that backtracks over sequence splits.
7.3 Orderless Matching
For symbols with the Orderless attribute, matching must consider all permutations of the argument list. We implement this as a wrapper that generates permutations lazily via the Prolog subsystem:
(define match-orderless
    PatArgs ExprArgs ->
        (prolog?
            (permutation ExprArgs Perm)
            (is Result (match-args-with-sequences PatArgs Perm))
            (when (some? Result))
            (return Result)))
(defprolog permutation
    [] [] <--;
    List [X | Perm] <--
        (select X List Rest)
        (permutation Rest Perm);
)
(defprolog select
    X [X | Rest] Rest <--;
    X [Y | Rest] [Y | Rest2] <-- (select X Rest Rest2);
)
7.4 Flat Matching
Flat (associativity) means that f[f[a, b], c] and f[a, f[b, c]] and f[a, b, c] are all equivalent for matching purposes. Before matching a Flat symbol, we normalize by flattening all nested applications of the same head:
(define flatten-flat
    Head [Head | Args] ->
        (mapcan (fn (flatten-flat Head)) Args)
    _ E -> [E])
The combination of Flat + Orderless + sequence patterns creates a search space that is factorial in the argument count. The type system cannot prevent this blowup, but it can warn at definition time: if a symbol is Flat + Orderless and a rule on it contains more than two sequence patterns, we emit a static warning about potential performance pathology.
⸻
8. The Evaluator
The evaluator is the fixed-point rewriting loop. It takes an expression, applies all applicable transformations (respecting attributes), and repeats until no rule fires.
(define evaluate
    \\ Atom: check OwnValues
    (sym S) -> (let Entry (lookup-symbol S)
                    (if (empty? (own-values Entry))
                        (sym S)
                        (apply-first-matching (own-values Entry) (sym S))))
    \\ Other atoms: self-evaluating
    (int N) -> (int N)
    (real R) -> (real R)
    (str S) -> (str S)
    \\ Compound expression
    [Head | Args] ->
        (let EHead (evaluate Head)           \\ evaluate the head
             Attrs (get-attributes EHead)    \\ look up attributes
             EArgs (eval-args Attrs Args)    \\ evaluate args per Hold attrs
             Flat  (if (has? flat Attrs)
                       (flatten-flat EHead EArgs)
                       EArgs)
             Sorted (if (has? orderless Attrs)
                        (sort-canonical Flat)
                        Flat)
             Threaded (if (has? listable Attrs)
                          (thread-over-lists EHead Sorted)
                          [EHead | Sorted])
             \\ Apply rules in priority order
             (try-rules Threaded)))
(define eval-args
    Attrs Args ->
        (map-indexed
            (/. I A
                (if (held? Attrs I) A (evaluate A)))
            Args))
(define held?
    Attrs _ -> true   where (has? hold-all Attrs)
    Attrs 0 -> true   where (has? hold-first Attrs)
    Attrs I -> true   where (and (> I 0) (has? hold-rest Attrs))
    _ _ -> false)
(define try-rules
    Expr ->
        (let Result (try-down-values Expr)
             (if (some? Result)
                 (evaluate (unwrap Result))    \\ re-evaluate: fixed point
                 (let Result2 (try-up-values Expr)
                      (if (some? Result2)
                          (evaluate (unwrap Result2))
                          Expr)))))              \\ no rule fired: return as-is
The evaluator's structure directly mirrors Mathematica's documented evaluation sequence: evaluate head, evaluate arguments (respecting holds), flatten, sort, thread, then try rules. The evaluate call on the result of a successful rule application is what creates the fixed-point loop.
⸻
9. Scoping
9.1 Module (Lexical Scoping via Gensym)
Module creates fresh symbols by appending a unique counter. It is implemented as a rule with HoldAll that rewrites the body before the normal evaluator sees it.
(set *gensym-counter* 0)
(define gensym
    S -> (let N (value *gensym-counter*)
              _ (set *gensym-counter* (+ N 1))
              (intern (cn (str S) (cn "$" (str N))))))
(define eval-module
    Vars Body ->
        (let Bindings (map (/. V (@ V (gensym V))) Vars)
             (evaluate (substitute-all Bindings Body))))
9.2 Block (Dynamic Scoping)
Block temporarily replaces the OwnValues of symbols and restores them on exit. This is inherently effectful and cannot be typed away, but we can at least enforce that the binding list contains only symbols:
(datatype block-binding
    S : symbol; V : expr;
    ______________________
    (block-bind S V) : block-binding;
)
(datatype block-form
    Binds : (list block-binding);
    Body : expr;
    ______________________________________
    (block Binds Body) : checked-block;
)
A Block with a non-symbol in the binding position — (block [(block-bind 3 x)] body) — is a type error.
⸻
10. Typing the Evaluation Contract
Beyond validating individual rules and attributes, we can use Shen's type system to express invariants about the evaluator itself.
10.1 Idempotence of Evaluation
A correctly implemented evaluator should be idempotent on its output: evaluate(evaluate(e)) = evaluate(e) for all expressions e. We cannot prove this in general within Shen's type system (it is undecidable for arbitrary rule sets), but we can encode it as a testable contract:
(define check-idempotence
    E -> (let R1 (evaluate E)
              R2 (evaluate R1)
              (if (= R1 R2)
                  true
                  (do (output "Idempotence violation: ~A -> ~A -> ~A~%" E R1 R2)
                      false))))
This is a runtime check, but it can be integrated into a test harness that runs automatically when new rules are registered.
10.2 Termination Heuristics
Mathematica's evaluator does not guarantee termination (the rule set can encode arbitrary computation). However, certain rule patterns are known to be non-terminating: a rule whose right-hand side contains the left-hand side as a subexpression, without a reducing measure, will loop. We can check for this statically:
(define contains-subexpr?
    E E -> true
    _ (sym _) -> false
    _ (int _) -> false
    E [_ | Args] -> (some? (filter (/. A (contains-subexpr? E A)) Args))
    _ _ -> false)
(define check-obvious-loop
    (rule LHS RHS) -> (if (contains-subexpr? LHS RHS)
                           (output "Warning: RHS contains LHS as subexpr~%")
                           ok))
This is a heuristic (it catches f[x_] := f[x] + 1 but not f[x_] := g[x] with g[x_] := f[x]), but even heuristic static warnings are more than Mathematica provides.
⸻
11. Bootstrapping: From Kernel to System
The kernel described above — expressions, patterns, matching, rules, attributes, evaluation, scoping — is approximately 500–800 lines of Shen. From this kernel, we bootstrap the rest:
11.1 Arithmetic
Arithmetic is a set of rules on the symbols Plus, Times, Power, etc., with Flat + Orderless attributes on Plus and Times:
(register-rule Plus
    (rule [(named x (blank (int))) (named y (blank (int)))]
          (int (+ x y))))
(set-attributes Plus [flat orderless])
11.2 Simplification
Algebraic simplification is a larger rule set. For example:
\\ x + 0 -> x
(register-rule Plus
    (rule [(named x (blank)) (int 0)]
          x))
\\ x * 1 -> x
(register-rule Times
    (rule [(named x (blank)) (int 1)]
          x))
\\ x * 0 -> 0
(register-rule Times
    (rule [(named x (blank)) (int 0)]
          (int 0)))
Because Plus is Orderless, the rule x + 0 -> x automatically handles 0 + x without a separate rule.
11.3 Control Flow
If, CompoundExpression, and other control structures are symbols with HoldAll or HoldRest and special evaluation rules:
(set-attributes If [hold-rest])
(register-rule If
    (rule [(sym True) (named then (blank)) (named else (blank))]
          then))
(register-rule If
    (rule [(sym False) (named then (blank)) (named else (blank))]
          else))
The condition is evaluated (it is not held), but the branches are held until one is selected.
⸻
12. What the Type System Buys Us
To summarize concretely what Shen's extensible type checking provides that no fixed-type-system language can:
Caught at definition time (not runtime):
Malformed patterns: Pattern[3, 5], sequence patterns in head position, conditions with non-boolean tests.
Unbound variables in rule right-hand sides.
Inconsistent attribute combinations: HoldAll + HoldFirst, Listable + HoldAll without opt-in.
Invalid scoping forms: Block with non-symbols in binding positions, Module with non-symbol variable lists.
Symbol table entries with ill-typed components.
Warned at definition time (heuristic):
Rules whose RHS contains the LHS (potential non-termination).
Flat + Orderless symbols with many sequence patterns (performance pathology).
OneIdentity on symbols with no single-argument rules.
Not caught (inherent limitations):
Semantic correctness of rules (does f[x_] := x^2 compute what you want?).
Termination in general.
Confluence (do different evaluation orders produce the same result?).
Items 1–8 constitute a significant fraction of the bugs encountered in real Mathematica programming. Moving them from "mysterious runtime failure" to "definition rejected at load time" is a qualitative improvement in the development experience.
⸻
13. Comparison with Alternative Approaches
Haskell with GADTs or Type Families
One could attempt to encode similar invariants in Haskell using GADTs to distinguish patterns from expressions, or type families to compute the set of bound variables in a pattern. This is possible in principle but painful in practice: the type-level programming required is complex, fragile, and produces error messages that are difficult to interpret. More fundamentally, Haskell's type system is fixed — you cannot add new typing rules without modifying the compiler. In Shen, adding a new invariant (for instance, a domain-specific check on a new attribute) is adding a new datatype rule, not modifying the type checker itself.
OCaml with Modular Implicits or Effects
OCaml's module system can enforce some interface-level invariants (a symbol table module that only accepts well-formed entries), but cannot express intra-expression constraints like binding coverage or attribute consistency. The recently proposed modular implicits and algebraic effects systems do not change this fundamental limitation.
Typed Racket
Typed Racket offers gradual typing over a Lisp, but its type system is fixed (occurrence typing, union types, refinement types). It cannot express the domain-specific sequent calculus rules that Shen allows. It would catch type-level errors on the expression ADT but not pattern well-formedness or attribute consistency.
Prolog with Constraint Handling Rules
CHR (Constraint Handling Rules) over Prolog could express attribute consistency checks as constraints, and Prolog's unification handles pattern matching. However, CHR constraints are runtime, not static, and Prolog lacks the type discipline to prevent malformed terms from being constructed in the first place. The checking would be more powerful than untyped Lisp but weaker than Shen's static sequent calculus.
⸻
14. Implementation Roadmap
An MVP implementation proceeds in phases:
Phase 1: Core (est. 300 lines of Shen). Expression representation, the expr and pattern datatypes with typing rules, the core matcher without sequence patterns, substitution, and the evaluator loop without attributes. At this stage we have a simple first-order term rewriting system with static checking of pattern and rule well-formedness.
Phase 2: Sequences and Attributes (est. 400 lines). Sequence patterns via the Prolog subsystem, attribute sets with consistency checking, attribute-aware evaluation (hold, flatten, sort, thread). The full matcher with Orderless and Flat support.
Phase 3: Scoping (est. 150 lines). Module, Block, With, and their typing rules.
Phase 4: Bootstrap (est. 500+ lines of rules). Arithmetic, algebraic simplification, control flow, list operations — all defined as checked rewrite rules in the language itself.
Phase 5: Surface Syntax (est. 300 lines). A parser/reader macro layer that translates infix notation (f[x_, y_] := x + y) to the internal S-expression representation. This is cosmetic but essential for usability.
Total estimated kernel size: approximately 1,200 lines of Shen for the typed core, plus an open-ended library of rules.
⸻
15. Conclusion
The conventional wisdom is that Mathematica-style term rewriting systems are best implemented in ML-family languages for their algebraic data types and pattern matching, or in Prolog for its unification engine. We have argued that Shen occupies a unique position in this design space: it provides homoiconicity (the representation is free), a Prolog subsystem (backtracking search for sequence matching is built in), and an extensible sequent calculus type system (domain-specific invariants are statically checkable).
The extensible type system is the key differentiator. The invariants that govern a Mathematica-style evaluator — pattern well-formedness, binding coverage, attribute consistency, scoping correctness — do not fit naturally into any fixed type system. They are domain-specific logical propositions about the relationships between patterns, expressions, symbols, and attributes. Shen's sequent calculus lets us express these propositions as typing rules, checked at definition time, without modifying the language's type checker.
The result is a kernel that is simultaneously a Lisp (flexible, homoiconic, rapid to prototype), a typed language (ill-formed rules and inconsistent configurations are caught statically), and a logic programming system (backtracking search for the hard parts of pattern matching). No other existing language provides all three, and a Mathematica-style evaluator needs all three.
⸻
References
Tarver, M. (2015). The Book of Shen. 3rd edition.
Wolfram, S. (2002). A New Kind of Science. Wolfram Media. Chapter 12 on evaluation.
Baader, F. and Nipkow, T. (1998). Term Rewriting and All That. Cambridge University Press.
Kluge, W. (2005). Abstract Computing Machines. Springer. Chapter on term rewriting systems.
Wolfram Language Documentation. Standard Evaluation Sequence. reference.wolfram.com.
Tarver, M. (2020). Shen Language Specification. shenlanguage.org.


