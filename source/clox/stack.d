module clox.stack;

enum STACK_MAX = 256;

struct Stack(T)
{
	T[STACK_MAX] stack = void;
	T* back;

	void clear()
	{
		back = &stack[0];
	}

	T* ptr()
	{
		return &stack[0];
	}

	void push(T value)
	{
		*(back++) = value;
	}

	T pop()
	{
		return *(--back);
	}

	T peek(int dist)
	{
		return back[-1 - dist];
	}
}
