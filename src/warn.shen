\\ warn.shen - static warnings surfaced at rule/attribute registration (SCUD 11.2)
\\ Per plan Phase 4, ADR-001: use plain analysis relations from query (covers?, unbound-vars,
\\ attr-conflicts, oneid-no-unary) at registration points.
\\ oneid-no-unary is warning/analysis (db contents + brute compare) not attr type rejection.
\\ Keep pure analysis in query; warn.shen is the output/surface layer.
\\ Invariant: analysis sound for static rejection thesis.

\\ Assume query (and deps) already loaded by load.shen order.

(define warn-unbound-in-db
  Db -> (let Bad (unbound-vars Db)
             (if (empty? Bad)
                 true
                 (do (output "WARN [unbound-vars]: rules with potential unbound RHS: ~A~%" Bad)
                     false))))

(define warn-attr-conflicts
  Db -> (let Bad (attr-conflicts Db)
             (if (empty? Bad)
                 true
                 (do (output "WARN [attr-conflicts]: symbols with inconsistent attrs: ~A~%" Bad)
                     false))))

(define warn-oneid-no-unary
  Db -> (let Bad (oneid-no-unary Db)
             (let Brute (oneid-no-unary-brute Db)
                 (do (if (not (empty? Bad))
                         (output "WARN [oneid-no-unary]: OneIdentity symbols lacking unary rule: ~A (brute: ~A)~%" Bad Brute)
                         true)
                     (if (not (= (length Bad) (length Brute)))
                         (output "WARN [invariant]: oneid-no-unary vs brute differ: ~A vs ~A~%" Bad Brute)
                         true)
                     (empty? Bad)))))   \\ return whether clean

(define warn-covers-check
  \\ example surface; not auto at reg yet. Returns the curried checker.
  Db -> (covers? Db))

(define run-warns
  Db -> (do (warn-unbound-in-db Db)
            (warn-attr-conflicts Db)
            (warn-oneid-no-unary Db)
            true))

\\ Called after rule registration (post assert). Uses current *db*.
(define warn-on-rule-registration
  _ -> (run-warns (value *db*)))

\\ Called after attribute declaration (may be sig or future assert-attr).
(define warn-on-attribute-declaration
  _ -> (run-warns (value *db*)))

(output "warn.shen loaded (analysis warnings at reg time: unbound, attr-conflicts, oneid-no-unary).~%")
