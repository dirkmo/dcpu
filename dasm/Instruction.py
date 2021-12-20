class Instruction:
    OPCODE = 0
    DATA = 1
    ORG = 2
    LABEL = 3

    @staticmethod
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

    @staticmethod
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

    def __init__(self, token, type=0):
        self.token = token
        self.type = type

    def data(self, pos=0):
        return [0]

    def len(self):
        return 1

    def data_hexdump(self):
        data = self.data()
        s = f"{data[0]:04x}"
        for i in range(1, len(data)):
            s = s + f", {data[i]:04x}"
        return s

    def line(self):
        return self.token.line()

    def column(self):
        return self.token.column()


class InstructionOp0(Instruction):
    _opcodes = {
        "RET": 0xd100,
    }

    def __init__(self, t):
        if not t.type in self._opcodes:
            raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
        super().__init__(t, Instruction.OPCODE)

    def data(self, pos=0):
        return [self._opcodes[self.token.type]]


class InstructionOp1JpBr(Instruction):
    _opcodes = {
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

    def __init__(self, t, r):
        if not t.type in self._opcodes:
            raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
        super().__init__(t, Instruction.OPCODE)
        self.register = r

    def data(self, pos=0):
        op = self._opcodes[self.token.type] | Instruction.RegIdx(self.register.value)
        return [op]


class InstructionOp1(Instruction):
    _opcodes = {
        "PUSH": 0xd110,
        "POP":  0xd120,
    }

    def __init__(self, t, r):
        if not t.type in self._opcodes:
            raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
        super().__init__(t, Instruction.OPCODE)
        self.register = r

    def data(self, pos=0):
        op = self._opcodes[self.token.type] | Instruction.RegIdx(self.register.value)
        return [op]


class InstructionOp2(Instruction):
    _opcodes = {
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

    def __init__(self, t, rd, rs):
        if not t.type in self._opcodes:
            raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
        super().__init__(t, Instruction.OPCODE)
        self.rd = rd
        self.rs = rs

    def data(self, pos=0):
        op = self._opcodes[self.token.type]
        rs = Instruction.RegIdx(self.rs.value) << 4
        rd = Instruction.RegIdx(self.rd.value)
        return [op | rs | rd]


class InstructionLdi(Instruction):
    _opcodes = {
        "LDI": 0x0000,
        "LDIL": 0x0000,
        "LDIH": 0x4000,
    }

    def __init__(self, t, rd, imm, symbols):
        if not t.type in self._opcodes:
            raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
        super().__init__(t, Instruction.OPCODE)
        self.rd = rd
        self.immediate = imm
        self.symbols = symbols

    def data(self, pos=0):
        try:
            imm = Instruction.convert_to_number(self.immediate)
        except:
            if not self.immediate in self.symbols:
                raise ValueError(f"Line {self.immediate.line}:{self.immediate.column}: Symbol '{self.immediate.value}' not found")
            imm = self.symbols[self.immediate]
        rd = Instruction.RegIdx(self.rd.value)
        ops = []
        if self.token.type == "LDI":
            op = self._opcodes["LDIL"] | ((imm & 0x2ff) << 4) | rd
            ops.append(op)
            op = self._opcodes["LDIH"] | ((imm >> 4) & 0x0ff0) | rd
            ops.append(op)
        else:
            op = self._opcodes[self.token.type] | (imm << 4) | rd
            ops = [op]
        return ops

    def len(self):
        if self.token.type == "LDI":
            return 2
        return 1


class InstructionLd(Instruction):
    _opcodes = {
        "LD": 0x8000,
    }

    def __init__(self, t, rd, rs, offset):
        super().__init__(t, Instruction.OPCODE)
        self.rd = rd
        self.rs = rs
        self.offset = offset

    def data(self, pos=0):
        offs = Instruction.convert_to_number(self.offset)
        src = Instruction.RegIdx(self.rs.value)
        dst = Instruction.RegIdx(self.rd.value)
        op = self._opcodes[self.token.type] | (offs << 8) | (src << 4) | dst
        return [op]


class InstructionSt(Instruction):
    _opcodes = {
        "ST": 0xa000,
    }

    def __init__(self, t, rs, offset, rd):
        super().__init__(t, Instruction.OPCODE)
        self.rs = rs
        self.offset = offset
        self.rd = rd

    def data(self, pos=0):
        offset = Instruction.convert_to_number(self.offset)
        src = Instruction.RegIdx(self.rs.value)
        dst = Instruction.RegIdx(self.rd.value)
        op = self._opcodes[self.token.type] | (offset << 8) | (src << 4) | dst
        return [op]


class InstructionRelJmp(Instruction):
    _opcodes = {
        "JP":  0xc000,
        "JZ":  0xc010,
        "JNZ": 0xc020,
        "JC":  0xc030,
        "JNC": 0xc040,
    }

    def __init__(self, t, offset, symbols):
        if not t.type in self._opcodes:
            raise ValueError(f"Line {t.line}:{t.column}: Unknown opcode '{t.value}'")
        super().__init__(t, Instruction.OPCODE)
        self.offset = offset
        self.symbols = symbols

    def data(self, pos=0):
        try:
            offs = Instruction.convert_to_number(self.offset)
        except:
            addr = self.symbols[self.offset]
            offs = addr - pos # TODO: Off by 1?
        # RJP: 1100 <offs:5> <cond:3> <offs:4>
        if (offs > 0xff) or (offs < -0x100):
            raise ValueError(f"Line {t.line}:{t.column}: Offset out of range '{offset}'")
        if offs < 0:
            offs = (1 << 9) + offs
        offs1 = offs & 0xf
        offs2 = (offs & 0x1f0) << 3
        op = self._opcodes[t.type] | offs2 | offs1
        return [op]


class DirectiveWord(Instruction):
    def __init__(self, a, symbols):
        super().__init__(a[0], Instruction.DATA)
        self._data = a

    def data(self, pos=0):
        i = 1
        d = []
        while i < len(self._data):
            try:
                v = Instruction.convert_to_number(self._data[i].value)
                d.append(v)
            except:
                if self._data[i].value in self.symbols:
                    v = self.symbols[self._data[i].value]
                    d.append(v)
                else:
                    raise ValueError(f"Line {self._data[i].line}:{self._data[i].column}: Symbol '{self._data[i].value}' not found")
            i = i + 1
        return d

    def len(self):
        return len(self._data) - 1


class DirectiveAscii(Instruction):
    def __init__(self, a):
        super().__init__(a[0], Instruction.DATA)
        self._data = a

    def data(self, pos=0):
        s = self._data[1].value[1:-1].encode('ascii','ignore')
        i = 0
        d = []
        while i < len(s):
            v = s[i]
            if (i+1) < len(s):
                v = v | (s[i+1] << 8)
            i = i+2
            d.append(v)
        if self._data[0].type == "ASCIIZ":
            d.append(0)
        return d

    def len(self):
        return len(self.data())


class DirectiveOrg(Instruction):
    def __init__(self, a):
        super().__init__(a, Instruction.ORG)
        self.org = a[1]

    def data(self):
        return None

    def len(self):
        return 0


class DirectiveLabel(Instruction):
    def __init__(self, a):
        super().__init__(a, Instruction.LABEL)
        self.org = a

    def data(self):
        return None

    def len(self):
        return 0