#!/usr/bin/env python3

import os
import sys

class Fragment:
    def __init__(self, _s, _linenum):
        self.s = _s
        self.linenum = _linenum

def fragment(s):
    # create list of words and whitespaces
    fragments = []
    t = ""
    space = False
    for c in s:
        o = ord(c)
        if space:
            if ord(c) < 33:
                t += c
            else:
                fragments.append(t)
                t = c
                space = False
        else:
            if ord(c) < 33:
                fragments.append(t)
                space = True
                t = c
            else:
                t += c
    fragments.append(t)
    ## merge comments to single fragment
    merge = []
    # \ comments
    try:
        f = fragments.index("\\")
        merge = fragments[0:f]
        merge.append("".join(fragments[f:]))
        fragments = merge
    except:
        pass
    # () comments
    try:
        c1 = fragments.index("(")
        c2 = fragments.index(")")
        merge = fragments[0:c1]
        comment = "".join(fragments[c1:c2+1])
        merge.append(comment)
        merge.extend(fragments[c2+1:])
        fragments = merge
    except:
        pass
    return fragments


#if len(sys.argv) < 2:
#    sys.stderr.write("Missing filename\n")
#    exit(1)
#
#fn = sys.argv[1]

fn = "colorforth/test.cf"

with open(fn,"r") as f:
    lines = f.readlines()

fragments = []

for num,line in enumerate(lines):
    frags = fragment(line)
    for f in frags:
        fragments.append(Fragment(f, num))



class Token:
    DEFINITION = 0
    LIT_NUMBER_DEC = 1
    LIT_NUMBER_HEX = 2
    IMMEDIATE = 3
    IMMEDIATE_NUMBER_DEC = 4
    IMMEDIATE_NUMBER_HEX = 5
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
        return []

class TokenLiteralNumberDec(Token):
    def __init__(self, num):
        super().__init__(self.LIT_NUMBER_DEC)
        self.value = num
        print(f"String literal: {self.value}")

    def generate(self):
        return []


class TokenLiteralNumberHex(Token):
    def __init__(self, num):
        super().__init__(self.LIT_NUMBER_HEX)
        self.value = num
        print(f"String literal: ${self.value:x}")

    def generate(self):
        return []


class TokenImmediate(Token):
    def __init__(self, name):
        super().__init__(self.IMMEDIATE)
        self.name = name
        print(f"Immediate call: {name}")

    def generate(self):
        return []


class TokenImmediateNumberHex(Token):
    def __init__(self, num):
        super().__init__(self.IMMEDIATE_NUMBER_HEX)
        self.value = num
        print(f"Immedate number ${num:x}")

    def generate(self):
        return []


class TokenImmediateNumberDec(Token):
    def __init__(self, num):
        super().__init__(self.IMMEDIATE_NUMBER_DEC)
        self.value = num
        print(f"Immedate number {num:x}")

    def generate(self):
        return []


tokens = []

for f in fragments:
    t = f.s
    print(f"'{t}'")
    if len(t) > 1:
        if t[0] == ":":
            tokens.append(TokenDefinition(t[1:]))
        elif t[0] == "^":
            # execute immediately
            if Token.definitionAvailable(t[1:]):
                tokens.append(TokenImmediate(t[1:]))
            else:
                try:
                    if t[1] == '$':
                        num = int(t[2:], 16)
                        tokens.append(TokenImmediateNumberHex(num))
                    else:
                        num = int(t[1:], 10)
                        tokens.append(TokenImmediateNumberDec(num))
                except:
                    assert False, f"ERROR on line {f.linenum+1}: Unkown word {t[1:]}"
        elif t[0] == '#':
            if Token.definitionAvailable(t[1:]):
                # execute immediately and compile result
                # means: assemble call word (not to dict)
                # and then compile result to dict as literal
                pass
            else:
                # compile literal
                try:
                    if t[1] == '$':
                        num = int(t[2:], 16)
                        tokens.append(TokenLiteralNumberHex(num))
                    else:
                        num = int(t[1:], 10)
                        tokens.append(TokenLiteralNumberDec(num))
                except:
                    assert False, f"ERROR on line {f.linenum+1}: Unknown word '{t[1:]}'"
        elif t[0] == '"' and len(t) > 2:
            # string literal
            pass
        else:
            # compile word
            if Token.definitionAvailable(t):
                pass

    else: # empty line
        pass
