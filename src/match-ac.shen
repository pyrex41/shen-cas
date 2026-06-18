\\ match-ac.shen - Quick stub for Orderless + Flat + AC blowup warning (Phase 2)
\\ Per sketch §7.3-7.4, plan Phase 2 acceptance, SCUD 9.2.
\\ - Orderless: permutation search via prolog (match-orderless + permutation/select)
\\ - Flat: flatten nested same-head before matching (flatten-flat + helpers)
\\ - AC blowup warning when Flat+Orderless + >1 sequence var in a rule pattern
\\ Light integration with match-seq (prolog seq match) + core match.
\\ Uses structural sigs from store when declared; falls back to known AC heads for stub.
\\ No full attrs yet.

(load "src/match.shen")
(load "src/match-seq.shen")

\\ --- AC head recognition (stub; later driven by attrs.shen + store sigs) ---
(define ac-known-heads -> [(sym Plus) (sym Times) Plus Times])

(define sym-name
  [(sym S) | _] -> S
  [sym S] -> S
  S -> S where (symbol? S)
  _ -> false)

(define is-ac-head?
  H -> (element? H (ac-known-heads)) where (cons? H)
  H -> (element? H (ac-known-heads)))

(define has-orderless?
  H -> (or (is-ac-head? H)
           (let S (sym-name H)
             (and S (structural-sig-contains-name? S "orderless")))))

(define has-flat?
  H -> (or (is-ac-head? H)
           (let S (sym-name H)
             (and S (structural-sig-contains-name? S "flat")))))

\\ --- count sequence vars in a pattern arg list (for blowup warning) ---
(define count-seq-vars
  [] -> 0
  [[blank-seq] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[blank-null-seq] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[named _ [blank-seq]] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[named _ [blank-null-seq]] | Rest] -> (+ 1 (count-seq-vars Rest))
  [_ | Rest] -> (count-seq-vars Rest))

(define ac-blowup-warning
  Head PArgs ->
    (if (and (has-flat? Head) (has-orderless? Head)
             (> (count-seq-vars PArgs) 1))
        (do (output "WARNING: AC blowup risk for ~A (Flat+Orderless + >1 seq var)~%" Head)
            true)
        true))

\\ --- Flat flattening (sketch §7.4) ---
(define flatten-flat
  Head [H | Args] ->
    (if (and (cons? H) (or (= H Head) (= (sym-name H) (sym-name Head))))
        (append (flatten-flat Head (tl H))
                (flatten-flat Head Args))
        [H | (flatten-flat Head Args)])
  _ [] -> []
  _ X -> [X])

(define flatten-flat-args
  Head EArgs ->
    (if (has-flat? Head)
        (flatten-flat Head EArgs)
        EArgs))

\\ --- Orderless via prolog permutation (sketch §7.3, using match-seq) ---
(defprolog permutation
  [] [] <-- ;
  [X | Y] Z <--
    (select X Z W)
    (permutation Y W); )

(defprolog select
  X [X | Y] Y <-- ;
  X [Y | Z] [Y | W] <-- (select X Z W); )

(define match-orderless
  Head PArgs EArgs ->
    (if (has-orderless? Head)
        (prolog?
          (permutation EArgs Perm)
          (is R (match-args-with-sequences PArgs Perm))
          (return R))
        (match-args-with-sequences PArgs EArgs)))

\\ --- Light integration: extend match-compound for AC heads ---
\\ pre-flatten for flat, orderless perm for orderless, call warning
(define match-compound
  PH PArgs EH EArgs ->
    (let HeadMatch (match PH EH)
         (if (match-some? HeadMatch)
             (let FlatEArgs (if (cons? EH) (flatten-flat-args EH EArgs) EArgs)
                  ArgMatch (if (and (cons? EH) (has-orderless? EH))
                               (match-orderless EH PArgs FlatEArgs)
                               (match-arg-list PArgs FlatEArgs))
                  _ (if (cons? EH) (ac-blowup-warning EH PArgs) true)
                  (if (match-some? ArgMatch)
                      (match-some (append (match-unwrap HeadMatch) (match-unwrap ArgMatch)))
                      match-none))
             match-none)))

(output "match-ac.shen loaded (quick AC stub: orderless perm + flat flatten + blowup warning).~%")