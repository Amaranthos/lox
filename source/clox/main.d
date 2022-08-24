module clox.main;

import core.stdc.stdio : fgets, fprintf, printf, stderr, stdin;
import core.stdc.stdlib : exit;

import clox.chunk;
import clox.opcode;
import clox.vm;

version (printAST)
{
}
else
{
	extern (C) int main(int argc, char** argv)
	{
		VM vm;
		scope (exit)
			vm.free();
		vm.init();

		switch (argc)
		{
		case 1:
			repl(&vm);
			break;
		case 2:
			runFile(&vm, argv[1]);
			break;
		default:
			fprintf(stderr, "Usage: clox [path]\n");
			exit(64);
		}

		return 0;
	}
}

void repl(VM* vm)
{
	char[1024] line;
	while (true)
	{
		printf("> ");
		if (!fgets(line.ptr, cast(int) line.arrSize, stdin))
		{
			printf("\n");
			break;
		}
		vm.interpret(line.ptr);
	}
}

void runFile(VM* vm, char* path)
{
	char* source = path.readFile();
	InterpretResult result = vm.interpret(source);
	scope (exit)
	{
		import core.stdc.stdlib : free;

		free(source);
	}

	final switch (result) with (InterpretResult)
	{
	case OK:
		break;
	case COMPILE_ERROR:
		exit(65);
	case RUNTIME_ERROR:
		exit(70);
	}
}

char* readFile(const char* path)
{
	import core.stdc.stdio : fclose, FILE, fopen, fread, fseek, ftell, rewind, SEEK_END;
	import core.stdc.stdlib : malloc;

	FILE* file = fopen(path, "rb");
	scope (exit)
		fclose(file);

	if (file is null)
	{
		fprintf(stderr, "Cound not open file \"%s\".\n", path);
		exit(74);
	}

	fseek(file, 0L, SEEK_END);
	size_t fileSize = ftell(file);
	rewind(file);

	char* buffer = cast(char*) malloc(fileSize + 1);
	if (buffer is null)
	{
		fprintf(stderr, "Not enought memory to read \"%s\". \n", path);
		exit(74);
	}

	size_t bytesRead = fread(buffer, char.sizeof, fileSize, file);
	if (bytesRead < fileSize)
	{
		fprintf(stderr, "Could not read file \"%s\".\n", path);
		exit(74);
	}
	buffer[bytesRead] = '\0';

	return buffer;
}

size_t arrSize(T)(T[] arr)
{
	return T.sizeof * arr.length;
}
