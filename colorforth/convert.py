#!/usr/bin/env python3

import argparse
import sys
from tokens import *


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
        merge = fragments[0:f] # fragments before "\""
        merge.append("".join(fragments[f:-1])) # join fragments up to (but excluding) newline
        merge.append(fragments[-1]) # append newline as separate fragment
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


def isAluMnemonic(s):
    # "RJ", "RJZ", "RJNZ", "RJN", "RJNN"
    mn = [ "T", "N", "R", "MEMT", "ADD", "SUB", "NOP", "AND", "OR", "XOR", "LTS", "LT", "SR", "SRW", "SL", "SLW", "JZ", "JNZ", "CARR", "INV", "MULL", "MULH" ]
    s = s.upper()
    p = s.find(">")
    return (p > 0) and (s[0:p] in mn)


def isMnemonic(s):
    mn = [ ";", "@", "!", "swap" ]
    return s in mn


def isBuildin(s):
    bi = [ "H" ]
    return s in bi


def tokenizeFragments(fragments):
    tokens = []
    for f in fragments:
        t = f.s
        if len(t.strip()):
            print(f"'{t.strip()}'")
            if isBuildin(t): # ";"
                tokens.append(TokenBuildin(t, f))
            elif isAluMnemonic(t) or isMnemonic(t): # "add>t:d+:r-:ret"
                tokens.append(TokenMnemonic(t, f))
            elif t[0] == ":": # add name to (virtual) dictionary ":name"
                tokens.append(TokenDefinition(t[1:], f))
            elif t[0] == "#": # immediates
                if t[1] == "'": # "#'name"
                    assert Token.definitionAvailable(t[2:]), f"ERROR on line {f.linenum+1}: Unkown word {t[1:]}"
                    tokens.append(TokenLiteralWordAddress(t[2:], f))
                else: # "#name", "#123", "#$1a2b"
                    # execute immediately
                    if Token.definitionAvailable(t[1:]): # "#name"
                        tokens.append(TokenImmediate(t[1:], f))
                    else:
                        try:
                            if t[1] == '$': # "#$1a2b"
                                num = int(t[2:], 16)
                                tokens.append(TokenImmediateNumberHex(num, f))
                            else: # "#123",
                                num = int(t[1:], 10)
                                tokens.append(TokenImmediateNumberDec(num, f))
                        except:
                            assert False, f"ERROR on line {f.linenum+1}: Unkown word {t[1:]}"
            elif t[0] == '"' and len(t) > 2: # '"str"'
                tokens.append(TokenLiteralString(t[1:-1], f))
            elif t[0:2] == "\ ": # "\ comment"
                tokens.append(TokenCommentBackslash(t, f))
            elif t[0:2] == "( ": # "( comment )"
                tokens.append(TokenCommentBraces(t, f))
            elif t[0] == "'": # "'name"
                tokens.append(TokenImmediateWordAddress(t[1:], f))
            else: # "name", "123", "$1a2b"
                # compile word
                if Token.definitionAvailable(t): # "name"
                    tokens.append(TokenCompileWord(t, f))
                else:
                    # compile literal
                    try:
                        if t[0] == '$': # "$1a2b"
                            num = int(t[1:], 16)
                            tokens.append(TokenLiteralNumberHex(num, f))
                        else: # "123"
                            num = int(t, 10)
                            tokens.append(TokenLiteralNumberDec(num, f))
                    except:
                        assert False, f"ERROR on line {f.linenum+1}: Unknown word '{t[1:]}'"
        else: # empty line
            if len(t):
                print(ord(t[0]))
                if ord(t[0]) < 33:
                    tokens.append(TokenWhitespace(t, f))
    return tokens


def convert(fn):
    try:
        with open(fn,"r") as f:
            lines = f.readlines()
    except:
        print(f"ERROR: Cannot open file {fn}")
        return None

    fragments = []

    for num,line in enumerate(lines):
        frags = merge_fragments(fragment(line))
        for f in frags:
            fragments.append(Fragment(f, num))

    tokens = tokenizeFragments(fragments)

    data = []
    for t in tokens:
        tokendata = t.generate()
        print(f"'{t.fragment.s}' tag:{t.tag} data:{tokendata}")
        data.extend(tokendata)

    return data


def main():
    parser = argparse.ArgumentParser(description='DCPU ColorForth Converter')
    parser.add_argument("-i", help="Assembly input file", action="store", metavar="<input file>", type=str, required=True, dest="input_filename")
    parser.add_argument("-o", help="Binary output file basename (without file extension)", metavar="<output file base name>", action="store", type=str, required=True, dest="output_filename")
    args = parser.parse_args()
    data = convert(args.input_filename)
    # write to file
    with open(args.output_filename, mode="wb") as f:
        f.write(bytes(data))
    for b in data:
        sys.stdout.write(f"{b:02x} ")
    print()

if __name__ == "__main__":
    sys.exit(main())
