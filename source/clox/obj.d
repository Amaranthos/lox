module clox.obj;

import clox.memory;
import clox.vm;

enum ObjType
{
	STRING
}

struct Obj
{
	ObjType type;
	Obj* next;

	void free()
	{
		final switch (type) with (ObjType)
		{
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
}

Obj* copyString(VM* vm, const char* chars, size_t length)
{
	import core.stdc.string : memcpy;

	char* heapChars = allocate!char(length + 1);
	memcpy(heapChars, chars, length);
	heapChars[length] = '\0';

	return allocateString(vm, heapChars, length);
}

Obj* takeString(VM* vm, char* chars, size_t length)
{
	return allocateString(vm, chars, length);
}

Obj* allocateString(VM* vm, char* chars, size_t length)
{
	ObjString* str = allocateObj!ObjString(vm, ObjType.STRING);
	str.length = length;
	str.chars = chars;
	return cast(Obj*) str;
}
