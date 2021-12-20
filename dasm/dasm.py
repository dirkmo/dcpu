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
    def __init__(self):
        self.program = {}
        self.pos = 0

    def insert(self, data):
        if self.pos in self.program:
            raise ValueError(f"Overlapping data!")
        self.program[self.pos] = data
        self.pos = self.pos + data.len()

    def getOffsetAndWords(self):
        i = 0
        sorted_prog = sorted(self.program)
        pos = sorted_prog[i]
        words = []
        for p in sorted_prog:
            while pos < p:
                words.append(Instruction(pos, lark.lexer.Token("NULL", 0), Instruction.DATA))
                pos = pos + 1
            words.append(self.program[p])
            pos = pos + 1
        return (sorted_prog[0], words)

class dcpuTransformer(lark.Transformer):

    def op0(self, a):
        return InstructionOp0(a[0])

    def op1(self, a):
        return InstructionOp1(a[0], a[1])

    def op1_jpbr(self, a):
        return InstructionOp1JpBr(a[0], a[1])

    def op2(self, a):
        return InstructionOp2(a[0], a[1], a[2])

    def ld(self, a):
        offs = '0'
        if len(a) == 4: offs = a[3].value
        return InstructionLd(a[0], a[1], a[2], offs)

    def st(self, a):
        if len(a) == 4:
            return InstructionSt(a[0], a[1], a[2], a[3])
        else:
            return InstructionSt(a[0], a[1], "0", a[2])

    def ld_imm(self, a):
        return InstructionLdi(a[0], a[1], a[2])

    def reljmp(self, a):
        return InstructionRelJmp(a[0], a[1])

    def equ(self, a):
        return DirectiveEqu(a[0], a[1], a[2])

    def label(self, a):
        return DirectiveLabel(a[0])

    def org(self, a):
        return DirectiveOrg(a[1])

    def word(self, a):
        return DirectiveWord(a)

    def ascii(self, a):
        return DirectiveAscii(a[0], a[1])


def write_program_as_bin(prog, fn, endianess='big'):
    with open(fn ,"wb") as f:
        for p in prog:
            for d in p.data():
                f.write(d.to_bytes(2, byteorder=endianess))

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

    global program
    program = Program()

    n = dcpuTransformer().transform(t)
    print(n)

    for c in n.children:
        print(c)

    fn_noext = os.path.splitext(fn)[0]
    (offset, words) = Program.getOffsetAndWords()

    write_program_as_bin(words, fn_noext+".bin")
    write_program_as_memfile(words, fn_noext+".mem")
    write_program_as_cfile(words, fn_noext+".c")
    write_program_as_hexdump(words, offset, lines, fn_noext+".hexdump")

if __name__ == "__main__":
    sys.exit(main())
