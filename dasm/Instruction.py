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

    def __init__(self, tokens, type):
        self.tokens = tokens
        self.type = type
        
    # def data(self, symbols=None):
    #     return []
    
    def len(self):
        return 0


class OpCall(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def data(self, symbols=None):
        v = self.tokens[1].value
        if v in symbols:
            addr = symbols[v]
        else:
            addr = convert_to_number(v)
        assert addr < 0x10000, f"ERROR on line {self.tokens[0].line}: Address out of range ({addr})."
        return [addr]

    def len(self):
        return 1


class OpLitl(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def len(self):
        return 1
    
    def data(self, symbols):
        v = convert_to_number(self.tokens[1].value)
        assert v > 0 and v < (1<<13), f"ERROR on line {self.tokens[0].line}: Literal out of range ({v})."
        return [0x8000 | v]


class OpLith(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def len(self):
        return 1

    def data(self, symbols):
        v = convert_to_number(self.tokens[1].value)
        assert v > 0 and v < (1<<8), f"ERROR on line {self.tokens[0].line}: Literal out of range ({v})."
        v = 0xa000 | v
        if len(self.tokens) > 2 and self.tokens[2].type == "RET":
            v = v | (1 << 8) # ret bit
        return [v]


class OpLit(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def len(self):
        return 2

    def data(self, symbols):
        v = self.tokens[1].value
        if v in symbols:
            v = symbols[v]
        else:
            v = convert_to_number(v)
        assert v >= -32768 and v < 32767, f"ERROR on line {self.tokens[0].line}: Literal out of range ({v})."

        ops = [0x8000 | (v & ((1<<13)-1)), 0xa000 | ((v>>8)&0xff)]
        
        if len(self.tokens) > 2 and self.tokens[2].type == "RET":
            ops[1] = ops[1] | (1 << 8) # ret bit
        return [ops]


class OpRelJmp(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def len(self):
        return 1


class OpAlu(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)

    def len(self):
        return 1


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
    

class OpOrg(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.ORG)

    def address(self):
        return convert_to_number(self.tokens[1].value)


class OpWord(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.DATA)


class OpAscii(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.DATA)


class OpCstr(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.DATA)
