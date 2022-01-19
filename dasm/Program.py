from Instruction import *

class Program:
    def __init__(self, tokens):
        self.tokens = tokens
        self.symbols = {}
        self.start_address = 0x10000
        self.end_address = 0
        pos = 0
        # locate the code, collect symbols
        for t in tokens:
            entry = t[-1]
            if entry.type in [OpBase.OPCODE, OpBase.DATA]:
                entry.pos = pos
                pos = pos + entry.len()
            elif entry.type == OpBase.ORG:
                pos = entry.address()
            elif entry.type == OpBase.LABEL:
                self.symbols[entry.label()] = pos
            elif entry.type == OpBase.EQU:
                self.symbols[entry.label()] = entry.value()
        