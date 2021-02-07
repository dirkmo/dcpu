import strformat, tables
import opcodes

const
    ADDR_INT*   = 0xfff0u16
    ADDR_RESET* = 0x0100u16
    FLAG_CARRY = 1u16
    FLAG_INTEN = 2u16

type
    DcpuState = enum
        dsReset, dsFetch, dsExecute

    ReadFunction* = proc(adr: uint16): uint16 {.nimcall.}
    WriteFunction* = proc(adr, dat: uint16) {.nimcall.}

    Dcpu* = object
        ir: array[0..2,uint8]
        pc: uint16
        t, n, a: uint16
        dsp, asp, usp: uint16
        status: uint16
        busaddr: uint16
        state: DcpuState
        read: ReadFunction
        write: WriteFunction

#----------------------------------------------------------------------
# private functions

proc opHasImm16(cpu: Dcpu): bool =
    let op = cpu.ir[0] and 0xFCu8
    case op
    of OpPushI, OpFetchAbs, OpStoreAbs, OpJmpAbs, OpBraAbs, OpJmpzAbs, OpJmpnzAbs, OpJmpcAbs, OpJmpncAbs:
        return true
    else:
        discard
    return false

proc opHasRelImm(cpu: Dcpu): bool =
    let op = cpu.ir[0]
    return (op == OpFetchU) or (op == OpStoreU)

proc imm16(cpu: Dcpu): uint16 =
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
    of OpLsr: r = cpu.n shl cpu.t
    of OpCpr: r = (cpu.n shl 8) or (cpu.t and 0xff)
    else: discard
    cpu.t = uint16(r)
    cpu.status = cpu.status and not FLAG_CARRY
    if r > 0xffff:
        cpu.status = cpu.status or FLAG_CARRY

proc executeStackOp(cpu: var Dcpu) =
    let imm = cpu.imm16()
    let src = [cpu.t, cpu.a, cpu.n, cpu.usp, imm, imm, imm, imm, cpu.status, cpu.dsp, cpu.asp, cpu.pc]
    let idx = cpu.ir[0] and 7
    cpu.write(cpu.dsp, cpu.n) # push n to ds
    cpu.dsp += 2
    cpu.n = cpu.t
    cpu.t = src[idx]

proc execute(cpu: var Dcpu) =
    let op = cpu.ir[0]
    let opgroup = cpu.ir[0] and OpMask
    case opgroup:
    of OpAlu:
        cpu.executeAluop()
    of OpStackGroup1, OpStackGroup2:
        cpu.executeStackOp()
    of OpFetchGroup:
        discard
    of OpStoreGroup:
        discard
    of OpJmpGroup:
        discard
    of OpBraGroup:
        discard
    of OpJmpzGroup:
        discard
    of OpJmpnzGroup:
        discard
    of OpJmpcGroup:
        discard
    of OpJmpncGroup:
        discard
    of OpPopGroup:
        discard
    of OpSetRegGroup:
        discard
    of OpMiscGroup:
        discard
    else:
        echo &"Unknown opcode {op}"

#----------------------------------------------------------------------
# public functions

proc disassemble*(cpu: Dcpu): string =
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
    echo "CPU Reset"
    cpu.ir = [0u8, 0u8, 0u8]
    cpu.pc = ADDR_RESET
    cpu.t = 0
    cpu.a = 0
    cpu.n = 0
    cpu.dsp = 0
    cpu.asp = 0
    cpu.usp = 0
    cpu.status = 0
    cpu.state = dsFetch
    # deliberately not setting read/write

proc setcallbacks*(cpu: var Dcpu, rf: ReadFunction, wf: WriteFunction) =
    cpu.read = rf
    cpu.write = wf

proc statemachine*(cpu: var Dcpu) =
    case cpu.state
    of dsReset:
        cpu.reset()
        cpu.state = dsFetch
    of dsFetch:
        cpu.ir[2] = cpu.ir[1]
        cpu.ir[1] = cpu.ir[0]
        let w = cpu.read(cpu.pc)
        # echo fmt"{w : 04x}"
        if (cpu.pc and 1) == 0:
            cpu.ir[0] = uint8(w)
        else:
            cpu.ir[0] = uint8(w shr 8)
        echo fmt"fetch {cpu.pc :04x}: {cpu.ir[0] :02x}"
        cpu.pc += 1
        if (cpu.ir[0] and 0x80) != 0:
            cpu.state = dsExecute
    of dsExecute:
        echo fmt"decode: {cpu.disassemble()}"
        cpu.execute()
        cpu.state = dsFetch
        cpu.ir[0] = 0
        cpu.ir[1] = 0
