#!/usr/bin/env python3
import sys
import os
import copy
import lark
import grammar

class Instruction:
    opcodes = {
        "RET": 0xd100,
        "JP":  0xd000,
        "JZ":  0xd010,
        "JNZ": 0xd020,
        "JC":  0xd030,
        "JNC": 0xd040,
    }

    @classmethod
    def opcode(cls, t):
        if t[0] in cls.opcodes:
            return cls.opcodes[t[0]]
        return -1
    
    @classmethod
    def regidx(cls, reg):
        r = reg.upper()
        if r == "ST": r = "R13"
        elif r == "SP": r = "R14"
        elif r == "PC": r = "R15"
        if r[0].upper() == 'R':
            n = int(r[1:])
            if n < 0 or n > 15:
                print(f"Invalid register {reg}")
                return -1
        return n
    
    @classmethod
    def add(cls, t):
        op = cls.opcode(cls, t)
        

def convert_to_number(s):
    if s[0] == '$': num = int(s[1:],16)
    elif s[0:1].upper() == "0X": int(s[2:], 16)
    else: num = int(s)
    return num

class dcpuTransformer(lark.Transformer):
    pos = 0
    program = {}
    symbols = {}

    def op0(self, a):
        self.program[self.pos] = Instruction.add([a[0].type])
        self.pos = self.pos + 1
        print(a)
    
    def op1(self, a):
        x = a[0]
        y = a[1]
        print(x.type, x.value)
        print(y.type, y.value)
        self.program[self.pos] = Instruction.add([a[0].type, a[1].type])
        self.pos = self.pos + 1

    def op2(self, a):
        print(a)
    
    def st(self, a):
        print(a)
        pass

    def stoffset(self, a):
        print(a)
        pass

    def st(self, a):
        print(a)
        pass

    def ld(self, a):
        print(a)
        pass

    def ldoffset(self, a):
        print(a)

    def ldimm(self, a):
        print(a)

    def reljmp_label(self, a):
        print(a)

    def relmp_offset(self, a):
        print(a)

    def equ(self, a):
        print(a)

    def org(self, a):
        pos = convert_to_number(a[1])
        print(a)

    def asciiz(self, a):
        print(a)

    def ascii(self, a):
        print(a)

    def word(self, a):
        print(a)
    
    def label(self, a):
        if (a[0].value in self.symbols):
            print(f"Error: Label {a[0].type} already defined")
        self.symbols[a[0].value] = self.pos


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
    # print(t.pretty())
    # print(t)

    n = dcpuTransformer().transform(t)

if __name__ == "__main__":
    sys.exit(main())
