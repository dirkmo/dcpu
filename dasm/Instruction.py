def convert_to_number(s):
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

class OpBase:
    OPCODE = 0
    DATA = 1
    ORG = 2
    LABEL = 3
    EQU = 4

    OP_CALL = 0x0000
    OP_LITL = 0x8000
    OP_LITH = 0xa000
    OP_RJP  = 0xe000
    OP_ALU  = 0xc000

    def __init__(self, tokens, type):
        self.tokens = tokens
        self.type = type


class OpCall(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)

    def data(self, symbols=None):
        v = self.tokens[1].value
        if v in symbols:
            addr = symbols[v]
        else:
            try:
                addr = convert_to_number(v)
            except:
                assert False, f"ERROR on line {self.tokens[0].line}: Invalid address ({v})."
        assert addr < 0x10000, f"ERROR on line {self.tokens[0].line}: Address out of range ({addr})."
        return [OpBase.OP_CALL | addr]

    def len(self, symbols):
        return 1


class OpLitl(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)

    def len(self, symbols):
        return 1

    def data(self, symbols):
        v = convert_to_number(self.tokens[1].value)
        v = (0x10000 + v) & 0xffff
        assert v > 0 and v < (1<<13), f"ERROR on line {self.tokens[0].line}: Literal out of range ({v})."
        return [OpBase.OP_LITL | v]


class OpLith(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)

    def len(self, symbols):
        return 1

    def data(self, symbols):
        v = convert_to_number(self.tokens[1].value)
        v = (0x10000 + v) & 0xffff
        assert v > 0 and v < (1<<8), f"ERROR on line {self.tokens[0].line}: Literal out of range ({v})."
        v = OpBase.OP_LITH | v
        if len(self.tokens) > 2 and self.tokens[2].type == "RET":
            v = v | (1 << 8) # ret bit
        return [v]


class OpLit(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)

    def len(self, symbols):
        retbit = len(self.tokens) > 2 and self.tokens[2].type == "RETBIT"
        if self.tokens[1].type == "SIGNED_NUMBER" and not retbit:
            v = convert_to_number(self.tokens[1].value)
            v = (0x10000 + v) & 0xffff
            if v < (1<<13):
                return 1
        return 2

    def data(self, symbols):
        v = self.tokens[1]
        sym = False
        ret = 0
        if v.type == "CNAME":
            sym = True
            assert v.value in symbols, f"ERROR on line {v.line}: Unknown symbol {v.value}."
            v = symbols[v.value]
        else:
            v = convert_to_number(v.value)
        assert v >= -32768 and v < 65536, f"ERROR on line {self.tokens[0].line}: Literal out of range ({v})."

        if len(self.tokens) > 2 and self.tokens[2].type == "RETBIT":
            ret = 1

        v = (0x10000 + v) & 0xffff

        vmasked = (v & ((1<<13)-1))
        vhmasked = ((v>>8)&0xff)
        ops = [OpBase.OP_LITL | (v & ((1<<13)-1))]

        if sym or (v >= (1<<13)) or ret:
            ops.append(OpBase.OP_LITH | ((v>>8)&0xff) | (ret << 8))

        return ops


class OpRelJmp(OpBase):
    _cond_codes = {
        "RJP":  0,
        "RJZ":  4,
        "RJNZ": 5,
        "RJN":  6,
        "RJNN": 7,
    }

    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)

    def len(self, symbols):
        return 1

    def data(self, symbols):
        t = self.tokens[0]
        v = self.tokens[1]
        if v.type == "CNAME":
            assert v.value in symbols, f"ERROR on line {v.line}: Unknown symbol {v.value}."
            v = symbols[v.value] - self.pos
        else:
            v = convert_to_number(v.value)
        assert (v < (1<<9)) or (v >= -(1<<9)), f"ERROR on line {self.tokens[0].line}: Relative jump is out of range (v)"

        cond = self._cond_codes[t.type]

        return [OpBase.OP_RJP | (cond << 10) | (v & ((1<<10)-1))]



