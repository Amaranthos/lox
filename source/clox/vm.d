module clox.vm;

import core.stdc.stdio;

import clox.chunk;
import clox.opcode;
import clox.stack;
import clox.value;

struct VM
{
	Chunk* chunk;
	ubyte* ip;
	Stack!(Value) stack;

	void init()
	{
		stack.init();
	}

	void free()
	{

	}

	InterpretResult interpret(char* source)
	{
		import clox.compiler : compile;

		compile(source);
		return InterpretResult.OK;
	}

	InterpretResult interpret(Chunk* chunk)
	{
		this.chunk = chunk;
		this.ip = this.chunk.code;

		return run();
	}

	InterpretResult run()
	{
		while (true)
		{
			debug (trace)
			{
				printf("          ");
				for (Value* slot = stack.ptr; slot < stack.back; ++slot)
				{
					printf("[ ");
					printValue(*slot);
					printf(" ]");
				}
				printf("\n");
				disassemble(chunk, cast(int)(ip - chunk.code));
			}

			Op instr;
			final switch (instr = cast(Op) READ_BYTE()) with (Op)
			{
			case CONSTANT:
				stack.push(READ_CONTSANT());
				break;

			case ADD:
				BINARY_OP!'+'();
				break;
			case SUBTRACT:
				BINARY_OP!'-'();
				break;
			case MULTIPLY:
				BINARY_OP!'*'();
				break;
			case DIVIDE:
				BINARY_OP!'/'();
				break;

			case NEGATE:
				stack.push(-stack.pop());
				break;

			case RETURN:
				printValue(stack.pop());
				printf("\n");
				return InterpretResult.OK;
			}
		}
	}

pragma(inline):
	ubyte READ_BYTE()
	{
		return *(++ip);
	}

pragma(inline):
	Value READ_CONTSANT()
	{
		return chunk.constants[READ_BYTE()];
	}

pragma(inline):
	void BINARY_OP(char op)()
	{
		double b = stack.pop();
		double a = stack.pop();
		stack.push(mixin("a " ~ op ~ " b"));
	}
}

enum InterpretResult
{
	OK,
	COMPILE_ERROR,
	RUNTIME_ERROR
}
