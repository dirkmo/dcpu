#!/usr/bin/env python3
import sys
import os
import copy
import lark
import grammar

def RegIdx(reg):
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

def InstOp0(t):
    opcodes = {
        "RET": 0xd100,
    }
    if not t in opcodes: return -1
    return opcodes[t]

def InstOp1JpBr(t, r):
    opcodes = {
        "JP":  0xd000,
        "JZ":  0xd010,
        "JNZ": 0xd020,
        "JC":  0xd030,
        "JNC": 0xd040,
        "BR":  0xd000 | 0x80,
        "BZ":  0xd010 | 0x80,
        "BNZ": 0xd020 | 0x80,
        "BC":  0xd030 | 0x80,
        "BNC": 0xd040 | 0x80,
    }
    cond = {
        "P":  0, # JP
        "R":  0, # BR
        "Z":  1, # JZ, BZ
        "NZ": 2, # JNZ, BNZ
        "C":  3, # JC, BC
        "NC": 4  # JNC, BNC
    }
    if not t in opcodes: return -1
    op = opcodes[t] | (cond[t[1:]] << 4) | RegIdx(r)
    return op

def InstOp1(t, r):
    opcodes = {
        "PUSH": 0xd110,
        "POP":  0xd120,
    }
    if not t in opcodes: return -1
    op = opcodes[t] | RegIdx(r)
    return op

def InstOp2(t, rd, rs):
    opcodes = {
        "LD":   0xe000,
        "ADD":  0xe100,
        "SUB":  0xe200,
        "AND":  0xe300,
        "OR":   0xe400,
        "XOR":  0xe500,
        "CMP":  0xe600,
        "SHR":  0xe700,
        "SHL":  0xe800,
        "WSHR": 0xe900,
        "WSHL": 0xea00,
    }
    if not t in opcodes: return -1
    op = opcodes[t] | (RegIdx(rs) << 4) | RegIdx(rd)
    return op

def InstLdi(t, rd, imm):
    value = convert_to_number(imm)
    opcodes = {
        "LDIL": 0x0000,
        "LDIH": 0x4000,
    }
    if t == "LDI":
        ops = []
        if value & 0x2ff:
            ops.append(opcodes["LDIL"] | ((value&0x2ff) << 4) | RegIdx(rd))
        if value > 0x2ff:
            ops.append(opcodes["LDIH"] | ((value >> 4) & 0x0ff0) | RegIdx(rd))
    else:
        if not t in opcodes: return -1
        ops = [opcodes[t] | (convert_to_number(imm) << 4) | RegIdx(rd)]
    return ops

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
        self.program[self.pos] = InstOp0(a[0])
        self.pos = self.pos + 1
    
    def op1(self, a):
        self.program[self.pos] = InstOp1(a[0].type, a[1].value)
        self.pos = self.pos + 1

    def op1_jpbr(self, a):
        self.program[self.pos] = InstOp1JpBr(a[0].type, a[1].value)
        self.pos = self.pos + 1

    def op2(self, a):
        self.program[self.pos] = InstOp2(a[0].type, a[1].value, a[2].value)
        self.pos = self.pos + 1
    
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
        ops = InstLdi(a[0].type, a[1].value, a[2].value)
        for op in ops:
            self.program[self.pos] = op
            self.pos = self.pos + 1

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

    lines = "ldi.l r2, $10\nldi.h r7, 20\nldi r1, 65534\n"
    contents = "".join(lines)

    t = l.parse(contents)
    # print(t.pretty())
    # print(t)

    n = dcpuTransformer().transform(t)

if __name__ == "__main__":
    sys.exit(main())
