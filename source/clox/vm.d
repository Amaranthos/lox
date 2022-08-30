module clox.vm;

import core.stdc.stdio;

import clox.chunk;
import clox.memory;
import clox.obj;
import clox.opcode;
import clox.stack;
import clox.table;
import clox.value;

struct VM
{
	Chunk* chunk;
	ubyte* ip;
	Stack!(Value) stack;
	Table strings;
	Table globals;
	Obj* objects;

	void init()
	{
		stack.clear();
	}

	void free()
	{
		globals.free();
		strings.free();
		freeObjects();
	}

	void freeObjects()
	{
		Obj* obj = objects;
		while (obj)
		{
			Obj* next = obj.next;
			obj.free();
			obj = next;
		}
	}

	InterpretResult interpret(char* source)
	{
		import clox.compiler : compile;

		Chunk chunk;
		scope (exit)
			chunk.free();

		if (!compile(&this, source, &chunk))
		{
			return InterpretResult.COMPILE_ERROR;
		}

		this.chunk = &chunk;
		this.ip = chunk.code;

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

			Op instr = cast(Op) READ_BYTE();
			final switch (instr) with (Op)
			{
			case CONSTANT:
				stack.push(READ_CONTSANT());
				break;
			case NIL:
				stack.push(Value.nil);
				break;
			case TRUE:
				stack.push(Value.from(true));
				break;
			case FALSE:
				stack.push(Value.from(false));
				break;

			case POP:
				stack.pop();
				break;

			case GET_LOCAL:
				ubyte slot = READ_BYTE();
				stack.push(stack[slot]);
				break;
			case SET_LOCAL:
				ubyte slot = READ_BYTE();
				stack[slot] = stack.peek(0);
				break;

			case GET_GLOBAL:
				ObjString* name = READ_STRING();
				Value value;
				if (!globals.get(name, &value))
				{
					runtimeError("Undefined variable '%s", name.chars);
					return InterpretResult.RUNTIME_ERROR;
				}
				stack.push(value);
				break;
			case DEFINE_GLOBAL:
				ObjString* name = READ_STRING();
				globals.set(name, stack.peek(0));
				stack.pop();
				break;
			case SET_GLOBAL:
				ObjString* name = READ_STRING();
				if (globals.set(name, stack.peek(0)))
				{
					globals.remove(name);
					runtimeError("Undefined variable '%s'", name.chars);
					return InterpretResult.RUNTIME_ERROR;
				}
				break;

			case EQUAL:
				Value b = stack.pop();
				Value a = stack.pop();
				stack.push(Value.from(a.equals(b)));
				break;
			case GREATER:
				mixin(BINARY_OP!'>');
				break;
			case LESS:
				mixin(BINARY_OP!'<');
				break;

			case ADD:
				if (stack.peek(0).isString && stack.peek(1).isString)
				{
					concatenate();
				}
				else if (stack.peek(0).isNumber || stack.peek(1).isNumber)
				{
					double b = stack.pop().asNumber;
					double a = stack.pop().asNumber;

					stack.push(Value.from(a + b));
				}
				else
				{
					runtimeError("Operands must be two numbers or two strings");
					return InterpretResult.RUNTIME_ERROR;
				}

				break;
			case SUBTRACT:
				mixin(BINARY_OP!'-');
				break;
			case MULTIPLY:
				mixin(BINARY_OP!'*');
				break;
			case DIVIDE:
				mixin(BINARY_OP!'/');
				break;

			case NOT:
				stack.push(Value.from(stack.pop().isFalsey));
				break;

			case NEGATE:
				if (!stack.peek(0).isNumber)
				{
					runtimeError("Operand must be a number");
					return InterpretResult.RUNTIME_ERROR;
				}
				stack.push(Value.from(-stack.pop().asNumber));
				break;

			case PRINT:
				printValue(stack.pop());
				printf("\n");
				break;

			case RETURN:
				return InterpretResult.OK;
			}
		}
	}

	void concatenate()
	{
		import core.stdc.string : memcpy;

		ObjString* b = stack.pop().asString;
		ObjString* a = stack.pop().asString;

		size_t length = a.length + b.length;
		char* chars = allocate!char(length + 1);

		memcpy(chars, a.chars, a.length);
		memcpy(chars + a.length, b.chars, b.length);
		chars[length] = '\0';

		stack.push(Value.from(takeString(&this, chars, length)));
	}

	extern (C) void runtimeError(const char* format, ...)
	{
		import core.stdc.stdarg : va_end, va_list, va_start;
		import core.stdc.stdio : fprintf, fputs, stderr, vfprintf;

		va_list args;
		va_start(args, format);
		vfprintf(stderr, format, args);
		va_end(args);
		fputs("\n", stderr);

		size_t instr = ip - chunk.code - 1;
		int line = chunk.lines[instr];
		fprintf(stderr, "[line %d] in script\n", line);

		stack.clear();
	}

pragma(inline):
	ubyte READ_BYTE()
	{
		return *(ip++);
	}

pragma(inline):
	Value READ_CONTSANT()
	{
		return chunk.constants[READ_BYTE()];
	}

pragma(inline):
	ObjString* READ_STRING()
	{
		return chunk.constants[READ_BYTE()].asString;
	}

pragma(inline):
	template BINARY_OP(char op)
	{
		enum BINARY_OP =
			q{
		if (!stack.peek(0).isNumber || !stack.peek(1).isNumber)
		{
			runtimeError("Operands must be numbers");
			return InterpretResult.RUNTIME_ERROR;
		}
		
		double b = stack.pop().asNumber;
		double a = stack.pop().asNumber;
		}
			~
			"stack.push(Value.from(a " ~ op ~ " b));";
	}
}

enum InterpretResult
{
	OK,
	COMPILE_ERROR,
	RUNTIME_ERROR
}
