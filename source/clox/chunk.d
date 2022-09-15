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
		constants ~= value;
		return constants.count - 1;
	}
}

void disassemble(Chunk* chunk, in char* name)
{
	printf("== %s == \n", name);

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
	final switch (cast(Op) instr) with (Op)
	{
	case CONSTANT:
		return constInstr(CONSTANT.stringof, chunk, offset);
	case NIL:
		return simpleInstr(NIL.stringof, offset);
	case TRUE:
		return simpleInstr(TRUE.stringof, offset);
	case FALSE:
		return simpleInstr(FALSE.stringof, offset);

	case POP:
		return simpleInstr(POP.stringof, offset);

	case GET_LOCAL:
		return byteInstr(GET_LOCAL.stringof, chunk, offset);
	case SET_LOCAL:
		return byteInstr(SET_LOCAL.stringof, chunk, offset);

	case GET_GLOBAL:
		return constInstr(GET_GLOBAL.stringof, chunk, offset);
	case DEFINE_GLOBAL:
		return constInstr(DEFINE_GLOBAL.stringof, chunk, offset);
	case SET_GLOBAL:
		return constInstr(SET_GLOBAL.stringof, chunk, offset);

	case EQUAL:
		return simpleInstr(EQUAL.stringof, offset);
	case GREATER:
		return simpleInstr(GREATER.stringof, offset);
	case LESS:
		return simpleInstr(LESS.stringof, offset);

	case ADD:
		return simpleInstr(ADD.stringof, offset);
	case SUBTRACT:
		return simpleInstr(SUBTRACT.stringof, offset);
	case MULTIPLY:
		return simpleInstr(MULTIPLY.stringof, offset);
	case DIVIDE:
		return simpleInstr(DIVIDE.stringof, offset);

	case NOT:
		return simpleInstr(NOT.stringof, offset);

	case NEGATE:
		return simpleInstr(NEGATE.stringof, offset);

	case PRINT:
		return simpleInstr(PRINT.stringof, offset);

	case JUMP:
		return jumpInstr(JUMP.stringof, 1, chunk, offset);
	case JUMP_IF_FALSE:
		return jumpInstr(JUMP_IF_FALSE.stringof, 1, chunk, offset);

	case LOOP:
		return jumpInstr(LOOP.stringof, -1, chunk, offset);

	case CALL:
		return byteInstr(CALL.stringof, chunk, offset);

	case RETURN:
		return simpleInstr(RETURN.stringof, offset);
	}
}

int simpleInstr(string name, int offset)
{
	printf("%s\n", name.ptr);
	return offset + 1;
}

int byteInstr(string name, Chunk* chunk, int offset)
{
	ubyte slot = chunk.code[offset + 1];
	printf("%-16s %4d\n", name.ptr, slot);
	return offset + 2;
}

int jumpInstr(string name, int sign, Chunk* chunk, int offset)
{
	ushort jump = cast(ushort)(chunk.code[offset + 1] << 8);
	jump |= chunk.code[offset + 2];
	printf("%-16s %4d -> %d\n", name.ptr, offset, offset + 3 + sign * jump);
	return offset + 3;
}

int constInstr(string name, Chunk* chunk, int offset)
{
	ubyte constIdx = chunk.code[offset + 1];
	printf("%-16s %4d '", name.ptr, constIdx);
	printValue(chunk.constants[constIdx]);
	printf("'\n");
	return offset + 2;
}
