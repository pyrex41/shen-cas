\\ series.shen - SCUD 20 Wave E: Taylor Series + Limit (built-in heads).
\\
\\ GUIDING PRINCIPLE: SOUND > COMPLETE. Return a value ONLY when it is justified
\\ by a terminating, checkable computation; otherwise stay INERT ([none]).
\\
\\ Series[F, V, N]  (V a [sym _], N a non-negative integer literal):
\\   Taylor expansion of F about V=0 to order N. For k=0..N,
\\     coeff_k = (k-th derivative of F wrt V, evaluated at V=0) / k!
\\   The k-th derivative is computed by iterating the D head through reduce;
\\   evaluated at 0 by substituting V->0 (own helper se-subst, NOT named subst)
\\   then reduce; the result MUST be numeric (else that coefficient cannot be
\\   formed -> INERT for the whole Series). k! via a guarded integer factorial
\\   (int64 overflow -> INERT). Output is the truncated polynomial sum over
\\   k=0..N of coeff_k * V^k as a normal expr (zero terms dropped, HONEST
\\   truncation -- no O-term appended).
\\   Optional 4-arg form Series[F, V, V0, N]: expansion about V=V0 with basis
\\   (V-V0)^k (coeff evaluated at V=V0).
\\
\\ Limit[F, V, V0]  (built-in head):
\\   - direct substitution: L0 = reduce(F[V:=V0]); if numeric & well-defined,
\\     return L0.
\\   - 0/0 form: F a ratio Divide[P,Q] with P(V0)=0 and Q(V0)=0 -> L'Hopital
\\     Limit[D[P]/D[Q], V, V0], bounded depth (<=5).
\\   - else INERT.
\\
\\ shen-go portable: no bare higher-order application, nested ifs (no and/or to
\\ guard partial accessors), int64 only (num.shen guards overflow; trap-error and
\\ decline to inert).

\\ ============================================================================
\\ head / constructor helpers.
\\ ============================================================================
(define se-plus  -> [sym (protect Plus)])
(define se-times -> [sym (protect Times)])
(define se-power -> [sym (protect Power)])
(define se-d     -> [sym (protect D)])

(define se-head-name
  [sym S] -> (str S)
  _ -> "")

(define se-divide-head? [sym S] -> (= (str S) "Divide") _ -> false)

\\ ============================================================================
\\ substitution helper (NOT named subst): replace V (a [sym _]) by R in E.
\\ ============================================================================
(define se-subst
  V R [sym S] -> (if (content-eq V [sym S]) R [sym S])
  V R [int N] -> [int N]
  V R [rat N D] -> [rat N D]
  V R [H | Args] -> [(se-subst V R H) | (se-subst-list V R Args)]
  V R E -> E)

(define se-subst-list
  V R [] -> []
  V R [A | As] -> [(se-subst V R A) | (se-subst-list V R As)])

\\ ============================================================================
\\ guarded integer factorial: k! ; int64 overflow (saturation) -> [none].
\\ Reuses num.shen's guard-int via num-mul on [int _] (which traps overflow at
\\ the saturation sentinel). We trap-error and decline.
\\ ============================================================================
(define se-factorial
  K -> (trap-error [some (se-fact-loop K 1)] (/. E [none])))

(define se-fact-loop
  0 Acc -> Acc
  K Acc -> (se-fact-loop (- K 1) (se-guard-mul Acc K)))

\\ multiply two raw ints with the int64 overflow guard (errors on saturation).
(define se-guard-mul
  A B -> (guard-int (* A B)))

\\ ============================================================================
\\ numeric well-definedness: E is numeric (int/rat literal).
\\ ============================================================================
(define se-numeric? E -> (numeric? E))

\\ ============================================================================
\\ Series built-in.  3-arg: about 0.  4-arg: about V0.  [some R] / [none].
\\ ============================================================================
(define series-builtin
  Args -> (trap-error (series-attempt Args) (/. E [none])))

(define series-attempt
  [F [sym V] N]    -> (series-go F [sym V] [int 0] N)
  [F [sym V] V0 N] -> (series-go F [sym V] V0 N)
  _ -> [none])

\\ Order N must be a non-negative integer literal.
(define series-go
  F V V0 [int N] -> (if (< N 0) [none] (series-build F V V0 N))
  F V V0 _ -> [none])

\\ Build the list of terms coeff_k*(basis_k) for k=0..N, then sum.
\\   basis_k = (V - V0)^k  ; about 0 (V0 = [int 0]) this is V^k.
\\ Each coeff_k computed from the k-th derivative; if ANY fails to evaluate to a
\\ number at the point, INERT the whole Series.
(define series-build
  F V V0 N -> (let Terms (series-terms F V V0 0 N F [])
                   (if (= Terms [none])
                       [none]
                       [some (series-sum (reverse Terms))])))

\\ series-terms: iterate k from 0..N. Dk is the current k-th derivative expr
\\ (D^0 F = F). Accumulate terms (in reverse). On any non-numeric coeff or
\\ factorial overflow -> [none] (propagated).
(define series-terms
  F V V0 K N Dk Acc -> (if (> K N)
                           Acc
                           (series-term-k F V V0 K N Dk Acc)))

