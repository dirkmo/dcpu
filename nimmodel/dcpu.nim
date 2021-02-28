import strformat, tables
import opcodes

const
    ADDR_INT*   = 0xfff0u16
    ADDR_RESET* = 0x0100u16
    FLAG_ZERO  = 1u16 # set by alu and fetch ops
    FLAG_CARRY = 2u16
    FLAG_INTEN = 4u16

type
    DcpuState* = enum
        dsReset, dsFetch, dsExecute, dsFinish, dsError

    ReadFunction* = proc(adr: uint16): uint16 {.nimcall.}
    WriteFunction* = proc(adr, dat: uint16) {.nimcall.}

    Dcpu* = object
        ir: array[0..2,uint8]
        pc: uint16
        lastPc: uint16 # for printing disasm before execution (where pc has already been inc'ed)
        t, n, a: uint16
        dsp, asp, u: uint16
        status: uint16
        busaddr: uint16
        state: DcpuState
        read: ReadFunction
        write: WriteFunction
    
    LogLevel* = enum
        llDebug, llVerbose, llInfo, llError

var
    # immediate counter to detect program errors (more than 2 immediates in sequence)
    immCounter = 0
    loglevel* = llVerbose

proc logTerminal*(s: string, level: LogLevel = llError, newline: bool = true)

#----------------------------------------------------------------------
# private functions

func opHasImm16(cpu: Dcpu): bool =
    let op = cpu.ir[0] and 0xFCu8
    case op
    of OpPushI, OpFetchAbs, OpStoreAbs, OpJmpAbs, OpBraAbs, OpJmpzAbs, OpJmpnzAbs, OpJmpcAbs, OpJmpncAbs:
        return true
    else:
        discard
    return false

func opHasRelImm(cpu: Dcpu): bool =
    let op = cpu.ir[0]
    return (op == OpFetchU) or (op == OpStoreU)

func imm16(cpu: Dcpu): uint16 =
    let xy = uint16(cpu.ir[0] and 0x03)
    let lo = uint16(cpu.ir[1] and 0x7f) shl 2
    let hi = uint16(cpu.ir[2] and 0x7f) shl 9
    return hi or lo or xy

proc relImm(cpu: Dcpu): uint16 =
    let lo = uint16(cpu.ir[1] and 0x7f)
    let hi = uint16(cpu.ir[2] and 0x7f) shl 7
    return hi or lo

proc executeAluop(cpu: var Dcpu) =
    let op = cpu.ir[0]
    var r: uint32
    case op:
    of OpAdd: r = cpu.n + cpu.t
    of OpSub: r = cpu.n - cpu.t
    of OpAnd: r = cpu.n and cpu.t
    of OpOr:  r = cpu.n or cpu.t
    of OpXor: r = cpu.n xor cpu.t
    of OpLsr: r = cpu.n shr cpu.t
    of OpLsl: r = cpu.n shl cpu.t
    of OpSwap:
        r = cpu.n
        cpu.n = cpu.t
    else: discard

    cpu.t = uint16(r)

    if op != OpSwap:
        # pop t
        cpu.dsp -= 2
        cpu.n = cpu.read(cpu.dsp)
    
    cpu.status = cpu.status and not (FLAG_ZERO or FLAG_CARRY)
    if r > 0xffff:
        cpu.status = cpu.status or FLAG_CARRY
    if cpu.t == 0:
        cpu.status = cpu.status or FLAG_ZERO

proc executeStackOp(cpu: var Dcpu) =
    let imm = cpu.imm16()
    let src = [cpu.t, cpu.a, cpu.u, cpu.n, imm, imm, imm, imm, cpu.status, cpu.dsp, cpu.asp, cpu.pc]
    let idx = cpu.ir[0] and 7
    cpu.write(cpu.dsp, cpu.n) # push n to ds
    cpu.dsp += 2
    cpu.n = cpu.t
    cpu.t = src[idx]

