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
	while (!parser.match(Token.EOF))
	{
		declaration(&parser);
	}
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

	bool match(Token.Type type)
	{
		if (!check(type))
			return false;
		advance();
		return true;
	}

	bool check(Token.Type type)
	{
		return current.type == type;
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

	ubyte parseVariable(const char* errorMsg)
	{
		consume(Token.IDENTIFIER, errorMsg);
		return identifierConstant(&previous);
	}

	ubyte identifierConstant(Token* name)
	{
		return makeConstant(Value.from(copyString(vm, name.start, name.length)));
	}

	void defineVariable(ubyte global)
	{
		emitBytes(Op.DEFINE_GLOBAL, global);
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

void binary(Parser* parser, bool _)
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

void grouping(Parser* parser, bool _)
{
	expression(parser);
	parser.consume(Token.RIGHT_PAREN, "Expect ')' after expression");
}

void number(Parser* parser, bool _)
{
	import core.stdc.stdlib : strtod;

	parser.emitConstant(Value.from(strtod(parser.previous.start, null)));
}

void str(Parser* parser, bool _)
{
	parser.emitConstant(Value.from(copyString(parser.vm, parser.previous.start + 1, parser.previous.length - 2)));
}

void namedVariable(Parser* parser, Token name, bool canAssign)
{
	ubyte arg = parser.identifierConstant(&name);

	if (canAssign && parser.match(Token.EQUAL))
	{
		expression(parser);
		parser.emitBytes(Op.SET_GLOBAL, arg);
	}
	else
		parser.emitBytes(Op.GET_GLOBAL, arg);
}

void variable(Parser* parser, bool canAssign)
{
	namedVariable(parser, parser.previous, canAssign);
}

void unary(Parser* parser, bool _)
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

	bool canAssign = precedence <= Precedence.ASSIGN;
	prefixRule(parser, canAssign);

	while (precedence <= getRule(parser.current.type).precedence)
	{
		parser.advance();
		ParseFn infixRule = getRule(parser.previous.type).infix;
		infixRule(parser, canAssign);

		if (canAssign && parser.match(Token.EQUAL))
			parser.error("Invalid assignment target");
	}
}

void expression(Parser* parser)
{
	parsePrecedence(parser, Precedence.ASSIGN);
}

void varDeclaration(Parser* parser)
{
	ubyte global = parser.parseVariable("Expect variable name");

	if (parser.match(Token.EQUAL))
		expression(parser);
	else
		parser.emitByte(Op.NIL);

	parser.consume(Token.SEMICOLON, "Expect ';' after variable declaration");

	parser.defineVariable(global);
}

void expressionStatement(Parser* parser)
{
	expression(parser);
	parser.consume(Token.SEMICOLON, "Expect ';' after expression");
	parser.emitByte(Op.POP);
}

void printStatement(Parser* parser)
{
	expression(parser);
	parser.consume(Token.SEMICOLON, "Expect ';' after value");
	parser.emitByte(Op.PRINT);
}

void declaration(Parser* parser)
{
	if (parser.match(Token.VAR))
		varDeclaration(parser);
	else
		statement(parser);

	if (parser.panicMode)
		synchronize(parser);
}

void synchronize(Parser* parser)
{
	parser.panicMode = false;

	while (parser.current.type != Token.EOF)
	{
		if (parser.previous.type == Token.SEMICOLON)
			return;

		switch (parser.current.type)
		{
		case Token.CLASS:
		case Token.FUN:
		case Token.VAR:
		case Token.FOR:
		case Token.IF:
		case Token.WHILE:
		case Token.PRINT:
		case Token.RETURN:
			return;

		default:
			{
				// NOOP
			}
		}
		parser.advance();
	}
}

void statement(Parser* parser)
{
	if (parser.match(Token.PRINT))
		printStatement(parser);
	else
		expressionStatement(parser);
}
