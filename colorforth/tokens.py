def lohi(v):
    return [(v >> 8) & 0xff, v & 0xff]

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

    D = {}
    Didx = 0

    def __init__(self, tag):
        self.tag = tag

    def addDefinition(name):
        assert not name in Token.D, f"{name} already defined"
        print(f"Definition {Token.Didx}: {name}")
        Token.D[name] = Token.Didx
        Token.Didx += 1

    def definitionAvailable(name):
        return name in Token.D

    def generate(self):
        ...


class TokenDefinition(Token):
    def __init__(self, name):
        super().__init__(self.DEFINITION)
        self.name = name
        Token.addDefinition(name)

    def generate(self):
        l = len(self.name) & 0xf
        data = [self.tag | (l << 4)]
        for i in range(l):
            data.append(self.name[i] & 0xff)
        return data


class TokenLiteralNumberDec(Token):
    def __init__(self, num):
        super().__init__(self.LIT_NUMBER_DEC)
        self.value = num
        print(f"literal: {self.value}")

    def generate(self):
        return [self.tag].extend(lohi(self.value))


class TokenLiteralNumberHex(Token):
    def __init__(self, num):
        super().__init__(self.LIT_NUMBER_HEX)
        self.value = num
        print(f"literal: ${self.value:x}")

    def generate(self):
        return [self.tag].extend(lohi(self.value))


class TokenLiteralString(Token):
    def __init__(self, s):
        super().__init__(self.LIT_STRING)
        self.s = s
        print(f"Literal string '{s}'")

    def generate(self):
        l = len(self.s) & 0xfff
        data = [self.tag | (l << 4)]
        for i in range(l):
            data.append(self.s[i] & 0xff)
        return data


class TokenLiteralWordAddress(Token):
    def __init__(self, s):
        super().__init__(self.LIT_WORD_ADDRESS)
        self.name = s
        print(f"Literal word address {s}")

    def generate(self):
        addr = Token.D[self.name]
        return [self.tag].extend(lohi(addr))


class TokenImmediate(Token):
    def __init__(self, name):
        super().__init__(self.IMMEDIATE)
        self.name = name
        print(f"Immediate call: {name}")

    def generate(self):
        idx = Token.D[self.name]
        return [self.tag | (idx & 0xf) << 4, (idx >> 4) & 0xff, (idx >> 12) & 0xff]


class TokenImmediateNumberHex(Token):
    def __init__(self, num):
        super().__init__(self.IMMEDIATE_NUMBER_HEX)
        self.value = num
        print(f"Immedate number ${num:x}")

    def generate(self):
        return [self.tag].extend(lohi(self.value))


class TokenImmediateNumberDec(Token):
    def __init__(self, num):
        super().__init__(self.IMMEDIATE_NUMBER_DEC)
        self.value = num
        print(f"Immedate number {num}")

    def generate(self):
        return [self.tag].extend(lohi(addr))


class TokenCommentBraces(Token):
    def __init__(self, s):
        super().__init__(self.COMMENT_BRACES)
        self.comment = s
        print(f"Comment {self.comment}")

    def generate(self): # TODO
        return [self.tag]


class TokenCommentBackslash(Token):
    def __init__(self, s):
        super().__init__(self.COMMENT_BACKSLASH)
        self.comment = s
        print(f"Comment {self.comment}")

    def generate(self):
        return [self.tag]


class TokenCompileWord(Token):
    def __init__(self, s):
        super().__init__(self.COMPILE_WORD)
        self.name = s
        print(f"Compile {s}")

    def generate(self):
        return [self.tag]


class TokenImmediateWordAddress(Token):
    def __init__(self, s):
        super().__init__(self.IMMEDIATE_WORD_ADDRESS)
        self.name = s
        print(f"Push word address {s}")

    def generate(self):
        return [self.tag]

class TokenWhitespace(Token):
    def __init__(self, s):
        super().__init__(self.WHITESPACE)
        self.s = s
        print(f"Whitespace")

    def generate(self):
        l = len(self.s) & 0xfff
        data = [self.tag | (l << 4)]
        for i in range(l):
            data.append(self.s[i] & 0xff)
        return data
