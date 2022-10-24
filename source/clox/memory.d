module clox.memory;

import core.stdc.stdio : printf;
import core.stdc.stdlib : exit, free, realloc;

T* reallocate(T)(T* ptr, size_t prev, size_t next)
{
	vm.bytesAllocated += next - prev;

	if (next > prev)
	{
		debug (stress_gc)
		{
			collectGarbage();
		}

		if (vm.bytesAllocated > vm.nextGC)
			collectGarbage();
	}

	if (next == 0)
	{
		free(ptr);
		return null;
	}

	T* mem = cast(T*) realloc(ptr, next);

	if (mem is null)
		exit(1);

	return mem;
}

T* expandArr(T)(T* ptr, size_t prev, size_t next)
{
	return reallocate(ptr, T.sizeof * prev, T.sizeof * next);
}

void freeArr(T)(T* ptr, size_t size)
{
	reallocate(ptr, T.sizeof * size, 0);
}

T* allocate(T)(size_t count)
{
	return cast(T*) reallocate!T(null, 0, T.sizeof * count);
}

void free(T)(T* ptr)
{
	reallocate!T(ptr, T.sizeof, 0);
}

import clox.obj : Obj, ObjUpvalue;
import clox.value;
import clox.vm : VM, vm;

void collectGarbage()
{
	debug (log_gc)
		printf("-- gc begin\n");

	size_t before = vm.bytesAllocated;

	markRoots();
	traceReferences();
	tableRemoveWhite(&vm.strings);
	sweep();

	vm.nextGC = vm.bytesAllocated * 2;

	debug (log_gc)
	{
		printf("-- gc end\n");
		printf("   collected %zu bytes (from %zu to %zu) next at %zu\n\n", before - vm.bytesAllocated, before, vm
				.bytesAllocated, vm.nextGC);
	}
}

void markRoots()
{
	foreach (Value slot; vm.stack)
	{
		markValue(slot);
	}

	foreach (ref callframe; vm.frames)
	{
		markObj(cast(Obj*) callframe.closure);
	}

	for (ObjUpvalue* upvalue = vm.openUpvalues; upvalue; upvalue = upvalue.next)
	{
		markObj(cast(Obj*) upvalue);
	}

	markTable(&vm.globals);

	import clox.compiler : markCompilerRoots;

	markCompilerRoots();
	markObj(cast(Obj*) vm.initString);
}

void traceReferences()
{
	while (vm.grayCount > 0)
	{
		Obj* obj = vm.grayStack[--vm.grayCount];
		blackenObj(obj);
	}
}

void markValue(Value value)
{
	if (value.isObj)
		markObj(value.asObj);
}

import clox.obj;

void blackenObj(Obj* obj)
{
	debug (log_gc)
	{
		printf("%p blacken ", cast(void*) obj);
		Value.from(obj).printValue();
		printf("\n");
	}

	final switch (obj.type) with (ObjType)
	{
	case BOUND_METHOD:
		ObjBoundMethod* bound = cast(ObjBoundMethod*) obj;
		markValue(bound.receiver);
		markObj(cast(Obj*) bound.method);
		break;
	case CLASS:
		ObjClass* klass = cast(ObjClass*) obj;
		markObj(cast(Obj*) klass.name);
		markTable(&klass.methods);
		break;
	case CLOSURE:
		ObjClosure* closure = cast(ObjClosure*) obj;
		markObj(cast(Obj*) closure.func);
		foreach (ref upvalue; closure.upvalues[0 .. closure.upvalueCount])
		{
			markObj(cast(Obj*) upvalue);
		}
		break;
	case FUNC:
		ObjFunc* func = cast(ObjFunc*) obj;
		markObj(cast(Obj*) func.name);
		markArray(&func.chunk.constants);
		break;
	case INSTANCE:
		ObjInstance* inst = cast(ObjInstance*) obj;
		markObj(cast(Obj*) inst.klass);
		markTable(&inst.fields);
		break;
	case UPVALUE:
		markValue((cast(ObjUpvalue*) obj).closed);
		break;
	case NATIVE:
	case STRING:
		break;
	}
}

void markObj(Obj* obj)
{
	if (obj is null)
		return;
	if (obj.isMarked)
		return;

	debug (log_gc)
	{
		printf("%p mark ", cast(void*) obj);
		Value.from(obj).printValue();
		printf("\n");
	}

	obj.isMarked = true;

	if (vm.grayCap < vm.grayCount + 1)
	{
		import clox.array : calcCapacity;

		vm.grayCap = vm.grayCap.calcCapacity;
		vm.grayStack = cast(Obj**) realloc(vm.grayStack, (Obj*).sizeof * vm.grayCount);

		if (vm.grayStack is null)
			exit(1);
	}

	vm.grayStack[vm.grayCount++] = obj;
}

import clox.array;

void markArray(Array!Value* array)
{
	foreach (elem; array.ptr[0 .. array.count])
	{
		markValue(elem);
	}
}

import clox.table : Table;

void markTable(Table* table)
{
	foreach (ref entry; table.entries[0 .. table.count])
	{
		markObj(cast(Obj*) entry.key);
		markValue(entry.value);
	}
}

void tableRemoveWhite(Table* table)
{
	foreach (entry; table.entries[0 .. table.count])
	{
		if (entry.key && !entry.key.obj.isMarked)
			table.remove(entry.key);
	}
}

void sweep()
{
	Obj* prev;
	Obj* next = vm.objects;
	while (next)
	{
		if (next.isMarked)
		{
			next.isMarked = false;
			prev = next;
			next = next.next;
		}
		else
		{
			Obj* unreached = next;
			next = next.next;
			if (prev)
				prev.next = next;
			else
				vm.objects = next;

			unreached.free();
		}
	}
}
