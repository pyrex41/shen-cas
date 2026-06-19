\\ solve.shen - SCUD 19 Wave D: solve polynomial equations in one variable over Q.
\\
\\ Built on src/polyalg.shen (univariate coeff-vector bridge + Factor), src/poly.shen
\\ and src/num.shen (exact rational arithmetic). GUIDING PRINCIPLE: SOUND > COMPLETE.
\\
\\ Solve[E, V] where V is a [sym _]:
\\   - Normalize to a polynomial P in V: Equal[L,R] -> L - R; else E (treat E==0).
\\   - Require P univariate in V with NUMERIC coefficients; else INERT ([none]).
\\   - deg 1: linear root.  deg 2: discriminant; exact rational root iff Disc is a
\\     perfect rational square, else the Sqrt closed form.  deg>=3: Factor and solve
\\     linear/quadratic factors; any irreducible factor of deg>=3 -> INERT.
\\   - Output a List of DISTINCT roots, or empty List for a nonzero constant
\\     (no solutions); identically-zero -> INERT.
\\   - SELF-SOUND GATE: each root substituted back into P must (reduce ...) to
\\     [int 0]; otherwise the whole Solve is INERT.
\\
\\ shen-go portable: no bare higher-order application, nested ifs (no and/or to
\\ guard partial accessors), int64 only (num.shen guards overflow; we trap-error
\\ and decline to inert).

\\ ============================================================================
\\ Head / constructor helpers.
\\ ============================================================================
(define sv-equal-head? [sym S] -> (= (str S) "Equal") _ -> false)

(define sv-plus  -> [sym (protect Plus)])
(define sv-times -> [sym (protect Times)])
(define sv-power -> [sym (protect Power)])
(define sv-list  -> [sym (protect List)])
(define sv-sqrt  -> [sym (protect Sqrt)])

\\ first element (head) of a compound; non-compound -> [none].
(define sv-head
  [H | _] -> H
  _ -> [none])

\\ ============================================================================
\\ Solve[E, V]: the wired built-in. Returns [some Result] / [none] (inert).
\\ ============================================================================
(define solve-builtin
  E V -> (trap-error (solve-attempt E V) (/. Er [none])))

(define solve-attempt
  E [sym S] -> (solve-with-var E [sym S])
  E _ -> [none])

\\ Normalize E to a polynomial expr P (= 0 understood), then solve P in V.
(define solve-with-var
  E V -> (solve-poly (solve-normalize E) V))

\\ Equal[L,R] -> L - R ; otherwise E itself (treated as E == 0).
(define solve-normalize
  [H L R] -> (if (sv-equal-head? H)
                 [(sv-plus) L [(sv-times) [int -1] R]]
                 [H L R])
  E -> E)

\\ ============================================================================
\\ solve-poly: require P univariate in V over Q (free-symbols(P) subset {V}),
\\ extract the dense coeff vector, dispatch by degree.
\\ ============================================================================
(define solve-poly
  P V -> (if (solve-univariate-in? P V)
             (solve-coeffs P V (expr->coeffs V P))
             [none]))

\\ P's free symbols must be a subset of {V} (so coeffs are numeric). Reuse
\\ polyalg's free-sym-names: the set of indeterminate symbol NAMES in P.
(define solve-univariate-in?
  P [sym Name] -> (solve-names-subset? (free-sym-names P) Name))

(define solve-names-subset?
  [] _ -> true
  [N | Ns] Name -> (if (= N Name) (solve-names-subset? Ns Name) false))

(define solve-coeffs
  _ _ [none] -> [none]
  P V [some Vec] -> (solve-dispatch P V (trim-coeffs Vec)))

\\ Dispatch on degree of the trimmed coeff vector.
\\   deg -1 : identically zero  -> INERT
\\   deg  0 : nonzero constant  -> empty List (no solutions)
\\   deg  1 : linear
\\   deg  2 : quadratic
\\   deg >=3: factor-based
(define solve-dispatch
  P V Vec -> (let D (coeffs-deg Vec)
                  (if (= D -1)
                      [none]
                      (if (= D 0)
                          [some [(sv-list)]]
                          (if (= D 1)
                              (solve-finish P V (solve-linear Vec))
                              (if (= D 2)
                                  (solve-finish P V (solve-quadratic Vec))
                                  (solve-finish P V (solve-highdeg P V Vec))))))))

