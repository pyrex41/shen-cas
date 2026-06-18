\\ match.shen - first-order matcher + substitute (Phase 1)
\\ Supports literal, blank, named, compound.
\\ Sequences via match-seq override; AC (Orderless/Flat) via match-ac stub (post load).

(load "src/expr.shen")
(load "src/pattern.shen")

\\ Custom optional type (avoid clash with Shen's list-existential some? / some)
(define match-some X -> [just X])
(define match-none -> [none])
(define match-some?
  X -> (if (cons? X) (= (hd X) (protect just)) false))

(define match-unwrap
  [just X] -> X)

(define match
  [blank] _ -> (match-some [])
  [blank H] [[sym H] | _] -> (match-some [])
  [blank H] _ -> match-none
  [named Name P] E -> (let R (match P E)
                           (if (match-some? R)
                               (match-some (cons [Name E] (match-unwrap R)))
                               match-none))
  E E -> (match-some []) where (not (expr-compound? E))
  [PH | PArgs] [EH | EArgs] -> (match-compound PH PArgs EH EArgs)
  [condition P Test] E -> (let R (match P E)
                              (if (and (match-some? R)
                                       (eval-to-true? (substitute (match-unwrap R) Test)))
                                  R
                                  match-none))
  _ _ -> match-none)

(define match-compound
  PH PArgs EH EArgs ->
    (let HeadMatch (match PH EH)
         (if (match-some? HeadMatch)
             (let ArgMatch (match-arg-list PArgs EArgs)
                  (if (match-some? ArgMatch)
                      (match-some (append (match-unwrap HeadMatch) (match-unwrap ArgMatch)))
                      match-none))
             match-none)))

(define match-arg-list
  [] [] -> (match-some [])
  [P | PRest] [E | ERest] ->
    (let M (match P E)
         (if (match-some? M)
             (let M2 (match-arg-list PRest ERest)
                  (if (match-some? M2)
                      (match-some (append (match-unwrap M) (match-unwrap M2)))
                      match-none))
             match-none))
  _ _ -> match-none)

(define expr-atom?
  [sym S] -> true where (symbol? S)
  [int N] -> true where (number? N)
  X -> false)

(define expr-compound?
  [H | Args] -> (and (not (expr-atom? [H | Args])) (cons? Args))
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

(define eval-to-true?
  [sym True] -> true
  _ -> false)

(output "match.shen loaded (first-order match + substitute).~%")