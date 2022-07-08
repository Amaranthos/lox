module jlox.scanner;

import std.conv : to;
import std.stdio : writeln, writefln;

import jlox.errors;
import jlox.token : Token;

// version = verbose;

auto scanTokens(string source)
{

	static struct Scanner
	{
		string source;
		size_t start = 0;
		size_t current = 0;
		size_t line = 1;
		Token token;
		bool eofEmitted = false;

		this(string source)
		{
			this.source = source;

			popFront();
		}

		@property bool empty() const @safe
		{
			return eofEmitted;
		}

		@property Token front()
		{
			version (verbose)
				writefln("front(): %s", token);

			eofEmitted = current == source.length + 1;

			return token;
		}

		void tokenOf(Token.Type type)
		{
			tokenOf(type, null);
		}

		void tokenOf(Token.Type type, string literal)
		{
			version (verbose)
				writefln!"tokenOf(): Token(type: %s, lexeme: %s, literal: %s, line: %s)"(type, source[start .. current], literal, line);
			token = Token(type, source[start .. current], literal, line);
		}

		void tokenOf(Token.Type type, double literal)
		{
			version (verbose)
				writefln!"tokenOf(): Token(type: %s, lexeme: %s, literal: %s, line: %s)"(type, source[start .. current], literal, line);
			token = Token(type, source[start .. current], literal, line);
		}

		void str()
		{
			while (peek() != '"' && !isAtEnd())
			{
				if (peek() == '\n')
					++line;
				advance();
			}

			if (isAtEnd())
			{
				error(line, "Unterminated string");
				return;
			}

			advance();
			tokenOf(Token.Type.STRING, source[start + 1 .. current - 1]);
		}

		void num()
		{
			while (isDigit(peek()))
				advance();

			if (peek() == '.' && isDigit(peekNext()))
			{
				advance();
				while (isDigit(peek()))
					advance();
			}

			tokenOf(Token.Type.NUMBER, source[start .. current].to!double);
		}

		void identifier()
		{
			while (isAlphaNumeric(peek()))
				advance();

			tokenOf(source[start .. current] in keywords ?
					keywords[source[start .. current]] : Token.Type.IDENTIFIER);
		}

		bool match(char expected) pure @safe
		{
			if (isAtEnd())
				return false;
			if (source[current] != expected)
				return false;

			++current;
			return true;
		}

		char advance() @safe
		in (!isAtEnd())
		{
			return source[current++];
		}

		char peek() const pure @safe
		{
			if (isAtEnd())
				return '\0';
			return source[current];
		}

		char peekNext() const pure @safe
		{
			if (current + 1 >= source.length)
				return '\0';
			return source[current + 1];
		}

		Scanner save() const
		{
			return this;
		}

		void popFront()
		{
			if (eofEmitted)
				return;

			start = current;

			if (isAtEnd())
			{
				tokenOf(Token.Type.EOF);
				++current;
				return;
			}

			char c = advance();

			version (verbose)
				writefln!"front(): c: '%c' start: %s current: %s"(c, start, current);

			switch (c) with (Token.Type)
			{
				// dfmt off
			case '(': tokenOf(LEFT_PAREN);  break;
			case ')': tokenOf(RIGHT_PAREN); break;
			case '{': tokenOf(LEFT_BRACE);  break;
			case '}': tokenOf(RIGHT_BRACE); break;
			case ',': tokenOf(COMMA);       break;
			case '.': tokenOf(DOT);         break;
			case '-': tokenOf(MINUS);       break;
			case '+': tokenOf(PLUS);        break;
			case ';': tokenOf(SEMICOLON);   break;
			case '*': tokenOf(STAR);        break;
			// dfmt on

			case '!':
				tokenOf(match('=') ? BANG_EQUAL : BANG);
				break;
			case '=':
				tokenOf(match('=') ? EQUAL_EQUAL : EQUAL);
				break;
			case '<':
				tokenOf(match('=') ? LESS_EQUAL : LESS);
				break;
			case '>':
				tokenOf(match('=') ? GREATER_EQUAL : GREATER);
				break;

			case '/':
				if (match('/'))
				{
					while (peek() != '\n' && !isAtEnd())
					{
						advance();
					}
					popFront();
				}
				else
					tokenOf(SLASH);
				break;

			case '\n':
				++line;
				goto case;
			case ' ':
			case '\r':
			case '\t':
				popFront();
				break;

			case '"':
				str();
				break;

			case '0': .. case '9':
				num();
				break;

			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			case '_':
				identifier();
				break;

			default:
				import std.string : format;

				error(line, source[current].format!"Unexpected character: '%s'");
				break;
			}
		}

		bool isAtEnd() const pure @safe
		{
			return current >= source.length;
		}

		bool isDigit(char c) const pure @safe
		{
			return c >= '0' && c <= '9';
		}

		bool isAlpha(char c) const pure @safe
		{
			return (c >= 'a' && c <= 'z') ||
				(c >= 'A' && c <= 'Z') ||
				c == '_';
		}

		bool isAlphaNumeric(char c) const pure @safe
		{
			return isAlpha(c) || isDigit(c);
		}

		// dfmt off
		static enum Token.Type[string] keywords = [
			"and":    Token.Type.AND,
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

	import std.range : isForwardRange, ElementType;

	static assert(isForwardRange!Scanner && is(ElementType!Scanner : Token));

	return Scanner(source);
}

/*
NOTE: https://forum.dlang.org/post/nyfcolufyurjkwjhwqfm@forum.dlang.org

struct TokenStream
{
	this(SourceBuffer source)
	{
		this.cursor = source.text.ptr;
		advance(this);
	}

	bool empty() const
	{
		return token.type == TokenType.eof;
	}

	ref front() return scope const
	{
		return token;
	}

	void popFront()
	{
		switch (token.type)
		{
		default:
			advance(this);
			break;
		case TokenType.eof:
			break;
		case TokenType.error:
			token.type = TokenType.eof;
			token.lexSpan = LexicalSpan(token.lexSpan.end, token.lexSpan.end);
			break;
		}
	}

	TokenStream save() const
	{
		return this;
	}

private:

	const(char)* cursor;
	Location location;
	Token token;
}
*/
