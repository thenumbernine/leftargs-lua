Here's a new idea I had...

Put function parenthesis on the left instead of the right.

## Reason for left-associative function args:
- Grammar order now follows evaluation order.  If you want to start with x, apply f, then g, then h:
	- Right: `h(g(f(x)))`
	- Left: `(x) -> f -> g -> h`
- If you want to immediately evaluate a lambda-function, for the sake of scope or any other reason, with left-associative parenthesis we no longer have the input values and the lambda arguments separated by the function body:
	- Right: `(function(x,y) return x + y end)(2, 2)`
	- Left: `(2,2) -> (function(x,y) return x + y end)`
- ... or using [langfix](https://github.com/thenumbernine/langfix-lua) to reduce the keywords it is easier to see ...
	- Right: `([x,y] x + y)(2, 2)`
	- Left: `(2,2) -> ([x,y] x + y)`
- Grammar order now follows instruction order:
printing "Hello World"` in IL looks like:
```
push "Hello World"
call print
```
- But in programming languages it looks like ...
	- Right: `print("Hello World")`
	- Left: `"Hello World" -> print`

## Reasons for right-associative function args:
- ... Tradition?
- In the order of object member function calls, `t:k(...)` is equivalent to `t.k(t, ...)`.
	- A left-associative call would now look like `(t, ...) -> t.k`, and now our `t`s are far apart.
	- I could define the `:`-index-call operator to insert-left the `self` such that `(...) -> t:k` evaluates to `(t, ...) -> t.k`.
	- Still, I'm suspicious that successive stream operations like `a(a1,a2,a3):b(b1,b2,b3):c(c1,c2,c3)` might look ugly.
```
	(c1, c2, c3) -> ((b1, b2, b3) -> ((a1,a2,a3) -> a):b):c
```
	- ... and now we have another mess.
	- Maybe the only way to read operations in the order of their execution in combination with member fields and the self-call `:` operator is by mixing left- and right-associative function args?
```
	((a1,a2,a3) -> a) :b(b1, b2, b3) :c(c1, c2, c3)
```
- Now Lua needs a statement-separator `;` like C++. But maybe the grammer can be tweaked to get around this, to treat `->` as an expression-operator as well as a statement, similar to how function-calls are already parsed exceptionally as either.  But function call statements already have their parsing gotches because of this.
