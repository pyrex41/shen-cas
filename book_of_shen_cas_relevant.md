# Relevant Excerpts from *The Book of Shen*, 4th Edition (Tarver, 2025)
## For shen-cas: Statically Checked Term Rewriting Kernel & CAS Foundation

**Source:** The_Book_of_Shen_4th_Edition.md (OCR from shenlanguage.org/TBoS, 524 pages).  
**Scope note:** Curated excerpts focused on material relevant to the shen-cas design (statically checked rewriting, datatypes via sequent calculus, algebraic simplification for CAS, Prolog-backed matching, YACC for surface syntax/reader, priority rewrite systems, type safety for evaluators).  

**Starting anchor:** Page 288 (section 22.3 Montague Grammars in Ch. 22 Typed Shen YACC) + immediately preceding core CAS material from 21.4 Algebraic Simplification (p. 274) because it is the book's explicit discussion of building computer algebra simplification on Shen's type system. Earlier foundational material (e.g., 2.7 Priority Rewrite Systems) is referenced in design docs but omitted here per "starting page 288" guidance except where essential context.

**Caveats:** OCR artifacts present (e.g., "protog" for "prolog", broken symbols, spacing). Re-verify all `(datatype ...)` and `(defcc ...)` syntax directly against a printed/PDF copy of the 4th edition before implementation (as flagged in design.md §10 and §3).

---

## 21.4 Algebraic Simplification (p. 274)

> Simplification is a high school algebra technique for reducing the complexity of algebraic expressions and is a basic technique of equational reasoning in more advanced algebra. Examples are the simplification of x + 5 - 3 to x+2 and x/x to x. **Computer algebra programs, of which there are many, need to perform these simplifications with accuracy.**

What does ‘accuracy’ mean here? There are two requirements; a weak syntactic requirement and a stronger semantic requirement. The weak syntactic requirement is that the algebra program output only syntactically legal algebraic expressions. The semantic requirement is that the simplifications should preserve the meaning of the expressions reduced. ...

These two requirements naturally issue in an approach based on semi-abstract datatypes. The syntactic approach is best realised in a concrete datatype, whereas the semantic requirement involves building an abstract datatype which operates over a concrete one.

...

To begin with the concrete syntax, we suppose that algebraic expressions (exprs) are regimented into fully parenthesised form. Here are the type rules.

```
274

<!-- sheet 289 -->

(datatype expr

(number? X)- verified >> X= number.

P.: verified, Q : verified >> R:

(end P Q) verified >> R:

number:

X expr:

if (not (element? X [-* /+))

symbol:

X expr:

(fr. Op) : (number —> number > number):

X: expr: ¥ expr.

1X Op Y]: expr)
```

Examples of exprs are [56 + [x - 7]] and [-245 * 67] - [x* yl]. exprs are a concrete type with respect to our algebra program. ...

We also assert that if an expression is an ok expression then it is an expression.

```
X:okexpr
X= expr)
```

...

Any semantically valid operation should also be syntactically valid, so the first step is to prove arithmetic simplification is a syntactically valid operation...

```
(define arith
{expr —> expr}
[X Op Y]-> (in Op) XY) where (and (number? X) (number? ¥))
X>X)
```

We continue by declaring arith to be (semantically) valid.

```
(narith): vai:
```

...

walk simply walks through all the subexpressions of an expression applying the function throughout. ...

```
(define walk
{valid —> expr —> ok-expr}
F DX Op ¥]~> (F (walk F X) Op (walk F Y)])
FX>(FX)
```

...

```
(define thrash
{expr —> valid —> ok-expr}
XF-> (let ¥ (FX)
(if(-=XY) ¥ (thrash Y F))))
```

...

```
(define simplify
{valid => expr —> ok-expr}

FX-> (thrash X (walk F)))
```

Here is a test

```
(10+) (simply (fn arith) + [12* (5-3)

Ik +24] : ok-expr
```

What benefits are there in building an algebra program this way? First, by defining the type of expressions as a concrete type we ensure that we can never output syntactic gibberish. But second, by rising above concrete types to define ok expressions as the result of applying meaning preserving operations we can also verify that our algebra program will perform only semantically legal transformations.

...

---

## Starting Page 288: 22.3 Montague Grammars (Ch. 22 Typed Shen YACC)

Montague grammars were developed for English in a series of three important papers by the logician Richard Montague. They are in form, context free grammars of the type commonly met but they are distinguished by their treatment of semantics. Montague believed that English was not importantly different from the formal languages of logic and that it was possible to parse English into logic without loss of important meaning.

