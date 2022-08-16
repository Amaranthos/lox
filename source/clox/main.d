module clox.main;

import core.stdc.stdio : printf;

version (printAST)
{
}
else
{
	extern (C) int main(int argc, char** argv)
	{

		import clox.chunk;
		import clox.opcode;

		Chunk chunk;
		chunk.write(Op.RETURN, 123);

		size_t constant = chunk.addConstant(1.2);
		chunk.write(Op.CONSTANT, 123);
		chunk.write(cast(ubyte) constant, 123);

		disassemble(&chunk, "test chunk");

		chunk.free();

		return 0;
	}
}
