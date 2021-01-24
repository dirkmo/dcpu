import sys
import os
import lark
import grammar
from instructions import *


class dcpuTransformer(lark.Transformer):
    
    @staticmethod
    def convert_to_number(s):
        if s[0] == '$': num = int(s[1:],16)
        else: num = int(s)
        return num

    def op(self, op): # op without immediate
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
    
    def opa(self, op): # op with immediate data
        s = str.upper(op[0])
        if s == "PUSH":
            if op[1].type == "REG":
                if   str.upper(op[1]) == "T": return Instruction(Instruction.OP_PUSHT)
                elif str.upper(op[1]) == "A": return Instruction(Instruction.OP_PUSHA)
                elif str.upper(op[1]) == "N": return Instruction(Instruction.OP_PUSHN)
                elif str.upper(op[1]) == "USP": return Instruction(Instruction.OP_PUSHUSP)
                elif str.upper(op[1]) == "STATUS": return Instruction(Instruction.OP_PUSHS)
                elif str.upper(op[1]) == "DSP": return Instruction(Instruction.OP_PUSHDSP)
                elif str.upper(op[1]) == "ASP": return Instruction(Instruction.OP_PUSHASP)
                elif str.upper(op[1]) == "PC": return Instruction(Instruction.OP_PUSHPC)
                else:
                    print(f"Invald PUSH register: {op[1]}")
                    exit(1)
            elif op[1].type == "NUMBER":
                num = self.convert_to_number(op[1])
                return Instruction(Instruction.OP_PUSHI, num)
        if s == ".ORG":
            pass
        #print(f"{s} {op[1]}")
        return op

    def org(self, dir):
        if dir[0].type == "NUMBER":
            num = self.convert_to_number(dir[0])
            dir[0].value = num


def main():
    l = lark.Lark(grammar.grammar, start = "start")

    try:
        fn = sys.argv[1]
        with open(fn) as f:
            lines = f.readlines()
    except:
        print("Cannot open file")
        return 1

    prog = "".join(lines)
    t = l.parse(prog)

    print(t.pretty())
    
    #n = dcpuTransformer().transform(t)
    #print(n.pretty())

main()
