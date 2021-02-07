import strformat
import opcodes

const
    ADDR_INT*   = 0xfff0
    ADDR_RESET* = 0x0100

type
    DcpuState = enum
        dsReset, dsFetch, dsExecute

    Dcpu* = object
        ir: array[0..2,uint8]
        pc: uint16
        t, n, a: uint16
        dsp, asp, usp: uint16
        status: uint16

        busaddr: uint16
        read: proc(): uint16
        write: proc(dat: uint16)
        state: DcpuState


proc reset*(cpu: var Dcpu) =
    cpu.ir = [0u8, 0u8, 0u8]
    cpu.pc = ADDR_RESET
    cpu.t = 0
    cpu.a = 0
    cpu.n = 0
    cpu.dsp = 0
    cpu.asp = 0
    cpu.usp = 0
    cpu.status = 0
    cpu.state = dsReset
    # deliberately not setting read/write

proc statemachine*(cpu: var Dcpu) =
    while true:
        discard