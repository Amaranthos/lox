module clox.opcode;

enum Op : ubyte
{
	CONSTANT,
	NIL,
	TRUE,
	FALSE,
	POP,
	GET_LOCAL,
	SET_LOCAL,
	GET_GLOBAL,
	DEFINE_GLOBAL,
	SET_GLOBAL,
	GET_UPVALUE,
	SET_UPVALUE,
	GET_PROP,
	SET_PROP,
	GET_SUPER,
	EQUAL,
	GREATER,
	LESS,
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	NOT,
	NEGATE,
	PRINT,
	JUMP,
	JUMP_IF_FALSE,
	LOOP,
	CALL,
	INVOKE,
	SUPER_INVOKE,
	CLOSURE,
	CLOSE_UPVALUE,
	RETURN,
	CLASS,
	INHERIT,
	METHOD,
}
