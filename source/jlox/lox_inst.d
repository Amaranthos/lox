module jlox.lox_inst;

import std.variant : Variant;

import jlox.lox_class;
import jlox.lox_func;
import jlox.token : Token;

class LoxInst
{
	private LoxClass klass;
	private Variant[string] fields;

	this(LoxClass klass)
	{
		this.klass = klass;
	}

	Variant get(Token name)
	{
		if (name.lexeme in fields)
			return fields[name.lexeme];

		LoxFunc method = klass.findMethod(name.lexeme);
		if (method)
			return Variant(method.bind(this));

		import std.format : format;
		import jlox.errors : RuntimeException;

		throw new RuntimeException(name, name.lexeme.format!"Undefined property '%s'");
	}

	void set(Token name, Variant value)
	{
		fields[name.lexeme] = value;
	}

	override string toString() const
	{
		return klass.name ~ " instance";
	}
}
