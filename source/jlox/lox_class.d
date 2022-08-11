module jlox.lox_class;

import std.variant : Variant;

import jlox.callable;
import jlox.interpreter;
import jlox.lox_inst;
import jlox.lox_func;

alias Methods = LoxFunc[string];

class LoxClass : Callable
{
	string name;
	private Methods methods;

	this(string name, Methods methods)
	{
		this.name = name;
		this.methods = methods;
	}

	LoxFunc findMethod(in string name)
	{
		if (name in methods)
			return methods[name];

		return null;
	}

	override int arity()
	{
		LoxFunc init = findMethod("init");
		return init ? init.arity() : 0;
	}

	override Variant call(Interpreter interpreter, Variant[] args)
	{
		LoxInst instance = new LoxInst(this);
		LoxFunc init = findMethod("init");
		if (init)
			init.bind(instance).call(interpreter, args);

		return Variant(instance);
	}

	override string toString() const
	{
		return this.name;
	}
}
