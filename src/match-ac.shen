\\ match-ac.shen - Quick stub for Orderless + Flat + AC blowup warning (Phase 2)
\\ Per sketch §7.3-7.4, plan Phase 2 acceptance, SCUD 9.2.
\\ 16e: match (and match-seq) are loaded by load.shen before match-ac; no redundant load.

(define ac-known-heads
  -> [[sym (protect Plus)] [sym (protect Times)] (protect Plus) (protect Times)])

(define is-ac-head?
  H -> (element? H (ac-known-heads)) where (cons? H)
  H -> (element? H (ac-known-heads)))

(define ac-head-has-orderless?
  H -> (or (is-ac-head? H)
           (if (sym? H) (has-orderless? (sym-name H)) false)))

(define ac-head-has-flat?
  H -> (or (is-ac-head? H)
           (if (sym? H) (has-flat? (sym-name H)) false)))

(define count-seq-vars
  [] -> 0
  [[blank-seq] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[blank-null-seq] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[named Name [blank-seq]] | Rest] -> (+ 1 (count-seq-vars Rest))
  [[named Name [blank-null-seq]] | Rest] -> (+ 1 (count-seq-vars Rest))
  [X | Rest] -> (count-seq-vars Rest))

(define ac-blowup-warning
  Head PArgs ->
    (if (and (ac-head-has-flat? Head) (ac-head-has-orderless? Head)
             (> (count-seq-vars PArgs) 1))
        (do (output "WARNING: AC blowup risk for ~A (Flat+Orderless + >1 seq var)~%" Head)
            true)
        true))

\\ Fallback while match-seq.shen is deferred. When sequence patterns are wired in,
\\ match-seq.shen can override this with the Prolog-backed implementation.
(define match-args-with-sequences
  PArgs EArgs -> (match-arg-list PArgs EArgs))

(define flatten-flat
  Head [H | Args] ->
    (if (and (sym? H) (sym? Head) (= (sym-name H) (sym-name Head)))
        (append (flatten-flat Head (tl H))
                (flatten-flat Head Args))
        [H | (flatten-flat Head Args)])
  Head [] -> []
  Head X -> [X])

(define flatten-flat-args
  Head EArgs ->
    (if (ac-head-has-flat? Head)
        (flatten-flat Head EArgs)
        EArgs))

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
    (if (ac-head-has-orderless? Head)
        (let R (prolog?
                 (permutation EArgs Perm)
                 (is M (match-args-with-sequences PArgs Perm))
                 (when (match-some? M))
                 (return M))
             (if (match-some? R) R (match-args-with-sequences PArgs EArgs)))
        (match-args-with-sequences PArgs EArgs)))

(define match-compound
  PH PArgs EH EArgs ->
    (let HeadMatch (match PH EH)
         (if (match-some? HeadMatch)
             (let FlatEArgs (if (cons? EH) (flatten-flat-args EH EArgs) EArgs)
                  ArgMatch (if (and (ac-head-has-orderless? EH) (> (count-seq-vars PArgs) 0))
                               (match-orderless EH PArgs FlatEArgs)
                               (match-arg-list PArgs FlatEArgs))
                  Ign (if (cons? EH) (ac-blowup-warning EH PArgs) true)
                  (if (match-some? ArgMatch)
                      (match-some (append (match-unwrap HeadMatch) (match-unwrap ArgMatch)))
                      match-none))
             match-none)))

(output "match-ac.shen loaded (quick AC stub: orderless perm + flat flatten + blowup warning).~%")