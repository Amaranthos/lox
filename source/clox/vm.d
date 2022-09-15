module clox.vm;

import core.stdc.stdio;

import clox.chunk;
import clox.memory;
import clox.obj;
import clox.opcode;
import clox.stack;
import clox.table;
import clox.value;

struct Callframe
{
	ObjFunc* func;
	ubyte* ip;
	Value* slots;
}

enum FRAMES_MAX = 64;

struct VM
{
	Callframe[FRAMES_MAX] frames;
	byte frameCount;

	Stack!(Value) stack;
	Table strings;
	Table globals;
	Obj* objects;

	void init()
	{
		stack.clear();
		frameCount = 0;

		defineNative("clock", &clockNative);
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

		ObjFunc* func = compile(&this, source);
		if (func is null)
			return InterpretResult.COMPILE_ERROR;

		stack.push(Value.from(cast(Obj*) func));
		call(func, 0);

		return run();
	}

	InterpretResult run()
	{
		Callframe* frame = &frames[frameCount - 1];

		// dfmt off
		ubyte READ_BYTE() { return (*frame.ip++); }
		ushort READ_SHORT() { frame.ip += 2; return cast(ushort)((frame.ip[-2] << 8) | frame.ip[-1]); }
		Value READ_CONSTANT() { return frame.func.chunk.constants[READ_BYTE()]; }
		ObjString* READ_STRING() { return READ_CONSTANT().asString; }
		// dfmt on

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
				disassemble(&frame.func.chunk, cast(int)(frame.ip - frame.func.chunk.code));
			}

			final switch (READ_BYTE()) with (Op)
			{
			case CONSTANT:
				stack.push(READ_CONSTANT());
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
				stack.push(frame.slots[slot]);
				break;
			case SET_LOCAL:
				ubyte slot = READ_BYTE();
				frame.slots[slot] = stack.peek(0);
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
				const _a = 1;
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

			case JUMP:
				ushort offset = READ_SHORT();
				frame.ip += offset;
				break;
			case JUMP_IF_FALSE:
				ushort offset = READ_SHORT();
				if (stack.peek(0).isFalsey)
					frame.ip += offset;
				break;

			case LOOP:
				ushort offset = READ_SHORT();
				frame.ip -= offset;
				break;

			case CALL:
				byte arity = READ_BYTE();
				if (!callValue(stack.peek(arity), arity))
					return InterpretResult.RUNTIME_ERROR;
				frame = &frames[frameCount - 1];
				break;

			case RETURN:
				Value result = stack.pop();
				--frameCount;

				if (frameCount == 0)
				{
					stack.pop();
					return InterpretResult.OK;
				}

				stack.back = frame.slots;
				stack.push(result);
				frame = &frames[frameCount - 1];
				break;
			}
		}
	}

	bool callValue(Value callee, ubyte arity)
	{
		if (callee.isObj)
		{
			switch (callee.objType) with (ObjType)
			{
			case FUNC:
				return call(callee.asFunc, arity);
			case NATIVE:
				NativeFn native = callee.asNative.func;
				Value result = native(arity, stack.back - arity);
				stack.back -= arity + 1;
				stack.push(result);
				return true;
			default:
				break;
			}
		}
		runtimeError("Can only call functions and classes");
		return false;
	}

	bool call(ObjFunc* func, ubyte arity)
	{
		if (arity != func.arity)
		{
			runtimeError("Expected %d arguments but got %d", func.arity, arity);
			return false;
		}

		if (frameCount == FRAMES_MAX)
		{
			runtimeError("Stack overflow");
			return false;
		}

		Callframe* frame = &frames[frameCount++];
		frame.func = func;
		frame.ip = func.chunk.code;
		frame.slots = stack.back - arity - 1;
		return true;
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

		for (int i = frameCount - 1; i >= 0; --i)
		{
			Callframe* frame = &frames[i];
			ObjFunc* func = frame.func;
			size_t instr = frame.ip - func.chunk.code - 1;
			fprintf(stderr, "[line %d] in ", func.chunk.lines[instr]);
			if (func.name is null)
			{
				fprintf(stderr, "script\n");
			}
			else
			{
				fprintf(stderr, "%s()\n", func.name.chars);
			}
		}

		stack.clear();
	}

	void defineNative(in string name, NativeFn func)
	{
		stack.push(Value.from(copyString(&this, name.ptr, name.length)));
		stack.push(Value.from(cast(Obj*) allocateNative(&this, func)));
		globals.set(stack.ptr[0].asString, stack.ptr[1]);
		stack.pop();
		stack.pop();
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

Value clockNative(int arity, Value* args)
{
	import core.stdc.time : clock, CLOCKS_PER_SEC;

	return Value.from(cast(double) clock() / CLOCKS_PER_SEC);
}

enum InterpretResult
{
	OK,
	COMPILE_ERROR,
	RUNTIME_ERROR
}
