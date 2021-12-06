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
    if not t.type in opcodes:
        raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
    return opcodes[t.type]

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
    if not t.type in opcodes:
        raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
    op = opcodes[t.type] | RegIdx(r.value)
    return op

def InstOp1(t, r):
    opcodes = {
        "PUSH": 0xd110,
        "POP":  0xd120,
    }
    if not t.type in opcodes:
        raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
    op = opcodes[t.type] | RegIdx(r.value)
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
    if not t.type in opcodes:
        raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
    op = opcodes[t.type] | (RegIdx(rs.value) << 4) | RegIdx(rd.value)
    return op

def InstLdi(t, rd, imm):
    value = convert_to_number(imm)
    opcodes = {
        "LDIL": 0x0000,
        "LDIH": 0x4000,
    }
    if t.type == "LDI":
        ops = []
        if value & 0x2ff:
            ops.append(opcodes["LDIL"] | ((value&0x2ff) << 4) | RegIdx(rd.value))
        if value > 0x2ff:
            ops.append(opcodes["LDIH"] | ((value >> 4) & 0x0ff0) | RegIdx(rd.value))
    else:
        if not t.type in opcodes:
            raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
        ops = [opcodes[t.type] | (convert_to_number(imm) << 4) | RegIdx(rd.value)]
    return ops

def InstLd(t, rd, rs, offset):
    offs = convert_to_number(offset)
    src = RegIdx(rs.value)
    dst = RegIdx(rd.value)
    op = 0x8000 | (offs<<8) | (src << 4) | dst
    return op

def InstSt(t, rs, offset, rd):
    offs = convert_to_number(offset)
    src = RegIdx(rs.value)
    dst = RegIdx(rd.value)
    op = 0xa000 | (offs<<8) | (src << 4) | dst
    return op

def InstReljmp_offset(t, offset):
    opcodes = {
        "JP":  0xc000,
        "JZ":  0xc010,
        "JNZ": 0xc020,
        "JC":  0xc030,
        "JNC": 0xc040,
    }
    offs = convert_to_number(offset)
    if not t.type in opcodes:
        raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
    # RJP: 1100 <offs:5> <cond:3> <offs:4>
    if (offs > 0xff) or (offs < -0x100):
        raise ValueError(f"Line {t.line}:{t.column}: Offset out of range '{offset}'")
    if offs < 0:
        offs = (1 << 9) + offs
    offs1 = offs & 0xf
    offs2 = (offs & 0x1f0) << 3
    op = opcodes[t] | offs2 | offs1
    return op

def convert_to_number(s):
    sign = 1
    if s[0] == '+':
        s = s[1:]
    elif s[0] == '-':
        sign = -1
        s = s[1:]
    if s[0] == '$': num = int(s[1:],16)
    elif s[0:1].upper() == "0X": int(s[2:], 16)
    else: num = int(s)
    return sign*num

class Program:
    pos = 0
    program = {}
    symbols = {}

    @classmethod
    def insertOp(cls, op):
        cls.program[cls.pos] = op
        cls.pos = cls.pos + 1

    @classmethod
    def getOffsetAndWords(cls):
        sorted_prog = sorted(cls.program)
        i = 0
        pos = sorted_prog[i]
        words = []
        for p in sorted_prog:
            while pos < p:
                words.append(0)
                pos = pos + 1
            words.append(cls.program[sorted_prog[p]])
            pos = pos + 1
        return (sorted_prog[0], words)