proc executeFetchOp(cpu: var Dcpu) =
    let imm = cpu.imm16()
    let rel = cpu.relImm()
    let src = [cpu.t, cpu.a, rel, cpu.n, imm, imm, imm, imm]
    let idx = cpu.ir[0] and 7
    cpu.t = cpu.read(src[idx])
    # setting zero flag
    if cpu.t == 0:
        cpu.status = cpu.status or FLAG_ZERO
    else:
        cpu.status = cpu.status and not FLAG_ZERO

proc executeStoreOp(cpu: var Dcpu) =
    let op = cpu.ir[0]
    let imm = cpu.imm16()
    let ufsofs = cpu.u + cpu.relImm()
    let dstaddr = [cpu.t, cpu.a, ufsofs, cpu.n, imm, imm, imm, imm]
    let dstidx = cpu.ir[0] and 7
    let src = if op == OpStoreT: cpu.n else: cpu.t
    cpu.write(dstaddr[dstidx], src)

proc jmpaddr(cpu: Dcpu): uint16 =
    let op = cpu.ir[0]
    let imm = cpu.imm16()
    let u_int = if (op == OpInt): ADDR_INT else: cpu.u
    let address = [cpu.t, cpu.a, u_int, cpu.n, imm, imm, imm, imm]
    let idx = cpu.ir[0] and 7
    return address[idx]

proc popDs(cpu: var Dcpu) =
    cpu.dsp -= 2
    cpu.t = cpu.n
    cpu.n = cpu.read(cpu.dsp)

proc popAs(cpu: var Dcpu) =
    cpu.asp -= 2
    cpu.a = cpu.read(cpu.asp)

proc executeJump(cpu: var Dcpu) =
    let idx = cpu.ir[0] and 7
    cpu.pc = cpu.jmpaddr()
    if idx == 0: # pop ds
        cpu.popDs()
    elif idx == 1: # pop as
        cpu.popAs()

proc executeBranch(cpu: var Dcpu) =
    let idx = cpu.ir[0] and 7
    if idx == 1: # pop as
        # no pop as necessary
        # cpu.a can just be overwritten with cpu.pc without touching asp
        discard
    else:
        # pushing a to as
        cpu.write(cpu.asp, cpu.a)
        cpu.asp += 2
    # save pc to a (pc has been incremented in dsFetch)
    cpu.a = cpu.pc
    cpu.pc = cpu.jmpaddr()
    if idx == 0: # pop ds
        cpu.popDs()


proc executePop(cpu: var Dcpu) =
    let op = cpu.ir[0]
    case op:
    of OpPop:
        cpu.pop_ds()
    of OpRet:
        cpu.pc = cpu.a
        cpu.popAs()
    of OpApop:
        cpu.popAs()
    else:
        logTerminal(&"Invalid opcode {op:02x}")
        quit(1)

proc executeSetReg(cpu: var Dcpu) =
    let idx = cpu.ir[0] and 0x7
    let dst = [addr cpu.status, addr cpu.dsp, addr cpu.asp, addr cpu.u, addr cpu.a]
    dst[idx][] = cpu.t

proc executeApush(cpu: var Dcpu) =
    cpu.write(cpu.asp, cpu.a)
    cpu.asp += 2
    cpu.a = cpu.t

