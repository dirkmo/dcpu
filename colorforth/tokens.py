from simpledasm import asm

def lohi(v):
    return [(v >> 8) & 0xff, v & 0xff]

class Consts:
    HERE = 8 # here is at address 8

class Token:
    DEFINITION = 0
    LIT_NUMBER_DEC = 1
    LIT_NUMBER_HEX = 2
    LIT_STRING = 3
    LIT_WORD_ADDRESS = 4
    IMMEDIATE = 5
    IMMEDIATE_NUMBER_DEC = 6
    IMMEDIATE_NUMBER_HEX = 7
    IMMEDIATE_WORD_ADDRESS = 8
    COMMENT_BRACES = 9
    COMMENT_BACKSLASH = 10
    COMPILE_WORD = 11
    WHITESPACE= 12
    MNEMONIC = 13
    BUILDIN = 14

    D = {}
    Didx = 0

    def __init__(self, tag, fragment):
        self.tag = tag
        self.fragment = fragment

    def addDefinition(name):
        assert not name in Token.D, f"{name} already defined"
        print(f"Definition {Token.Didx}: {name}")
        Token.D[name] = Token.Didx
        Token.Didx += 1

    def definitionAvailable(name):
        return name in Token.D

    def generate(self):
        ...

    def generateStringData(tag, s):
        l = len(s) & 0xff
        data = [tag, l]
        for i in range(l):
            data.append(ord(s[i]) & 0xff)
        return data


class TokenDefinition(Token):
    def __init__(self, name, fragment):
        super().__init__(self.DEFINITION, fragment)
        self.name = name
        Token.addDefinition(name)

    def generate(self):
        return Token.generateStringData(self.tag, self.name)


class TokenLiteralNumberDec(Token):
    def __init__(self, num, fragment):
        super().__init__(self.LIT_NUMBER_DEC, fragment)
        self.value = num
        print(f"literal: {self.value}")

    def generate(self):
        data = [self.tag]
        data.extend(lohi(self.value))
        return data


class TokenLiteralNumberHex(Token):
    def __init__(self, num, fragment):
        super().__init__(self.LIT_NUMBER_HEX, fragment)
        self.value = num
        print(f"literal: ${self.value:x}")

    def generate(self):
        data = [self.tag]
        data.extend(lohi(self.value))
        return data


class TokenLiteralString(Token):
    def __init__(self, s, fragment):
        super().__init__(self.LIT_STRING, fragment)
        self.s = s
        print(f"Literal string '{s}'")

    def generate(self):
        return Token.generateStringData(self.tag, self.s)


class TokenLiteralWordAddress(Token):
    def __init__(self, s, fragment):
        super().__init__(self.LIT_WORD_ADDRESS, fragment)
        self.name = s
        print(f"Literal word address {s}")

    def generate(self):
        addr = Token.D[self.name]
        data = [self.tag]
        data.extend(lohi(addr))
        return data


class TokenImmediate(Token):
    def __init__(self, name, fragment):
        super().__init__(self.IMMEDIATE, fragment)
        self.name = name
        print(f"Immediate call: {name}")

    def generate(self):
        idx = Token.D[self.name]
        return [self.tag, idx & 0xff, (idx >> 8) & 0xff]


class TokenImmediateNumberHex(Token):
    def __init__(self, num, fragment):
        super().__init__(self.IMMEDIATE_NUMBER_HEX, fragment)
        self.value = num
        print(f"Immedate number ${num:x}")

    def generate(self):
        data = [self.tag]
        data.extend(lohi(self.value))
        return data


class TokenImmediateNumberDec(Token):
    def __init__(self, num, fragment):
        super().__init__(self.IMMEDIATE_NUMBER_DEC, fragment)
        self.value = num
        print(f"Immedate number {num}")

    def generate(self):
        data = [self.tag]
        data.extend(lohi(self.value))
        return data


class TokenCommentBraces(Token):
    def __init__(self, s, fragment):
        super().__init__(self.COMMENT_BRACES, fragment)
        self.comment = s
        print(f"Comment {self.comment}")

    def generate(self): # TODO
        return Token.generateStringData(self.tag, self.comment)


class TokenCommentBackslash(Token):
    def __init__(self, s, fragment):
        super().__init__(self.COMMENT_BACKSLASH, fragment)
        self.comment = s
        print(f"Comment {self.comment}")

    def generate(self):
        return Token.generateStringData(self.tag, self.comment)


class TokenCompileWord(Token):
    def __init__(self, s, fragment):
        super().__init__(self.COMPILE_WORD, fragment)
        self.name = s
        print(f"Compile {s}")

    def generate(self):
        return [self.tag, Token.D[self.name]]


class TokenImmediateWordAddress(Token):
    def __init__(self, s, fragment):
        super().__init__(self.IMMEDIATE_WORD_ADDRESS, fragment)
        self.name = s
        print(f"Push word address {s}")

    def generate(self):
        return [self.tag]


class TokenWhitespace(Token):
    def __init__(self, s, fragment):
        super().__init__(self.WHITESPACE, fragment)
        self.ws = s
        print(f"Whitespace")

    def generate(self):
        return Token.generateStringData(self.tag, self.ws)


class TokenBuildin(Token):
    def __init__(self, s, fragment):
        super().__init__(self.BUILDIN, fragment)
        self.name = s
        print(f"Buildin")

    def generate(self):
        # TODO
        op = None
        assert not op is None, f"{self.name} is not a valid buildin."

class TokenMnemonic(Token):
    def __init__(self, s, fragment):
        super().__init__(self.MNEMONIC, fragment)
        self.name = s
        print(f"Mnemonic")

    def generate(self):
        data = [self.tag] # TODO: Länge fehlt
        if self.name == ";":
            ops = asm("nop>t:r-:ret")
        elif self.name == "@":
            ops = asm("mem>t")
        elif self.name == "!":
            ops = asm("t>mem:d-")
        elif self.name == "swap":
            ops = asm("n>r:r+") + asm("t>t:d-") + asm("r>t:d+:r-")
        elif self.name == "H":
            ops = asm(f"litl {Consts.HERE}")
        else:
            ops = asm(self.name)
        for op in ops:
            data.extend(lohi(op))
        return data
