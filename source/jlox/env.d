module jlox.env;

import jlox.errors : RuntimeException;
import jlox.token : Token;

import std.variant : Variant;

class Env
{
	Env enclosing = null;
	Variant[string] values;

	this()
	{
	}

	this(Env env)
	{
		this.enclosing = env;
	}

	void define(in string name, Variant value)
	{
		values[name] = value;
	}

	Variant get(Token name)
	{
		if (name.lexeme in values)
		{
			return values[name.lexeme];
		}

		if (enclosing)
		{
			return enclosing.get(name);
		}

		import std.format : format;

		throw new RuntimeException(name, format!"Undefined variable '%s'"(
				name.lexeme));
	}

	Variant getAt(int dist, string name)
	{
		return ancestor(dist).values[name];
	}

	void assign(Token name, Variant value)
	{
		if (name.lexeme in values)
		{
			values[name.lexeme] = value;
			return;
		}

		if (enclosing)
		{
			enclosing.assign(name, value);
			return;
		}

		import std.format : format;

		throw new RuntimeException(name, format!"Undefined variable '%s'"(
				name.lexeme));
	}

	void assignAt(int dist, Token name, Variant value)
	{
		ancestor(dist).values[name.lexeme] = value;
	}

private:
	Env ancestor(int dist)
	{
		Env env = this;
		foreach (_; 0 .. dist)
		{
			env = env.enclosing;
		}
		return env;
	}
}