\\ solve-finish: a roots-attempt is [none] (already inert) or [some RootList].
\\ Dedup, run the substitute-back soundness gate, then emit a List.
(define solve-finish
  _ _ [none] -> [none]
  P V [some Roots] -> (solve-gate P V (sv-dedup-roots Roots)))

\\ ============================================================================
\\ Degree 1: c1 x + c0 -> root = -c0 / c1.
\\ ============================================================================
(define solve-linear
  Vec -> (let C0 (hd Vec)
              C1 (hd (tl Vec))
              [some [(num-div (num-mul [int -1] C0) C1)]]))

\\ ============================================================================
\\ Degree 2: c2 x^2 + c1 x + c0.  Disc = c1^2 - 4 c2 c0.
\\   Disc a perfect rational square -> exact rational roots (-c1 +/- sqrt)/(2 c2).
\\   else -> Sqrt closed form:  (-c1 +/- Sqrt[Disc]) / (2 c2)  (the soundness gate
\\   then decides whether the current rules can verify it; if not, INERT).
\\ ============================================================================
(define solve-quadratic
  Vec -> (let C0 (hd Vec)
              C1 (hd (tl Vec))
              C2 (hd (tl (tl Vec)))
              Disc (num-sub (num-mul C1 C1)
                            (num-mul [int 4] (num-mul C2 C0)))
              (solve-quad-from-disc C0 C1 C2 Disc)))

(define solve-quad-from-disc
  C0 C1 C2 Disc -> (let PS (perfect-rat-sqrt Disc)
                        (if (= PS [none])
                            (solve-quad-symbolic C1 C2 Disc)
                            (solve-quad-rational C1 C2 (hd (tl PS))))))

\\ rational roots: (-c1 +/- S) / (2 c2), S = exact sqrt(Disc).
(define solve-quad-rational
  C1 C2 S -> (let Den (num-mul [int 2] C2)
                  NegC1 (num-mul [int -1] C1)
                  R1 (num-div (num-add NegC1 S) Den)
                  R2 (num-div (num-sub NegC1 S) Den)
                  [some [R1 R2]]))

\\ symbolic roots with the Sqrt head: (-c1 +/- Sqrt[Disc]) / (2 c2).
\\ Built as exprs (not numeric). The soundness gate decides if they survive.
(define solve-quad-symbolic
  C1 C2 Disc -> (let Den (num-mul [int 2] C2)
                     NegC1 (num-mul [int -1] C1)
                     Root (sv-quad-root NegC1 Disc Den [int 1])
                     Root2 (sv-quad-root NegC1 Disc Den [int -1])
                     [some [Root Root2]]))

\\ build  (NegC1 + Sign*Sqrt[Disc]) / Den  as a reduced expr.
(define sv-quad-root
  NegC1 Disc Den Sign ->
    (reduce [(sv-times)
              [(sv-plus) NegC1 [(sv-times) Sign [(sv-sqrt) Disc]]]
              [(sv-power) Den [int -1]]]))

\\ perfect rational square: N/D (in lowest terms) is a perfect square iff both |N|
\\ and D are perfect integer squares AND N >= 0. Returns [some S] (S = exact sqrt
\\ as a numeric expr) / [none].
(define perfect-rat-sqrt
  Disc -> (let R (as-rat Disc)
               N (rat-num R)
               D (rat-den R)
               (if (< N 0)
                   [none]
                   (let SN (int-sqrt N)
                        SD (int-sqrt D)
                        (if (or (= SN [none]) (= SD [none]))
                            [none]
                            [some (make-rat (hd (tl SN)) (hd (tl SD)))])))))

\\ integer square root of a NON-NEGATIVE integer N: [some S] if S*S=N exactly,
\\ else [none]. Bounded linear search to floor(sqrt) -- inputs are small coeff
\\ products; trap-error in solve-builtin guards any pathological size.
(define int-sqrt
  0 -> [some 0]
  N -> (int-sqrt-loop N 1))

(define int-sqrt-loop
  N I -> (let Sq (* I I)
              (if (= Sq N)
                  [some I]
                  (if (> Sq N)
                      [none]
                      (int-sqrt-loop N (+ I 1))))))