proc execute(cpu: var Dcpu) =
    let op = cpu.ir[0]
    let opgroup = op and OpMask
    case opgroup:
    of OpAlu:
        cpu.executeAluop()
    of OpStackGroup1, OpStackGroup2:
        cpu.executeStackOp()
    of OpFetchGroup:
        cpu.executeFetchOp()
    of OpStoreGroup:
        cpu.executeStoreOp()
    of OpJmpGroup:
        cpu.executeJump()
    of OpBraGroup:
        cpu.executeBranch()
    of OpJmpzGroup:
        if (cpu.status and FLAG_ZERO) != 0:
            cpu.executeJump()
    of OpJmpnzGroup:
        if (cpu.status and FLAG_ZERO) == 0:
            cpu.executeJump()
    of OpJmpcGroup:
        if (cpu.status and FLAG_CARRY) != 0:
            cpu.executeJump()
    of OpJmpncGroup:
        if (cpu.status and FLAG_CARRY) == 0:
            cpu.executeJump()
    of OpPopGroup:
        cpu.executePop()
    of OpSetRegGroup:
        cpu.executeSetReg()
    of OpMiscGroup:
        if op == OpApush:
            cpu.executeApush()
    else:
        logTerminal(&"Unknown opcode {op:02x}")
        quit(1)

#----------------------------------------------------------------------
# public functions

func pc*(cpu: Dcpu): uint16 = cpu.pc
func lastPc*(cpu: Dcpu): uint16 = cpu.lastPc
func t*(cpu: Dcpu): uint16 = cpu.t
func n*(cpu: Dcpu): uint16 = cpu.n
func a*(cpu: Dcpu): uint16 = cpu.a
func dsp*(cpu: Dcpu): uint16 = cpu.dsp
func asp*(cpu: Dcpu): uint16 = cpu.asp
func u*(cpu: Dcpu): uint16 = cpu.u
func status*(cpu: Dcpu): uint16 = cpu.status

proc logTerminal*(s: string, level: LogLevel = llError, newline: bool = true) =
    if loglevel < level:
        if newline:
            echo s
        else:
            stdout.write s

func disassemble*(cpu: Dcpu): string =
    let op = cpu.ir[0]
    if mnemonics.hasKey(op):
        var sImm: string
        if cpu.opHasImm16():
            sImm = &" ${cpu.imm16():x}"
        elif cpu.opHasRelImm():
            sImm = &" u+${cpu.relImm():x}"
        return mnemonics[op] & sImm
    return &"unknown op {op:02x}"

proc reset*(cpu: var Dcpu) =
    logTerminal("CPU Reset", llInfo)
    cpu.ir = [0u8, 0u8, 0u8]
    cpu.pc = ADDR_RESET
    cpu.lastPc = ADDR_RESET
    cpu.t = 0
    cpu.a = 0
    cpu.n = 0
    cpu.dsp = 0
    cpu.asp = 0
    cpu.u = 0
    cpu.status = 0
    cpu.state = dsFetch
    # deliberately not setting read/write

proc setcallbacks*(cpu: var Dcpu, rf: ReadFunction, wf: WriteFunction) =
    cpu.read = rf
    cpu.write = wf

proc statemachine*(cpu: var Dcpu): DcpuState =
    case cpu.state
    of dsReset:
        cpu.reset()
        cpu.state = dsFetch
        immCounter = 0
    of dsFetch:
        cpu.ir[2] = cpu.ir[1]
        cpu.ir[1] = cpu.ir[0]
        let w = cpu.read(cpu.pc)
        if (cpu.pc and 1) == 0:
            cpu.ir[0] = uint8(w)
        else:
            cpu.ir[0] = uint8(w shr 8)
        # logTerminal(&"fetch {cpu.pc :04x}: {cpu.ir[0] :02x}", llDebug)
        cpu.pc += 1
        if (cpu.ir[0] and 0x80) != 0:
            cpu.state = dsExecute
        else:
            immCounter += 1
            if immCounter > 2:
                cpu.state = dsError
    of dsExecute:
        immCounter = 0
        if cpu.ir[0] == OpEnd:
            cpu.state = dsFinish
        else:
            # logTerminal &"decode: {cpu.disassemble()}", llInfo
            cpu.execute()
            cpu.state = dsFetch
            cpu.ir[0] = 0
            cpu.ir[1] = 0
            cpu.lastPc = cpu.pc
    of dsFinish:
        discard
    of dsError:
        logTerminal &"Program error"
        cpu.state = dsFinish

    return cpu.state # this is the next state
