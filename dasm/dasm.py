#!/usr/bin/env python3
from instructions import Instruction
import sys
import os
import lark
import grammar
from instructions import *

program  = []
variables = []

def newToken(name, value):
    t = lark.Token()
    t.type = name
    t.value = value

class dcpuTransformer(lark.Transformer):
    
    _ops = {
        "ADD": Instruction.OP_ADD,
        "SUB": Instruction.OP_SUB,
        "AND": Instruction.OP_AND,
        "OR": Instruction.OP_OR,
        "XOR": Instruction.OP_XOR,
        "LSR": Instruction.OP_LSR,
        "CPR": Instruction.OP_CPR,
        "POP": Instruction.OP_POP,
        "APOP": Instruction.OP_APOP,
        "RET": Instruction.OP_RET,
        "SETSTATUS": Instruction.OP_SETSTATUS,
        "SETDSP": Instruction.OP_SETDSP,
        "SETASP": Instruction.OP_SETASP,
        "SETUSP": Instruction.OP_SETUSP,
        "SETA": Instruction.OP_SETA,
        "APUSH": Instruction.OP_APUSH,
        "INT": Instruction.OP_INT
    }

    _opa_push_regs = {
        "T": Instruction.OP_PUSHT,
        "A": Instruction.OP_PUSHA,
        "N": Instruction.OP_PUSHN,
        "USP": Instruction.OP_PUSHUSP,
        "STATUS": Instruction.OP_PUSHS,
        "DSP": Instruction.OP_PUSHDSP,
        "ASP": Instruction.OP_PUSHASP,
        "PC": Instruction.OP_PUSHPC
    }

    @staticmethod
    def convert_to_number(s):
        if s[0] == '$': num = int(s[1:],16)
        else: num = int(s)
        return num
    
    @staticmethod
    def convert_rel_to_number(s):
        s = s[s.find('+')+1:]
        return dcpuTransformer.convert_to_number(s)

    def op(self, op): # op without immediate
        inst = Instruction(self._ops[op[0].upper()])
        program.append(inst)
    
    def op_store_fetch(self, op_group, op):
        if isinstance(op, lark.Token):
            if op.type == "REG":
                if   op.upper() == "T": return Instruction(op_group | 0x0) # fetch/store t
                elif op.upper() == "A": return Instruction(op_group | 0x1) # fetch/store a
            elif op.type == "REL":
                return InstructionRel(op_group | 0x02, self.convert_rel_to_number(op)) # fetch/store u+#offs
            elif op.type == "NUMBER":
                num = self.convert_to_number(op)
                return InstructionAbs(op_group | 0x04, num) # fetch/store #imm
            elif op.type == "ID":
                return InstructionAbs(op_group | 0x4, op.value)
        print("not handled yet")
        return None

    def op_jmp(self, op_group, op):
        if isinstance(op, lark.Token):
            if op.type == "REG":
                if   op.upper() == "T": return Instruction(op_group | 0x0) # jmp t
                elif op.upper() == "A": return Instruction(op_group | 0x1) # jmp a
            elif op.type == "NUMBER":
                num = self.convert_to_number(op)
                return InstructionAbs(op_group | 0x04, num) # jmp #imm
            elif op.type == "ID":
                return InstructionAbs(op_group | 0x04, op.value)
        print("not handled yet")
        return None


    def opa(self, op): # op with immediate data
        print(op)
        s = str.upper(op[0])
        ret = None
        if s == "PUSH":
            if op[1].type == "REG":
                ret = Instruction(self._opa_push_regs[str.upper(op[1])])
            elif op[1].type == "NUMBER":
                num = self.convert_to_number(op[1])
                ret = InstructionAbs(Instruction.OP_PUSHI, num)
            elif op[1].type == "ID":
                ret = InstructionAbs(Instruction.OP_PUSHI, op[1].value)
        elif s == "FETCH":
            ret = self.op_store_fetch(InstructionAbs.OP_FETCHGROUP, op[1])
        elif s == "STORE":
            ret = self.op_store_fetch(InstructionAbs.OP_STOREGROUP, op[1])
        elif s == "JMP":
            ret = self.op_jmp(InstructionAbs.OP_JMPGROUP, op[1])
        elif s == "BRA":
            ret = self.op_jmp(InstructionAbs.OP_BRANCHGROUP, op[1])
        elif s == "JPC":
            ret = self.op_jmp(InstructionAbs.OP_JMPCGROUP, op[1])
        elif s == "JPNC":
            ret = self.op_jmp(InstructionAbs.OP_JMPNCGROUP, op[1])
        elif s == "JPZ":
            ret = self.op_jmp(InstructionAbs.OP_JMPZGROUP, op[1])
        elif s == "JPNZ":
            ret = self.op_jmp(InstructionAbs.OP_JMPNZGROUP, op[1])
        if ret != None:
            program.append(ret)
        else:
            print("###not handled yet")
            return lark.Tree('opa', op)

    def org(self, dir):
        print(dir)
        if dir[0].type == "NUMBER":
            num = self.convert_to_number(dir[0])
            Instruction._current = num
            program.append(Instruction(Instruction.OP_ORG, num))
        else:
            return dir
    
    def equ(self, op):
        print(op)
        if op[0].type == "ID":
            if op[0] in variables:
                print(f"Error in line {op[0].line}: {op[1]} already defined.")
                exit(1)
            program.append(Instruction(Instruction.OP_EQU, [op[0].value, self.convert_to_number(op[1].value)]))
            variables.append(op[0].value)
        else:
            return op
    
    def byte(self, op):
        print(op)
        data = []
        for o in op:
            if o.type == "NUMBER":
                data.append(self.convert_to_number(o))
            elif o.type == "ESCAPED_STRING":
                for c in o.value[1:-1]:
                    data.append(c)
            else:
                print(f"Unknown byte payload in line {o.line}")
                exit(1)
        program.append(Instruction(Instruction.OP_BYTE, data))

    def word(self, op):
        print(op)
        data = []
        for o in op:
            if o.type == "NUMBER":
                data.append(self.convert_to_number(o))
            elif o.type == "ID":
                    data.append(o.value) # undefined ID appended as Token
            else:
                print(f"Unknown word payload in line {o.line}")
                exit(1)
        program.append(Instruction(Instruction.OP_WORD, data))

    def res(self, op):
        print(op)
        size = self.convert_to_number(op[0].value)
        program.append(Instruction(Instruction.OP_RES, size))


    def label(self, op):
        print(op)
        if op[0].type == "CNAME":
            if op[0] in variables:
                print(f"Error in line {op[0].line}: {op[0]} already defined.")
                exit(1)
            variables.append(op[0].value)
            program.append(Instruction(Instruction.OP_LABEL, op[0].value))
        else:
            return lark.Tree('label', op)
    
    def mul(self, op):
        print(op)
        try:
            value = int(op[0].children[0]) * int(op[1].children[0])
            return lark.Token(type_="NUMBER",value=str(value))
        except:
            return op

    def div(self, op):
        print(op)
        try:
            value = int(op[0].children[0]) // int(op[1].children[0])
            return lark.Token(type_="NUMBER",value=str(value))
        except:
            return op

    def plus(self, op):
        print(op)
        try:
            value = int(op[0]) + int(op[1])
            return lark.Token(type_="NUMBER",value=str(value))
        except:
            return op

    def minus(self, op):
        print(op)
        try:
            value = int(op[0].children[0]) - int(op[1].children[0])
            return lark.Token(type_="NUMBER",value=str(value))
        except:
            return op

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

    print(t)

    print("-----------------------------------------")

    print("Transformer:")
    n = dcpuTransformer().transform(t)

    print("-----------------------------------------")

    print(variables)

    print("-----------------------------------------")

    for p in program:
        print(p)

main()
