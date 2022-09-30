module clox.obj;

import clox.chunk;
import clox.memory;
import clox.value;
import clox.vm;

enum ObjType
{
	CLOSURE,
	FUNC,
	NATIVE,
	STRING,
	UPVALUE
}

struct Obj
{
	ObjType type;
	Obj* next;

	void free()
	{
		final switch (type) with (ObjType)
		{
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
	obj.type = type;
	obj.next = vm.objects;
	vm.objects = obj;

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

	vm.strings.set(str, Value.nil());

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
