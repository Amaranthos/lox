module jlox.interpreter;

import std.variant : Variant;

import jlox.ast;
import jlox.callable : Callable;
import jlox.errors : RuntimeException;
import jlox.env : Env;
import jlox.lox_class;
import jlox.lox_func : LoxFunc;
import jlox.lox_inst : LoxInst;
import jlox.token : Token;

alias ExprVisitor = Expr.Visitor!Variant;
alias StmtVisitor = Stmt.Visitor!void;

class Interpreter : ExprVisitor, StmtVisitor
{
	Env globals = new Env();
	Env env;
	int[Expr] locals;

	this()
	{
		auto clock = new class Callable
		{
			int arity()
			{
				return 0;
			}

			Variant call(Interpreter interpreter, Variant[] args)
			{
				import std.datetime : Clock, stdTimeToUnixTime;

				return Variant((cast(double) Clock.currStdTime.stdTimeToUnixTime) / 1000.0);
			}

			override string toString() const
			{
				return "<native fun>";
			}
		};

		globals.define("clock", Variant(clock));
		env = globals;
	}

	void interpret(Stmt[] statements)
	{
		try
		{
			foreach (statement; statements)
			{
				execute(statement);
			}
		}
		catch (RuntimeException e)
		{
			import jlox.errors : runtimeError;

			runtimeError(e);
		}
	}

	void visit(Print stmt)
	{
		import std.stdio : writeln;

		auto v = evaluate(stmt.expression);
		writeln(stringify(v));
	}

	void visit(Return stmt)
	{
		Variant value = Variant(null);
		if (stmt.value)
			value = evaluate(stmt.value);

		import jlox.return_exception : ReturnException;

		throw new ReturnException(value);
	}

	void visit(Block stmt)
	{
		executeBlock(stmt.statements, new Env(env));
	}

	void visit(Class stmt)
	{
		import jlox.lox_class : LoxClass;

		LoxClass superclass;
		if (stmt.superclass)
		{
			// auto variant = evaluate(stmt.superclass);
			// if (!variant.convertsTo!LoxClass)
			// 	throw new RuntimeException(stmt.superclass.name, "Superclass must be a class");
			// superclass = variant.get!LoxClass;
		}

		env.define(stmt.name.lexeme, Variant(null));

		if (stmt.superclass)
		{
			auto variant = evaluate(stmt.superclass);
			if (!variant.convertsTo!LoxClass)
				throw new RuntimeException(stmt.superclass.name, "Superclass must be a class");
			superclass = variant.get!LoxClass;

			env = new Env(env);
			env.define("super", Variant(superclass));
		}

		Methods methods;
		foreach (method; stmt.methods)
		{
			methods[method.name.lexeme] = new LoxFunc(method, env, method.name.lexeme == "init");
		}

		LoxClass klass = new LoxClass(stmt.name.lexeme, superclass, methods);

		if (superclass)
			env = env.enclosing;

		env.assign(stmt.name, Variant(klass));
	}

	void visit(Expression stmt)
	{
		evaluate(stmt.expression);
	}

	void visit(Function stmt)
	{
		import jlox.lox_func : LoxFunc;

		LoxFunc func = new LoxFunc(stmt, env);
		env.define(stmt.name.lexeme, Variant(func));
	}

	void visit(If stmt)
	{
		if (isTruthy(evaluate(stmt.condition)))
		{
			execute(stmt.thenBranch);
		}
		else if (stmt.elseBranch)
		{
			execute(stmt.elseBranch);
		}
	}

	void visit(Var stmt)
	{
		Variant value = null;
		if (stmt.initializer)
		{
			value = evaluate(stmt.initializer);
		}

		env.define(stmt.name.lexeme, value);
	}

	void visit(While stmt)
	{
		while (isTruthy(evaluate(stmt.condition)))
		{
			execute(stmt.body);
		}
	}

	Variant visit(Assign expr)
	{
		Variant value = evaluate(expr.value);

		if (expr in locals)
			env.assignAt(locals[expr], expr.name, value);
		else
			globals.assign(expr.name, value);

		return value;
	}

	Variant visit(Binary expr)
	{
		Variant left = evaluate(expr.left);
		Variant right = evaluate(expr.right);

		switch (expr.operator.type) with (Token.Type)
		{
		case MINUS:
			checkNumberOperands(expr.operator, left, right);
			return Variant(
				left.get!double - right.get!double);
		case SLASH:
			checkNumberOperands(expr.operator, left, right);

			if (right.get!double == 0.0)
			{
				throw new RuntimeException(expr.operator, "Cannot divide by 0");
			}

			return Variant(
				left.get!double / right.get!double);
		case STAR:
			checkNumberOperands(expr.operator, left, right);
			return Variant(
				left.get!double * right.get!double);
		case PLUS:
			if (left.peek!double && right.peek!double)
			{
				return Variant(
					left.get!double + right.get!double);
			}

			if (left.peek!string && right.peek!string)
			{
				return Variant(
					left.get!string ~ right.get!string);
			}
			throw new RuntimeException(expr.operator, "Operands must be two numbers or two strings");

		case GREATER:
			checkNumberOperands(expr.operator, left, right);
			return Variant(
				left.get!double > right.get!double);
		case GREATER_EQUAL:
			checkNumberOperands(expr.operator, left, right);
			return Variant(
				left.get!double >= right
					.get!double);
		case LESS:
			checkNumberOperands(expr.operator, left, right);
			return Variant(
				left.get!double < right.get!double);
		case LESS_EQUAL:
			checkNumberOperands(expr.operator, left, right);
			return Variant(
				left.get!double <= right
					.get!double);
		case BANG_EQUAL:
			return Variant(!isEqual(left, right));
		case EQUAL_EQUAL:
			return Variant(isEqual(left, right));

		default:
			break;
		}

		return Variant(null);
	}

