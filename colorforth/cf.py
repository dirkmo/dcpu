#! /usr/bin/env python3

import argparse
import sys
from tokens import *

D = {}
definitionCounter = 0

def addDefinition(name):
    D[name] = definitionCounter
    definitionCounter += 1

def immediate_number(hi, lo):
    # lit.l: 0x8000, lit.h: 0xa000
    return [0x8000 | lo, 0xa000 | hi]

def interpret(data):
    idx = 0
    data = []
    while True:
        tag = data[idx]
        idx += 1
        if tag == Token.DEFINITION:
            l = data[idx]
            idx += 1
            addDefinition(data[idx:idx+l])
        elif tag in [Token.LIT_NUMBER_DEC, Token.LIT_NUMBER_HEX]:
            pass
        elif tag == Token.LIT_STRING:
            pass
        elif tag == Token.LIT_WORD_ADDRESS:
            pass
        elif tag == Token.IMMEDIATE:
            pass
        elif tag == [Token.IMMEDIATE_NUMBER_DEC, IMMEDIATE_NUMBER_HEX]:
            idx += 2
            data.append(immediate_number(data[idx] << 8, data[idx+1]))
        elif tag == Token.IMMEDIATE_WORD_ADDRESS:
            pass
        elif tag == Token.COMMENT_BRACES:
            pass
        elif tag == Token.COMMENT_BACKSLASH:
            pass
        elif tag == Token.COMPILE_WORD:
            pass
        elif tag == Token.WHITESPACE:
            pass
        elif tag == Token.MNEMONIC_ALU:
            pass
        elif tag == Token.BUILDIN:
            pass


def main():
    parser = argparse.ArgumentParser(description='DCPU ColorForth Compiler')
    parser.add_argument("-i", help="Assembly input file", action="store", metavar="<input file>", type=str, required=True, dest="input_filename")
    parser.add_argument("-o", help="Binary output file basename (without file extension)", metavar="<output file base name>", action="store", type=str, required=True, dest="output_filename")
    args = parser.parse_args()

    with open(args.input_filename, "rb") as f:
        tokendata = f.read()

    rawdata = interpret(tokendata)

if __name__ == "__main__":
    sys.exit(main())
