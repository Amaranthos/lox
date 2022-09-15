module clox.obj;

import clox.chunk;
import clox.memory;
import clox.value;
import clox.vm;

enum ObjType
{
	FUNC,
	NATIVE,
	STRING,
}

struct Obj
{
	ObjType type;
	Obj* next;

	void free()
	{
		final switch (type) with (ObjType)
		{
		case FUNC:
			ObjFunc* func = cast(ObjFunc*)&this;
			func.chunk.free();
			clox.memory.free!ObjFunc(cast(ObjFunc*)&this);
			break;

		case NATIVE:
			clox.memory.free!ObjNative(cast(ObjNative*)&this);
			break;

		case STRING:
			ObjString* str = cast(ObjString*)&this;
			freeArr(str.chars, str.length + 1);
			clox.memory.free!ObjString(cast(ObjString*)&this);
			break;

		}
	}
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
	Chunk chunk;
	ObjString* name;
}

ObjFunc* allocateFunc(VM* vm)
{
	ObjFunc* func = allocateObj!ObjFunc(vm, ObjType.FUNC);
	func.arity = 0;
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