(define series-term-k
  F V V0 K N Dk Acc ->
    (let DkAt (reduce (se-subst V V0 Dk))
         (if (se-numeric? DkAt)
             (series-term-coeff F V V0 K N Dk Acc DkAt)
             [none])))

(define series-term-coeff
  F V V0 K N Dk Acc DkAt ->
    (let Fact (se-factorial K)
         (if (= Fact [none])
             [none]
             (series-term-emit F V V0 K N Dk Acc
                               (num-div DkAt [int (hd (tl Fact))])))))

\\ Coeff_k = DkAt / k!.  Emit the term coeff_k*(V-V0)^k (dropping zero coeff),
\\ then advance: Dk+1 = reduce D[Dk, V].
(define series-term-emit
  F V V0 K N Dk Acc Coeff ->
    (let Term (if (num-eq? Coeff [int 0])
                  [skip]
                  (series-term-expr Coeff V V0 K))
         Acc2 (if (= Term [skip]) Acc [Term | Acc])
         Dnext (reduce [(se-d) Dk V])
         (series-terms F V V0 (+ K 1) N Dnext Acc2)))

\\ term coeff_k*(V-V0)^k, reduced to normal form. basis = (V-V0)^k. For k=0 the
\\ basis is 1 so the term is just Coeff. About 0, (V-V0) reduces to V.
(define series-term-expr
  Coeff V V0 0 -> Coeff
  Coeff V V0 K -> (reduce [(se-times) Coeff [(se-power) (series-basis V V0) [int K]]]))

\\ basis variable: V about 0, else (V - V0) = Plus[V, Times[-1,V0]].
(define series-basis
  V V0 -> (if (num-eq-zero? V0)
              V
              [(se-plus) V [(se-times) [int -1] V0]]))

(define num-eq-zero?
  E -> (if (numeric? E) (num-eq? E [int 0]) false))

\\ Sum the term list. [] -> 0 ; [T] -> T ; else reduce Plus[..].
(define series-sum
  [] -> [int 0]
  [T] -> (reduce T)
  Ts -> (reduce [(se-plus) | Ts]))

\\ ============================================================================
\\ Limit built-in.  Limit[F, V, V0].  [some R] / [none].
\\ ============================================================================
(define se-limit-max-depth -> 5)

(define limit-builtin
  Args -> (trap-error (limit-attempt Args) (/. E [none])))

(define limit-attempt
  [F [sym V] V0] -> (limit-go F [sym V] V0 (se-limit-max-depth))
  _ -> [none])

\\ Try direct substitution first; if that yields a well-defined numeric value,
\\ return it. Otherwise, if F is a 0/0 ratio, apply L'Hopital (bounded depth).
\\ Else INERT.
(define limit-go
  F V V0 Depth -> (let L0 (se-try-subst F V V0)
                       (if (= L0 [none])
                           (limit-lhopital F V V0 Depth)
                           L0)))

\\ Direct substitution: reduce F[V:=V0]; require the result NUMERIC and
\\ well-defined. (A division by zero raises an error inside reduce -> trapped by
\\ the outer trap-error in limit-builtin, so we never return a bogus value; but
\\ to keep substitution local we also guard with trap-error here so a 0/0 ratio
\\ falls through to L'Hopital rather than aborting the whole Limit.)
(define se-try-subst
  F V V0 -> (trap-error (se-subst-numeric F V V0) (/. E [none])))

(define se-subst-numeric
  F V V0 -> (let R (reduce (se-subst V V0 F))
                 (if (se-numeric? R) [some R] [none])))

\\ L'Hopital: only for a ratio Divide[P,Q] with P(V0)=0 AND Q(V0)=0. Then
\\ Limit[ D[P]/D[Q], V, V0 ] at depth-1. Bounded recursion. Else INERT.
(define limit-lhopital
  F V V0 0 -> [none]
  F V V0 Depth -> (limit-on-ratio (se-as-ratio F) V V0 Depth))

\\ se-as-ratio: recognize F as a ratio. Divide[P,Q] -> [some [P Q]].
\\ (Times[P, Power[Q,-1]] could also be detected, but Cancel/Divide is the
\\ canonical ratio shape here; keep it sound and narrow.)
(define se-as-ratio
  [H P Q] -> (if (se-divide-head? H) [some [P Q]] [none])
  _ -> [none])

(define limit-on-ratio
  [none] _ _ _ -> [none]
  [some [P Q]] V V0 Depth -> (limit-check-00 P Q V V0 Depth))

\\ require P(V0)=0 and Q(V0)=0 (the 0/0 indeterminate form); else INERT (a
\\ ratio with nonzero denominator was already caught by direct substitution; a
\\ nonzero/0 is a genuine pole we decline).
(define limit-check-00
  P Q V V0 Depth -> (let PA (reduce (se-subst V V0 P))
                         QA (reduce (se-subst V V0 Q))
                         (if (se-both-zero? PA QA)
                             (limit-go (se-make-ratio (reduce [(se-d) P V])
                                                      (reduce [(se-d) Q V]))
                                       V V0 (- Depth 1))
                             [none])))

(define se-both-zero?
  PA QA -> (if (num-eq-zero? PA)
               (if (num-eq-zero? QA) true false)
               false))

(define se-make-ratio
  DP DQ -> [[sym (protect Divide)] DP DQ])

(output "series.shen loaded (Wave E: Series + Limit; sound, inert when unjustified).~%")
