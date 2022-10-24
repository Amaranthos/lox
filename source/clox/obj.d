module clox.obj;

import clox.chunk;
import clox.memory;
import clox.value;
import clox.vm;

import core.stdc.stdio : printf;

enum ObjType : ushort
{
	BOUND_METHOD,
	CLASS,
	CLOSURE,
	FUNC,
	INSTANCE,
	NATIVE,
	STRING,
	UPVALUE,
}

struct Obj
{
	ulong header;

	ObjType type() const
	{
		return cast(ObjType)((header >> 56) & 0xff);
	}

	bool isMarked() const
	{
		return cast(bool)((header >> 48) & 0x01);
	}

	void isMarked(bool b)
	{
		header = header & 0xff00ffffffffffff | (cast(ulong) b << 48);
	}

	Obj* next()
	{
		return cast(Obj*)((header >> 0) & 0x0000ffffffffffff);
	}

	void next(Obj* o)
	{
		header = header & 0xffff000000000000 | (cast(ulong) o);
	}

	void free()
	{
		debug (log_gc)
			printf("%p free type %d\n", cast(void*)&this, type);

		final switch (type) with (ObjType)
		{
		case BOUND_METHOD:
			freeObj!ObjBoundMethod(&this);
			break;

		case CLASS:
			ObjClass* klass = cast(ObjClass*)(&this);
			klass.methods.free();
			freeObj!ObjClass(&this);
			break;

		case CLOSURE:
			ObjClosure* closure = cast(ObjClosure*)(&this);
			freeObj!ObjClosure(&this);
			freeArr!(ObjUpvalue*)(closure.upvalues, closure.upvalueCount);
			break;

		case FUNC:
			ObjFunc* func = cast(ObjFunc*)&this;
			func.chunk.free();
			freeObj!ObjFunc(&this);
			break;

		case INSTANCE:
			ObjInstance* inst = cast(ObjInstance*)(&this);
			inst.fields.free();
			freeObj!ObjInstance(&this);
			break;

		case NATIVE:
			freeObj!ObjNative(&this);
			break;

		case STRING:
			ObjString* str = cast(ObjString*)&this;
			freeArr(str.chars, str.length + 1);
			freeObj!ObjString(&this);
			break;

		case UPVALUE:
			freeObj!ObjUpvalue(&this);
			break;
		}
	}
}

void freeObj(T)(Obj* ptr)
{
	import clox.memory : free;

	free!T(cast(T*) ptr);
}

T* allocateObj(T)(VM* vm, ObjType type)
{
	Obj* obj = cast(Obj*) reallocate!T(null, 0, T.sizeof);
	obj.header = cast(ulong) vm.objects | cast(ulong) type << 56;
	vm.objects = obj;

	debug (log_gc)
		printf("%p allocate %zu for %d\n", cast(void*) obj, T.sizeof, type);

	return cast(T*) obj;
}

struct ObjString
{
	Obj obj;
	size_t length;
	char* chars;
	uint hash;
}

Obj* copyString(VM* vm, const char* chars, size_t length)
{
	import core.stdc.string : memcpy;

	uint hash = chars.hash(length);
	ObjString* interned = vm.strings.findString(chars, length, hash);
	if (interned)
		return cast(Obj*) interned;

	char* heapChars = allocate!char(length + 1);
	memcpy(heapChars, chars, length);
	heapChars[length] = '\0';

	return allocateString(vm, heapChars, length, hash);
}

Obj* takeString(VM* vm, char* chars, size_t length)
{
	uint hash = chars.hash(length);
	ObjString* interned = vm.strings.findString(chars, length, hash);
	if (interned)
	{
		freeArr(chars, length + 1);
		return cast(Obj*) interned;
	}

	return allocateString(vm, chars, length, hash);
}

Obj* allocateString(VM* vm, char* chars, size_t length, uint hash)
{
	ObjString* str = allocateObj!ObjString(vm, ObjType.STRING);
	str.length = length;
	str.chars = chars;
	str.hash = hash;

	vm.stack.push(Value.from(cast(Obj*) str));
	vm.strings.set(str, Value.nil());
	vm.stack.pop();

	return cast(Obj*) str;
}

uint hash(in char* chars, size_t length)
{
	uint hash = 2_166_136_261u;
	foreach (idx; 0 .. length)
	{
		hash ^= chars[idx];
		hash *= 16_777_619;
	}
	return hash;
}

struct ObjFunc
{
	Obj obj;
	int arity;
	int upvalueCount;
	Chunk chunk;
	ObjString* name;
}

ObjFunc* allocateFunc(VM* vm)
{
	ObjFunc* func = allocateObj!ObjFunc(vm, ObjType.FUNC);
	func.arity = 0;
	func.upvalueCount = 0;
	func.name = null;
	func.chunk = Chunk.init;
	return func;
}

alias NativeFn = Value function(int, Value*);

struct ObjNative
{
	Obj obj;
	NativeFn func;
}

ObjNative* allocateNative(VM* vm, NativeFn func)
{
	ObjNative* native = allocateObj!ObjNative(vm, ObjType.NATIVE);
	native.func = func;
	return native;
}

struct ObjClosure
{
	Obj obj;
	ObjFunc* func;
	ObjUpvalue** upvalues;
	int upvalueCount;
}

ObjClosure* allocateClosure(VM* vm, ObjFunc* func)
{
	ObjUpvalue** upvalues = allocate!(ObjUpvalue*)(func.upvalueCount);
	foreach (ref uv; upvalues[0 .. func.upvalueCount])
		uv = null;

	ObjClosure* closure = allocateObj!ObjClosure(vm, ObjType.CLOSURE);
	closure.func = func;
	closure.upvalues = upvalues;
	closure.upvalueCount = func.upvalueCount;
	return closure;
}

struct ObjUpvalue
{
	Obj obj;
	Value* location;
	Value closed;
	ObjUpvalue* next;
}

ObjUpvalue* allocateUpvalue(VM* vm, Value* slot)
{
	ObjUpvalue* upvalue = allocateObj!ObjUpvalue(vm, ObjType.UPVALUE);
	upvalue.closed = Value.nil;
	upvalue.location = slot;
	upvalue.next = null;
	return upvalue;
}

struct ObjClass
{
	Obj obj;
	ObjString* name;
	Table methods;
}

ObjClass* allocateClass(VM* vm, ObjString* name)
{
	ObjClass* klass = allocateObj!ObjClass(vm, ObjType.CLASS);
	klass.name = name;
	klass.methods = Table();

	return klass;
}

import clox.table;

struct ObjInstance
{
	Obj obj;
	ObjClass* klass;
	Table fields;
}

ObjInstance* allocateInstance(VM* vm, ObjClass* klass)
{
	ObjInstance* inst = allocateObj!ObjInstance(vm, ObjType.INSTANCE);
	inst.klass = klass;
	inst.fields = Table();

	return inst;
}

struct ObjBoundMethod
{
	Obj obj;
	Value receiver;
	ObjClosure* method;
}

ObjBoundMethod* allocateBoundMethod(VM* vm, Value receiver, ObjClosure* method)
{
	ObjBoundMethod* bound = allocateObj!ObjBoundMethod(vm, ObjType.BOUND_METHOD);
	bound.receiver = receiver;
	bound.method = method;

	return bound;
}
