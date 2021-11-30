#!/usr/bin/env python3
import sys
import os
import copy
import lark
import grammar

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

    lines = "st (r1+1), r2\n"
    contents = "".join(lines)

    t = l.parse(contents)
    print(t.pretty())
    print(t)

if __name__ == "__main__":
    sys.exit(main())
