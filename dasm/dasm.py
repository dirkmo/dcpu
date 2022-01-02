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
        self.start_address = 0x10000
        self.end_address = 0
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
        
        # Create raw memory
        self.data = [-1] * 65536
        for t in tokens:
            entry = t[-1]
            if entry.type in [Instruction.OPCODE, Instruction.DATA]:
                data = entry.data(self.symbols)
                pos = entry.pos
                self.start_address = min(self.start_address, pos)
                for c,d in enumerate(data):
                    self.data[pos+c] = d
                    self.end_address = max(self.end_address, pos+c)

    def write_as_bin(self, fn, endianess='big'):
        with open(fn ,"wb") as f:
            for addr in range(self.start_address, self.end_address + 1):
                d = max(0, self.data[addr])
                f.write(d.to_bytes(2, byteorder=endianess))

    def write_as_memfile(self, fn, endianess='big'):
        with open(fn ,"wt") as f:
            f.write(f"// start_address = 16'h{self.start_address:04x}\n")
            for addr in range(self.start_address, self.end_address + 1):
                d = max(0, self.data[addr])
                f.write(f"{d:04x}")
                if (addr % 8) == 7:
                    f.write("\n")
                else:
                    f.write(" ")

    def write_as_cfile(self, fn, endianess='big'):
        with open(fn ,"wt") as f:
            f.write(f"uint16_t start_address = 0x{self.start_address:04x};\n\n")
            f.write("uint16_t program[] = {\n")
            for addr in range(self.start_address, self.end_address + 1):
                d = max(0, self.data[addr])
                if (addr % 8) == 0:
                    f.write("    ")
                f.write(f"0x{d:04x}, ")
                if (addr % 8) == 7:
                    f.write("\n")
            if ((self.end_address - self.start_address) % 8):
                f.write("\n")
            f.write("};\n")

    def write_as_listing(self, fn, lines, endianess='big'):
        def find_token(line):
            for i,t in enumerate(self.tokens):
                l = t[0].line
                if (line == l) and (t[-1].type in [Instruction.OPCODE, Instruction.DATA]):
                    return t
            return None
        with open(fn ,"wt") as f:
            for i,l in enumerate(lines):
                f.write(f">{l}")
                t = find_token(i+1)
                if t != None:
                    entry = t[-1]
                    data = entry.data(self.symbols)
                    f.write(f"{entry.pos:04x}:")
                    for d in data:
                        f.write(f" {d:04x}")
                    f.write("\n")


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
    program.write_as_memfile(fn_noext+".mem")
    program.write_as_cfile(fn_noext+".c")
    program.write_as_listing(fn_noext+".list", lines)

if __name__ == "__main__":
    sys.exit(main())
