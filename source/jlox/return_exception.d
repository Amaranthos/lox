module jlox.return_exception;

import std.variant : Variant;

class ReturnException : Exception
{
	Variant value;

	this(Variant value)
	{
		super("");
		this.value = value;
	}
}