class OpAlu(OpBase):
    _options = {
        # alu ops
        "ALU_T":    0 << 7,
        "ALU_N":    1 << 7,
        "ALU_R":    2 << 7,
        "ALU_MEM":  3 << 7,
        "ADD":      4 << 7,
        "SUB":      5 << 7,
        "NOP":      6 << 7,
        "AND":      7 << 7,
        "OR":       8 << 7,
        "XOR":      9 << 7,
        "LTS":     10 << 7,
        "LT":      11 << 7,
        "SR":      12 << 7,
        "SRW":     13 << 7,
        "SL":      14 << 7,
        "SLW":     15 << 7,
        "JZ":      16 << 7,
        "JNZ":     17 << 7,
        "CARRY":   18 << 7,
        "INV":     19 << 7,
        "MULL":    20 << 7,
        "MULH":    21 << 7,
        # destination of alu op
        "DST_T":    0 << 4, # T = alu
        "DST_R":    1 << 4, # R = alu
        "DST_PC":   2 << 4, # PC = alu (for jumps/calls)
        "DST_MEM":  3 << 4, # mem[T] = alu (write to memory)
        # data stack pointer manipulation
        "DP":       1 << 2, # d+
        "DM":       2 << 2, # d-
        # return stack pointer manipulation
        "RP":       1 << 0, # r+
        "RM":       2 << 0, # r-
        "RPC":      3 << 0, # r+pc (push pc to return stack, for calls)
        "RETBIT":   1 << 6, # return bit
    }
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)

    def len(self, symbols):
        return 1

    def data(self, symbols):
        op = OpBase.OP_ALU
        rsp_dec = False
        ret_bit = False
        for t in self.tokens[0:-1]:
            assert t.type in self._options, f"ERROR on line {t.line}, column {t.column}: Unknown token '{t.value}'."
            op = op | self._options[t.type]
            if t.type == "RM": rsp_dec = True
            if t.type == "RETBIT": ret_bit = True
        assert op != 0

        if ret_bit:
            assert rsp_dec, f"ERROR on line {t.line}, column {t.column}: R- required when return bit is set by [ret]."

        return [op]


class OpEqu(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.EQU)

    def label(self):
        return self.tokens[1].value

    def value(self):
        return convert_to_number(self.tokens[2].value)


class OpLabel(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.LABEL)

    def label(self):
        return self.tokens[0].value

    def len(self, symbols):
        return 0


class OpOrg(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.ORG)

    def address(self):
        return convert_to_number(self.tokens[1].value)

    def len(self, symbols):
        return 0

class OpWord(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.DATA)

    def len(self, symbols):
        return len(self.tokens) - 2

    def data(self, symbols):
        d = []
        for t in self.tokens[1:-1]:
            if t.type == "CNAME":
                assert t.value in symbols, f"ERROR on line {t.line}, column {t.column}: Unknown token '{t.value}'."
                v = symbols[t.value]
            else:
                v = convert_to_number(t.value)
            d.append(v)
        return d

class OpAscii(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.DATA)

    def len(self, symbols):
        return len(self.data(None))

    def data(self, symbols):
        v = self.tokens[1].value[1:-1]
        if self.tokens[0].type == "ASCIIZ":
            v = v + chr(0)
        d = []
        for i in range(len(v)):
            if (i % 2) == 0:
                a = ((ord(v[i]) & 0xff) << 8)
                d.append(a)
            else:
                d[-1] = d[-1] | (ord(v[i]) & 0xff)
        return d


class OpCstr(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.DATA)

    def len(self, symbols):
        data = self.data(None)
        return len(data)

    def data(self, symbols):
        t = self.tokens[1]
        v = t.value[1:-1]
        d = []
        for i in range(len(v)):
            if (i % 2) == 0:
                a = ((ord(v[i]) & 0xff) << 8)
                d.append(a)
            else:
                d[-1] = d[-1] | (ord(v[i]) & 0xff)
        l = len(v)
        return [l] + d # the count is in chars, not words

class OpSpace(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.DATA)

    def len(self, symbols):
        t = self.tokens[1]
        if t.type == "CNAME":
            assert t.value in symbols, f"ERROR on line {t.line}, column {t.column}: Unknown token '{t.value}'. " \
                                        "Token must be defined before .space directive."
            v = symbols[t.value]
        else:
            v = convert_to_number(t.value)
        return v

    def data(self, symbols):
        return [0] * self.len(symbols)
