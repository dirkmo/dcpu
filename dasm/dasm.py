#!/usr/bin/env python3
import sys
import os
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


def main():
    print("dasm: Simple dcpu assembler\n")
    l = lark.Lark(grammar.grammar, start = "start")

    if len(sys.argv) < 2:
        print("Usage: dasm.py <asm file input>")
        exit(1)

    try:
        fn = sys.argv[1]
        with open(fn) as f:
            lines = f.readlines()
    except:
        print(f"ERROR: Cannot open file {fn}")
        return 2

    contents = "".join(lines)

    t = l.parse(contents)
    print(t.pretty())
    print(t)

    n = dcpuTransformer().transform(t)
    print(n)

    program = Program(n.children)

    # for c in n.children:
    #     print(c)

    # fn_noext = os.path.splitext(fn)[0]


if __name__ == "__main__":
    sys.exit(main())
