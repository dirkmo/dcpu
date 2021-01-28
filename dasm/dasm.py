#!/usr/bin/env python3
from instructions import Instruction
import sys
import os
import lark
import grammar
from instructions import *

variables = {}

def newToken(name, value):
    t = lark.Token()
    t.type = name
    t.value = value

class dcpuTransformer(lark.Transformer):
    
    _ops = {
        "ADD": Instruction(Instruction.OP_ADD),
        "SUB": Instruction(Instruction.OP_SUB),
        "AND": Instruction(Instruction.OP_AND),
        "OR": Instruction(Instruction.OP_OR),
        "XOR": Instruction(Instruction.OP_XOR),
        "LSR": Instruction(Instruction.OP_LSR),
        "CPR": Instruction(Instruction.OP_CPR),
        "POP": Instruction(Instruction.OP_POP),
        "APOP": Instruction(Instruction.OP_APOP),
        "RET": Instruction(Instruction.OP_RET),
        "SETSTATUS": Instruction(Instruction.OP_SETSTATUS),
        "SETDSP": Instruction(Instruction.OP_SETDSP),
        "SETASP": Instruction(Instruction.OP_SETASP),
        "SETUSP": Instruction(Instruction.OP_SETUSP),
        "SETA": Instruction(Instruction.OP_SETA),
        "APUSH": Instruction(Instruction.OP_APUSH),
        "INT": Instruction(Instruction.OP_INT)
    }

    _opa_push_regs = {
        "T": Instruction(Instruction.OP_PUSHT),
        "A": Instruction(Instruction.OP_PUSHA),
        "N": Instruction(Instruction.OP_PUSHN),
        "USP": Instruction(Instruction.OP_PUSHUSP),
        "STATUS": Instruction(Instruction.OP_PUSHS),
        "DSP": Instruction(Instruction.OP_PUSHDSP),
        "ASP": Instruction(Instruction.OP_PUSHASP),
        "PC": Instruction(Instruction.OP_PUSHPC)
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

    @staticmethod
    def isID(id):
        t = id in ["ID", "IDLO", "IDHI" ]
        return t

    @staticmethod
    def hasUndefined(op):
        for o in op:
            isid = dcpuTransformer.isID(o.type)
            if isid and not o.value in variables:
                return True
        return False

    def op(self, op): # op without immediate
        return self._ops[op[0].upper()]
    
    def op_store_fetch(self, op_group, op):
        if isinstance(op, lark.Token):
            if op.type == "REG":
                if   op.upper() == "T": return Instruction(op_group | 0x0) # fetch/store t
                elif op.upper() == "A": return Instruction(op_group | 0x1) # fetch/store a
            elif op.type == "REL":
                return Instruction(op_group | 0x02, self.convert_rel_to_number(op)) # fetch/store u+#offs
            elif op.type == "NUMBER":
                num = self.convert_to_number(op)
                return Instruction(op_group | 0x04, num) # fetch/store #imm
            elif op.type == "ID":
                pass # TODO
        else:
            print("not handled yet")
        return op

    def op_jmp(self, op_group, op):
        if isinstance(op, lark.Token):
            if op.type == "REG":
                if   op.upper() == "T": return Instruction(op_group | 0x0) # jmp t
                elif op.upper() == "A": return Instruction(op_group | 0x1) # jmp a
            elif op.type == "NUMBER":
                num = self.convert_to_number(op)
                return Instruction(op_group | 0x04, num) # jmp #imm
            elif op.type == "ID":
                pass # TODO
        else:
            print("not handled yet")
        return op


    def opa(self, op): # op with immediate data
        print(op)
        s = str.upper(op[0])
        ret = None
        if s == "PUSH":
            if isinstance(op[1], lark.Token):
                if op[1].type == "REG":
                    return self._opa_push_regs[str.upper(op[1])]
                elif op[1].type == "NUMBER":
                    num = self.convert_to_number(op[1])
                    return Instruction(Instruction.OP_PUSHI, num)
                elif op[1].type == "ID":
                    pass # TODO
            else:
                print("not handled yet")
        elif s == "FETCH":
            if isinstance(op[1], lark.Token):
                ret = self.op_store_fetch(Instruction.OP_FETCHGROUP, op[1])
            else:
                print("###not handled yet")
        elif s == "STORE":
            if isinstance(op[1], lark.Token):
                ret = self.op_store_fetch(Instruction.OP_STOREGROUP, op[1])
            else:
                print("###not handled yet")
        elif s == "JMP":
            if isinstance(op[1], lark.Token):
                ret = self.op_jmp(Instruction.OP_JMPGROUP, op[1])
            else:
                print("###not handled yet")
        elif s == "BRA":
            if isinstance(op[1], lark.Token):
                ret = self.op_jmp(Instruction.OP_BRANCHGROUP, op[1])
            else:
                print("###not handled yet")
        elif s == "JPC":
            if isinstance(op[1], lark.Token):
                ret = self.op_jmp(Instruction.OP_JMPCGROUP, op[1])
            else:
                print("###not handled yet")
        elif s == "JPNC":
            if isinstance(op[1], lark.Token):
                ret = self.op_jmp(Instruction.OP_JMPNCGROUP, op[1])
            else:
                print("###not handled yet")
        elif s == "JPZ":
            if isinstance(op[1], lark.Token):
                ret = self.op_jmp(Instruction.OP_JMPZGROUP, op[1])
            else:
                print("###not handled yet")
        elif s == "JPNZ":
            if isinstance(op[1], lark.Token):
                ret = self.op_jmp(Instruction.OP_JMPNZGROUP, op[1])
            else:
                print("###not handled yet")
        if ret != None:
            return ret
        return op

    def org(self, dir):
        print(dir)
        if dir[0].type == "NUMBER":
            num = self.convert_to_number(dir[0])
            dir[0].value = num
            Instruction._current = num
    
    def equ(self, op):
        print(op)
        if op[0].type == "ID":
            variables[op[0].value] = self.convert_to_number(op[1])
    
    def byte(self, op):
        print(op)
        data = []
        for o in op:
            if o.type == "NUMBER":
                data.append(self.convert_to_number(o))
            elif dcpuTransformer.isID(o.type):
                if o.value in variables:
                    data.append(variables[o.value])
                else: return op # undefined ID
            elif o.type == "ESCAPED_STRING":
                for c in o.value[1:-1]:
                    data.append(c)
        return Instruction(None, None, data)
        pass

    def word(self, op):
        print(op)
        pass

    def res(self, op):
        size = self.convert_to_number(op.value)
        Instruction._current = Instruction._current + size
        pass

    def label(self, op):
        print(dir)
        if op[0].type == "CNAME":
            if op[0] in variables:
                print(f"Error in line {op[0].line}: {op[0]} already defined.")
                exit(1)
            variables[op[0].value] = current
        pass

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

    print(t.pretty())
    
    print("---------------")
    print("Transformer:")
    n = dcpuTransformer().transform(t)

    print("---------------")

    print(n.pretty())

main()
