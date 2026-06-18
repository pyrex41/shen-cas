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
          (prolog-match-arg-list PatArgs ExprArgs [] B)
          (return (some B))))

(defprolog prolog-match-arg-list
    \\ Base: unify out = in ; return the acc wrapped
    [] [] Acc Acc <-- ;

    \\ Seq 1+: delegate, no added binding for unnamed
    [(blank-seq) | PRest] EArgs In Out <--
        (split EArgs Front Back)
        (when (not (= Front [])))
        (prolog-match-arg-list PRest Back In Out);

    \\ Null 0+
    [(blank-null-seq) | PRest] EArgs In Out <--
        (split EArgs Front Back)
        (prolog-match-arg-list PRest Back In Out);

    \\ Named seq: add binding, delegate
    [(named Name (blank-seq)) | PRest] EArgs In Out <--
        (split EArgs Front Back)
        (when (not (= Front [])))
        (is Mid (append In [[Name Front]]))
        (prolog-match-arg-list PRest Back Mid Out);

    [(named Name (blank-null-seq)) | PRest] EArgs In Out <--
        (split EArgs Front Back)
        (is Mid (append In [[Name Front]]))
        (prolog-match-arg-list PRest Back Mid Out);

    \\ Normal: match, append binding, delegate
    [P | PRest] [E | ERest] In Out <--
        (is R (match P E))
        (when (some? R))
        (is Mid (append In (unwrap R)))
        (prolog-match-arg-list PRest ERest Mid Out);
)

\\ Prolog predicate to split a list at all possible positions (prefix/suffix)
\\ Backtracks over every valid (Front, Back) pair.
(defprolog split
    L [] L <--;
    [X | Rest] [X | Front] Back <-- (split Rest Front Back);
)

\\ Light integration point: override the first-order match-arg-list (defined in match.shen)
\\ with the Prolog-backed version that handles seq patterns.
\\ Use internal prolog name to avoid arity clash.
(define match-arg-list
  [] [] -> (some [])
  PArgs EArgs ->
    (let R (match-args-with-sequences PArgs EArgs)
         (if R R none)))

(princ "match-seq.shen loaded (prolog split + basic seq matchers + light match integration).~%")