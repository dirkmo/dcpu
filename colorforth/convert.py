#!/usr/bin/env python3

import os
import sys
from token import *

# <add:t:d+:r-:ret>
# <rjp offs>


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
    return fragments


def merge_fragments(fragments):
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

def isMnemonic(s):
    mn = [ "T", "N", "R", "MEMT", "ADD", "SUB", "NOP", "AND", "OR", "XOR", "LTS", "LT", "SR", "SRW", "SL", "SLW", "JZ", "JNZ", "CARR", "INV", "MULL", "MULH", "RJ", "RJZ", "RJNZ", "RJN", "RJNN" ]
    p = s.find(">")
    if p > 0:
        pass
    return False

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
    frags = merge_fragments(fragment(line))
    for f in frags:
        fragments.append(Fragment(f, num))

tokens = []

for f in fragments:
    t = f.s
    if len(t.strip()):
        print(f"'{t.strip()}'")
    if len(t) > 1:
        if isMnemonic(t):
            pass
        elif t[0] == ":":
            tokens.append(TokenDefinition(t[1:]))
        elif t[0] == "#":
            if t[1] == "'":
                assert Token.definitionAvailable(t[2:]), f"ERROR on line {f.linenum+1}: Unkown word {t[1:]}"
                tokens.append(TokenImmediateWordAddress(t[2:]))
            else:
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
        elif t[0] == '"' and len(t) > 2:
            tokens.append(TokenLiteralString(t[1:-1]))
        elif t[0:2] == "\ ":
            tokens.append(TokenCommentBackslash(t))
        elif t[0:2] == "( ":
            tokens.append(TokenCommentBraces(t))
        elif t[0] == "'":
            tokens.append(TokenImmediateWordAddress(t[1:]))
        else:
            # compile word
            if Token.definitionAvailable(t):
                tokens.append(TokenCompileWord(t))
            else:
                # compile literal
                try:
                    if t[0] == '$':
                        num = int(t[1:], 16)
                        tokens.append(TokenLiteralNumberHex(num))
                    else:
                        num = int(t, 10)
                        tokens.append(TokenLiteralNumberDec(num))
                except:
                    assert False, f"ERROR on line {f.linenum+1}: Unknown word '{t[1:]}'"
    else: # empty line
        if len(t) and ord(t[0]) < 32:
            tokens.append(TokenWhitespace(t))
