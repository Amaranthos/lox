module clox.main;

import core.stdc.stdio : printf;

import clox.chunk;
import clox.opcode;
import clox.vm;

version (printAST)
{
}
else
{
	extern (C) int main(int argc, char** argv)
	{
		VM vm;
		vm.init();

		Chunk chunk;

		size_t constant = chunk.addConstant(1.2);
		chunk.write(Op.CONSTANT, 123);
		chunk.write(cast(ubyte) constant, 123);

		constant = chunk.addConstant(3.4);
		chunk.write(Op.CONSTANT, 123);
		chunk.write(cast(ubyte) constant, 123);

		chunk.write(Op.ADD, 123);

		constant = chunk.addConstant(5.6);
		chunk.write(Op.CONSTANT, 123);
		chunk.write(cast(ubyte) constant, 123);

		chunk.write(Op.DIVIDE, 123);
		chunk.write(Op.NEGATE, 123);

		chunk.write(Op.RETURN, 123);

		vm.interpret(&chunk);

		vm.free();
		chunk.free();

		return 0;
	}
}
