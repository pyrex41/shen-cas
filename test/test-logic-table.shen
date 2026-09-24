\\ Left-recursive transitive closure, cycles, deduplication and version isolation.
(define logic-example-facts
  -> [[logic-atom edge [[sym a] [sym b]]]
      [logic-atom edge [[sym b] [sym c]]]
      [logic-atom edge [[sym c] [sym a]]]
      [logic-atom edge [[sym c] [sym d]]]])

(define logic-example-rules
  -> [[logic-rule [logic-atom path [[logic-var x] [logic-var y]]]
                   [[logic-atom path [[logic-var x] [logic-var z]]]
                    [logic-atom edge [[logic-var z] [logic-var y]]]]]
      [logic-rule [logic-atom path [[logic-var x] [logic-var y]]]
                   [[logic-atom edge [[logic-var x] [logic-var y]]]]]])

(define run-logic-table-tests
  -> (let Base (logic-example-facts)
          Rules (logic-example-rules)
          Table (logic-table Base Rules)
          FromA (logic-select [logic-atom path [[sym a] [logic-var y]]] Table)
          Extended (logic-table (cons [logic-atom edge [[sym d] [sym e]]] Base) Rules)
          Bad (trap-error
                (do (logic-table Base
                      [[logic-rule [logic-atom bad [[logic-var missing]]] []]]) false)
                (/. E true))
          BadFact (trap-error
                    (do (logic-table [[logic-atom edge [[logic-var x] [sym b]]]] []) false)
                    (/. E true))
          Ok (and (= (length FromA) 4)
                  (element? [logic-atom path [[sym a] [sym a]]] FromA)
                  (element? [logic-atom path [[sym a] [sym d]]] FromA)
                  (= (length Table) 16)
                  (= (length (logic-table Base Rules)) (length Table))
                  (not (element? [logic-atom path [[sym a] [sym e]]] Table))
                  (element? [logic-atom path [[sym a] [sym e]]] Extended)
                  (= (length (logic-query Base Rules
                               [logic-atom path [[sym a] [logic-var y]]])) 4)
                  (= (length (logic-table (cons (hd Base) Base) Rules)) 16)
                  Bad BadFact)
          (do (output "logic table (left recursion, cycles, isolation, safety): ~A~%" Ok)
              Ok)))
