# RAzL – The Rascal Assembler Lab

## Parts

* src/assembler – editor components and tools for universal assembler programming
* src/assembler/z80 – an instantiation for the Z80
* src/basic – editor components and tools for 8-bit BASIC (no generic implementation yet)
* src/basic/zx81 – grammar, editor parts and "compiler" (to token stream / `.p`-file) for ZX81 BASIC
* src/basic/zxPresenter – a small presentation tool based on the zx81 basic implementation
* src/intermediate – editor components and tools for intermediate code representations
   * TAC language with three-address code
   * A virtual machine that can run TAC programs

