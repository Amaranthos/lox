module jlox.lox_func;

import jlox.ast : Function;
import jlox.env : Env;
import jlox.interpreter : Interpreter;

import std.variant : Variant;

interface Callable
{
	int arity();
	Variant call(Interpreter interpreter, Variant[] args);
}

class LoxFunc : Callable
{
	private Function declaration;
	private Env closure;

	this(Function declaration, Env closure)
	{
		this.declaration = declaration;
		this.closure = closure;
	}

	override int arity()
	{
		import std.conv : to;

		return declaration.params.length.to!int;
	}

	override Variant call(Interpreter interpreter, Variant[] args)
	{
		Env env = new Env(closure);
		foreach (idx, param; declaration.params)
		{
			env.define(param.lexeme, args[idx]);
		}

		import jlox.return_exception : ReturnException;

		try
		{
			interpreter.executeBlock(declaration.body, env);
		}
		catch (ReturnException returnValue)
		{
			return returnValue.value;
		}
		return Variant(null);
	}

	override string toString() const
	{
		import std.format : format;

		return declaration.name.lexeme.format!"<fun %s>";
	}
}