\\ ============================================================================
\\ Degree >= 3: Factor[P] (Wave C). If it factors entirely into linear and/or
\\ quadratic factors over Q, solve each and union the roots. If any irreducible
\\ factor of degree >= 3 remains, INERT.
\\ ============================================================================
(define solve-highdeg
  P V Vec -> (let F (factor-builtin P)
                  (if (= F [none])
                      [none]
                      (solve-factors V (sv-factor-list (hd (tl F)))))))

\\ Factor returns a single expr: either Times[f1 f2 ..] or a lone factor.
\\ Split into the list of factor exprs.
(define sv-factor-list
  [H | Fs] -> (if (sv-times-head? H) Fs [[H | Fs]])
  F -> [F])

(define sv-times-head? [sym S] -> (= (str S) "Times") _ -> false)

\\ Solve every factor; union roots. Any factor that itself goes INERT (irreducible
\\ deg>=3, or a non-V factor we can't handle) makes the whole solve INERT.
(define solve-factors
  V [] -> [some []]
  V [F | Fs] -> (sv-merge-factor-roots (solve-one-factor V F) V Fs))

(define sv-merge-factor-roots
  [none] _ _ -> [none]
  [some Rs] V Fs -> (sv-merge-rest Rs (solve-factors V Fs)))

(define sv-merge-rest
  _ [none] -> [none]
  Rs [some More] -> [some (append Rs More)])

\\ Solve a single factor for its roots. A numeric (constant) factor contributes
\\ no roots. A factor free of V (a pure-numeric content) contributes none. Else
\\ recurse via the degree dispatch on its OWN coeff vector (linear/quadratic),
\\ and INERT on degree >= 3 (irreducible leftover).
(define solve-one-factor
  V F -> (if (numeric? F)
             [some []]
             (if (free-of? F V)
                 [some []]
                 (solve-factor-coeffs V F (expr->coeffs V F)))))

(define solve-factor-coeffs
  V F [none] -> [none]
  V F [some Vec] -> (solve-factor-by-deg V (trim-coeffs Vec)))

(define solve-factor-by-deg
  V Vec -> (let D (coeffs-deg Vec)
                (if (= D 1)
                    (solve-linear Vec)
                    (if (= D 2)
                        (solve-quadratic Vec)
                        (if (= D 0)
                            [some []]      \\ constant factor: no roots
                            [none])))))    \\ deg>=3 irreducible -> INERT

\\ ============================================================================
\\ Dedup roots by content-eq on the REDUCED form (numeric roots fold; identical
\\ Sqrt forms collapse).
\\ ============================================================================
(define sv-dedup-roots
  [] -> []
  [R | Rs] -> (if (sv-root-member? R Rs)
                  (sv-dedup-roots Rs)
                  [R | (sv-dedup-roots Rs)]))

(define sv-root-member?
  _ [] -> false
  R [X | Xs] -> (if (content-eq R X) true (sv-root-member? R Xs)))

\\ ============================================================================
\\ SELF-SOUND GATE: substitute each root back into P, (reduce ...), require [int 0].
\\ If any root fails to verify, INERT. (sv-subst is our substitution helper --
\\ NOT named subst.)  On pass, emit the List of roots.
\\ ============================================================================
(define solve-gate
  P V Roots -> (if (sv-verify-all P V Roots)
                   [some [(sv-list) | Roots]]
                   [none]))

(define sv-verify-all
  _ _ [] -> true
  P V [R | Rs] -> (if (sv-verify-one P V R)
                      (sv-verify-all P V Rs)
                      false))

(define sv-verify-one
  P V R -> (sv-zero? (reduce (sv-subst V R P))))

(define sv-zero?
  E -> (if (numeric? E) (num-eq? E [int 0]) false))

\\ substitute occurrences of variable V (a [sym _]) with expr R throughout E.
(define sv-subst
  V R [sym S] -> (if (content-eq V [sym S]) R [sym S])
  V R [int N] -> [int N]
  V R [rat N D] -> [rat N D]
  V R [H | Args] -> [(sv-subst V R H) | (sv-subst-list V R Args)]
  V R E -> E)

(define sv-subst-list
  V R [] -> []
  V R [A | As] -> [(sv-subst V R A) | (sv-subst-list V R As)])

(output "solve.shen loaded (Wave D: Solve polynomial equations in one var over Q).~%")
