module clox.chunk;

import core.stdc.stdio : printf;

import clox.array;
import clox.memory;
import clox.opcode;
import clox.value;

struct Chunk
{
	Array!Value constants;

	size_t capacity;
	size_t count;
	ubyte* code;
	int* lines;

	void write(ubyte b, int line)
	out (; code[count - 1] == b)
	out (; lines[count - 1] == line)
	{
		if (capacity < count + 1)
		{
			size_t prev = capacity;
			capacity = prev.calcCapacity;
			code = expandArr!ubyte(code, prev, capacity);
			lines = expandArr!int(lines, prev, capacity);
		}

		code[count] = b;
		lines[count] = line;
		++count;
	}

	void free()
	out (; code is null)
	out (; lines is null)
	{
		constants.free();

		freeArr!(ubyte)(code, capacity);
		freeArr!(int)(lines, capacity);

		this = Chunk.init;
	}

	size_t addConstant(Value value)
	out (; constants[constants.count - 1] == value)
	{
		constants.write(value);
		return constants.count - 1;
	}
}

void disassemble(Chunk* chunk, in string name)
{
	printf("== %s == \n", name.ptr);

	for (int offset = 0; offset < chunk.count; offset = disassemble(chunk, offset))
	{
	}
}

int disassemble(Chunk* chunk, int offset)
{
	printf("%04d ", offset);

	if (offset > 0 && chunk.lines[offset] == chunk.lines[offset - 1])
		printf("   | ");
	else
		printf("%4d ", chunk.lines[offset]);

	ubyte instr = chunk.code[offset];
	switch (instr) with (Op)
	{
	case CONSTANT:
		return constInstr(CONSTANT.stringof, chunk, offset);

	case RETURN:
		return simpleInstr(RETURN.stringof, offset);

	default:
		printf("Unknown opcode %d\n", instr);
		return offset + 1;
	}
}

int simpleInstr(string name, int offset)
{
	printf("%s\n", name.ptr);
	return offset + 1;
}

int constInstr(string name, Chunk* chunk, int offset)
{
	ubyte constIdx = chunk.code[offset + 1];
	printf("%-16s %4d '", name.ptr, constIdx);
	printValue(chunk.constants[constIdx]);
	printf("'\n");
	return offset + 2;
}
