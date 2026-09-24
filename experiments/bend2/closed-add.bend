import Base

# This is the closed, pure arithmetic fragment used by bridge.mjs. The
# generated cases replace only the expression passed to eval in main.
type Expr is Data:
  Lit{value: U32}
  Add{left: Expr, right: Expr}

def eval(term: Expr) -> U32:
  match term:
    case Lit{value}:
      value
    case Add{left, right}:
      x y = eval(left) eval(right)
      (x + y : U32)

def main() -> IO(Unit):
  IO.print(U32.show(eval(Add{Lit{1}, Lit{2}})))
