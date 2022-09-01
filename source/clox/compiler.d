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
	Compiler compiler = Compiler();
	Parser parser = Parser(&compiler, &scanner, vm, chunk);

	parser.advance();
	while (!parser.match(Token.EOF))
	{
		declaration(&parser);
	}
	parser.end();

	return !parser.hadError;
}

struct Compiler
{
	Local[ubyte.max + 1] locals;
	int localCount;
	int scopeDepth;
}

struct Local
{
	Token name;
	int depth;
}

struct Parser
{
	Compiler* compiler;
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

		declareVariable();
		if (compiler.scopeDepth > 0)
			return 0;

		return identifierConstant(&previous);
	}

	size_t resolveLocal(Token* name)
	{
		for (int i = compiler.localCount - 1; i >= 0; --i)
		{
			Local* local = &compiler.locals[i];
			if (identifiersEqual(name, &local.name))
			{
				if (local.depth == -1)
					error("Can't read local variable in its own initializer");
				return i;
			}
		}

		return -1;
	}

	ubyte identifierConstant(Token* name)
	{
		return makeConstant(Value.from(copyString(vm, name.start, name.length)));
	}

	void declareVariable()
	{
		if (compiler.scopeDepth == 0)
			return;

		Token* name = &previous;
		for (long i = compiler.localCount - 1; i >= 0; --i)
		{
			Local* local = &compiler.locals[i];
			if (local.depth != -1 && local.depth < compiler.scopeDepth)
				break;

			if (identifiersEqual(name, &local.name))
				error("Already a variable with this name in this scope");
		}

		addLocal(*name);
	}

	void addLocal(Token name)
	{
		if (compiler.localCount == ubyte.max + 1)
		{
			error("Too many local variables in function");
			return;
		}

		Local* local = &compiler.locals[compiler.localCount++];
		local.name = name;
		local.depth = -1;
	}

	void defineVariable(ubyte global)
	{
		if (compiler.scopeDepth > 0)
		{
			markInitialized();
			return;
		}

		emitBytes(Op.DEFINE_GLOBAL, global);
	}

	void markInitialized()
	{
		compiler.locals[compiler.localCount - 1].depth = compiler.scopeDepth;
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

	void emitLoop(int start)
	{
		emitByte(Op.LOOP);

		int offset = cast(int) compilingChunk.count - start + 2;
		if (offset > ushort.max)
			error("Loop body too large");

		emitByte((offset >> 8) & 0xff);
		emitByte(offset & 0xff);
	}

	uint emitJump(ubyte instr)
	{
		emitByte(instr);
		emitByte(0xff);
		emitByte(0xff);
		return cast(int) compilingChunk.count - 2;
	}

	void patchJump(int offset)
	{
		int jump = cast(int) compilingChunk.count - offset - 2;
		if (jump > ushort.max)
			error("Too much code to jump over");

		compilingChunk.code[offset] = (jump >> 8) & 0xff;
		compilingChunk.code[offset + 1] = jump & 0xff;
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
	ubyte getOp, setOp;
	size_t arg = parser.resolveLocal(&name);
	if (arg != -1)
	{
		getOp = Op.GET_LOCAL;
		setOp = Op.SET_LOCAL;
	}
	else
	{
		arg = parser.identifierConstant(&name);
		getOp = Op.GET_GLOBAL;
		setOp = Op.SET_GLOBAL;
	}

	if (canAssign && parser.match(Token.EQUAL))
	{
		expression(parser);
		parser.emitBytes(setOp, cast(ubyte) arg);
	}
	else
		parser.emitBytes(getOp, cast(ubyte) arg);
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

void and_(Parser* parser, bool canAssign)
{
	auto endJump = parser.emitJump(Op.JUMP_IF_FALSE);
	parser.emitByte(Op.POP);
	parsePrecedence(parser, Precedence.AND);
	parser.patchJump(endJump);
}

void or_(Parser* parser, bool canAssign)
{
	auto elseJump = parser.emitJump(Op.JUMP_IF_FALSE);
	auto endJump = parser.emitJump(Op.JUMP);

	parser.patchJump(elseJump);
	parser.emitByte(Op.POP);

	parsePrecedence(parser, Precedence.OR);
	parser.patchJump(endJump);
}

void expression(Parser* parser)
{
	parsePrecedence(parser, Precedence.ASSIGN);
}

void block(Parser* parser)
{
	while (!parser.check(Token.RIGHT_BRACE) && !parser.check(Token.EOF))
		declaration(parser);

	parser.consume(Token.RIGHT_BRACE, "Expect '{' after block");
}

void beginScope(Parser* parser)
{
	++parser.compiler.scopeDepth;
}

void endScope(Parser* parser)
{
	Compiler* compiler = parser.compiler;
	--compiler.scopeDepth;

	while (compiler.localCount > 0 && compiler.locals[compiler.localCount - 1].depth > compiler
		.scopeDepth)
	{
		parser.emitByte(Op.POP);
		--compiler.localCount;
	}
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

void ifStatement(Parser* parser)
{
	parser.consume(Token.LEFT_PAREN, "Expect '(' after 'if'");
	expression(parser);
	parser.consume(Token.RIGHT_PAREN, "Expect ')' after condition expression");

	auto thenJump = parser.emitJump(Op.JUMP_IF_FALSE);
	parser.emitByte(Op.POP);
	statement(parser);

	auto elseJump = parser.emitJump(Op.JUMP);

	parser.patchJump(thenJump);
	parser.emitByte(Op.POP);

	if (parser.match(Token.ELSE))
		statement(parser);

	parser.patchJump(elseJump);
}

void printStatement(Parser* parser)
{
	expression(parser);
	parser.consume(Token.SEMICOLON, "Expect ';' after value");
	parser.emitByte(Op.PRINT);
}

void whileStatement(Parser* parser)
{
	int loopStart = cast(int) parser.compilingChunk.count;
	parser.consume(Token.LEFT_PAREN, "Expect '(' after 'while'");
	expression(parser);
	parser.consume(Token.RIGHT_PAREN, "Expect ')' after condition expression");

	auto exitJump = parser.emitJump(Op.JUMP_IF_FALSE);
	parser.emitByte(Op.POP);
	statement(parser);
	parser.emitLoop(loopStart);

	parser.patchJump(exitJump);
	parser.emitByte(Op.POP);
}

void forStatement(Parser* parser)
{
	beginScope(parser);
	parser.consume(Token.LEFT_PAREN, "Expect '(' after 'for'");
	if (parser.match(Token.SEMICOLON))
	{
		// NOOP
	}
	else if (parser.match(Token.VAR))
		varDeclaration(parser);
	else
		expressionStatement(parser);

	int loopStart = cast(int) parser.compilingChunk.count;
	int exitJump = -1;
	if (!parser.match(Token.SEMICOLON))
	{
		expression(parser);
		parser.consume(Token.SEMICOLON, "Expect ';' after loop condition");
		exitJump = parser.emitJump(Op.JUMP_IF_FALSE);
		parser.emitByte(Op.POP);
	}

	if (!parser.match(Token.RIGHT_PAREN))
	{
		int bodyJump = parser.emitJump(Op.JUMP);
		int incrStart = cast(int) parser.compilingChunk.count;
		expression(parser);
		parser.emitByte(Op.POP);
		parser.consume(Token.RIGHT_PAREN, "Expect ')' after for clauses");
		parser.emitLoop(loopStart);
		loopStart = incrStart;
		parser.patchJump(bodyJump);
	}

	statement(parser);
	parser.emitLoop(loopStart);

	if (exitJump != -1)
	{
		parser.patchJump(exitJump);
		parser.emitByte(Op.POP);
	}

	endScope(parser);
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
	else if (parser.match(Token.IF))
		ifStatement(parser);
	else if (parser.match(Token.WHILE))
		whileStatement(parser);
	else if (parser.match(Token.FOR))
		forStatement(parser);
	else if (parser.match(Token.LEFT_BRACE))
	{
		parser.beginScope();
		block(parser);
		parser.endScope();
	}
	else
		expressionStatement(parser);
}
