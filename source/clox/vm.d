module clox.vm;

import core.stdc.stdio;

import clox.chunk;
import clox.memory;
import clox.obj;
import clox.opcode;
import clox.stack;
import clox.table;
import clox.value;

public VM* vm;

struct Callframe
{
	ObjClosure* closure;
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
	ObjUpvalue* openUpvalues;
	Obj* objects;

	size_t bytesAllocated;
	size_t nextGC = 1024 * 1024;

	size_t grayCount;
	size_t grayCap;
	Obj** grayStack;

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

		import core.stdc.stdlib : free;

		free(grayStack);
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
		ObjClosure* closure = allocateClosure(&this, func);
		stack.pop();
		stack.push(Value.from(cast(Obj*) closure));
		call(closure, 0);

		return run();
	}

	InterpretResult run()
	{
		Callframe* frame = &frames[frameCount - 1];

		// dfmt off
		ubyte READ_BYTE() { return (*frame.ip++); }
		ushort READ_SHORT() { frame.ip += 2; return cast(ushort)((frame.ip[-2] << 8) | frame.ip[-1]); }
		Value READ_CONSTANT() { return frame.closure.func.chunk.constants[READ_BYTE()]; }
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
				disassemble(&frame.closure.func.chunk, cast(int)(
						frame.ip - frame.closure.func.chunk.code));
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
					runtimeError("Undefined variable '%s'", name.chars);
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

			case GET_UPVALUE:
				ubyte slot = READ_BYTE();
				stack.push(*frame.closure.upvalues[slot].location);
				break;
			case SET_UPVALUE:
				ubyte slot = READ_BYTE();
				*frame.closure.upvalues[slot].location = stack.peek(0);
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
			case CLOSURE:
				ObjFunc* func = READ_CONSTANT().asFunc();
				ObjClosure* closure = allocateClosure(&this, func);
				stack.push(Value.from(cast(Obj*) closure));

				foreach (ref upvalue; closure.upvalues[0 .. closure.upvalueCount])
				{
					ubyte isLocal = READ_BYTE();
					ubyte idx = READ_BYTE();
					upvalue = isLocal ? captureUpvalue(frame.slots + idx)
						: frame.closure.upvalues[idx];
				}
				break;

			case CLOSE_UPVALUE:
				closeUpvalues(stack.back - 1);
				stack.pop();
				break;

			case RETURN:
				Value result = stack.pop();
				closeUpvalues(frame.slots);
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
			case CLOSURE:
				return call(callee.asClosure, arity);
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

	ObjUpvalue* captureUpvalue(Value* local)
	{
		ObjUpvalue* prevUpvalue;
		ObjUpvalue* upvalue = openUpvalues;

		while (upvalue && upvalue.location > local)
		{
			prevUpvalue = upvalue;
			upvalue = upvalue.next;
		}

		if (upvalue && upvalue.location == local)
		{
			return upvalue;
		}

		auto result = allocateUpvalue(&this, local);
		result.next = upvalue;

		if (prevUpvalue is null)
			openUpvalues = result;
		else
			prevUpvalue.next = result;

		return result;
	}

	void closeUpvalues(Value* last)
	{
		while (openUpvalues && openUpvalues.location >= last)
		{
			ObjUpvalue* upvalue = openUpvalues;
			upvalue.closed = *upvalue.location;
			upvalue.location = &upvalue.closed;
			openUpvalues = upvalue.next;
		}
	}

	bool call(ObjClosure* closure, ubyte arity)
	{
		if (arity != closure.func.arity)
		{
			runtimeError("Expected %d arguments but got %d", closure.func.arity, arity);
			return false;
		}

		if (frameCount == FRAMES_MAX)
		{
			runtimeError("Stack overflow");
			return false;
		}

		Callframe* frame = &frames[frameCount++];
		frame.closure = closure;
		frame.ip = closure.func.chunk.code;
		frame.slots = stack.back - arity - 1;
		return true;
	}

	void concatenate()
	{
		import core.stdc.string : memcpy;

		ObjString* b = stack.peek(0).asString;
		ObjString* a = stack.peek(1).asString;

		size_t length = a.length + b.length;
		char* chars = allocate!char(length + 1);

		memcpy(chars, a.chars, a.length);
		memcpy(chars + a.length, b.chars, b.length);
		chars[length] = '\0';

		Value value = Value.from(takeString(&this, chars, length));
		stack.pop();
		stack.pop();
		stack.push(value);
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
			ObjFunc* func = frame.closure.func;
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
