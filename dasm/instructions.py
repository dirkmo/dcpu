class Instruction:
    OP_ALU      = 0x80             # 1000 0xxx

    # Alu Ops    T <- N op T

    OP_ADD      = OP_ALU | 0x0     # 1000 0000 plus
    OP_SUB      = OP_ALU | 0x1     # 1000 0001 minus
    OP_AND      = OP_ALU | 0x2     # 1000 0010 and
    OP_OR       = OP_ALU | 0x3     # 1000 0011 or
    OP_XOR      = OP_ALU | 0x4     # 1000 0100 xor
    OP_LSR      = OP_ALU | 0x5     # 1000 0101 lsr
    OP_CPR      = OP_ALU | 0x6     # 1000 0110 cpr  ; t <- { n[7:0], t[7:0] } (compress 2 chars into one word)

    # Stack
    OP_STACKGROUP1  = 0x90                  # 1001 xxxx
    OP_PUSHT        = OP_STACKGROUP1 | 0x0  # 1001 0000 push t         ; mem[dsp] <- n, dsp++, n <- t
    OP_PUSHA        = OP_STACKGROUP1 | 0x1  # 1001 0001 push a         ; mem[dsp] <- n, dsp++, n <- t, t <- a
    OP_PUSHN        = OP_STACKGROUP1 | 0x2  # 1001 0010 push n         ; mem[dsp] <- n, dsp++, n <- t, t <- n
    OP_PUSHUSP      = OP_STACKGROUP1 | 0x3  # 1001 0011 push usp       ; mem[dsp] <- n, dsp++, n <- t, t <- usp
    OP_PUSHI        = OP_STACKGROUP1 | 0x4  # 1001 01xy push #im       ; mem[dsp] <- n, dsp++, n <- t, t <- {x, ir[22:16], y, ir[14:8]}

    OP_STACKGROUP2  = 0x98
    OP_PUSHS        = OP_STACKGROUP2 | 0x8  # 1001 1000 push status    ; mem[dsp] <- n, dsp++, n <- t, t <- status
    OP_PUSHDSP      = OP_STACKGROUP2 | 0x9  # 1001 1001 push dsp       ; mem[dsp] <- n, dsp++, n <- t, t <- dsp
    OP_PUSHASP      = OP_STACKGROUP2 | 0xA  # 1001 1010 push asp       ; mem[dsp] <- n, dsp++, n <- t, t <- asp
    OP_PUSHPC       = OP_STACKGROUP2 | 0xB  # 1001 1011 push pc+1      ; mem[dsp] <- n, dsp++, n <- t, t <- pc+1

    # Memory
    OP_FETCHGROUP   = 0xA0
    OP_FETCHT       = OP_FETCHGROUP | 0x0   # 1010 0000 fetch t        ; t <- mem[t]
    OP_FETCHA       = OP_FETCHGROUP | 0x1   # 1010 0001 fetch a        ; t <- mem[a]
    OP_FETCHU       = OP_FETCHGROUP | 0x2   # 1010 0010 fetch u+#ofs   ; t <- mem[usp+#ofs]
    # OP_FETCH     = OP_FETCHGROUP | 0x3    # 1010 0011
    OP_FETCHABS     = OP_FETCHGROUP | 0x4   # 1010 01xy fetch #imm     ; t <- mem[#imm] mit #imm = {x, ir[22:16], y, ir[14:8]}

    OP_STOREGROUP   = 0xA8
    OP_STORET       = OP_STOREGROUP | 0x0   # 1010 1000 store t        ; mem[t] <- n
    OP_STOREA       = OP_STOREGROUP | 0x1   # 1010 1001 store a        ; mem[a] <- t
    OP_STOREU       = OP_STOREGROUP | 0x2   # 1010 1010 store u+#ofs   ; mem[usp+#ofs] <- t
    # OP_STORE     = OP_STOREGROUP | 0x3    # 1010 1011
    OP_STOREABS     = OP_STOREGROUP | 0x4   # 1010 11xy store #imm     ; mem[#imm] <- t mit #imm = {x, ir[22:16], y, ir[14:8]}

    # # Jumps
    OP_JMPGROUP     = 0xB0
    OP_JMPT         = OP_JMPGROUP | 0x0     # 1011 0000 jmp t          ; pc <- t
    OP_JMPA         = OP_JMPGROUP | 0x1     # 1011 0001 jmp a          ; pc <- a
    # OP_JMP       = OP_JMPGROUP | 0x2      # 1011 0010
    # OP_JMP       = OP_JMPGROUP | 0x3      # 1011 0011
    OP_JMPABS       = OP_JMPGROUP | 0x4     # 1011 01xy jmp #im        ; pc <- #im mit #im =  {x, ir[22:16], y, ir[14:8]}

    OP_BRANCHGROUP  = 0xB8
    OP_BRAT         = OP_BRANCHGROUP | 0x0  # 1011 1000 bra t          ; mem[asp] <- a, a <- pc+1, asp++, pc <- t
    OP_BRAA         = OP_BRANCHGROUP | 0x1  # 1011 1001 bra a          ; mem[asp] <- a, a <- pc+1, asp++, pc <- t
    OP_INT          = OP_BRANCHGROUP | 0x2  # 1011 1010 int            ; mem[asp] <- a, a <- pc+1, asp++, pc <- int-vec
    # OP_BRAx      = OP_BRANCHGROUP | 0x3   # 1011 1011
    OP_BRAABS       = OP_BRANCHGROUP | 0x4  # 1011 11xy bra #im        ; mem[asp] <- a, a <- pc+1, asp++, pc <- {x, ir[22:16], y, ir[14:8]}

    OP_JMPZGROUP    = 0xC0
    OP_JMPZT        = OP_JMPZGROUP | 0x0    # 1100 0000 jz t           ; pc <- t
    OP_JMPZA        = OP_JMPZGROUP | 0x1    # 1100 0001 jz a           ; pc <- a
    # OP_JMPZ      = OP_JMPZGROUP | 0x2     # 1100 0010
    # OP_JMPZ      = OP_JMPZGROUP | 0x3     # 1100 0011
    OP_JMPZABS      = OP_JMPZGROUP | 0x4    # 1100 01xy jz #im         ; pc <- {x, ir[22:16], y, ir[14:8]}

    OP_JMPNZGROUP   = 0xC8
    OP_JMPNZT       = OP_JMPNZGROUP | 0x0   # 1100 1000 jnz t          ; pc <- t or pc+1
    OP_JMPNZA       = OP_JMPNZGROUP | 0x1   # 1100 1001 jnz a          ; pc <- a or pc+1
    # OP_JMPNZ     = OP_JMPNZGROUP | 0x2    # 1100 1010
    # OP_JMPNZ     = OP_JMPNZGROUP | 0x3    # 1100 1011
    OP_JMPNZABS     = OP_JMPNZGROUP | 0x4   # 1100 11xy jnz #im        ; pc <- #im or pc+1

    OP_JMPCGROUP    = 0xD0
    OP_JMPCT        = OP_JMPCGROUP | 0x0    # 1101 0000 jc t
    OP_JMPCA        = OP_JMPCGROUP | 0x1    # 1101 0001 jc a
    # OP_JMPC      = OP_JMPCGROUP | 0x2     # 1101 0010
    # OP_JMPC      = OP_JMPCGROUP | 0x3     # 1101 0011
    OP_JMPCABS      = OP_JMPCGROUP | 0x4    # 1101 01xy jc #im         ; #im =  {x, ir[22:16], y, ir[14:8]}

    OP_JMPNCGROUP   = 0xD8
    OP_JMPNCT       = OP_JMPNCGROUP | 0x0   # 1101 1000 jc t
    OP_JMPNCA       = OP_JMPNCGROUP | 0x1   # 1101 1001 jc a
    # OP_JMPNC     = OP_JMPNCGROUP | 0x2    # 1101 1010
    # OP_JMPNC     = OP_JMPNCGROUP | 0x3    # 1101 1011
    OP_JMPNCABS     = OP_JMPNCGROUP | 0x4   # 1101 11xy jc #im         ; #im =  {x, ir[22:16], y, ir[14:8]}

    OP_POPGROUP     = 0xE0
    OP_POP          = OP_POPGROUP | 0x0     # 1110 0000 pop            ; t <- n, n <- mem[dsp-1], dsp--
    # OP_POPx      = OP_POPGROUP | 0x1      # 1110 0001 
    OP_APOP         = OP_POPGROUP | 0x2     # 1110 0010 popa           ; a <- mem[asp-1], asp--
    OP_RET          = OP_POPGROUP | 0x3     # 1110 0011 ret            ; pc <- a, a <- mem[asp-1], asp--
        
    # Registers
    OP_SETREGGROUP  = 0xF0
    OP_SETSTATUS    = OP_SETREGGROUP | 0x0  # 1111 0000 status         ; status <- t
    OP_SETDSP       = OP_SETREGGROUP | 0x1  # 1111 0001 dsp            ; dsp <- t
    OP_SETASP       = OP_SETREGGROUP | 0x2  # 1111 0010 asp            ; asp <- t
    OP_SETUSP       = OP_SETREGGROUP | 0x3  # 1111 0011 usp            ; usp <- t
    OP_SETA         = OP_SETREGGROUP | 0x4  # 1111 0100 a              ; a <- t

    OP_MISC         = 0xF8
    OP_APUSH        = OP_MISC | 0x0         # 1111 1000 apush          ; mem[asp] <- a, a <- t, asp++

    OP_END = 0xFF # simulator only

    _instructions = ["INV"] * 256
    
    @classmethod
    def define_disassembly(cls):
        for i in range(0,0x7f):
            cls._instructions[i] = "LIT {0:04x}"
        cls._instructions[cls.OP_ADD] = "ADD"
        cls._instructions[cls.OP_SUB] = "SUB"
        cls._instructions[cls.OP_AND] = "AND"
        cls._instructions[cls.OP_OR] = "OR"
        cls._instructions[cls.OP_XOR] = "XOR"
        cls._instructions[cls.OP_LSR] = "LSR"
        cls._instructions[cls.OP_CPR] = "CPR"
        cls._instructions[cls.OP_PUSHT] = "PUSH T"
        cls._instructions[cls.OP_PUSHA] = "PUSH A"
        cls._instructions[cls.OP_PUSHN] = "PUSH N"
        cls._instructions[cls.OP_PUSHUSP] = "PUSH USP"
        cls._instructions[cls.OP_PUSHI] = "PUSH {0:04x}"
        cls._instructions[cls.OP_PUSHI|1] = "PUSH {0:04x}"
        cls._instructions[cls.OP_PUSHI|2] = "PUSH {0:04x}"
        cls._instructions[cls.OP_PUSHI|3] = "PUSH {0:04x}"
        cls._instructions[cls.OP_PUSHS] = "PUSH STATUS"
        cls._instructions[cls.OP_PUSHDSP] = "PUSH DSP"
        cls._instructions[cls.OP_PUSHASP] = "PUSH ASP"
        cls._instructions[cls.OP_PUSHPC] = "PUSH PC"
        cls._instructions[cls.OP_FETCHT] = "FETCH T"
        cls._instructions[cls.OP_FETCHA] = "FETCH A"
        cls._instructions[cls.OP_FETCHU] = "FETCH USP+#ofs"
        cls._instructions[cls.OP_FETCHABS] = "FETCH {0:04x}"
        cls._instructions[cls.OP_FETCHABS|1] = "FETCH {0:04x}"
        cls._instructions[cls.OP_FETCHABS|2] = "FETCH {0:04x}"
        cls._instructions[cls.OP_FETCHABS|3] = "FETCH {0:04x}"
        cls._instructions[cls.OP_STORET] = "STORE T"
        cls._instructions[cls.OP_STOREA] = "STORE A"
        cls._instructions[cls.OP_STOREU] = "STORE U+#ofs"
        cls._instructions[cls.OP_STOREABS] = "STORE {0:04x}"
        cls._instructions[cls.OP_STOREABS|1] = "STORE {0:04x}"
        cls._instructions[cls.OP_STOREABS|2] = "STORE {0:04x}"
        cls._instructions[cls.OP_STOREABS|3] = "STORE {0:04x}"
        cls._instructions[cls.OP_JMPT] = "JMP T"
        cls._instructions[cls.OP_JMPA] = "JMP A"
        cls._instructions[cls.OP_JMPABS] = "JMP {0:04x}"
        cls._instructions[cls.OP_JMPABS|1] = "JMP {0:04x}"
        cls._instructions[cls.OP_JMPABS|2] = "JMP {0:04x}"
        cls._instructions[cls.OP_JMPABS|3] = "JMP {0:04x}"
        cls._instructions[cls.OP_BRAT] = "BRA T"
        cls._instructions[cls.OP_BRAA] = "BRA A"
        cls._instructions[cls.OP_INT] = "INT"
        cls._instructions[cls.OP_BRAABS] = "BRA {0:04x}"
        cls._instructions[cls.OP_BRAABS|1] = "BRA {0:04x}"
        cls._instructions[cls.OP_BRAABS|2] = "BRA {0:04x}"
        cls._instructions[cls.OP_BRAABS|3] = "BRA {0:04x}"
        cls._instructions[cls.OP_JMPZT] = "JMPZ T"
        cls._instructions[cls.OP_JMPZA] = "JMPZ A"
        cls._instructions[cls.OP_JMPZABS] = "JMPZ {0:04x}"
        cls._instructions[cls.OP_JMPZABS|1] = "JMPZ {0:04x}"
        cls._instructions[cls.OP_JMPZABS|2] = "JMPZ {0:04x}"
        cls._instructions[cls.OP_JMPZABS|3] = "JMPZ {0:04x}"
        cls._instructions[cls.OP_JMPNZT] = "JMPNZ T"
        cls._instructions[cls.OP_JMPNZA] = "JMPNZ A"
        cls._instructions[cls.OP_JMPNZABS] = "JMPNZ {0:04x}"
        cls._instructions[cls.OP_JMPNZABS|1] = "JMPNZ {0:04x}"
        cls._instructions[cls.OP_JMPNZABS|2] = "JMPNZ {0:04x}"
        cls._instructions[cls.OP_JMPNZABS|3] = "JMPNZ {0:04x}"
        cls._instructions[cls.OP_JMPCT] = "JMPC T"
        cls._instructions[cls.OP_JMPCA] = "JMPC A"
        cls._instructions[cls.OP_JMPCABS] = "JMPC {0:04x}"
        cls._instructions[cls.OP_JMPCABS|1] = "JMPC {0:04x}"
        cls._instructions[cls.OP_JMPCABS|2] = "JMPC {0:04x}"
        cls._instructions[cls.OP_JMPCABS|3] = "JMPC {0:04x}"
        cls._instructions[cls.OP_JMPNCT] = "JMPNC T"
        cls._instructions[cls.OP_JMPNCA] = "JMPNC A"
        cls._instructions[cls.OP_JMPNCABS] = "JMPNC {0:04x}"
        cls._instructions[cls.OP_JMPNCABS|1] = "JMPNC {0:04x}"
        cls._instructions[cls.OP_JMPNCABS|2] = "JMPNC {0:04x}"
        cls._instructions[cls.OP_JMPNCABS|3] = "JMPNC {0:04x}"
        cls._instructions[cls.OP_POP] = "POP"
        cls._instructions[cls.OP_APOP] = "APOP"
        cls._instructions[cls.OP_RET] = "RET"
        cls._instructions[cls.OP_SETSTATUS] = "SETSTATUS"
        cls._instructions[cls.OP_SETDSP] = "SETDSP"
        cls._instructions[cls.OP_SETASP] = "SETASP"
        cls._instructions[cls.OP_SETUSP] = "SETUSP"
        cls._instructions[cls.OP_SETA] = "SETA"
        cls._instructions[cls.OP_APUSH] = "APUSH"

    def __init__(self, op, immediate = None):
        self.op = op
        self.immediate = immediate
    
    def a__str__(self):
        return f"{self.disassemble()}"

    def __repr__(self):
        return f"op: {self.op:02X} asm: '{self.disassemble()}'"

    def disassemble(self):
        code = str.format(self._instructions[self.op], self.immediate)
        return code
    
    def data(self):
        num = self.immediate
        extra = 0
        b = []
        if num != None:
            if self.op == self.OP_FETCHU or self.op == self.OP_STOREU:
                num = num & 0x3fff
            else:
                if num & 0x8000:
                    extra = 2
                if num & 0x0080:
                    extra = extra | 1
                num = num & 0x7f7f
        if num > 0xff:
            b.append((num >> 8) & 0xff)
        if num > 0:
            b.append(num & 0xff)
        b.append(self.op | extra)
        return b
            

        


Instruction.define_disassembly()