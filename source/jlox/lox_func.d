module jlox.lox_func;

import jlox.ast : Function;
import jlox.env : Env;
import jlox.interpreter : Interpreter;
import jlox.lox_inst;

import std.variant : Variant;

import jlox.callable;

class LoxFunc : Callable
{
	private Function declaration;
	private Env closure;
	private bool isInitializer;

	this(Function declaration, Env closure, bool isInitializer = false)
	{
		this.declaration = declaration;
		this.closure = closure;
		this.isInitializer = isInitializer;
	}

	LoxFunc bind(LoxInst inst)
	{
		Env env = new Env(closure);
		env.define("this", Variant(inst));
		return new LoxFunc(declaration, env, isInitializer);
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
			if (isInitializer)
				return closure.getAt(0, "this");

			return returnValue.value;
		}

		if (isInitializer)
			return closure.getAt(0, "this");

		return Variant(null);
	}

	override string toString() const
	{
		import std.format : format;

		return declaration.name.lexeme.format!"<fun %s>";
	}
}
