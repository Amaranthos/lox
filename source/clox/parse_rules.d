module clox.parse_rules;

import clox.compiler;
import clox.opcode;
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

alias ParseFn = void function(Parser*, bool);

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
	Token.Type.LEFT_PAREN:    ParseRule(&grouping, &call,   Precedence.CALL),
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
	Token.Type.BANG:          ParseRule(&unary,    null,    Precedence.NONE),
	Token.Type.BANG_EQUAL:    ParseRule(null,      &binary, Precedence.EQ),
	Token.Type.EQUAL:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.EQUAL_EQUAL:   ParseRule(null,      &binary, Precedence.EQ),
	Token.Type.GREATER:       ParseRule(null,      &binary, Precedence.COMP),
	Token.Type.GREATER_EQUAL: ParseRule(null,      &binary, Precedence.COMP),
	Token.Type.LESS:          ParseRule(null,      &binary, Precedence.COMP),
	Token.Type.LESS_EQUAL:    ParseRule(null,      &binary, Precedence.COMP),
	Token.Type.IDENTIFIER:    ParseRule(&variable, null,    Precedence.NONE),
	Token.Type.STRING:        ParseRule(&str,      null,    Precedence.NONE),
	Token.Type.NUMBER:        ParseRule(&number,   null,    Precedence.NONE),
	Token.Type.AND:           ParseRule(null,      &and_,   Precedence.NONE),
	Token.Type.CLASS:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.ELSE:          ParseRule(null,      null,    Precedence.NONE),
	Token.Type.FALSE:         ParseRule((Parser* p, bool _) { p.emitByte(Op.FALSE); },  null,    Precedence.NONE),
	Token.Type.FOR:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.FUN:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.IF:            ParseRule(null,      null,    Precedence.NONE),
	Token.Type.NIL:           ParseRule((Parser* p, bool _) { p.emitByte(Op.NIL); },  null,    Precedence.NONE),
	Token.Type.OR:            ParseRule(null,      &or_,    Precedence.NONE),
	Token.Type.PRINT:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.RETURN:        ParseRule(null,      null,    Precedence.NONE),
	Token.Type.SUPER:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.THIS:          ParseRule(null,      null,    Precedence.NONE),
	Token.Type.TRUE:          ParseRule((Parser* p, bool _) { p.emitByte(Op.TRUE); },  null,    Precedence.NONE),
	Token.Type.VAR:           ParseRule(null,      null,    Precedence.NONE),
	Token.Type.WHILE:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.ERROR:         ParseRule(null,      null,    Precedence.NONE),
	Token.Type.EOF:           ParseRule(null,      null,    Precedence.NONE),
];
// dfmt on
