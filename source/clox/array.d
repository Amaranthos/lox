module clox.array;

import clox.memory;

struct Array(T)
{
	size_t capacity;
	size_t count;
	T* ptr;

	ref T opIndex(size_t i)
	{
		return ptr[i];
	}

	ref T opDollar()
	{
		return ptr[count];
	}

	void opOpAssign(string op : "~")(T elem)
	{
		write(elem);
	}

	void write(T elem)
	{
		if (capacity < count + 1)
		{
			size_t prev = capacity;
			capacity = prev.calcCapacity;
			ptr = expandArr!T(ptr, prev, capacity);
		}

		ptr[count++] = elem;
	}

	void free()
	{
		freeArr!T(ptr, capacity);
		this = Array.init;
	}
}

size_t calcCapacity(in size_t current) pure nothrow
{
	return current < 8 ? 8 : current * 2;
}
