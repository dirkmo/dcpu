#! /usr/bin/env python3

import argparse
import sys
from tokens import *
from dcpu import Dcpu, DcpuMemoryIf

class Mif(DcpuMemoryIf):
    def __init__(self):
        self._mem = bytearray(0x20000)

    def read(self, wordaddr):
        if wordaddr == 0xfffe: # uart-status
            pass
        elif wordaddr == 0xffff: # uart-rx
            pass
        else:
            return (self._mem[wordaddr*2] << 8) | self._mem[wordaddr*2+1]

    def write(self, wordaddr, word):
       if wordaddr == 0xfffe:
           pass
       elif wordaddr == 0xffff: # uart-tx
           pass
       else:
            self._mem[wordaddr*2] = (word >> 8) & 0xff
            self._mem[wordaddr*2+1] = word & 0xff


mif = Mif()
cpu = Dcpu(mif)


class Definition:
    D = []
    definitionCounter = 0

    def __init__(self):
        pass

    @classmethod
    def add(cls, name, addr):
        print(f"definition{Definition.definitionCounter}: {name}")
        Definition.D.append((name, addr))
        Definition.definitionCounter += 1

    @classmethod
    def addr(cls, idx):
        return Definition.D[idx]


def literal_number(hi, lo):
    # lit.l: 0x8000, lit.h: 0xa000
    return [0x8000 | lo, 0xa000 | hi]


def compileWord(idx):
    print(f"compile word {idx}: {Definition.D[idx]}")


def compileInstruction(op):
    print(f"compile instruction {op}")

def interpret(tok):
    idx = 0
    data = []
    mif.write(Consts.HERE, Consts.HERE+1)
    while idx < len(tok):
        tag = tok[idx]
        print(f"tag: {tag}")
        idx += 1
        if tag == Token.DEFINITION:
            l = tok[idx]
            idx += 1
            Definition.add(tok[idx:idx+l], mif.read(Consts.HERE))
            idx += l
        elif tag in [Token.LIT_NUMBER_DEC, Token.LIT_NUMBER_HEX]:
            data.extend(literal_number(tok[idx] << 8, tok[idx+1]))
            idx += 2
        elif tag == Token.LIT_STRING:
            pass
        elif tag == Token.LIT_WORD_ADDRESS:
            pass
        elif tag == Token.IMMEDIATE:
            pass
        elif tag == [Token.IMMEDIATE_NUMBER_DEC, Token.IMMEDIATE_NUMBER_HEX]:
            idx += 2
        elif tag == Token.IMMEDIATE_WORD_ADDRESS:
            pass
        elif tag == Token.COMMENT_BRACES:
            pass
        elif tag == Token.COMMENT_BACKSLASH:
            pass
        elif tag == Token.COMPILE_WORD:
            compileWord(tok[idx])
            idx += 1
        elif tag == Token.WHITESPACE:
            print("WS")
            l = tok[idx]
            idx += l + 1
        elif tag == Token.MNEMONIC:
            compileInstruction(tok[idx])
            idx += 1
        elif tag == Token.BUILDIN:
            compileInstruction(tok[idx])
            idx += 1

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
