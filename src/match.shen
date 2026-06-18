\\ match.shen - first-order matcher + substitute (Phase 1)
\\ Supports literal, blank, named, compound.
\\ Sequences via match-seq override; AC (Orderless/Flat) via match-ac stub (post load).

(load "src/expr.shen")
(load "src/pattern.shen")

(define match
  [blank] _ -> (some [])
  [blank H] [[sym H] | _] -> (some [])   ; note: head of compound is the sym list [sym H] , outer list pattern simplified
  [blank H] _ -> none
  [named Name P] E -> (let R (match P E)
                           (if (some? R)
                               (some (cons [Name E] (unwrap R)))
                               none))
  E E -> (some []) where (not (compound? E))
  [PH | PArgs] [EH | EArgs] -> (match-compound PH PArgs EH EArgs)
  [condition P Test] E -> (let R (match P E)
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

\\ NOTE: match-seq.shen (loaded after) overrides match-arg-list.
\\ match-ac.shen (loaded after seq) further extends match-compound for Orderless/Flat + warning.
\\ The above is the Phase-1 first-order fallback.

(define compound? 
  [_ | _] -> true
  _ -> false)

(define substitute
  [] E -> E
  [[Name Val] | Rest] E -> (substitute Rest (replace-free Name Val E)))

(define replace-free
  Name Val [sym Name] -> Val
  Name Val [sym S] -> [sym S]
  Name Val [int N] -> [int N]
  Name Val [H | Args] -> [(replace-free Name Val H) | (map (/. X (replace-free Name Val X)) Args)]
  Name Val X -> X)

(define some? (some _) -> true ; _ -> false)
(define unwrap (some X) -> X)

(define eval-to-true?
  [sym True] -> true
  _ -> false)   \\ very crude for skeleton

(output "match.shen loaded (first-order match + substitute).~%")