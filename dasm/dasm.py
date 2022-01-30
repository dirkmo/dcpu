#!/usr/bin/env python3
import sys
import os
import argparse
import lark
import grammar
import Instruction
from Program import Program

class dcpuTransformer(lark.Transformer):
    def call(self, a):
        a.append(Instruction.OpCall(a))
        return a

    def litl(self, a):
        a.append(Instruction.OpLitl(a))
        return a

    def lith(self, a):
        a.append(Instruction.OpLith(a))
        return a

    def lit(self, a):
        a.append(Instruction.OpLit(a))
        return a

    def rj(self, a):
        a.append(Instruction.OpRelJmp(a))
        return a

    def alu(self, a):
        a.append(Instruction.OpAlu(a))
        return a

    def equ(self, a):
        a.append(Instruction.OpEqu(a))
        return a

    def label(self, a):
        a.append(Instruction.OpLabel(a))
        return a

    def org(self, a):
        a.append(Instruction.OpOrg(a))
        return a

    def word(self, a):
        a.append(Instruction.OpWord(a))
        return a

    def ascii(self, a):
        a.append(Instruction.OpAscii(a))
        return a
    
    def cstr(self, a):
        a.append(Instruction.OpCstr(a))
        return a
    
    def space(self, a):
        a.append(Instruction.OpSpace(a))
        return a


def main():
    print("dasm: Simple dcpu assembler\n")
    l = lark.Lark(grammar.grammar, start = "start")

    parser = argparse.ArgumentParser(description='dcpu assembler')
    parser.add_argument("-i", help="Assembly input file", action="store", metavar="<input file>", type=str, required=True, dest="input_filename")
    parser.add_argument("-o", help="Binary output file basename (without file extension)", metavar="<output file base name>", action="store", type=str, required=False, dest="output_filebase")

    args = parser.parse_args()

    try:
        fn = args.input_filename
        with open(fn) as f:
            lines = f.readlines()
    except:
        print(f"ERROR: Cannot open file {fn}")
        return 2

    contents = "".join(lines)

    t = l.parse(contents)
    # print(t.pretty())
    # print(t)

    n = dcpuTransformer().transform(t)

    program = Program(n.children)

    (path, name) = os.path.split(fn) # remove path
    if args.output_filebase == None:
        outfn_noext = os.path.splitext(name)[0] # remove extension
    else:
        outfn_noext = args.output_filebase
    
    program.write_as_bin(outfn_noext+".bin")
    program.write_as_memfile(outfn_noext+".mem")
    program.write_as_cfile(outfn_noext+".c")
    program.write_as_listing(outfn_noext+".list", lines)
    program.write_symbols(outfn_noext+".symbols")
    program.write_as_simdata(outfn_noext+".sim", lines)

    size = program.end_address - program.start_address + 1
    print(f"File '{name}' assembled\nOutput size: {size} words")

if __name__ == "__main__":
    sys.exit(main())
