def convert_to_number(s):
    sign = 1
    if s[0] == '+':
        s = s[1:]
    elif s[0] == '-':
        sign = -1
        s = s[1:]
    if s[0] == '$':
        num = int(s[1:],16)
    elif s[0:1].upper() == "0X":
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
        
    def data(self):
        return []
    
    def len(self):
        return 0


class OpCall(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def data(self):
        pass

    def len(self):
        return 1


class OpLitl(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def len(self):
        return 1


class OpLith(OpBase):
    def __init__(self, tokens):
        super().__init__(tokens, OpBase.OPCODE)
    
    def len(self):
        return 1


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
