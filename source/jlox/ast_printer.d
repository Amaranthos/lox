module jlox.ast_printer;

import std.format : format;
import std.variant : Variant;

import jlox.ast;
import jlox.token : Token;

string printAST(Expr expr)
{
	alias Visitor = Expr.Visitor!string;

	class Printer : Visitor
	{
		string visit(Binary expr)
		{
			return parenthesize(expr.operator.lexeme, expr.left, expr.right);
		}

		string visit(Grouping expr)
		{
			return parenthesize("group", expr.expression);
		}

		string visit(Literal expr)
		{
			if (expr.value.type != typeid(null))
				return expr.value.toString();
			return "nil";
		}

		string visit(Unary expr)
		{
			return parenthesize(expr.operator.lexeme, expr.right);
		}

		private string parenthesize(string name, Expr[] exprs...)
		{
			import std.algorithm : map;
			import std.stdio : writeln;

			return format!("(%s %-(%s %))")(name, exprs.map!(expr => expr.accept(this)));
		}
	}

	Visitor visitor = new Printer();
	return expr.accept(visitor);
}

version (printAST)
{
	void main()
	{
		import std.stdio : writeln;

		// dfmt off
		printAST(
			new Binary(
				new Unary(
					Token(Token.Type.MINUS, "-", null, 1),
					new Literal(Variant(123.0))
				),
				Token(Token.Type.STAR, "*", null , 1),
				new Grouping(
					new Literal(Variant(45.67))
				)
			)
		)
		.writeln();
		// dfmt on
	}
}
