module jlox.token;

import std.variant : Variant;

struct Token
{
	Type type;
	string lexeme;
	Variant literal;
	size_t line;

	this(T)(Token.Type type, string lexeme, T literal, size_t line)
	{
		this.type = type;
		this.lexeme = lexeme;
		this.literal = literal;
		this.line = line;
	}

	// string toString() const
	// {
	// 	import std.string : format;

	// 	switch (type) with (Type)
	// 	{
	// 	case STRING:
	// 		return format!"%s %s %s"(type, lexeme, literal.get!string);
	// 	case NUMBER:
	// 		return format!"%s %s %s"(type, lexeme, literal.get!double);
	// 	default:
	// 		return format!"%s %s"(type, lexeme);
	// 	}
	// }

	enum Type
	{
		// Single-character tokens.
		LEFT_PAREN,
		RIGHT_PAREN,
		LEFT_BRACE,
		RIGHT_BRACE,
		COMMA,
		DOT,
		MINUS,
		PLUS,
		SEMICOLON,
		SLASH,
		STAR,

		// One or two character tokens.
		BANG,
		BANG_EQUAL,
		EQUAL,
		EQUAL_EQUAL,
		GREATER,
		GREATER_EQUAL,
		LESS,
		LESS_EQUAL,

		// Literals.
		IDENTIFIER,
		STRING,
		NUMBER,

		// Keywords.
		AND,
		CLASS,
		ELSE,
		FALSE,
		FUN,
		FOR,
		IF,
		NIL,
		OR,
		PRINT,
		RETURN,
		SUPER,
		THIS,
		TRUE,
		VAR,
		WHILE,

		EOF
	}
}