> There is in my opinion no important theoretical difference between natural languages and the artificial languages of logicians; indeed, I consider it possible to comprehend the syntax and semantics of both kinds of language within a single natural and mathematically precise theory. ...

Montague’s ‘natural and mathematically precise’ notation was an extension of first-order logic which incorporated modal concepts like possible worlds and also moments of time. Unusually for his period, Montague's papers also used lambda abstractions.

Montague’s work is a very nice illustration of working with typed Shen YACC because the underlying type theory is simple but the ramifications are profound. We begin with the type theory before going on to the construction of grammars themselves. Our focus is a proper subset of English and for this subset the resources of function-free first-order logic without equality (FOL-) are sufficient.

```
288

<!-- sheet 303 -->

This will be the object language into which compilation from English will proceed.
```

The most fundamental concept of the type theory is a term and the type of all terms is t. For us a term is a symbol that is not an element of [~ v & => <=> e! al. This latter list is the list of logical constants of FOL.

```
(datatype t

if not (element? t[~ v & => <=> el all))

T= symbol:

Tt
```

We also have occasion later to want to generate fresh terms at will so we add this axiom.

```
(gensym v) -t:)
```

The other fundamental concept is that of a formula of FOL-. This is encapsulated in the rules for a type f

```
(datatype f

Fit T: (ist t):

Ft
```

The first R rule says that a formula is a non-empty list of terms. This corresponds to an atomic formula; [likes Bill Mary] would be an example.

The L rules are more complex because of the restrictions on what can count as a term. ...

(Details of case analysis on logical constants and quantifiers omitted for brevity; the full rules use verified side-conditions, element? tests, and decompose lists into t components.)

```
289

<!-- sheet 304 -->
```

... (L/R rules for propositional connectives and quantifiers follow, using if side conditions for verified facts.)

```
290

<!-- sheet 305 -->
```

(Recognizers defined outside YACC:)

```
(define name?
{t— boolean}
Name -> (variable? Name)
```

... (common-noun?, intrans?, trans? etc.)

The top level says that a sentence is a list of terms composed of a noun phrase and a verb phrase and the action of the compiler is to produce a formula. ...

```
(defcc <sent>
{ist t) ==> f}
<np> <vp> == (<np> <vp>):)
```

... (higher-order semantic actions using lambda, gensym for bound vars, quantifiers [e! ...], [al ...] etc.)

This illustrates building a typed term language + compiler from surface syntax to a typed logical form using Shen's sequent datatypes + YACC (defcc), with static guarantees and gensym for hygiene — directly relevant to Phase 6 surface reader and the expr/pattern datatypes.

---

## 22.7 The Compilation of YACC Rules (p. 298)

The compilation of a YACC grammar rule R begins by rendering it into an internal form which is a list (x y). ...

```
(define yace-syntax   ; (note: OCR 'yacc-syntax')
‘Type Structure [] [where P Semantics]
~> [if (yace-syntax Type Structure [] Semantics) [parse-failure]]
‘Type Structure [] Semantics -> (semantics Type Structure Semantics)
‘Type Structure [Syntaxitem | Syntax] Semantics,
> (cases (non-terminal? Syntaxltem)
(non-terminalcode Type Structure Syntaxitem Syntax Semantics)
(variable? Syntaxitem)
(variablecode Type Structure Syntaxltem Syntax Semantics)
...
```

(Then cases for non-terminals, variables (using gensym + hds/tls on structures), wildcards, terminals, cons forms.)

The compile harness:

```
(define compile
FL (let Compile (F [L ignore-me))
(cases (parse-ailure? Compile) (error "parse failure™24")
...
(true (<o Compile))))
```

Key for CAS: this shows how to turn infix-like or custom surface syntax into internal checked terms while preserving types. The design's Phase 6 reader can follow similar structure (or use defcc) to produce `checked-rule` / `expr` that already satisfy the sequent datatype invariants.

---

## Chapter 25 Shen Prolog (p. 345)

### 25.1 A Short History of Prolog

...

In Shen, Prolog is the language into which type declarations are compiled and it is the Prolog inference engine in Shen that makes the inferences that drive the type checking process. Shen Prolog is, in turn, compiled into Shen and Shen into KA. ...

A grasp of Prolog is essential if we wish to understand the relations between sequent calculus and Prolog and how sequent rules are compiled.

### 25.2 Horn Clause Logic

... (syntax rules, variables, terms, facts, rules, implicit quantification of variables in sequents...)

### 25.6 Shen Prolog (p. 357)

Shen Prolog is a version of Prolog that provides the object code for the sequent calculus rules of Shen. The syntax of Shen Prolog is based on that of Shen itself, with three differences.

1. `defprolog` is used instead of `define`.

2. `<--` is used instead of `->` or `<-` . In the clause `xxx <-- yyy;` the place of xxx is taken by a series of terms and yyy by a series of literals represented as function calls. Note the semi-colon terminates a clause.

3. Pattern-matching takes place only with respect to lists.

In Edinburgh syntax these facts

```
woman(martha)
woman(joan).
```

are written in Shen Prolog as

```
(defprolog woman
martha <--
joan <-- ;)
```

To pose a Prolog query, the macro `prolog?` is used.

```
(prolog? (woman martha))
true

(prolog? (woman X))
true   ; note: returns on first success in some contexts; use findall for all
```

Note that repeated variables in Shen Prolog programs are interpreted using occurs-check unification ...

The predicate `return` ends the Prolog computation returning the value of its argument.

```
(prolog? (woman X) (return X))
martha
```

To find all the values ... `findall` is used.

```
(prolog? (findall X (woman X) Y) (return Y))
[martha joan]
```

The predicate `when` enables boolean tests...

`is` unifies to result of evaluating a Shen expression. `bind` for when first arg known to be var.

(Example Bible program with lived/begat using defprolog.)

**Direct relevance to shen-cas:** The sketch (and match.shen / match-seq.shen / match-ac.shen) drive sequence matching, Orderless permutation search, and Flat splitting via exactly `(prolog? ...)` and `(defprolog split ... match-arg-list ... permutation ... select ...)` . The top-down backtracking nature of Prolog is used for the "hard parts" of AC matching inside the Evaluation Core, while Datalog (ADR) is reserved for the bottom-up indexing + analysis layer. This separation is already foreshadowed by the book's explanation that Prolog is the object code for sequent rules and provides the search engine.

---

## Additional Context from Design-Relevant Book Themes (near/after p. 288)

- **Sequent calculus as the engine for datatypes:** The book's extensive use of `(datatype Name ... rules with if verified side-conditions ...)` is exactly the mechanism used in sketch.md for `expr`, `pattern`, `seq-pattern`, `compound-pattern`, `rewrite-rule` (with `bindings-cover` side condition), `valid-attrs`, `symbol-entry`, `block-form` etc. The 4th edition syntax (verified, element?, gensym in rules, etc.) must be matched.

- **Priority rewrite systems (early ref, cross-referenced in design):** Shen's `define` uses top-to-bottom ordered application of rules (priority). This matches the "ordered, generally non-confluent strategy" that the shen-cas Evaluation Core must reproduce to be compatible with Mathematica-style CAS usage (see design §4, §9.3).

- **Type safety + ok/valid wrappers:** 21.4's distinction between `expr` (concrete syntax) and `ok-expr` / `valid` operations (semantic preservation via the type checker) is a microcosm of the design's `checked-rule` + definition-time `bindings-cover` + `valid-attrs`. The substrate (content store + immutable db) + Evaluation Core seam make these guarantees hold across basis changes and memoization.

- **Algebra as the bootstrap target:** The book's `simplify`/`thrash`/`walk` + `arith` is a concrete seed for Phase 5 bootstrap rule libraries (arithmetic, simplification) expressed as checked rules.

---

## Notes for Implementation (shen-cas)

- Replicate the style of book's `(datatype expr ...)` and `(datatype f ...)` when re-verifying sketch datatypes against 4th ed.
- Use `gensym` + alpha handling for Module/With (design §5.1, sketch §9).
- The YACC compilation model (defcc → internal + semantics) informs a clean reader that produces only well-typed internal `expr`/`checked-rule`.
- Keep Prolog strictly for the matcher (backtracking over splits/permutations); do not host the full Datalog layer on it (per ADR-001 / prologue+...).
- The immutable accumulate-only db + content hashes + basis-keyed memo are *additions* on top of the book; the book provides the host language primitives and type discipline that make the static-checking thesis possible.

**End of curated excerpts.** For full context read the original 4th edition, Ch. 2.7, 18 (Sequent Calculus), 19–21 (datatypes, algebraic simplification), 22 (YACC), 25 (Prolog), 26–27 (compilation of sequent/Prolog), and the algebraic examples.

---

**References in this excerpt file:**
- Tarver, M. (2025). *The Book of Shen*, 4th edition. Shen Technology.
- Cross-referenced against shen-cas design.md (v2), sketch.md, and prologue+datalogue_decision.md.
