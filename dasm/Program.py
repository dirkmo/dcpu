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
                pos = pos + entry.len(self.symbols)
            elif entry.type == OpBase.ORG:
                pos = entry.address()
                entry.pos = pos
            elif entry.type == OpBase.LABEL:
                self.symbols[entry.label()] = pos
                entry.pos = pos
            elif entry.type == OpBase.EQU:
                self.symbols[entry.label()] = entry.value()
        
        # Create raw memory
        self.data = [-1] * 65536
        for t in tokens:
            entry = t[-1]
            if entry.type in [OpBase.OPCODE, OpBase.DATA]:
                data = entry.data(self.symbols)
                pos = entry.pos
                self.start_address = min(self.start_address, pos)
                for c,d in enumerate(data):
                    self.data[pos+c] = d
                    self.end_address = max(self.end_address, pos+c)


    def write_as_bin(self, fn, endianess='big'):
        with open(fn ,"wb") as f:
            for addr in range(self.start_address, self.end_address + 1):
                d = max(0, self.data[addr])
                f.write(d.to_bytes(2, byteorder=endianess))


    def write_as_memfile(self, fn, endianess='big'):
        with open(fn ,"wt") as f:
            f.write(f"// start_address = 16'h{self.start_address:04x}\n")
            for addr in range(self.start_address, self.end_address + 1):
                d = max(0, self.data[addr])
                f.write(f"{d:04x}")
                if (addr % 8) == 7:
                    f.write("\n")
                else:
                    f.write(" ")


    def write_as_cfile(self, fn, endianess='big'):
        with open(fn ,"wt") as f:
            f.write(f"uint16_t start_address = 0x{self.start_address:04x};\n\n")
            f.write("uint16_t program[] = {\n")
            for addr in range(self.start_address, self.end_address + 1):
                d = max(0, self.data[addr])
                if (addr % 8) == 0:
                    f.write("    ")
                f.write(f"0x{d:04x}, ")
                if (addr % 8) == 7:
                    f.write("\n")
            if ((self.end_address - self.start_address) % 8):
                f.write("\n")
            f.write("};\n")


    def write_as_listing(self, fn, lines, endianess='big'):
        def find_token(line):
            for i,t in enumerate(self.tokens):
                l = t[0].line
                if (line == l) and (t[-1].type in [OpBase.OPCODE, OpBase.DATA]):
                    return t
            return None
        with open(fn ,"wt") as f:
            for i,l in enumerate(lines):
                f.write(f">{l}")
                t = find_token(i+1)
                if t != None:
                    entry = t[-1]
                    data = entry.data(self.symbols)
                    f.write(f"{entry.pos:04x}:")
                    for d in data:
                        f.write(f" {d:04x}")
                    f.write("\n")


    def write_as_simdata(self, fn, lines, endianess='big'):
        def find_token(line):
            for i,t in enumerate(self.tokens):
                l = t[0].line
                if (line == l) and (t[-1].type in [OpBase.OPCODE, OpBase.DATA, OpBase.LABEL, OpBase.ORG]):
                    return t
            return None
        
        pos = 0
        with open(fn ,"wt") as f:
            for i,l in enumerate(lines):
                t = find_token(i+1)
                if t != None:
                    entry = t[-1]
                    dl = entry.len(self.symbols)
                    pos = entry.pos
                    f.write(f"{pos:04x}: {l}")
                    if entry.type == OpBase.OPCODE:
                        for di in range(1,dl):
                            pos = pos + 1
                            f.write(f"{pos:04x}:\n")
                else:
                    f.write(f"{pos:04x}: {l}")


    def write_symbols(self, fn):
        with open(fn ,"wt") as f:
            for s in self.symbols:
                f.write(f"{s} 0x{self.symbols[s]:04x}\n")