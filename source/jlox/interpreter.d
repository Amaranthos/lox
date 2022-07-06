module jlox.interpreter;

import std.variant : Variant;

import jlox.ast;
import jlox.errors : RuntimeException;
import jlox.token : Token;

string interpret(Expr expr)
{
	alias Visitor = Expr.Visitor!Variant;

	class Interpreter : Visitor
	{
		Variant visit(Binary expr)
		{
			Variant left = evaluate(expr.left);
			Variant right = evaluate(expr.right);

			switch (expr.operator.type) with (Token.Type)
			{
			case MINUS:
				checkNumberOperands(expr.operator, left, right);
				return Variant(left.get!double - right.get!double);
			case SLASH:
				checkNumberOperands(expr.operator, left, right);
				return Variant(left.get!double / right.get!double);
			case STAR:
				checkNumberOperands(expr.operator, left, right);
				return Variant(left.get!double * right.get!double);
			case PLUS:
				if (left.peek!double && right.peek!double)
				{
					return Variant(left.get!double + right.get!double);
				}

				if (left.peek!string && right.peek!string)
				{
					return Variant(left.get!string ~ right.get!string);
				}
				throw new RuntimeException(expr.operator, "Operands must be two numbers or two strings");

			case GREATER:
				checkNumberOperands(expr.operator, left, right);
				return Variant(left.get!double > right.get!double);
			case GREATER_EQUAL:
				checkNumberOperands(expr.operator, left, right);
				return Variant(left.get!double >= right.get!double);
			case LESS:
				checkNumberOperands(expr.operator, left, right);
				return Variant(left.get!double < right.get!double);
			case LESS_EQUAL:
				checkNumberOperands(expr.operator, left, right);
				return Variant(left.get!double <= right.get!double);

			case BANG_EQUAL:
				return Variant(!isEqual(left, right));
			case EQUAL_EQUAL:
				return Variant(isEqual(left, right));

			default:
				break;
			}

			return Variant(null);
		}

		Variant visit(Grouping expr)
		{
			return evaluate(expr.expression);
		}

		Variant visit(Literal expr)
		{
			return expr.value;
		}

		Variant visit(Unary expr)
		{
			Variant right = evaluate(expr.right);

			switch (expr.operator.type) with (Token.Type)
			{
			case BANG:
				return Variant(!isTruthy(right));

			case MINUS:
				checkNumberOperand(expr.operator, right);
				return Variant(-right.get!double);

			default:
				return Variant(null);
			}
		}

		private Variant evaluate(Expr expr)
		{
			return expr.accept(this);
		}

		private bool isTruthy(Variant var)
		{
			if (var.type == typeid(null))
				return false;
			if (var.type == typeid(bool))
				return var.get!bool;

			return true;
		}

		private bool isEqual(Variant a, Variant b)
		{
			if (a.type == typeid(null) && b.type == typeid(null))
				return true;

			if (a.type == typeid(null))
				return false;

			return a == b;
		}

		private void checkNumberOperand(Token operator, Variant operand)
		{
			if (operand.type == typeid(double))
				return;
			throw new RuntimeException(operator, "Operand must be a number");
		}

		private void checkNumberOperands(Token operator, Variant left, Variant right)
		{
			if (left.type == typeid(double) && right.type == typeid(double))
				return;
			throw new RuntimeException(operator, "Operands must be a number");
		}
	}

	string stringify(Variant variant)
	{
		if (variant.type == typeid(null))
			return "nil";
		if (variant.type == typeid(double))
		{
			import std.string : endsWith;

			string text = variant.toString();
			if (text.endsWith(".0"))
			{
				text = text[0 .. $ - 2];
			}

			return text;
		}

		return variant.toString();
	}

	try
	{
		Visitor visitor = new Interpreter();
		return stringify(expr
				.accept(visitor));
	}
	catch (RuntimeException e)
	{
		import jlox.errors : runtimeError;

		runtimeError(e);

		return "";
	}
}
