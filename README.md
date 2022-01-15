# dcpu
16 Bit Stack Machine

This is my attempt of a relatively minimal stack processor suitable for executing Forth.

## Opcodes

Call
0 <addr:15>

Push 13 bit literal on data stack
1 00 <imm:13>

Set 8 bit literal to MSB of T
1 01 <unused:4> <return:1> <imm:8>    imm.h   ; T <- T | imm, return

ALU opcodes
1 10 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>  alu

Relative jumps
1 11 <cond:3> <imm:10>  rjp ; PC <- cond ? PC+imm : PC
