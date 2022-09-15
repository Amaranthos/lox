module clox.value;

import clox.obj;

enum ValueType
{
	BOOL,
	NIL,
	NUMBER,
	OBJ
}

struct Value
{
	ValueType type;

	union
	{
		bool boolean;
		double number;
		Obj* obj;
	}

	bool equals(Value b)
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
		case OBJ:
			return asString == b.asString;
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

	bool isObj() const
	{
		return type == ValueType.OBJ;
	}

	Obj* asObj()
	in (isObj)
	{
		return obj;
	}

	static Value from(Obj* value)
	{
		Value r = {type: ValueType.OBJ, obj: value};
		return r;
	}

	ObjType objType() const
	in (isObj)
	{
		return obj.type;
	}

	bool isObjType(ObjType type)
	{
		return isObj && asObj.type == type;
	}

	bool isString()
	{
		return isObjType(ObjType.STRING);
	}

	ObjString* asString()
	{
		return cast(ObjString*) asObj;
	}

	char* asCstring()
	{
		return asString.chars;
	}

	bool isFunc()
	{
		return isObjType(ObjType.FUNC);
	}

	ObjFunc* asFunc()
	{
		return cast(ObjFunc*) asObj;
	}

	bool isNative()
	{
		return isObjType(ObjType.NATIVE);
	}

	ObjNative* asNative()
	{
		return cast(ObjNative*) asObj;
	}
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
	case OBJ:
		printObj(value);
		break;
	}
}

void printObj(Value value)
{
	import core.stdc.stdio : printf;

	final switch (value.objType) with (ObjType)
	{
	case FUNC:
		if (value.asFunc.name is null)
		{
			printf("<script>");
			return;
		}
		printf("<fn %s>", value.asFunc.name.chars);
		break;

	case NATIVE:
		printf("<native fn>");
		break;

	case STRING:
		printf("%s", value.asCstring);
		break;
	}
}
