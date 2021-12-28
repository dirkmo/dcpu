#!/usr/bin/env python3
import sys
import os
import lark
import grammar
from Instruction import *

# globals
global symbols
global program
symbols = {}
program = None


class Program:
    def __init__(self, tokens):
        pos = 0
        self.tokens = tokens
        self.symbols = {}
        self.start_address = -1
        self.end_address = -1
        for t in tokens:
            entry = t[-1]
            if entry.type in [Instruction.OPCODE, Instruction.DATA]:
                entry.pos = pos
                pos = pos + entry.len()
            elif entry.type == Instruction.ORG:
                pos = entry.address()
            elif entry.type == Instruction.LABEL:
                self.symbols[entry.label()] = pos
            elif entry.type == Instruction.EQU:
                    self.symbols[entry.name.value] = Instruction.convert_to_number(entry.value.value)
        
        # TODO: Second run to resolve symbols
        self.data = [-1] * 65536
        # TODO: Create raw memory


    def write_as_bin(self, fn, endianess='big'):
        with open(fn ,"wb") as f:
            for addr in range(self.start_address, self.end_address + 1):
                d = self.data[addr]
                if d < 0:
                    d = 0
                f.write(d.to_bytes(2, byteorder=endianess))


class dcpuTransformer(lark.Transformer):

    def op0(self, a):
        a.append(InstructionOp0(a[0]))
        return a

    def op1(self, a):
        a.append(InstructionOp1(a[0], a[1]))
        return a

    def op1_jpbr(self, a):
        a.append(InstructionOp1JpBr(a[0], a[1]))
        return a

    def op2(self, a):
        a.append(InstructionOp2(a[0], a[1], a[2]))
        return a

    def ld(self, a):
        offs = '0'
        if len(a) == 4: offs = a[3].value
        a.append(InstructionLd(a[0], a[1], a[2], offs))
        return a

    def st(self, a):
        if len(a) == 4:
            a.append(InstructionSt(a[0], a[1], a[2], a[3]))
        else:
            a.append(InstructionSt(a[0], a[1], "0", a[2]))
        return a

    def ld_imm(self, a):
        a.append(InstructionLdi(a[0], a[1], a[2]))
        return a

    def reljmp(self, a):
        a.append(InstructionRelJmp(a[0], a[1]))
        return a

    def equ(self, a):
        a.append(DirectiveEqu(a[0], a[1], a[2]))
        return a

    def label(self, a):
        a.append(DirectiveLabel(a[0]))
        return a

    def org(self, a):
        a.append(DirectiveOrg(a[1]))
        return a

    def word(self, a):
        a.append(DirectiveWord(a))
        return a

    def ascii(self, a):
        a.append(DirectiveAscii(a[0], a[1]))
        return a


def write_program_as_memfile(prog, fn, endianess='big'):
    with open(fn ,"wt") as f:
        for c,p in enumerate(prog):
            for d in p.data():
                f.write(f"{d:04x}")
                if (c % 8) == 7:
                    f.write("\n")
                else:
                    f.write(" ")
                c = c + 1

def write_program_as_cfile(prog, fn, endianess='big'):
    with open(fn ,"wt") as f:
        f.write("uint16_t program[] = {\n")
        for c,p in enumerate(prog):
            for d in p.data():
                if (c % 8) == 0:
                    f.write("    ")
                f.write(f"0x{d:04x}, ")
                if (c % 8) == 7:
                    f.write("\n")
                c = c + 1
        if (len(prog) % 8):
            f.write("\n")
        f.write("};")

def write_program_as_hexdump(prog, offset, lines, fn, endianess='big'):
    with open(fn ,"wt") as f:
        for i,p in enumerate(prog):
            addr = offset + i
            l = p.line - 1
            f.write("# " + lines[l].strip() + "\n")
            f.write(f"{addr:04x}: {prog[i].data_hexdump()}\n")

def main():
    print("dasm: Simple dcpu assembler\n")
    l = lark.Lark(grammar.grammar, start = "start")

    if len(sys.argv) < 2:
        print("Usage: dasm.py <asm file input>")
        exit(1)

    try:
        fn = sys.argv[1]
        with open(fn) as f:
            lines = f.readlines()
    except:
        print(f"ERROR: Cannot open file {fn}")
        return 2

    contents = "".join(lines)

    t = l.parse(contents)
    print(t.pretty())
    # print(t)

    n = dcpuTransformer().transform(t)
    print(n)

    for c in n.children:
        print(c)
         

    fn_noext = os.path.splitext(fn)[0]
    program = Program(n.children)

    program.write_as_bin(fn_noext+".bin")
    
    write_program_as_memfile(words, fn_noext+".mem")
    write_program_as_cfile(words, fn_noext+".c")
    write_program_as_hexdump(words, offset, lines, fn_noext+".hexdump")

if __name__ == "__main__":
    sys.exit(main())
