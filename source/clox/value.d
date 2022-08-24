module clox.value;

struct Value
{
	ValueType type;

	union
	{
		bool boolean;
		double number;
	}

	bool equals(in Value b) const
	{
		if (type != b.type)
			return false;

		final switch (type) with (ValueType)
		{
		case BOOL:
			return asBool == b.asBool;
		case NIL:
			return true;
		case NUMBER:
			return asNumber == b.asNumber;
		}
	}

	bool isBool() const
	{
		return type == ValueType.BOOL;
	}

	bool isFalsey() const
	{
		return isNil || (isBool && !asBool);
	}

	bool asBool() const
	in (isBool)
	{
		return boolean;
	}

	static Value from(bool value)
	{
		Value r = {type: ValueType.BOOL, boolean: value};
		return r;
	}

	bool isNil() const
	{
		return type == ValueType.NIL;
	}

	static Value nil()
	{
		Value r = {type: ValueType.NIL, number: 0};
		return r;
	}

	bool isNumber() const
	{
		return type == ValueType.NUMBER;
	}

	double asNumber() const
	in (isNumber)
	{
		return number;
	}

	static Value from(double value)
	{
		Value r = {type: ValueType.NUMBER, number: value};
		return r;
	}

}

enum ValueType
{
	BOOL,
	NIL,
	NUMBER
}

void printValue(Value value)
{
	import core.stdc.stdio : printf;

	final switch (value.type) with (ValueType)
	{
	case BOOL:
		printf(value.asBool ? "true" : "false");
		break;
	case NIL:
		printf("nil");
		break;
	case NUMBER:
		printf("%g", value.asNumber);
		break;
	}
}
