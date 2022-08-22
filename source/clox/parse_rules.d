module clox.parse_rules;

import clox.compiler;
import clox.scanner : Token;

enum Precedence
{
	NONE,
	ASSIGN,
	OR,
	AND,
	EQ,
	COMP,
	TERM,
	FACTOR,
	UNARY,
	CALL,
	PRIMARY
}

alias ParseFn = void function(Parser*);

struct ParseRule
{
	ParseFn prefix;
	ParseFn infix;
	Precedence precedence;
}

ParseRule* getRule(Token.Type type)
{
	return &rules[type];
}

// dfmt off
ParseRule[] rules = [
	Token.Type.LEFT_PAREN:    ParseRule(&grouping, null,    Precedence.NONE),
	Token.Type.RIGHT_PAREN:   ParseRule(null,      null,    Precedence.NONE),
	Token.Type.LEFT_BRACE:    ParseRule(null,      null,    Precedence.NONE),
	Token.Type.RIGHT_BRACE:   ParseRule(null,      null,    Precedence.NONE),
	Token.Type.COMMA:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.DOT:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.MINUS:         ParseRule(&unary,    &binary, Precedence.TERM),
	Token.Type.PLUS:          ParseRule(null,      &binary, Precedence.TERM),
	Token.Type.SEMICOLON:     ParseRule(null,      null,    Precedence.NONE),
	Token.Type.SLASH:         ParseRule(null,      &binary, Precedence.FACTOR),
	Token.Type.STAR:          ParseRule(null,      &binary, Precedence.FACTOR),
	Token.Type.BANG:          ParseRule(null,      null,    Precedence.NONE),
	Token.Type.BANG_EQUAL:    ParseRule(null,      null,    Precedence.NONE),
	Token.Type.EQUAL:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.EQUAL_EQUAL:   ParseRule(null,      null,    Precedence.NONE),
	Token.Type.GREATER:       ParseRule(null,      null,    Precedence.NONE),
	Token.Type.GREATER_EQUAL: ParseRule(null,      null,    Precedence.NONE),
	Token.Type.LESS:          ParseRule(null,      null,    Precedence.NONE),
	Token.Type.LESS_EQUAL:    ParseRule(null,      null,    Precedence.NONE),
	Token.Type.IDENTIFIER:    ParseRule(null,      null,    Precedence.NONE),
	Token.Type.STRING:        ParseRule(null,      null,    Precedence.NONE),
	Token.Type.NUMBER:        ParseRule(&number,   null,    Precedence.NONE),
	Token.Type.AND:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.CLASS:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.ELSE:          ParseRule(null,      null,    Precedence.NONE),
	Token.Type.FALSE:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.FOR:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.FUN:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.IF:            ParseRule(null,      null,    Precedence.NONE),
	Token.Type.NIL:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.OR:            ParseRule(null,      null,    Precedence.NONE),
	Token.Type.PRINT:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.RETURN:        ParseRule(null,      null,    Precedence.NONE),
	Token.Type.SUPER:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.THIS:          ParseRule(null,      null,    Precedence.NONE),
	Token.Type.TRUE:          ParseRule(null,      null,    Precedence.NONE),
	Token.Type.VAR:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.WHILE:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.ERROR:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.EOF:           ParseRule(null,      null,    Precedence.NONE),
];
// dfmt on
