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
	Func
}

class Resolver : ExprVisitor, StmtVisitor
{
	private Interpreter interpreter;
	private Map[] scopes;
	private FunctionType currentFunc = FunctionType.None;

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
		if (currentFunc == FunctionType.None)
		{
			import jlox.errors : error;

			error(stmt.keyword, "Can't return from global scope");
		}

		if (stmt.value)
			resolve(stmt.value);
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
		foreach_reverse (idx, _scope; scopes)
		{
			if (name.lexeme in _scope)
			{
				interpreter.resolve(expr, idx.to!int);
				return;
			}
		}
	}
}
