module jlox.errors;

import jlox.token : Token;

bool hadError = false;
bool hadRuntimeError = false;

void error(size_t line, string message) @safe
{
	report(line, "", message);
}

void error(Token token, string message) @safe
{
	if (token.type == Token.Type.EOF)
	{
		report(token.line, " at end", message);
	}
	else
	{
		report(token.line, " at '" ~ token.lexeme ~ "'", message);
	}
}

void report(size_t line, string where, string message) @safe
{
	import std.stdio : writefln;

	writefln!"(%s): Error%s: %s"(line, where, message);
	hadError = true;
}

class RuntimeException : Exception
{
	Token token;

	this(Token token, string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
	{
		super(msg, file, line, nextInChain);
		this.token = token;
	}
}

void runtimeError(RuntimeException e)
{
	import std.stdio : writefln;

	writefln!"RuntimeError[line %s]: %s"(e.token.line, e.message());
	hadRuntimeError = true;
}
