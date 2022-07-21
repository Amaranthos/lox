module jlox.parser;

import std.range : isForwardRange, ElementType;

import jlox.ast;
import jlox.token : Token;

template isTokenRange(R)
{
	enum isTokenRange = isForwardRange!R && is(ElementType!R : Token);
}

auto parseTokens(Range)(Range tokens) if (isTokenRange!Range)
{
	return Parser!Range(tokens).parse();
}

private:
static struct Parser(Range)
{
	Range range;
	Token[] tokens;
	size_t idx = 0;

	this(Range tokens)
	{
		import std.range : array;

		this.range = tokens;
		this.tokens = tokens.array;
	}

	Stmt[] parse()
	{
		Stmt[] statements;
		while (!isAtEnd())
			statements ~= declaration();

		return statements;
	}

private:
	Stmt declaration()
	{
		try
		{
			with (Token.Type)
			{
				if (match(FUN))
					return funcDeclaration("function");
				if (match(VAR))
					return varDeclaration();
				return statement();
			}
		}
		catch (ParseException e)
		{
			sync();
			return null;
		}
	}

	Stmt varDeclaration()
	{
		with (Token.Type)
		{
			Token name = consume(IDENTIFIER, "Expect variable name");

			Expr initializer = null;
			if (match(EQUAL))
			{
				initializer = expression();
			}

			consume(SEMICOLON, "Expect ';' after variable declaration");
			return new Var(name, initializer);
		}
	}

	Stmt statement()
	{
		with (Token.Type)
		{
			if (match(FOR))
				return forStatement();
			if (match(IF))
				return ifStatement();
			if (match(PRINT))
				return printStatement();
			if (match(RETURN))
				return returnStatement();
			if (match(WHILE))
				return whileStatement();
			if (match(LEFT_BRACE))
				return new Block(block());

			return expressionStatement();
		}
	}

	Stmt forStatement()
	{
		with (Token.Type)
		{
			consume(LEFT_PAREN, "Expect '(' after 'for'");

			Stmt initializer;
			if (match(SEMICOLON))
				initializer = null;
			else if (match(VAR))
				initializer = varDeclaration();
			else
				initializer = expressionStatement();

			Expr condition = null;
			if (!check(SEMICOLON))
			{
				condition = expression();
			}

			consume(SEMICOLON, "Expect ';' after 'for' condition");

			Expr increment = null;
			if (!check(RIGHT_PAREN))
			{
				increment = expression();
			}

			consume(RIGHT_PAREN, "Expect ')' after 'for' clauses");

			Stmt forBody = statement();

			if (increment)
			{
				forBody = new Block([forBody, new Expression(increment)]);
			}

			if (condition is null)
			{
				import std.variant : Variant;

				condition = new Literal(Variant(true));
			}

			forBody = new While(condition, forBody);

			if (initializer)
				forBody = new Block([initializer, forBody]);

			return forBody;
		}
	}

	Stmt ifStatement()
	{
		with (Token.Type)
		{
			consume(LEFT_PAREN, "Expect '(' after 'if'");
			Expr condition = expression();
			consume(RIGHT_PAREN, "Expect ')' after if condition");

			Stmt thenBranch = statement();
			Stmt elseBranch = match(ELSE) ? statement() : null;

			return new If(condition, thenBranch, elseBranch);
		}
	}

	Stmt printStatement()
	{
		Expr value = expression();
		consume(Token.Type.SEMICOLON, "Expect ';' after value");
		return new Print(value);
	}

	Stmt returnStatement()
	{
		Token keyword = previous();
		Expr value = null;
		if (!check(Token.Type.SEMICOLON))
			value = expression();

		consume(Token.Type.SEMICOLON, "Expect ';' after return value");
		return new Return(keyword, value);
	}

	Stmt whileStatement()
	{
		consume(Token.Type.LEFT_PAREN, "Expect '(' after 'while'");
		Expr condition = expression();
		consume(Token.Type.RIGHT_PAREN, "Expect ')' after condition");
		Stmt body = statement();

		return new While(condition, body);
	}

	Stmt expressionStatement()
	{
		Expr expr = expression();
		consume(Token.Type.SEMICOLON, "Expect ';' after value");
		return new Expression(expr);
	}

	Function funcDeclaration(string kind)
	{
		import std.format : format;

		with (Token.Type)
		{
			Token name = consume(IDENTIFIER, kind.format!"Expect %s name");
			consume(LEFT_PAREN, kind.format!"Expect '(' after %s name");

			Token[] params;
			if (!check(RIGHT_PAREN))
			{
				do
				{
					if (params.length >= 255)
						error(peek(), "Can't have more than 255 parameters");

					params ~= consume(IDENTIFIER, "Expect parameter name");
				}
				while (match(COMMA));
			}

			consume(RIGHT_PAREN, "Expect '(' after parameters");

			consume(LEFT_BRACE, kind.format!"Expect '{' before %s body");
			Stmt[] body = block();

			return new Function(name, params, body);
		}
	}

	Stmt[] block()
	{
		Stmt[] statements;

		with (Token.Type)
		{

			while (!check(RIGHT_BRACE) && !isAtEnd())
			{
				statements ~= declaration();
			}

			consume(RIGHT_BRACE, "Expect '}' after block");
			return statements;
		}
	}

