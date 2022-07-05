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
	static struct Parser
	{
		Range range;
		Token[] tokens;
		size_t idx = 0;

		this(Range tokens)
		{
			import std.range : array;

			this.range = tokens;
			this.tokens = tokens.array;
			this.tokens ~= Token(Token.Type.EOF, "", null, 1);
		}

		Expr parse()
		{
			try
			{
				return expression();
			}
			catch (ParseException e)
			{
				return null;
			}
		}

		Expr expression()
		{
			return equality();
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

			return primary();
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

	return Parser(tokens).parse();
}

private:
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
