module jlox.callable;

import std.variant : Variant;

import jlox.interpreter : Interpreter;

interface Callable
{
	int arity();
	Variant call(Interpreter interpreter, Variant[] args);
}
