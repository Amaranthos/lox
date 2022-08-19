module clox.compiler;

import core.stdc.stdio : printf;

import clox.scanner;

void compile(char* source)
{
	Scanner scanner = Scanner(source, source, 1);

	int line = -1;
	while (true)
	{
		Token token = scanner.scanToken();
		if (token.line != line)
		{
			printf("%4d ", token.line);
			line = token.line;
		}
		else
		{
			printf("   | ");
		}

		printf("%2d '%.*s'\n", token.type, cast(int) token.length, token.start);

		if (token.type == Token.EOF)
			break;
	}
}
