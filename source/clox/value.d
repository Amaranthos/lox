module clox.value;

import clox.obj;

enum ValueType
{
	BOOL,
	NIL,
	NUMBER,
	OBJ
}

version (nan_boxing)
{
	enum ulong QNAN = 0x7ffc000000000000;
	enum ulong SIGN_BIT = 0x8000000000000000;
	enum uint TAG_NIL = 1;
	enum uint TAG_FALSE = 2;
	enum uint TAG_TRUE = 3;

	enum ulong NIL_VAL = QNAN | TAG_NIL;
	enum ulong FALSE_VAL = QNAN | TAG_FALSE;
	enum ulong TRUE_VAL = QNAN | TAG_TRUE;

	struct Value
	{
		ulong v;

		void printValue()
		{
			import core.stdc.stdio : printf;

			if (isBool)
				printf(asBool ? "true" : "false");
			else if (isNil)
				printf("nil");
			else if (isNumber)
				printf("%g", asNumber);
			else if (isObj)
				printObj(this);
		}

		bool equals(Value b)
		{
			if (isNumber && b.isNumber)
			{
				return asNumber == b.asNumber;
			}
			return v == b.v;
		}

		bool isBool() const
		{
			return (v | 1) == TRUE_VAL;
		}

		bool isFalsey() const
		{
			return isNil || (isBool && !asBool);
		}

		bool asBool() const
		in (isBool)
		{
			return v == TRUE_VAL;
		}

		static Value from(bool value)
		{
			return Value(value ? TRUE_VAL : FALSE_VAL);
		}

		bool isNil() const
		{
			return v == (QNAN | TAG_NIL);
		}

		static Value nil()
		{
			return cast(Value)(QNAN | TAG_NIL);
		}

		bool isNumber() const
		{
			return (v & QNAN) != QNAN;
		}

		double asNumber() const
		in (isNumber)
		{
			import core.stdc.string : memcpy;

			double res;
			memcpy(&res, &v, Value.sizeof);
			return res;
		}

		static Value from(double value)
		{
			import core.stdc.string : memcpy;

			Value res;
			memcpy(&res, &value, double.sizeof);
			return res;
		}

		bool isObj() const
		{
			return (v & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT);
		}

		Obj* asObj() const
		in (isObj)
		{
			return cast(Obj*)(v & ~(SIGN_BIT | QNAN));
		}

		static Value from(Obj* value)
		{
			return cast(Value)(SIGN_BIT | QNAN | cast(ulong) value);
		}

		ObjType objType() const
		in (isObj)
		{
			return asObj.type;
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

		bool isClosure()
		{
			return isObjType(ObjType.CLOSURE);
		}

		ObjClosure* asClosure()
		{
			return cast(ObjClosure*) asObj;
		}

		bool isClass()
		{
			return isObjType(ObjType.CLASS);
		}

		ObjClass* asClass()
		{
			return cast(ObjClass*) asObj;
		}

		bool isInstance()
		{
			return isObjType(ObjType.INSTANCE);
		}

		ObjInstance* asInstance()
		{
			return cast(ObjInstance*) asObj;
		}

		bool isBoundMethod()
		{
			return isObjType(ObjType.BOUND_METHOD);
		}

		ObjBoundMethod* asBoundMethod()
		{
			return cast(ObjBoundMethod*) asObj;
		}
	}
}
else
{
	struct Value
	{
		ValueType type;

		union
		{
			bool boolean;
			double number;
			Obj* obj;
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

		bool isClosure()
		{
			return isObjType(ObjType.CLOSURE);
		}

		ObjClosure* asClosure()
		{
			return cast(ObjClosure*) asObj;
		}

		bool isClass()
		{
			return isObjType(ObjType.CLASS);
		}

		ObjClass* asClass()
		{
			return cast(ObjClass*) asObj;
		}

		bool isInstance()
		{
			return isObjType(ObjType.INSTANCE);
		}

		ObjInstance* asInstance()
		{
			return cast(ObjInstance*) asObj;
		}

		bool isBoundMethod()
		{
			return isObjType(ObjType.BOUND_METHOD);
		}

		ObjBoundMethod* asBoundMethod()
		{
			return cast(ObjBoundMethod*) asObj;
		}
	}
}

void printObj(Value value)
{
	import core.stdc.stdio : printf;

	final switch (value.objType) with (ObjType)
	{
	case BOUND_METHOD:
		printFunc(value.asBoundMethod().method.func);
		break;

	case CLASS:
		printf("%s", value.asClass.name.chars);
		break;

	case CLOSURE:
		printFunc(value.asClosure.func);
		break;

	case FUNC:
		printFunc(value.asFunc);
		break;

	case INSTANCE:
		printf("%s instance", value.asInstance.klass.name.chars);
		break;

	case NATIVE:
		printf("<native fn>");
		break;

	case STRING:
		printf("%s", value.asCstring);
		break;

	case UPVALUE:
		printf("upvalue");
		break;
	}
}

void printFunc(ObjFunc* func)
{
	import core.stdc.stdio : printf;

	if (func.name is null)
	{
		printf("<script>");
		return;
	}
	printf("<fn %s>", func.name.chars);
}
