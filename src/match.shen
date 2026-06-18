\\ match.shen - first-order matcher + substitute (Phase 1)
\\ Supports literal, blank, named, compound.
\\ No sequences / AC yet (match-seq + match-ac later).

(load "src/expr.shen")
(load "src/pattern.shen")

(define match
  (blank) _ -> (some [])
  (blank H) [[(sym H) | _] | _] -> (some [])
  (blank H) _ -> none
  (named Name P) E -> (let R (match P E)
                           (if (some? R)
                               (some (cons [Name E] (unwrap R)))
                               none))
  E E -> (some []) where (not (compound? E))
  [PH | PArgs] [EH | EArgs] -> (match-compound PH PArgs EH EArgs)
  (condition P Test) E -> (let R (match P E)
                              (if (and (some? R)
                                       (eval-to-true? (substitute (unwrap R) Test)))
                                  R
                                  none))
  _ _ -> none)

(define match-compound
  PH PArgs EH EArgs ->
    (let HeadMatch (match PH EH)
         (if (some? HeadMatch)
             (let ArgMatch (match-arg-list PArgs EArgs)
                  (if (some? ArgMatch)
                      (some (append (unwrap HeadMatch) (unwrap ArgMatch)))
                      none))
             none)))

(define match-arg-list
  [] [] -> (some [])
  [P | PRest] [E | ERest] ->
    (let M (match P E)
         (if (some? M)
             (let M2 (match-arg-list PRest ERest)
                  (if (some? M2)
                      (some (append (unwrap M) (unwrap M2)))
                      none))
             none))
  _ _ -> none)

\\ NOTE: match-seq.shen (loaded after) overrides match-arg-list with prolog-backed
\\ version supporting BlankSequence/BlankNullSequence + named seq vars (light integration).
\\ The above is the Phase-1 first-order fallback used inside the prolog normal case.

(define compound? 
  [_ | _] -> true
  _ -> false)

(define substitute
  [] E -> E
  [[Name Val] | Rest] E -> (substitute Rest (replace-free Name Val E)))

(define replace-free
  Name Val (sym Name) -> Val
  Name Val (sym S) -> (sym S)
  Name Val (int N) -> (int N)
  Name Val [H | Args] -> [(replace-free Name Val H) | (map (/. X (replace-free Name Val X)) Args)]
  Name Val X -> X)

(define some? (some _) -> true ; _ -> false)
(define unwrap (some X) -> X)

(define eval-to-true?
  (sym True) -> true
  _ -> false)   \\ very crude for skeleton

(princ "match.shen loaded (first-order match + substitute).~%")