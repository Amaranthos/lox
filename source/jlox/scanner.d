module jlox.scanner;

import std.conv : to;
import std.stdio : writeln, writefln;

import jlox.token : Token;

auto scanTokens(string source)
{
	struct Scanner
	{
		string source;
		size_t start = 0;
		size_t current = 0;
		size_t line = 1;

		@property bool empty() const @safe
		{
			return current >= source.length;
		}

		Token token(Token.Type type)
		{
			return token(type, null);
		}

		Token token(Token.Type type, string literal)
		{
			debug (verbose)
				writefln!"token(): Token(type: %s, lexeme: %s, literal: %s, line: %s)"(type, source[start .. current], literal, line);
			return Token(type, source[start .. current], literal, line);
		}

		Token token(Token.Type type, double literal)
		{
			debug (verbose)
				writefln!"token(): Token(type: %s, lexeme: %s, literal: %s, line: %s)"(type, source[start .. current], literal, line);
			return Token(type, source[start .. current], literal, line);
		}

		Token str()
		{
			while (peek() != '"' && !empty)
			{
				if (peek() == '\n')
					++line;
				advance();
			}

			if (empty)
			{
				import jlox.main : error;

				error(line, "Unterminated string");
				return Token();
			}

			advance();

			return token(Token.Type.STRING, source[start + 1 .. current - 1]);
		}

		Token num()
		{
			while (isDigit(peek()))
				advance();

			if (peek() == '.' && isDigit(peekNext()))
			{
				advance();
				while (isDigit(peek()))
					advance();
			}

			return token(Token.Type.NUMBER, source[start .. current].to!double);
		}

		Token identifier()
		{
			while (isAlphaNumeric(peek()))
				advance();

			return token(source[start .. current] in keywords ?
					keywords[source[start .. current]] : Token.Type.IDENTIFIER);
		}

		bool match(char expected)
		{
			if (empty)
				return false;
			if (source[current] != expected)
				return false;

			++current;
			return true;
		}

		char advance()
		{
			return source[current++];
		}

		char peek()
		{
			if (empty)
				return '\0';
			return source[current];
		}

		char peekNext()
		{
			if (current + 1 >= source.length)
				return '\0';
			return source[current + 1];
		}

		@property Token front()
		{
			char c = advance();

			debug (verbose)
				writefln!"front(): c: %s start: %s current: %s"(c, start, current);

			switch (c) with (Token.Type)
			{
				// dfmt off
			case '(': return token(LEFT_PAREN);
			case ')': return token(RIGHT_PAREN);
			case '{': return token(LEFT_BRACE);
			case '}': return token(RIGHT_BRACE);
			case ',': return token(COMMA);
			case '.': return token(DOT);
			case '-': return token(MINUS);
			case '+': return token(PLUS);
			case ';': return token(SEMICOLON);
			case '*': return token(STAR);
			// dfmt on

			case '!':
				return token(match('=') ? BANG_EQUAL : BANG);
			case '=':
				return token(match('=') ? EQUAL_EQUAL : EQUAL);
			case '<':
				return token(match('=') ? LESS_EQUAL : LESS);
			case '>':
				return token(match('=') ? GREATER_EQUAL : GREATER);

			case '/':
				if (match('/'))
				{
					while (peek() != '\n' && !empty)
					{
						advance();
					}
					return front();
				}
				else
					return token(SLASH);

			case '\n':
				++line;
				goto case;
			case ' ':
			case '\r':
			case '\t':
				popFront();
				return empty ? token(EOF) : front();

			case '"':
				return str();

			case '0': .. case '9':
				return num();

			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			case '_':
				return identifier();

			default:
				import jlox.main : error;
				import std.string : format;

				error(line, source[current].format!"Unexpected character: '%s'");
				return Token();
			}
		}

		void popFront() @safe
		{
			start = current;
		}

		bool isDigit(char c)
		{
			return c >= '0' && c < '9';
		}

		bool isAlpha(char c)
		{
			return (c >= 'a' && c <= 'z') ||
				(c >= 'A' && c <= 'Z') ||
				c == '_';
		}

		bool isAlphaNumeric(char c)
		{
			return isAlpha(c) || isDigit(c);
		}

		// dfmt off
		static enum Token.Type[string] keywords = [
			"and":   Token.Type.AND,
			"class":  Token.Type.CLASS,
			"else":   Token.Type.ELSE,
			"false":  Token.Type.FALSE,
			"for":    Token.Type.FOR,
			"fun":    Token.Type.FUN,
			"if":     Token.Type.IF,
			"nil":    Token.Type.NIL,
			"or":     Token.Type.OR,
			"print":  Token.Type.PRINT,
			"return": Token.Type.RETURN,
			"super":  Token.Type.SUPER,
			"this":   Token.Type.THIS,
			"true":   Token.Type.TRUE,
			"var":    Token.Type.VAR,
			"while":  Token.Type.WHILE,
		];
		// dfmt on
	}

	return Scanner(source);
}
