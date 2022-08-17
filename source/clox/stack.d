module clox.stack;

enum STACK_MAX = 256;

struct Stack(T)
{
	T[STACK_MAX] stack;
	T* back;

	alias stack this;

	void init()
	{
		back = stack.ptr;
	}

	void push(T value)
	{
		*back++ = value;
	}

	T pop()
	{
		return *--back;
	}
}
