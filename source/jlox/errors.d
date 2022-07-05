module jlox.errors;

bool hadError = false;

void error(size_t line, string message) @safe
{
	report(line, "", message);
}

import jlox.token : Token;

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
