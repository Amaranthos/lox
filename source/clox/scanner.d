module clox.scanner;

struct Scanner
{
	char* start;
	char* current;
	int line;

	Token scanToken()
	{
		skipWhitespace();
		start = current;

		if (isAtEnd())
			return makeToken(Token.EOF);

		char c = advance();

		if (c.isAlpha())
			return identifier();

		if (c.isDigit())
			return number();

		switch (c) with (Token.Type)
		{
		case '(':
			return makeToken(LEFT_PAREN);
		case ')':
			return makeToken(RIGHT_PAREN);
		case '{':
			return makeToken(LEFT_BRACE);
		case '}':
			return makeToken(RIGHT_BRACE);
		case ';':
			return makeToken(SEMICOLON);
		case ',':
			return makeToken(COMMA);
		case '.':
			return makeToken(DOT);
		case '-':
			return makeToken(MINUS);
		case '+':
			return makeToken(PLUS);
		case '/':
			return makeToken(SLASH);
		case '*':
			return makeToken(STAR);

		case '!':
			return makeToken(match('=') ? BANG_EQUAL : BANG);

		case '=':
			return makeToken(match('=') ? EQUAL_EQUAL : EQUAL);

		case '<':
			return makeToken(match('=') ? LESS_EQUAL : LESS);

		case '>':
			return makeToken(match('=') ? GREATER_EQUAL : GREATER);

		case '"':
			return str();

		default:
			break;
		}

		return errorToken("Unexpected character");
	}

	bool isAtEnd()
	{
		return *current == '\0';
	}

	char peek()
	{
		return *current;
	}

	char peekNext()
	{
		if (isAtEnd())
			return '\0';
		return current[1];
	}

	char advance()
	{
		++current;
		return current[-1];
	}

	bool match(char expected)
	{
		if (isAtEnd())
			return false;
		if (*current != expected)
			return false;
		++current;
		return true;
	}

	void skipWhitespace()
	{
		while (true)
		{
			switch (peek())
			{
			case ' ':
			case '\r':
			case '\t':
				advance();
				break;

			case '\n':
				++line;
				advance();
				return;

			case '/':
				if (peekNext() == '/')
					while (peek() != '\n' && !isAtEnd())
						advance();
				else
					return;
				break;

			default:
				return;
			}
		}
	}

	Token identifier()
	{
		while (peek().isAlpha() || peek().isDigit())
			advance();
		return makeToken(identifierType());
	}

	Token.Type identifierType()
	{
		// dfmt off
		switch (start[0]) with (Token.Type)
		{
		case 'a': return checkKeyword(1, 2, "nd", AND);
		case 'c': return checkKeyword(1, 4, "lass", CLASS);
		case 'e': return checkKeyword(1, 3, "lse", ELSE);
		case 'i': return checkKeyword(1, 1, "f", IF);
		case 'n': return checkKeyword(1, 2, "il", NIL);
		case 'o': return checkKeyword(1, 1, "r", OR);
		case 'p': return checkKeyword(1, 4, "rint", PRINT);
		case 'r': return checkKeyword(1, 5, "eturn", RETURN);
		case 's': return checkKeyword(1, 4, "uper", SUPER);
		case 'v': return checkKeyword(1, 2, "ar", VAR);
		case 'w': return checkKeyword(1, 4, "hile", WHILE);

		case 'f':
			if (current - start > 1)
			{
				switch(start[1])
				{
					case 'a': return checkKeyword(2, 3, "lse", FALSE);
					case 'o': return checkKeyword(2, 1, "r", FOR);
					case 'u': return checkKeyword(2, 1, "n", FUN);
					default: break;
				}
			}
			break;

		case 't':
			if (current - start > 1)
			{
				switch(start[1])
				{
					case 'h': return checkKeyword(2, 2, "is", THIS);
					case 'r': return checkKeyword(2, 2, "ue", TRUE);
					default: break;
				}
			}
			break;

		default: break;
		}
		// dfmt on
		return Token.IDENTIFIER;
	}

	Token.Type checkKeyword(int start, int length, const char* rest, Token.Type type)
	{
		import core.stdc.string : memcpy;

		if (this.current - this.start == start + length && memcpy(this.start + start, rest, length) is null)
			return type;
		return Token.IDENTIFIER;
	}

	Token number()
	{
		while (peek().isDigit())
			advance();

		if (peek() == '.' && peekNext().isDigit())
		{
			advance();
			while (peek().isDigit())
				advance();
		}

		return makeToken(Token.NUMBER);
	}

	Token str()
	{
		while (peek() != '"' && !isAtEnd())
		{
			if (peek() == '\n')
				++line;
			advance();
		}

		if (isAtEnd())
			return errorToken("Unterminated string");

		advance();
		return makeToken(Token.STRING);
	}

	Token makeToken(Token.Type type)
	{
		return Token(type, start, current - start, line);
	}

	Token errorToken(const char* msg)
	{
		import core.stdc.string : strlen;

		return Token(Token.ERROR, msg, msg.strlen, line);
	}
}

bool isAlpha(char c)
{
	return c >= 'a' && c <= 'z'
		|| c >= 'A' && c <= 'Z'
		|| c == '_';
}

bool isDigit(char c)
{
	return c >= '0' && c <= '9';
}

struct Token
{
	Type type;
	const(char)* start;
	size_t length;
	int line;

	alias Type this;

	enum Type
	{
		// dfmt off
		LEFT_PAREN, RIGHT_PAREN,
		LEFT_BRACE, RIGHT_BRACE,
		COMMA, DOT, MINUS, PLUS,
		SEMICOLON, SLASH, STAR,

		BANG, BANG_EQUAL,
		EQUAL, EQUAL_EQUAL,
		GREATER, GREATER_EQUAL,
		LESS, LESS_EQUAL,

		IDENTIFIER, STRING, NUMBER,

		AND, CLASS, ELSE, FALSE,
		FOR, FUN, IF, NIL, OR,
		PRINT, RETURN, SUPER, THIS,
		TRUE, VAR, WHILE,

		ERROR, EOF,
		// dfmt on
	}
}