	Variant visit(Call expr)
	{
		Variant callee = evaluate(expr.callee);

		Variant[] args;
		foreach (arg; expr.args)
		{
			args ~= evaluate(arg);
		}

		if (!callee.convertsTo!Callable)
		{
			throw new RuntimeException(expr.paren, "Can only call functions and classes");
		}

		Callable func = callee.get!Callable;
		if (args.length != func.arity)
		{
			import std.format : format;

			throw new RuntimeException(expr.paren, format!"Expected %s arguments but got %s"(
					func.arity, args
					.length));
		}
		return func.call(this, args);
	}

	Variant visit(Get expr)
	{
		Variant obj = evaluate(expr.object);
		if (obj.convertsTo!LoxInst)
		{
			return obj.get!LoxInst.get(expr.name);
		}

		throw new RuntimeException(expr.name, "Only instances have properties");
	}

	Variant visit(Grouping expr)
	{
		return evaluate(expr.expression);
	}

	Variant visit(Literal expr)
	{
		return expr.value;
	}

	Variant visit(Logical expr)
	{
		Variant left = evaluate(expr.left);

		if (
			expr.operator.type == Token
			.Type.OR)
		{
			if (isTruthy(left))
				return left;
		}
		else
		{
			if (!isTruthy(left))
				return left;
		}

		return evaluate(expr.right);
	}

	Variant visit(Set expr)
	{
		Variant obj = evaluate(expr.object);

		if (!obj.convertsTo!LoxInst)
			throw new RuntimeException(expr.name, "Only instances have fields");

		Variant value = evaluate(expr.value);
		obj.get!LoxInst.set(expr.name, value);
		return value;
	}

	Variant visit(Super expr)
	{
		int dist = locals[expr];
		LoxClass superclass = env.getAt(dist, "super").get!LoxClass;
		LoxInst object = env.getAt(dist - 1, "this").get!LoxInst;

		LoxFunc method = superclass.findMethod(expr.method.lexeme);

		if (method is null)
		{
			import std.format : format;

			throw new RuntimeException(expr.method, expr.method.lexeme
					.format!"Undefined property '%s'");
		}

		return Variant(method.bind(object));
	}

	Variant visit(This expr)
	{
		return lookUpVariable(expr.keyword, expr);
	}

	Variant visit(Unary expr)
	{
		Variant right = evaluate(expr.right);

		switch (expr.operator.type) with (
			Token.Type)
		{
		case BANG:
			return Variant(
				!isTruthy(right));

		case MINUS:
			checkNumberOperand(expr.operator, right);
			return Variant(
				-right.get!double);

		default:
			return Variant(null);
		}
	}

	Variant visit(Variable expr)
	{
		return lookUpVariable(expr.name, expr);
	}

	Variant evaluate(Expr expr)
	{
		return expr.accept(this);
	}

	void executeBlock(Stmt[] statements, Env env)
	{
		Env previous = this.env;
		try
		{
			this.env = env;

			foreach (statement; statements)
			{
				execute(statement);
			}
		}
		finally
		{
			this.env = previous;
		}
	}

	void execute(Stmt statement)
	{
		statement.accept(this);
	}

	void resolve(Expr expr, int depth)
	{
		locals[expr] = depth;
	}

private:
	bool isTruthy(Variant var)
	{
		if (var.type == typeid(null))
			return false;
		if (
			var.type == typeid(bool))
			return var.get!bool;

		return true;
	}

	bool isEqual(Variant a, Variant b)
	{
		if (a.type == typeid(null) && b.type == typeid(
				null))
			return true;
		if (
			a.type == typeid(null))
			return false;

		return a == b;
	}

	void checkNumberOperand(Token operator, Variant operand)
	{
		if (operand.type == typeid(double))
			return;
		throw new RuntimeException(operator, "Operand must be a number");
	}

	void checkNumberOperands(Token operator, Variant left, Variant right)
	{
		if (left.type == typeid(double) && right.type == typeid(
				double))
			return;
		throw new RuntimeException(operator, "Operands must be a number");
	}

	Variant lookUpVariable(Token name, Expr expr)
	{
		if (expr in locals)
			return env.getAt(locals[expr], name.lexeme);
		else
			return globals.get(name);
	}
}

private:
string stringify(Variant variant)
{
	if (variant.type == typeid(null))
		return "nil";
	if (variant.type == typeid(double))
	{
		import std.string : endsWith, format;

		string text = variant.get!double
			.format!"%g";
		if (text.endsWith(".0"))
		{
			text = text[0 .. $ - 2];
		}

		return text;
	}

	return variant.toString();
}
