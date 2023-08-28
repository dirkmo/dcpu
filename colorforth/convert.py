#!/usr/bin/env python3

import os
import sys

def tokenize(s):
    tokens = []
    t = ""
    space = False
    for c in s:
        o = ord(c)
        if space:
            if ord(c) < 33:
                t += c
            else:
                tokens.append(t)
                t = c
                space = False
        else:
            if ord(c) < 33:
                tokens.append(t)
                space = True
                t = c
            else:
                t += c
    tokens.append(t)
    return tokens


#if len(sys.argv) < 2:
#    sys.stderr.write("Missing filename\n")
#    exit(1)
#
#fn = sys.argv[1]

fn = "colorforth/test.cf"

with open(fn,"r") as f:
    lines = [line.strip() for line in f.readlines()]

tokens = []

for line in lines:
    tokens.extend(tokenize(line))

print(tokens)

class Token:
    DEFINITION = 0
    IMMEDIATE = 1
    D = {}
    Didx = 0
    def __init__(self, tag):
        self.tag = tag
    
    def addDefinition(name):
        assert not name in Token.D, f"{name} already defined"
        print(f"Definition {Token.Didx}: {name}")
        Token.D[name] = Token.Didx
        Token.Didx += 1

    def generate(self):
        ...

class TokenDefinition(Token):
    def __init__(self, name):
        super().__init__(self.DEFINITION)
        self.name = name
        Token.addDefinition(name)

    def generate(self):
        pass

class TokenImmediate(Token):
    def __init__(self, s):
        #super().__init__(self.imm
        pass

program = []

for t in tokens:
    print(f"'{t}'")
    if len(t) > 1:
        if t[0] == ":":
            program.append(TokenDefinition(t[1:]))
        elif t[0] == "^":
            # execute immediately
            # means: assemble call word (not to dict)
            pass
        elif t[0] == "#":
            # execute immediately and compile result
            # means: assemble call word (not to dict)
            # and then compile result to dict as literal
            pass
        elif t[0] == '"' and len(t) > 2:
            # string literal
            pass
        else:
            # compile word
            pass
    else: # empty line
        pass
