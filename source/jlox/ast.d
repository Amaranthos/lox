module jlox.ast;

private:
const baseClassFmt = q{
interface %1$s {
	interface Visitor(T) {
		%2$s
	}
	string accept(Visitor!string visitor);
	Variant accept(Visitor!Variant visitor);
	void accept(Visitor!void visitor);
}
};

const childClassFmt = q{
class %1$s : %2$s {
	%3$s
	this(%4$s) { %5$s }
	string accept(%2$s.Visitor!string visitor) { return visitor.visit(this); }
	Variant accept(%2$s.Visitor!Variant visitor) { return visitor.visit(this); }
	void accept(%2$s.Visitor!void visitor) { return visitor.visit(this); }
}
};

string generateAST(in string baseName, in string[] childernFieldDefinition)
{
	import std.string : format, strip;
	import std.algorithm : map;
	import std.range : join, array, split;

	// dfmt off
	auto childrenFields =
		childernFieldDefinition.
			map!(definition => 
				definition
					.split(":")
					.map!strip
			);

	const string baseClass = format!(baseClassFmt) (
		baseName, 
		childrenFields
			.map!(field => 
				field[0]
					.format!(q{T visit(%s expr);})
			)
			.join("\n\t\t")
	);

	const string childrenClasses =
		childrenFields
			.map!((childFields) {
				auto fields = 
					childFields[1]
						.split(',')
						.map!strip;

				return format!(childClassFmt)(
					childFields[0],
					baseName,
					fields.format!"%-(%s;%| %)",
					childFields[1],
					fields
						.map!((field) =>
							field
								.split(" ")[1]
								.format!(q{this.%1$s = %1$s;})
						)
						.join(' ')
				);
			})
			.join("");
	// dfmt on

	return baseClass ~ childrenClasses;
}

// dfmt off
enum exprString = generateAST("Expr", [
	"Assign   : Token name, Expr value",
	"Binary   : Expr left, Token operator, Expr right",
	"Call     : Expr callee, Token paren, Expr[] args",
	"Grouping : Expr expression",
	"Literal  : Variant value",
	"Logical  : Expr left, Token operator, Expr right",
	"Unary    : Token operator, Expr right",
	"Variable : Token name",
]);

enum stmtString = generateAST("Stmt", [
	"Block      : Stmt[] statements",
	"Expression : Expr expression",
	"Function   : Token name, Token[] params, Stmt[] body",
	"If         : Expr condition, Stmt thenBranch, Stmt elseBranch",
	"Print      : Expr expression",
	"Return     : Token keyword, Expr value",
	"Var        : Token name, Expr initializer",
	"While      : Expr condition, Stmt body"
]);
// dfmt on

// version = printGeneratedAST;
version (printGeneratedAST)
{
	pragma(msg, exprString);
	pragma(msg, stmtString);
}

import std.variant : Variant;
import jlox.token : Token;

public:
mixin(exprString);
mixin(stmtString);
