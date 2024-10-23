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
But in programming languages it looks like ...
- Right: `print("Hello World")`
- Left: `"Hello World" -> print`

## Reasons for right-associative function args:
- ... Tradition?
- Now Lua needs a statement-separator ; like C++. But maybe the grammer can be tweaked to get around this ...
