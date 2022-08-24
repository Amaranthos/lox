module clox.compiler;

import core.stdc.stdio : printf;

import clox.chunk;
import clox.obj;
import clox.opcode;
import clox.parse_rules;
import clox.scanner;
import clox.value;
import clox.vm;

bool compile(VM* vm, char* source, Chunk* chunk)
{
	Scanner scanner = Scanner(source, source, 1);
	Parser parser = Parser(&scanner, vm, chunk);

	parser.advance();
	(&parser).expression();
	parser.consume(Token.EOF, "Expect end of expression");

	parser.end();

	return !parser.hadError;
}

struct Parser
{
	Scanner* scanner;
	VM* vm;

	Chunk* compilingChunk;

	Token current;
	Token previous;

	bool hadError;
	bool panicMode;

	void consume(Token.Type type, const char* msg)
	{
		if (current.type == type)
		{
			advance();
			return;
		}

		errorAtCurrent(msg);
	}

	void advance()
	{
		previous = current;

		while (true)
		{
			current = scanner.scanToken();
			if (current.type != Token.ERROR)
				break;
			errorAtCurrent(current.start);
		}
	}

	void end()
	{
		emitReturn();

		debug (print)
		{
			if (!hadError)
				compilingChunk.disassemble("code");
		}
	}

	void emitConstant(Value value)
	{
		emitBytes(Op.CONSTANT, makeConstant(value));
	}

	ubyte makeConstant(Value value)
	{
		size_t constant = compilingChunk.addConstant(value);
		if (constant > ubyte.max)
		{
			error("Too many constants in one chunk");
			return 0;
		}

		return cast(ubyte) constant;
	}

	void emitReturn()
	{
		emitByte(Op.RETURN);
	}

	void emitByte(ubyte b)
	{
		compilingChunk.write(b, previous.line);
	}

	void emitBytes(ubyte b1, ubyte b2)
	{
		emitByte(b1);
		emitByte(b2);
	}

	void error(const char* msg)
	{
		errorAt(&previous, msg);
	}

	void errorAtCurrent(const char* msg)
	{
		errorAt(&current, msg);
	}

	void errorAt(Token* token, const char* msg)
	{
		if (panicMode)
			return;

		panicMode = true;
		import core.stdc.stdio : fprintf, stderr;

		fprintf(stderr, "[line %d] Error", token.line);

		if (token.type == Token.EOF)
			fprintf(stderr, " at end");
		else if (token.type == Token.ERROR)
		{
		}
		else
			fprintf(stderr, " at '%.*s'", cast(int) token.length, token.start);

		fprintf(stderr, ": %s\n", msg);
		hadError = true;
	}
}

void binary(Parser* parser)
{
	Token.Type operatorType = parser.previous.type;
	ParseRule* rule = getRule(operatorType);
	parsePrecedence(parser, cast(Precedence)(rule.precedence + 1));

	switch (operatorType)
	{
	case Token.BANG_EQUAL:
		parser.emitBytes(Op.EQUAL, Op.NOT);
		break;
	case Token.EQUAL_EQUAL:
		parser.emitByte(Op.EQUAL);
		break;
	case Token.GREATER:
		parser.emitByte(Op.GREATER);
		break;
	case Token.GREATER_EQUAL:
		parser.emitBytes(Op.LESS, Op.NOT);
		break;
	case Token.LESS:
		parser.emitByte(Op.LESS);
		break;
	case Token.LESS_EQUAL:
		parser.emitBytes(Op.GREATER, Op.NOT);
		break;

	case Token.PLUS:
		parser.emitByte(Op.ADD);
		break;
	case Token.MINUS:
		parser.emitByte(Op.SUBTRACT);
		break;
	case Token.STAR:
		parser.emitByte(Op.MULTIPLY);
		break;
	case Token.SLASH:
		parser.emitByte(Op.DIVIDE);
		break;
	default:
		return;
	}
}

void grouping(Parser* parser)
{
	expression(parser);
	parser.consume(Token.RIGHT_PAREN, "Expect ')' after expression");
}

void number(Parser* parser)
{
	import core.stdc.stdlib : strtod;

	parser.emitConstant(Value.from(strtod(parser.previous.start, null)));
}

void str(Parser* parser)
{
	parser.emitConstant(Value.from(copyString(parser.vm, parser.previous.start + 1, parser.previous.length - 2)));
}

void unary(Parser* parser)
{
	Token.Type operatorType = parser.previous.type;

	parsePrecedence(parser, Precedence.UNARY);

	switch (operatorType)
	{
	case Token.BANG:
		parser.emitByte(Op.NOT);
		break;
	case Token.MINUS:
		parser.emitByte(Op.NEGATE);
		break;
	default:
		return;
	}
}

void parsePrecedence(Parser* parser, Precedence precedence)
{
	parser.advance();

	ParseFn prefixRule = getRule(parser.previous.type).prefix;
	if (prefixRule is null)
	{
		parser.error("Expect expression");
		return;
	}

	prefixRule(parser);

	while (precedence <= getRule(parser.current.type).precedence)
	{
		parser.advance();
		ParseFn infixRule = getRule(parser.previous.type).infix;
		infixRule(parser);
	}
}

void expression(Parser* parser)
{
	parsePrecedence(parser, Precedence.ASSIGN);
}
