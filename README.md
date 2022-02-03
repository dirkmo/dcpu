# dcpu
16 Bit Stack Machine

DCPU is a pretty minimal stack processor suitable for executing Forth.
This repo includes the CPU implemented in Verilog, an assembler written in Python and a simulator
written in C/C++ using Verilator.

DCPU has no user accessible registers (except a carry flag register). Instead it uses two stacks (data
stack, return stack). A stack entry is 16-bit wide. All memory accesses are also 16-bit, and the CPU
can access a 16-bit address space of 16-bit words. No 8-bit accesses are possible, this must be handled
in software.

## CPU instructions

### Opcodes overview

Subroutine calls: `0   <addr:15>`

Push 13-bit literal: `100 <imm:13>`

Set upper 8-bit literal: `101 <unused:4> <return:1> <imm:8>`

ALU operations: `110 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>`

Relative jumps: `111 <cond:3> <imm:10>`


### Detailed explanation

__Subroutine calls__

For an efficient subroutine threading Forth, I decided to dedicate half of the instruction space for
calls. These calls can access only the lower part of the address space. For the upper half, an ALU
instruction has to be used.
```
0 <addr:15>
```


Push 13 bit literal on data stack
```
100 <imm:13>
```

Set 8 bit literal to MSB of T
```
101 <unused:4> <return:1> <imm:8>
```

ALU opcodes
```
110 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>
```

Relative jumps
```
111 <cond:3> <imm:10>
```
## Simulator

![Simulator screenshot](doc/sim.png)
