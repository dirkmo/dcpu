#! /usr/bin/env python3

# really simple assembler for dcpu

def convert_to_number(s):
    s = s.strip()
    sign = 1
    if s[0] == '+':
        s = s[1:]
    elif s[0] == '-':
        sign = -1
        s = s[1:]
    if s[0] == '$':
        num = int(s[1:],16)
    elif s[0:2].upper() == "0X":
        num = int(s[2:], 16)
    else:
        num = int(s)
    return sign*num

def startsWith(substr, s):
    if substr.upper() == s[0:len(substr)].upper():
        return len(substr)
    return 0

class DcpuAsm:
    OP_CALL = 0x0000
    OP_LITL = 0x8000
    OP_LITH = 0xa000
    OP_RJ   = 0xe000
    OP_RJZ  = OP_RJ | 0x400
    OP_RJNZ = OP_RJ | 0x500
    OP_RJN  = OP_RJ | 0x600
    OP_RJNN = OP_RJ | 0x700
    OP_ALU  = 0xc000

    def __init__(self):
        pass

    def call(self, s):
        p = startsWith("CALL ", s)
        if p:
            try: num = convert_to_number(s[p:])
            except: assert False, f"ERROR: Failed to convert to number {s[p:]}"
            assert num < 0x8000, f"ERROR: Call to address greater 0x7fff"
            return [num]
        return []

    def litl(self, s):
        p = startsWith("LITL ", s)
        if p:
            try: num = convert_to_number(s[p:])
            except: assert False, f"ERROR: Failed to convert to number {s[p:]}"
            assert num < 0x2000, f"ERROR: LITL value is greater 0x1fff"
            return [self.OP_LITL | num]
        return []

    def lith(self, s):
        # TODO: ret
        p = startsWith("LITH ", s)
        if p:
            try: num = convert_to_number(s[p:])
            except: assert False, f"ERROR: Failed to convert to number {s[p:]}"
            assert num < 0x100, f"ERROR: LITH value is greater 0xff"
            return [self.OP_LITH | num]
        return []

    def lit(self, s):
        # TODO: ret
        p = startsWith("LIT ", s)
        if p:
            try: num = convert_to_number(s[p:])
            except: assert False, f"ERROR: Failed to convert to number {s[p:]}"
            num = num & 0xffff
            return [self.OP_LITL | num & 0xff, self.OP_LITH | ((num >> 8) & 0xff)]
        return []

    def rjp(self, s):
        opcode = None
        p = startsWith("RJ ",s)
        if p:
            s = s[p:]
            opcode = self.OP_RJ
        p = startsWith("RJ.Z ",s)
        if p:
            s = s[p:]
            opcode = self.OP_RJZ
        p = startsWith("RJ.NZ ",s)
        if p:
            s = s[p:]
            opcode = self.OP_RJNZ
        p = startsWith("RJ.N ",s)
        if p:
            s = s[p:]
            opcode = self.OP_RJN
        p = startsWith("RJ.NN ",s)
        if p:
            s = s[p:]
            opcode = self.OP_RJNN
        if opcode == None:
            return []
        num = convert_to_number(s)
        assert (num < (1<<9)) and (num >= -(1<<9)), f"ERROR: Relative jump is out of range (offset {num})"
        num &= 0x3ff
        opcode |= num
        return [opcode]

    def alu(self, s):
        mn = [ "T", "N", "R", "MEMT", "ADD", "SUB", "NOP", "AND", "OR", "XOR", "LTS", "LT", "SR", "SRW", "SL", "SLW", "JZ", "JNZ", "CARR", "INV", "MULL", "MULH" ]

        return []

    def assemble(self, s):
        s = s.strip().upper()
        opcodes = self.call(s)
        opcodes.extend(self.litl(s))
        opcodes.extend(self.lith(s))
        opcodes.extend(self.lit(s))
        opcodes.extend(self.rjp(s))
        opcodes.extend(self.alu(s))
        return opcodes


def main():
    asm = DcpuAsm()
    print(f'{asm.assemble("call 1234")}')
    print(f'{asm.assemble("call 0x1234")}')
    print(f'{asm.assemble("call $1234")}')
    print(f'{asm.assemble("litl $1234")}')
    print(f'{asm.assemble("lith $54")}')
    print(f'{asm.assemble("lit $febc")}')
    print(f'{asm.assemble("rj -1")}')
    print(f'{asm.assemble("rj.z $1ff")}')
    print(f'{asm.assemble("rj.nz -$100")}')
    print(f'{asm.assemble("rj.n -$100")}')
    print(f'{asm.assemble("rj.nn -$1f")}')


if __name__ == "__main__":
    main()
