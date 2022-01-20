from distutils.command.config import LANG_EXT
from lib2to3.pytree import convert


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
        return [OpBase.OP_CALL | addr]

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
        return [OpBase.OP_LITL | v]


class OpLith(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def len(self):
        return 1

    def data(self, symbols):
        v = convert_to_number(self.tokens[1].value)
        assert v > 0 and v < (1<<8), f"ERROR on line {self.tokens[0].line}: Literal out of range ({v})."
        v = OpBase.OP_LITH | v
        if len(self.tokens) > 2 and self.tokens[2].type == "RET":
            v = v | (1 << 8) # ret bit
        return [v]


class OpLit(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def len(self):
        if self.tokens[1].type == "UNSIGNED_NUMBER":
            v = convert_to_number(self.tokens[1].value)
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

        vmasked = (v & ((1<<13)-1))
        vhmasked = ((v>>8)&0xff)
        ops = [OpBase.OP_LITL | (v & ((1<<13)-1))]
        
        if sym or (v >= (1<<13)) or ret:
            ops.append(OpBase.OP_LITH | ((v>>8)&0xff) | (ret << 8))

        return [ops]


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
    
    def len(self):
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
