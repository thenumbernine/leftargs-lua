Here's a new idea I had...

Put function parenthesis on the left instead of the right.

## Reason for left-associative function args:
- Lambda-function evaluations no longer have the input parameters and the lambda function arguments separated by the function body.
	- Right: `((x,y) => { return x + y; })(2, 2)`
	- Left: `(2,2) -> (x,y) => { return x + y; }`
- Grammar order now follows evaluation order.  If you want to start with x, apply f, then g, then h:
	- Right: `h(g(f(x)))`
	- Left: `x -> f -> g -> h`
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
