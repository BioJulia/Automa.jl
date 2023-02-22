* Doctests in all docstrings and documentation
* 

================ PRECONDITIONS
Seems like it's not quite though out yet. Does anyone use it?

What do we REALLY want? Some kind of toggle:
    precond(::Expr, re1, [re2]), where if only 1 regex is passed, you can only move into
    regex if Expr. If two are passed, you check Expr, and move into re1, else re2.
