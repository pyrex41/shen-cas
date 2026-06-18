\\ num.shen - exact integer numeric layer (Phase 1)
\\ Per notes/syntax-verification.md (task 4): only [int N] for now.
\\ All arith ops centralized here for hash stability + future HVM.

(define num-add
  [int A] [int B] -> (int (+ A B)))

(define num-sub
  [int A] [int B] -> (int (- A B)))

(define num-mul
  [int A] [int B] -> (int (* A B)))

(define num-div
  [int A] [int B] -> (int (/ A B)) where (not (= B 0)))

(define num-eq?
  [int A] [int B] -> (= A B))

(output "num.shen (exact int only) loaded.~%")