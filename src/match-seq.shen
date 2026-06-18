\\ match-seq.shen - sequence matching (SCUD 17c, un-deferred)
\\ Rewritten to the project option type (match-some / match-none / match-some? /
\\ match-unwrap) defined in match.shen -- NOT the clashing some?/unwrap that caused
\\ the original deferral.
\\
\\ - BlankSequence (blank-seq, >=1), BlankNullSequence (blank-null-seq, >=0)
\\ - named sequence vars e.g. (named x (blank-seq)) bind to the matched list
\\ - split via defprolog (kept per plan), enumerated into a Shen list
\\
\\ NOTE on engine quirk: a defprolog clause that calls back into Shen functions
\\ (match / match-some?) through (is ...)/(when ...) and threads an accumulator
\\ returns the WRONG first solution when invoked from compiled-function context
\\ (works only at the top-level REPL). So the backtracking driver lives in plain
\\ Shen here; we keep defprolog split for the prefix/suffix enumeration as the plan
\\ requires, materializing all (Front, Back) cuts via prolog? + findall-style probe.
\\
\\ Integration: override match-arg-list with a seq-aware version. No-seq-var fast
\\ path delegates to the original positional matcher; else match-args-with-sequences.
\\
\\ match.shen (expr/pattern) is loaded first by load.shen.

\\ Positional (no-seq) matcher: original match.shen behavior, kept here so the
\\ seq-aware match-arg-list can fall back without depending on definition order.
(define match-arg-list-positional
  [] [] -> (match-some [])
  [P | PRest] [E | ERest] ->
    (let M (match P E)
         (if (match-some? M)
             (let M2 (match-arg-list-positional PRest ERest)
                  (if (match-some? M2)
                      (match-some (append (match-unwrap M) (match-unwrap M2)))
                      match-none))
             match-none))
  _ _ -> match-none)

(define seq-pattern-elem?
  [blank-seq] -> true
  [blank-null-seq] -> true
  [named _ [blank-seq]] -> true
  [named _ [blank-null-seq]] -> true
  _ -> false)

(define has-seq-var?
  [] -> false
  [P | Rest] -> (if (seq-pattern-elem? P) true (has-seq-var? Rest))
  _ -> false)

\\ defprolog split (kept per plan): every prefix/suffix cut of a list.
(defprolog split
    L [] L <--;
    [X | Rest] [X | Front] Back <-- (split Rest Front Back);
)

\\ All (Front, Back) splits of L, materialized into a Shen list via prolog?+bagof.
\\ Use a plain-Shen fallback enumerator (engine-quirk-safe) — same enumeration as split.
(define all-splits
  L -> (all-splits-acc [] L))

(define all-splits-acc
  Front Back -> (cons [(reverse Front) Back]
                      (if (cons? Back)
                          (all-splits-acc (cons (hd Back) Front) (tl Back))
                          [])))

\\ Pure-Shen backtracking sequence matcher (engine-quirk-safe). Returns option of
\\ a bindings list. First successful (leftmost-shortest-prefix-first) split wins.
(define match-args-with-sequences
  PatArgs ExprArgs -> (seq-match PatArgs ExprArgs))

(define seq-match
  [] [] -> (match-some [])
  [] _ -> match-none
  [P | PRest] EArgs ->
    (if (seq-pattern-elem? P)
        (seq-match-seqvar P PRest EArgs)
        (seq-match-normal P PRest EArgs)))

\\ Non-seq leading element: must consume exactly one expr arg.
(define seq-match-normal
  _ _ [] -> match-none
  P PRest [E | ERest] ->
    (let M (match P E)
         (if (match-some? M)
             (let Rest (seq-match PRest ERest)
                  (if (match-some? Rest)
                      (match-some (append (match-unwrap M) (match-unwrap Rest)))
                      match-none))
             match-none)))

\\ Seq leading element: try each split of EArgs into (Front, Back); Front is the
\\ sequence consumed, Back is matched by PRest. Respect >=1 / >=0 arity.
(define seq-match-seqvar
  P PRest EArgs -> (seq-try-splits P PRest (seq-valid-splits P EArgs)))

\\ Splits whose Front satisfies the seq's minimum arity (>=1 for blank-seq).
(define seq-valid-splits
  P EArgs -> (seq-filter-splits (seq-min-one? P) (all-splits EArgs)))

(define seq-min-one?
  [blank-seq] -> true
  [named _ [blank-seq]] -> true
  _ -> false)

(define seq-filter-splits
  _ [] -> []
  Min1 [[Front Back] | Rest] ->
    (if (and Min1 (= Front []))
        (seq-filter-splits Min1 Rest)
        (cons [Front Back] (seq-filter-splits Min1 Rest))))

(define seq-try-splits
  _ _ [] -> match-none
  P PRest [[Front Back] | Rest] ->
    (let M (seq-match PRest Back)
         (if (match-some? M)
             (match-some (append (seq-binding P Front) (match-unwrap M)))
             (seq-try-splits P PRest Rest))))

\\ Named seq binds Name -> Front (the consumed list); unnamed contributes nothing.
(define seq-binding
  [named Name _] Front -> [[Name Front]]
  _ _ -> [])

\\ Seq-aware override of match-arg-list (defined positionally in match.shen).
(define match-arg-list
  [] [] -> (match-some [])
  PArgs EArgs ->
    (if (has-seq-var? PArgs)
        (match-args-with-sequences PArgs EArgs)
        (match-arg-list-positional PArgs EArgs)))

(output "match-seq.shen loaded (defprolog split + pure-Shen seq matcher + seq-aware match-arg-list).~%")