	Expr expression()
	{
		return assignment();
	}

	Expr assignment()
	{
		Expr expr = or();

		with (Token.Type)
		{
			if (match(EQUAL))
			{
				Token equals = previous();
				Expr value = assignment();

				if (cast(Variable) expr)
				{
					Token name = (cast(Variable) expr).name;
					return new Assign(name, value);
				}

				error(equals, "Invalid assignment target");
			}
		}

		return expr;
	}

	Expr or()
	{
		Expr expr = and();
		with (Token.Type)
		{
			while (match(OR))
			{
				Token operator = previous();
				Expr right = and();
				expr = new Logical(expr, operator, right);
			}
		}
		return expr;
	}

	Expr and()
	{
		Expr expr = equality();
		with (Token.Type)
		{
			while (match(AND))
			{
				Token operator = previous();
				Expr right = equality();
				expr = new Logical(expr, operator, right);
			}
		}
		return expr;
	}

	Expr equality()
	{
		Expr expr = comparison();

		with (Token.Type)
		{
			while (match(BANG_EQUAL, EQUAL_EQUAL))
			{
				Token operator = previous();
				Expr right = comparison();
				expr = new Binary(expr, operator, right);
			}
		}

		return expr;
	}

	Expr comparison()
	{
		Expr expr = term();

		with (Token.Type)
		{
			while (match(GREATER, GREATER_EQUAL, LESS, LESS_EQUAL))
			{
				Token operator = previous();
				Expr right = term();
				expr = new Binary(expr, operator, right);
			}
		}

		return expr;
	}

	Expr term()
	{
		Expr expr = factor();

		with (Token.Type)
		{
			while (match(MINUS, PLUS))
			{
				Token operator = previous();
				Expr right = factor();
				expr = new Binary(expr, operator, right);
			}
		}

		return expr;
	}

	Expr factor()
	{
		Expr expr = unary();

		with (Token.Type)
		{
			while (match(SLASH, STAR))
			{
				Token operator = previous();
				Expr right = unary();
				expr = new Binary(expr, operator, right);
			}
		}

		return expr;
	}

	Expr unary()
	{
		with (Token.Type)
		{
			if (match(BANG, MINUS))
			{
				Token operator = previous();
				Expr right = unary();
				return new Unary(operator, right);
			}
		}

		return call();
	}

	Expr call()
	{
		Expr expr = primary();

		with (Token.Type)
		{
			while (true)
			{
				if (match(LEFT_PAREN))
					expr = finishCall(expr);
				else
					break;
			}
		}

		return expr;
	}

	Expr finishCall(Expr callee)
	{
		Expr[] args;
		with (Token.Type)
		{
			if (!check(RIGHT_PAREN))
			{
				do
				{
					if (args.length >= 255)
						error(peek(), "Can't have more than 255 arguments");
					args ~= expression();
				}
				while (match(COMMA));
			}

			Token paren = consume(RIGHT_PAREN, "Expect ')' after arguments");
			return new Call(callee, paren, args);
		}
	}

	Expr primary()
	{
		with (Token.Type)
		{
			import std.variant : Variant;

			// dfmt off
				if (match(FALSE)) return new Literal(Variant(false));
				if (match(TRUE)) return new Literal(Variant(true));
				if (match(NIL)) return new Literal(Variant(null));
				if (match(NUMBER)) return new Literal(Variant(previous().literal.get!double));
				if (match(STRING)) return new Literal(Variant(previous().literal.get!string));
				if (match(IDENTIFIER)) return new Variable(previous());
				// dfmt on

			if (match(LEFT_PAREN))
			{
				Expr expr = expression();
				consume(RIGHT_PAREN, "Expect ')' after expression");
				return new Grouping(expr);
			}

			throw error(peek(), "Expect expression");
		}
	}

	bool match(Token.Type[] types...)
	{
		foreach (type; types)
		{
			if (check(type))
			{
				advance();
				return true;
			}
		}

		return false;
	}

	bool check(Token.Type type)
	{
		if (isAtEnd())
		{
			return false;
		}

		return peek().type == type;
	}

	Token advance()
	{
		if (!isAtEnd())
			++idx;
		return previous();
	}

	bool isAtEnd()
	{
		return peek().type == Token.type.EOF;
	}

	Token peek()
	{
		return tokens[idx];
	}

	Token previous()
	{
		return tokens[idx - 1];
	}

	Token consume(Token.Type type, string message)
	{
		if (check(type))
			return advance();

		throw error(peek(), message);
	}

	void sync()
	{
		advance();

		with (Token.Type)
		{
			while (!isAtEnd())
			{
				if (previous().type == SEMICOLON)
					return;

				switch (peek().type)
				{
				case CLASS:
				case FUN:
				case VAR:
				case FOR:
				case IF:
				case WHILE:
				case PRINT:
				case RETURN:
					return;

				default:
					break;
				}

				advance();
			}
		}
	}
}

ParseException error(Token token, string message)
{
	import jlox.errors : error;

	error(token, message);
	return new ParseException(message);
}

class ParseException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure nothrow @nogc @safe
	{
		super(msg, file, line, nextInChain);
	}
}
