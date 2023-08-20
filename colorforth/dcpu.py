class dcpu:
    OP_LITL = 0x8000
    OP_LITH = 0xa000
    OP_RJP = 0xe000
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

    def __init__(self, mif):
        self._mif = mif
        self.ds = []
        self.rs = []
        self.dsp = 0
        self.rsp = 0

    def dsp_op(self, dspmod):
        assert dspmod in [self.DSP_INC, self.DSP_DEC], f"Invalid dspmod {dspmod}"
        if dspmod == self.DSP_PLUS:
            self.dsp = (self.dsp + 1) % self.DS_SIZE
        elif dspmod == self.DSP_MINUS:
            self.dsp = (self.dsp - 1) % self.DS_SIZE

    def rsp_op(self, rspmod):
        assert rspmod in [self.RSP_RPC, self.RSP_INC, self.RSP_DEC, 0], f"Invalid rspmod {rspmod}"
        if rspmod == self.RSP_PLUS:
            self.rsp = (self.rsp + 1) % self.RS_SIZE
        elif rspmod in [self.RSP_MINUS, self.RSP_RPC]:
            self.rsp = (self.rsp - 1) % self.RS_SIZE

    def t(self):
        return self.ds[self.dsp]

    def n(self):
        return self.ds[(self.dsp-1)%self.DS_SIZE]

    def r(self):
        return self.rs[self.rsp]

    def call(self):
        self.rpush(self._pc + 1)
        self._pc = self._ir & 0x7fff

    def litl(self):
        self.dsp_op(self.DSP_INC)
        self.ds[self.dsp] = self._ir & ~0xe000

    def lith(self):
        self.ds[self.dsp] = (self.ds[self.dsp] & 0xff) | ((self._ir & 0xff) << 8)
        if (self._ir & 0x100):
            self.cpu_return()

    def cpu_return(self):
        self._pc = self.r()
        self.rsp_op(self.RSP_DEC)

    def rjp(self):
        cond = self._ir & 0x1c00
        condition  = ((cond == self.RJP_COND_ALWAYS))
        condition |= ((cond == self.RJP_COND_ZERO) and (self.t() == 0))
        condition |= ((cond == self.RJP_COND_NOTZERO) and (self.t() != 0))
        condition |= ((cond == self.RJP_COND_NEGATIVE) and (self.t() & 0x8000))
        condition |= ((cond == self.RJP_COND_NOTNEGATIVE) and not (self.t() & 0x8000))
        if condition:
            offs = self._ir & 0x3ff
            if (offs > 0x1ff): offs = offs - 0x200
            self._pc = self._pc % 0x10000

    def alu_op(self, op):
        pass

    def alu(self):
        rsp_op = self._ir & 0x3
        dsp_op = (self._ir >> 2) & 0x3
        dst = (self._ir >> 4) & 0x3
        ret = (self._ir >> 6) & 0x1
        op = (self._ir >> 7) & 0x1f
        result = self.alu_op(op)
        addr = self.t()
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
            self.cpu_return()

    def reset(self):
        self._pc = 0

    def step(self):
        pass
