#! /usr/bin/env python3

import sys

class DcpuMemoryIf:
    def read(self, wordaddr) -> int:
        ...

    def write(self, wordaddr, word):
        ...

class Dcpu:
    ALU_OP_MNEMONIC = ["T", "N", "R", "MEMT", "ADD", "SUB", "NOP", "AND", "OR", "XOR", "LTS", "LT", "SR", "SRW", "SL", "SLW", "JZ", "JNZ", "CARRY", "INV", "MULL", "MULH"]
    OP_LITL = 0x8000
    OP_LITH = 0xa000
    OP_RJP = 0xe000
    SIM_END = OP_LITH | (0xf << 9)
    RJP_COND_ALWAYS = 0
    RJP_COND_ZERO = 0x400
    RJP_COND_NOTZERO = 0x500
    RJP_COND_NEGATIVE = 0x600
    RJP_COND_NOTNEGATIVE = 0x700
    DS_SIZE = 16
    RS_SIZE = 16
    RSP_NONE = 0x0
    RSP_INC = 0x1
    RSP_DEC = 0x2
    RSP_RPC = 0x3
    DSP_NONE = 0x0
    DSP_INC = 0x4
    DSP_DEC = 0x8
    DST_T = 0x0
    DST_R = 0x1
    DST_PC = 0x2
    DST_MEM = 0x3
    ALU_T = 0
    ALU_N = 1
    ALU_R = 2
    ALU_MEMT = 3
    ALU_ADD = 4
    ALU_SUB = 5
    ALU_NOP = 6
    ALU_AND = 7
    ALU_OR = 8
    ALU_XOR = 9
    ALU_LTS = 10
    ALU_LT = 11
    ALU_SR = 12
    ALU_SRW = 13
    ALU_SL = 14
    ALU_SLW = 15
    ALU_JZ = 16
    ALU_JNZ = 17
    ALU_CARRY = 18
    ALU_INV = 19
    ALU_MULL = 20
    ALU_MULH = 21

    def __init__(self, mif: DcpuMemoryIf):
        self._mif = mif
        self._ir = 0
        self.ds = [0] * self.DS_SIZE
        self.rs = [0] * self.RS_SIZE
        self.dsp = 0
        self.rsp = 0
        self.reset()

    def dsp_op(self, dspmod):
        assert dspmod in [0, self.DSP_INC, self.DSP_DEC], f"Invalid dspmod {dspmod}"
        if dspmod == self.DSP_INC:
            self.dsp = (self.dsp + 1) % self.DS_SIZE
        elif dspmod == self.DSP_DEC:
            self.dsp = (self.dsp - 1) % self.DS_SIZE

    def rsp_op(self, rspmod):
        assert rspmod in [self.RSP_RPC, self.RSP_INC, self.RSP_DEC, 0], f"Invalid rspmod {rspmod}"
        if rspmod == self.RSP_INC:
            self.rsp = (self.rsp + 1) % self.RS_SIZE
        elif rspmod in [self.RSP_DEC, self.RSP_RPC]:
            self.rsp = (self.rsp - 1) % self.RS_SIZE

    def t(self):
        return self.ds[self.dsp]

    def n(self):
        return self.ds[(self.dsp-1) % self.DS_SIZE]

    def r(self):
        return self.rs[self.rsp]

    def call(self):
        self.rsp_op(self.RSP_INC)
        self.rs[self.rsp] = (self._pc + 1) & 0xffff
        self._pc = self._ir & 0x7fff
        sys.stdout.write(f"call {self._pc}")

    def litl(self):
        self.dsp_op(self.DSP_INC)
        self.ds[self.dsp] = self._ir & ~0xe000
        sys.stdout.write(f"litl {self.ds[self.dsp]:x}")

    def lith(self):
        self.ds[self.dsp] = (self.ds[self.dsp] & 0xff) | ((self._ir & 0xff) << 8)
        if (self._ir & 0x100):
            # return bit set
            self._pc = self.r()
            sys.stdout.write(f"lith {self._ir & 0xff:x} [ret]")
        else:
            sys.stdout.write(f"lith {self._ir & 0xff:x}")

    def rjp(self):
        cond = self._ir & 0x1c00
        offs = self._ir & 0x3ff
        if (offs > 0x1ff):
            offs = offs - 0x400
        condition  = ((cond == self.RJP_COND_ALWAYS))
        condition |= ((cond == self.RJP_COND_ZERO) and (self.t() == 0))
        condition |= ((cond == self.RJP_COND_NOTZERO) and (self.t() != 0))
        condition |= ((cond == self.RJP_COND_NEGATIVE) and (self.t() & 0x8000))
        condition |= ((cond == self.RJP_COND_NOTNEGATIVE) and not (self.t() & 0x8000))

        if cond == self.RJP_COND_ALWAYS: sys.stdout.write(f"rj {self._pc + offs}")
        elif cond == self.RJP_COND_ZERO: sys.stdout.write(f"rj.z {self._pc + offs}")
        elif cond == self.RJP_COND_NOTZERO: sys.stdout.write(f"rj.nz {self._pc + offs}")
        elif cond == self.RJP_COND_NEGATIVE: sys.stdout.write(f"rj.n {self._pc + offs}")
        elif cond == self.RJP_COND_NOT_NEGATIVE: sys.stdout.write(f"rj.nn {self._pc + offs}")

        if condition:
            self._pc = (self._pc + offs) & 0xffff

    def complement2(self, v):
        if v & 0x8000:
            v = -(0x10000 - v)
        return v

    def alu_op(self, op):
        if op == self.ALU_T:
            return self.t()
        elif op == self.ALU_N:
            return self.n()
        elif op == self.ALU_R:
            return self.r()
        elif op == self.ALU_MEMT:
            return self._mif.read(self.t())
        elif op == self.ALU_ADD:
            sum = self.n() + self.t()
            self.carry = 1 if sum > 0xffff else 0
            return sum & 0xffff
        elif op == self.ALU_SUB:
            res = self.n() - self.t()
            self.carry = 1 if res < 0 else 0
            return res & 0xffff
        elif op == self.ALU_NOP:
            return self.t()
        elif op == self.ALU_AND:
            return (self.n() & self.t()) & 0xffff
        elif op == self.ALU_OR:
            return (self.n() | self.t()) & 0xffff
        elif op == self.ALU_XOR:
            return (self.n() ^ self.t()) & 0xffff
        elif op == self.ALU_LTS:
            return self.complement2(self.n()) < self.complement2(self.t())
        elif op == self.ALU_LT:
            return self.n() < self.t()
        elif op == self.ALU_SR:
            return self.t() >> 1
        elif op == self.ALU_SRW:
            return self.t() >> 8
        elif op == self.ALU_SL:
            return self.t() << 1
        elif op == self.ALU_SLW:
            return self.t() << 8
        elif op == self.ALU_JZ:
            return self.n() if self.t() == 0 else (self._pc+1) & 0xffff
        elif op == self.ALU_JNZ:
            return self.n() if self.t() != 0 else (self._pc+1) & 0xffff
        elif op == self.ALU_CARRY:
            return self.carry
        elif op == self.ALU_INV:
            return ~self.t()
        elif op == self.ALU_MULL:
            return (self.n() * self.t()) & 0xffff
        elif op == self.ALU_MULH:
            return ((self.n() * self.t()) >> 16) & 0xffff
        else:
            assert False, f"Invalid alu op {op}"

    def alu(self):
        rsp_op = self._ir & 0x3
        dsp_op = self._ir & 0xc
        dst = (self._ir >> 4) & 0x3
        ret = (self._ir >> 6) & 0x1
        op = (self._ir >> 7) & 0x1f
        sys.stdout.write(f"a:{self.ALU_OP_MNEMONIC[op]}")
        result = self.alu_op(op)
        addr = self.t()
        ret_addr = self.r()
        self.dsp_op(dsp_op)
        self.rsp_op(rsp_op)
        if dst == self.DST_T:
            self.ds[self.dsp] = result
        elif dst == self.DST_R:
            self.rs[self.rsp] = result
        elif dst == self.DST_PC:
            self._pc = result
        elif dst == self.DST_MEM:
            self._mif.write(addr, result)
        if ret:
            self._pc = ret_addr
        if not ret and not (dst == self.DST_PC):
            self._pc = (self._pc + 1) & 0xffff

    def reset(self):
        self._pc = 0
        self.carry = 0

    def decode(self):
        if self._ir & 0x8000 == 0:
            self.call()
        elif self._ir & 0xe000 == 0x8000:
            self.litl()
            self._pc = (self._pc + 1) & 0xffff
        elif self._ir & 0xe000 == 0xa000:
            self.lith()
            self._pc = (self._pc + 1) & 0xffff
        elif self._ir & 0xe000 == 0xe000:
            self.rjp()
        elif self._ir & 0xe000 == 0xc000:
            self.alu()
        else:
            assert False, f"Unknown opcode {self._ir:04x}"

    def print_dstack(self):
        sys.stdout.write(" <")
        for i in range(0, (self.dsp+1)%self.DS_SIZE):
            sys.stdout.write(f"{self.ds[i]:04x}")
            if  i < self.dsp:
                sys.stdout.write(" ")
        sys.stdout.write(">\n")

    def step(self):
        self._ir = self._mif.read(self._pc)
        if self._ir == self.SIM_END:
            return False
        sys.stdout.write(f"{self._pc:04x} ")
        self.decode()
        self.print_dstack()
        return True


class Mif(DcpuMemoryIf):
    def __init__(self, image_fn):
        self._mem = bytearray(0x20000)
        with open(image_fn,"rb") as f:
            buf = f.read()
        for i in range(len(buf)):
            self._mem[i] = buf[i]

    def read(self, wordaddr):
        return (self._mem[wordaddr*2] << 8) | self._mem[wordaddr*2+1]

    def write(self, wordaddr, word):
       self._mem[wordaddr*2] = (word >> 8) & 0xff
       self._mem[wordaddr*2+1] = word & 0xff


def main():
    mif = Mif("prog.bin")

    cpu = Dcpu(mif)
    while cpu.step():
        pass


if __name__ == "__main__":
    main()
