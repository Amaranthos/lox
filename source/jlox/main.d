module jlox.main;

import std.conv : to;
import std.stdio : writeln, writefln;

import jlox.errors;
import jlox.ast_printer;

version (printAST)
{
}
else
{
	int main(string[] args)
	{
		args = args[1 .. $];
		switch (args.length)
		{
		case 0:
			runPrompt();
			break;

		case 1:
			runFile(args[0]);
			break;

		default:
			writeln("Usage: jlox [script]");
			return 64;
		}

		return 0;
	}
}

void runFile(string path)
{
	import std.file : read;

	path
		.read
		.to!string
		.run;

	import core.stdc.stdlib : exit;

	if (hadError)
		exit(65);
}

void runPrompt()
{
	import std.stdio : readln;

	string line;
	while ((line = readln()) !is null)
	{
		line.run;
		hadError = false;
	}
}

void run(string source)
{
	import jlox.scanner : scanTokens;

	foreach (token; source.scanTokens)
	{
		token.writeln;
	}
}
