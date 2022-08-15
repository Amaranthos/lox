module jlox.resolver;

import jlox.ast;
import jlox.interpreter : Interpreter;
import jlox.token : Token;

import std.conv : to;
import std.range : popBack, back, empty;

alias ExprVisitor = Expr.Visitor!void;
alias StmtVisitor = Stmt.Visitor!void;

alias Map = bool[string];

private enum FunctionType
{
	None,
	Func,
	Init,
	Method,
}

private enum ClassType
{
	None,
	Class,
	Subclass
}

class Resolver : ExprVisitor, StmtVisitor
{
	private Interpreter interpreter;
	private Map[] scopes;
	private FunctionType currentFunc = FunctionType.None;
	private ClassType currentClass = ClassType.None;

	this(Interpreter interpreter)
	{
		this.interpreter = interpreter;
	}

	void resolve(Stmt[] stmts)
	{
		foreach (stmt; stmts)
		{
			resolve(stmt);
		}
	}

	void visit(Block stmt)
	{
		beginScope();
		resolve(stmt.statements);
		endScope();
	}

	void visit(Class stmt)
	{
		auto enclosingClass = currentClass;
		currentClass = ClassType.Class;

		declare(stmt.name);
		define(stmt.name);

		if (stmt.superclass)
		{
			if (stmt.name.lexeme == stmt.superclass.name.lexeme)
			{
				import jlox.errors : error;

				error(stmt.superclass.name, "A class can't inherit from itself");
			}
			else
			{
				currentClass = ClassType.Subclass;
				resolve(stmt.superclass);
				beginScope();
				scopes.back["super"] = true;
			}
		}

		beginScope();
		scopes.back["this"] = true;

		foreach (method; stmt.methods)
		{
			resolveFunc(method, method.name.lexeme == "init" ? FunctionType.Init
					: FunctionType.Method);
		}

		endScope();

		if (stmt.superclass)
			endScope();

		currentClass = enclosingClass;
	}

	void visit(Expression stmt)
	{
		resolve(stmt.expression);
	}

	void visit(Function stmt)
	{
		declare(stmt.name);
		define(stmt.name);

		resolveFunc(stmt, FunctionType.Func);
	}

	void visit(If stmt)
	{
		resolve(stmt.condition);
		resolve(stmt.thenBranch);
		if (stmt.elseBranch)
			resolve(stmt.elseBranch);
	}

	void visit(Print stmt)
	{
		resolve(stmt.expression);
	}

	void visit(Return stmt)
	{
		import jlox.errors : error;

		if (currentFunc == FunctionType.None)
		{

			error(stmt.keyword, "Can't return from global scope");
		}

		if (stmt.value)
		{
			if (currentFunc == FunctionType.Init)
				error(stmt.keyword, "Can't return a value from an initializer");
			resolve(stmt.value);
		}
	}

	void visit(Var stmt)
	{
		declare(stmt.name);
		if (stmt.initializer)
			resolve(stmt.initializer);

		define(stmt.name);
	}

	void visit(While stmt)
	{
		resolve(stmt.condition);
		resolve(stmt.body);
	}

	void visit(Assign expr)
	{
		resolve(expr.value);
		resolveLocal(expr, expr.name);
	}

	void visit(Binary expr)
	{
		resolve(expr.left);
		resolve(expr.right);
	}

	void visit(Call expr)
	{
		resolve(expr.callee);

		foreach (arg; expr.args)
			resolve(arg);
	}

	void visit(Get expr)
	{
		resolve(expr.object);
	}

	void visit(Grouping expr)
	{
		resolve(expr.expression);
	}

	void visit(Literal expr)
	{
		return;
	}

	void visit(Logical expr)
	{
		resolve(expr.left);
		resolve(expr.right);
	}

	void visit(Set expr)
	{
		resolve(expr.value);
		resolve(expr.object);
	}

	void visit(Super expr)
	{
		import jlox.errors : error;

		switch (currentClass) with (ClassType)
		{
		case Subclass:
			break;

		case None:
			error(expr.keyword, "Can't use 'super' outside of a class");
			break;

		default:
			error(expr.keyword, "Can't use 'super' in a class with no superclass");
			break;
		}

		resolveLocal(expr, expr.keyword);
	}

	void visit(This expr)
	{
		if (currentClass == ClassType.None)
		{
			import jlox.errors : error;

			error(expr.keyword, "Can't use 'this' outside of a class");
			return;
		}

		resolveLocal(expr, expr.keyword);
	}

	void visit(Unary expr)
	{
		resolve(expr.right);
	}

	void visit(Variable expr)
	{

		if (!scopes.empty && expr.name.lexeme in scopes.back && scopes.back[expr.name.lexeme] == false)
		{
			import jlox.errors : error;

			error(expr.name, "Can't read local variable in its own initializer");
		}

		resolveLocal(expr, expr.name);
	}

private:
	void beginScope()
	{
		Map newScope;
		scopes ~= newScope;
	}

	void endScope()
	{
		scopes.popBack();
	}

	void declare(Token name)
	{
		if (scopes.empty)
			return;

		auto _scope = scopes.back;

		if (name.lexeme in _scope)
		{
			import jlox.errors : error;

			error(name, "Already a variable with this name in this scope");
		}

		_scope[name.lexeme] = false;
	}

	void define(Token name)
	{
		if (scopes.empty)
			return;
		scopes.back[name.lexeme] = true;
	}

	void resolve(Stmt stmt)
	{
		stmt.accept(this);
	}

	void resolve(Expr expr)
	{
		expr.accept(this);
	}

	void resolveFunc(Function func, FunctionType type)
	{
		FunctionType enclosingFunc = currentFunc;
		currentFunc = type;

		beginScope();
		foreach (param; func.params)
		{
			declare(param);
			define(param);
		}
		resolve(func.body);
		endScope();

		currentFunc = enclosingFunc;
	}

	void resolveLocal(Expr expr, Token name)
	{
		import std.stdio;

		for (long i = scopes.length - 1; i >= 0; --i)
		{
			if (name.lexeme in scopes[i])
			{

				interpreter.resolve(expr, (scopes.length - 1 - i).to!int);
				return;
			}
		}
	}
}
