#!/usr/bin/env python3
import sys
import os
import lark
import grammar

class dcpuTransformer(lark.Transformer):

    def call(self, a):
        return a

    def litl(self, a):
        return a

    def lith(self, a):
        return a

    def rj(self, a):
        return a

    def alu(self, a):
        return a

    def equ(self, a):
        return a

    def label(self, a):
        return a

    def org(self, a):
        return a

    def word(self, a):
        return a

    def ascii(self, a):
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

    # n = dcpuTransformer().transform(t)
    # print(n)

    # for c in n.children:
    #     print(c)

    # fn_noext = os.path.splitext(fn)[0]


if __name__ == "__main__":
    sys.exit(main())
