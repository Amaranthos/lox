module clox.memory;

import core.stdc.stdlib : free, exit, realloc;

T* reallocate(T)(T* ptr, size_t prev, size_t next)
{
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
