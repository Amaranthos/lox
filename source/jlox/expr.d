module jlox.expr;

import jlox.token : Token;

abstract class Expr
{
}

class Binary : Expr
{
	Expr left;
	Token operator;
	Expr right;
}
