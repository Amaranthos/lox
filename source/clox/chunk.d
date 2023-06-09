module clox.chunk;

import core.stdc.stdio : printf;

import clox.array;
import clox.memory;
import clox.obj;
import clox.opcode;
import clox.value;
import clox.vm;

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
		vm.stack.push(value);
		constants ~= value;
		vm.stack.pop();
		return constants.count - 1;
	}
}

void disassemble(Chunk* chunk, in char* name)
{
	printf("== %s == \n", name);

	for (int offset = 0; offset < chunk.count; offset = disassemble(chunk, offset))
	{
	}

	printf("\n");
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

	case GET_UPVALUE:
		return byteInstr(GET_UPVALUE.stringof, chunk, offset);
	case SET_UPVALUE:
		return byteInstr(SET_UPVALUE.stringof, chunk, offset);

	case GET_PROP:
		return byteInstr(GET_PROP.stringof, chunk, offset);
	case SET_PROP:
		return byteInstr(SET_PROP.stringof, chunk, offset);
	case GET_SUPER:
		return constInstr(GET_SUPER.stringof, chunk, offset);

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
	case INVOKE:
		return invokeInstr(INVOKE.stringof, chunk, offset);
	case SUPER_INVOKE:
		return invokeInstr(SUPER_INVOKE.stringof, chunk, offset);
	case CLOSURE:
		++offset;
		ubyte constant = chunk.code[offset++];
		printf("%-16s %4d ", CLOSURE.stringof.ptr, constant);
		chunk.constants[constant].printValue();
		printf("\n");

		ObjFunc* func = chunk.constants[constant].asFunc;
		foreach (_; 0 .. func.upvalueCount)
		{
			ubyte isLocal = chunk.code[offset++];
			ubyte idx = chunk.code[offset++];
			auto str = (isLocal ? "local" : "upvalue");

			printf("%04d      |                     %*s %d\n", offset - 2, cast(int) str.length, str.ptr, idx);
		}

		return offset;

	case CLOSE_UPVALUE:
		return simpleInstr(CLOSE_UPVALUE.stringof, offset);

	case RETURN:
		return simpleInstr(RETURN.stringof, offset);

	case CLASS:
		return constInstr(CLASS.stringof, chunk, offset);
	case INHERIT:
		return simpleInstr(INHERIT.stringof, offset);
	case METHOD:
		return constInstr(METHOD.stringof, chunk, offset);
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
	chunk.constants[constIdx].printValue();
	printf("'\n");
	return offset + 2;
}

int invokeInstr(string name, Chunk* chunk, int offset)
{
	ubyte constant = chunk.code[offset + 1];
	ubyte arity = chunk.code[offset + 2];

	printf("%-16s (%d args) %4d '", name.ptr, arity, constant);
	chunk.constants.ptr[constant].printValue();
	printf("'\n");
	return offset + 3;
}
