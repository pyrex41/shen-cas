\\ match-seq.shen - Prolog sequence matching stub (Phase 2 start)
\\ Per sketch §7.2 and plan Phase 2:
\\ - BlankSequence (blank-seq), BlankNullSequence (blank-null-seq)
\\ - named sequence vars e.g. (named x (blank-seq))
\\ - split via defprolog (match-arg-list style)
\\
\\ Provides split + basic sequence matchers using prolog? as in Book/sketch.
\\ Integrates lightly by overriding match-arg-list (after match.shen load) with seq-aware version.
\\ No full AC (Orderless/Flat) yet -- match-ac.shen later.
\\ Uses first-order match for non-seq elements.

\\ match.shen (which pulls expr/pattern) is expected to be loaded first.
\\ some? / unwrap are defined there.

(define match-args-with-sequences
  \\ Use Shen's Prolog subsystem for nondeterministic splitting (per sketch)
  PatArgs ExprArgs ->
      (prolog?
          (match-arg-list PatArgs ExprArgs Bindings)
          (return Bindings)))

(defprolog match-arg-list
    \\ Base case: empty pattern matches empty args
    [] [] Bindings <-- (return (some Bindings));

    \\ Sequence pattern (one or more): try all splits
    [(blank-seq) | PRest] EArgs Bindings <--
        (split EArgs Front Back)
        (when (not (= Front [])))   \\ at least one element
        (match-arg-list PRest Back Bindings2)
        (return (some (append Bindings Bindings2)));

    \\ Null sequence: zero or more allowed
    [(blank-null-seq) | PRest] EArgs Bindings <--
        (split EArgs Front Back)
        (match-arg-list PRest Back Bindings2)
        (return (some (append Bindings Bindings2)));

    \\ Named sequence var (blank-seq)
    [(named Name (blank-seq)) | PRest] EArgs Bindings <--
        (split EArgs Front Back)
        (when (not (= Front [])))
        (match-arg-list PRest Back Bindings2)
        (return (some [(Name Front) | (append Bindings Bindings2)]));

    \\ Named sequence var (blank-null-seq)
    [(named Name (blank-null-seq)) | PRest] EArgs Bindings <--
        (split EArgs Front Back)
        (match-arg-list PRest Back Bindings2)
        (return (some [(Name Front) | (append Bindings Bindings2)]));

    \\ Normal (non-seq) pattern element: delegate to first-order match
    [P | PRest] [E | ERest] Bindings <--
        (is Result (match P E))
        (when (some? Result))
        (match-arg-list PRest ERest
            (append Bindings (unwrap Result)));

    \\ no more clauses: implicit failure (prolog? will not return a value)
)

\\ Prolog predicate to split a list at all possible positions (prefix/suffix)
\\ Backtracks over every valid (Front, Back) pair.
(defprolog split
    L [] L <--;
    [X | Rest] [X | Front] Back <-- (split Rest Front Back);
)

\\ Light integration point: override the first-order match-arg-list (defined in match.shen)
\\ with the Prolog-backed version that handles seq patterns.
\\ (Prolog version delegates non-seq cases back to (match).)
(define match-arg-list
  [] [] -> (some [])
  PArgs EArgs ->
    (let R (match-args-with-sequences PArgs EArgs)
         (if R R none)))

(princ "match-seq.shen loaded (prolog split + basic seq matchers + light match integration).~%")