class dcpuTransformer(lark.Transformer):
   
    def op0(self, a):
        Program.insertOp(InstOp0(a[0]))
    
    def op1(self, a):
        self.insertOp(InstOp1(a[0], a[1]))

    def op1_jpbr(self, a):
        self.insertOp(InstOp1JpBr(a[0], a[1]))

    def op2(self, a):
        self.insertOp(InstOp2(a[0], a[1], a[2]))
    
    def ld(self, a):
        offs = '0'
        if len(a) == 4: offs = a[3].value
        self.insertOp(InstLd(a[0].type, a[1], a[2], offs))

    def st(self, a):
        offs = '0'
        if len(a) == 4: # InstSt(t, rs, offset, rd):
            self.insertOp(InstSt(a[0], a[1], a[2], a[3]))
        else:
            self.insertOp(InstSt(a[0], a[1], "0", a[2]))

    def ldimm(self, a):
        ops = InstLdi(a[0], a[1], a[2])
        for op in ops:
            Program.insertOp(op)

    def reljmp_label(self, a):
        try: addr = Program.symbols[a[1].value]
        except: raise ValueError(f"Symbol '{a[1].value}' not found.")
        offs = addr - self.pos - 1
        self.insertOp(InstReljmp_offset(a[0], str(offs)))

    def reljmp_offset(self, a):
        self.insertOp(InstReljmp_offset(a[0], a[1]))

    def equ(self, a):
        if a[1].value in Program.symbols:
            raise ValueError(f"Symbol '{a[1].value}' already defined.")
        Program.symbols[a[1].value] = convert_to_number(a[2].value)

    def label(self, a):
        if (a[0].value in Program.symbols):
            raise ValueError(f"Line {a[0].line}:{a[0].column}: Symbol '{a[0].value}' already defined")
        Program.symbols[a[0].value] = Program.pos

    def org(self, a):
        Program.pos = convert_to_number(a[1])

    def word(self, a):
        i = 1
        while i < len(a):
            try:
                v = convert_to_number(a[i].value)
                Program.insertOp(v)
            except:
                if a[i].value in Program.symbols:
                    v = Program.symbols[a[i].value]
                    Program.insertOp(v)
                else:
                    raise ValueError(f"Line {a[i].line}:{a[i].column}: Symbol '{a[i].value}' not found")
            i = i + 1

    def ascii(self, a):
        s = a[1].value[1:-1].encode('ascii','ignore')
        i = 0
        while i < len(s):
            v = s[i]
            if i+1 < len(s):
                v = v | (s[i+1] << 8)
            Program.insertOp(v)
            i = i+2

    def asciiz(self, a):
        self.ascii(a)
        Program.insertOp(0)

def write_program_as_bin(prog, fn, endianess='big'):
    with open(fn ,"wb") as f:
        for p in prog:
            f.write(p.to_bytes(2, byteorder=endianess))

def write_program_as_memfile(prog, fn, endianess='big'):
    with open(fn ,"wt") as f:
        for c,p in enumerate(prog):
            f.write(f"{p:04x}")
            if (c % 8) == 7:
                f.write("\n")
            else:
                f.write(" ")
            
def write_program_as_cfile(prog, fn, endianess='big'):
    with open(fn ,"wt") as f:
        f.write("uint16_t program[] = {\n")
        for c,p in enumerate(prog):
            if (c % 8) == 0:
                f.write("    ")
            f.write(f"0x{p:04x}, ")
            if (c % 8) == 7:
                f.write("\n")
        if (len(prog) % 8):
            f.write("\n")
        f.write("};")

def write_program_as_hexdump(prog, offset, fn, endianess='big'):
    with open(fn ,"wt") as f:
        for i in range(len(prog)):
            addr = i + offset
            if (addr % 8) == 0:
                f.write(f"{addr:04x}")
        # todo

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

    lines = ".asciiz \"Hallo Welt!!!!\"\n"
    contents = "".join(lines)

    t = l.parse(contents)
    #print(t.pretty())
    # print(t)

    n = dcpuTransformer().transform(t)

    fn_noext = os.path.splitext(fn)[0]
    # write_program(Program.program, fn_raw)
    (offset, words) = Program.getOffsetAndWords()

    write_program_as_bin(words, fn_noext+".bin")
    write_program_as_memfile(words, fn_noext+".mem")
    write_program_as_cfile(words, fn_noext+".c")
    write_program_as_hexdump(words, offset, fn_noext+".hexdump")

if __name__ == "__main__":
    sys.exit(main())
