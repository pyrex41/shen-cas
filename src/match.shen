\\ match.shen - first-order matcher + substitute (Phase 1)
\\ Supports literal, blank, named, compound.
\\ Sequences via match-seq override; AC (Orderless/Flat) via match-ac stub (post load).
\\ 16e: expr/pattern loaded by load.shen before match; no redundant loads.

\\ Custom optional type (avoid clash with Shen's list-existential some? / some)
(define match-some X -> [just X])
(define match-none -> [none])
(define match-some?
  X -> (if (cons? X) (= (hd X) (protect just)) false))

(define match-unwrap
  [just X] -> X)

\\ P0-1: repeated pattern variables must bind CONSISTENTLY. Combine two binding
\\ lists, failing (match-none) if any shared name maps to unequal values, so e.g.
\\ f[x_,x_] matches f[1,1] but NOT f[1,2]. Enforced at every binding-combination
\\ point: the orderless/seq search backtracks for free since a conflicting combine
\\ returns match-none and the caller tries the next permutation/split.
(define merge-bindings
  B1 B2 -> (if (bindings-compatible? B1 B2)
               (match-some (append B1 B2))
               match-none))

(define bindings-compatible?
  [] _ -> true
  [[Name Val] | Rest] B2 -> (if (binding-conflicts? Name Val B2)
                                false
                                (bindings-compatible? Rest B2))
  [_ | Rest] B2 -> (bindings-compatible? Rest B2))

(define binding-conflicts?
  Name Val B2 -> (let Hit (assoc Name B2)
                      (if (assoc-hit? Hit)
                          (not (binding-vals-equal? Val (hd (tl Hit))))
                          false)))

\\ seqval lists are not ordinary exprs (content-hash buckets them all to "other"),
\\ so compare those structurally; ordinary expr values compare by content hash.
(define binding-vals-equal?
  V1 V2 -> (if (or (seqval? V1) (seqval? V2))
               (= V1 V2)
               (content-eq V1 V2)))

(define match
  [blank] _ -> (match-some [])
  [blank H] [[sym H] | _] -> (match-some [])
  [blank H] _ -> match-none
  [named Name P] E -> (let R (match P E)
                           (if (match-some? R)
                               (match-some (cons [Name E] (match-unwrap R)))
                               match-none))
  E E -> (match-some []) where (not (expr-compound? E))
  \\ 18a: PatternTest - match the sub-pattern, then require the test predicate
  \\ applied to the bound value to reduce to [sym True].
  [ptest P F] E -> (let R (match P E)
                        (if (match-some? R)
                            (if (eval-to-true? (normal-form [F E]))
                                R
                                match-none)
                            match-none))
  \\ 18b: Condition - match the sub-pattern, substitute bindings into the Test,
  \\ then NORMAL-FORM the Test before the truth check (was: literal [sym True] only).
  [condition P Test] E -> (let R (match P E)
                              (if (match-some? R)
                                  (if (eval-to-true? (normal-form (substitute (match-unwrap R) Test)))
                                      R
                                      match-none)
                                  match-none))
  [PH | PArgs] [EH | EArgs] -> (match-compound PH PArgs EH EArgs)
  _ _ -> match-none)

(define match-compound
  PH PArgs EH EArgs ->
    (let HeadMatch (match PH EH)
         (if (match-some? HeadMatch)
             (let ArgMatch (match-arg-list PArgs EArgs)
                  (if (match-some? ArgMatch)
                      (merge-bindings (match-unwrap HeadMatch) (match-unwrap ArgMatch))
                      match-none))
             match-none)))

(define match-arg-list
  [] [] -> (match-some [])
  [P | PRest] [E | ERest] ->
    (let M (match P E)
         (if (match-some? M)
             (let M2 (match-arg-list PRest ERest)
                  (if (match-some? M2)
                      (merge-bindings (match-unwrap M) (match-unwrap M2))
                      match-none))
             match-none))
  _ _ -> match-none)

(define expr-atom?
  [sym S] -> true where (symbol? S)
  [int N] -> true where (number? N)
  [rat N D] -> true where (and (number? N) (number? D))
  X -> false)

(define expr-compound?
  [H | Args] -> (and (not (expr-atom? [H | Args])) (cons? Args))
  _ -> false)

(define substitute
  [] E -> E
  [[Name Val] | Rest] E -> (substitute Rest (replace-free Name Val E)))

\\ Sequence values are wrapped [seqval | Front] (see match-seq seq-binding) so a
\\ matched sequence can be distinguished from an ordinary compound expr at
\\ substitution time and SPLICED into the enclosing argument list. A bare [sym Name]
\\ that resolves to a seq value in head position degrades to its first element
\\ (seq vars are only meaningful in arg position, so this branch is unused in well-
\\ formed rules; we keep it total).
(define seqval?
  X -> (and (cons? X) (= (hd X) (intern "seqval"))))

(define seqval-items
  X -> (tl X))

(define replace-free
  Name Val [sym Name] -> Val
  Name Val [sym S] -> [sym S]
  Name Val [int N] -> [int N]
  Name Val [rat N D] -> [rat N D]
  Name Val [H | Args] -> [(replace-free-head Name Val H) | (replace-free-args Name Val Args)]
  Name Val X -> X)

\\ Head position: a seqval substituted into head collapses to its first element
\\ (defensive; not produced by well-formed calculus rules).
(define replace-free-head
  Name Val H -> (let R (replace-free Name Val H)
                     (if (seqval? R)
                         (if (cons? (seqval-items R)) (hd (seqval-items R)) R)
                         R)))

\\ Arg position: substitute each arg; if the result is a seqval, splice its items
\\ into the surrounding arg list instead of nesting a list.
(define replace-free-args
  Name Val [] -> []
  Name Val [A | As] -> (let R (replace-free Name Val A)
                            Rest (replace-free-args Name Val As)
                            (if (seqval? R)
                                (append (seqval-items R) Rest)
                                (cons R Rest))))

\\ 18b: True is the canonical (protect True) symbol; an uppercase pattern var
\\ would wrongly match ANY [sym X] (incl. [sym False]). Compare by name.
(define eval-to-true?
  [sym S] -> true where (= S (protect True))
  _ -> false)

(output "match.shen loaded (first-order match + substitute).~%")