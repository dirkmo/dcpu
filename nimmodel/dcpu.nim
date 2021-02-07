import strformat
import opcodes

type
    DcpuState = enum
        dsReset, dsFetch, dsExecute

    Dcpu = object
        ir: array[3,uint8]
        pc: uint16
        t, n, a: uint16
        dsp, asp, usp: uint16
        status: uint16

        busaddr: uint16
        state: DcpuState

