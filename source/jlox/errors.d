module jlox.errors;

bool hadError = false;

void error(size_t line, string message) @safe
{
	report(line, "", message);
}

void report(size_t line, string where, string message) @safe
{
	import std.stdio : writefln;

	writefln!"(%s): Error%s: %s"(line, where, message);
	hadError = true;
}
