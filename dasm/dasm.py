import sys
import os
import lark
import grammar
from instructions import *

class dcpuTransformer(lark.Transformer):
    def op(self, op):
        s = str.upper(op[0])
        if   s == "ADD": return Instruction(Instruction.OP_ADD)
        elif s == "SUB": return Instruction(Instruction.OP_SUB)
        elif s == "AND": return Instruction(Instruction.OP_AND)
        elif s == "OR": return Instruction(Instruction.OP_OR)
        elif s == "XOR": return Instruction(Instruction.OP_XOR)
        elif s == "LSR": return Instruction(Instruction.OP_LSR)
        elif s == "CPR": return Instruction(Instruction.OP_CPR)
        elif s == "POP": return Instruction(Instruction.OP_POP)
        elif s == "APOP": return Instruction(Instruction.OP_APOP)
        elif s == "RET": return Instruction(Instruction.OP_RET)
        elif s == "SETSTATUS": return Instruction(Instruction.OP_SETSTATUS)
        elif s == "SETDSP": return Instruction(Instruction.OP_SETDSP)
        elif s == "SETASP": return Instruction(Instruction.OP_SETASP)
        elif s == "SETUSP": return Instruction(Instruction.OP_SETUSP)
        elif s == "SETA": return Instruction(Instruction.OP_SETA)
        elif s == "APUSH": return Instruction(Instruction.OP_APUSH)
    
    def opa(self, op):

        return op



def main():
    l = lark.Lark(grammar.grammar)

    try:
        fn = sys.argv[1]
        with open(fn) as f:
            lines = f.readlines()
    except:
        print("Cannot open file")
        return 1

    prog = "".join(lines)
    t = l.parse(prog)

    n = dcpuTransformer().transform(t)

    print(n.pretty())

main()
