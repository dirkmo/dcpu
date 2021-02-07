import tables

const
    OpAlu*         : uint8 = 0x80
    OpStackGroup1* : uint8 = 0x90
    OpStackGroup2* : uint8 = 0x98
    OpFetchGroup*  : uint8 = 0xA0
    OpStoreGroup*  : uint8 = 0xA8
    OpJmpGroup*    : uint8 = 0xB0
    OpBraGroup*    : uint8 = 0xB8
    OpJmpzGroup*   : uint8 = 0xC0
    OpJmpnzGroup*  : uint8 = 0xC8
    OpJmpcGroup*   : uint8 = 0xD0
    OpJmpncGroup*  : uint8 = 0xD8
    OpPopGroup*    : uint8 = 0xE0
    OpSetRegGroup* : uint8 = 0xF0
    OpMiscGroup*   : uint8 = 0xF8

const
    OpAdd*       : uint8 = OpAlu or 0x00
    OpSub*       : uint8 = OpAlu or 0x01
    OpAnd*       : uint8 = OpAlu or 0x02
    OpOr*        : uint8 = OpAlu or 0x03
    OpXor*       : uint8 = OpAlu or 0x04
    OpLsr*       : uint8 = OpAlu or 0x05
    OpCpr*       : uint8 = OpAlu or 0x06

    OpPushT*     : uint8 = OpStackGroup1 or 0x00
    OpPushA*     : uint8 = OpStackGroup1 or 0x01
    OpPushN*     : uint8 = OpStackGroup1 or 0x02
    OpPushUsp*   : uint8 = OpStackGroup1 or 0x03
    OpPushI*     : uint8 = OpStackGroup1 or 0x04

    OpPushS*     : uint8 = OpStackGroup2 or 0x00
    OpPushDsp*   : uint8 = OpStackGroup2 or 0x01
    OpPushAsp*   : uint8 = OpStackGroup2 or 0x02
    OpPushPc*    : uint8 = OpStackGroup2 or 0x03

    OpFetchT*    : uint8 = OpFetchGroup or 0x00
    OpFetchA*    : uint8 = OpFetchGroup or 0x01
    OpFetchU*    : uint8 = OpFetchGroup or 0x02
    OpFetchAbs*  : uint8 = OpFetchGroup or 0x04

    OpStoreT*    : uint8 = OpStoreGroup or 0x00
    OpStoreA*    : uint8 = OpStoreGroup or 0x01
    OpStoreU*    : uint8 = OpStoreGroup or 0x02
    OpStoreAbs*  : uint8 = OpStoreGroup or 0x04

    OpJmpT*      : uint8   = OpJmpGroup or 0x00
    OpJmpA*      : uint8   = OpJmpGroup or 0x01
    OpJmpAbs*    : uint8   = OpJmpGroup or 0x04

    OpBraT*      : uint8   = OpBraGroup or 0x00
    OpBraA*      : uint8   = OpBraGroup or 0x01
    OpInt*       : uint8   = OpBraGroup or 0x02
    OpBraAbs*    : uint8   = OpBraGroup or 0x04

    OpJmpzT*     : uint8  = OpJmpzGroup or 0x00
    OpJmpzA*     : uint8  = OpJmpzGroup or 0x01
    OpJmpzAbs*   : uint8  = OpJmpzGroup or 0x04

    OpJmpnzT*    : uint8 = OpJmpnzGroup or 0x00
    OpJmpnzA*    : uint8 = OpJmpnzGroup or 0x01
    OpJmpnzAbs*  : uint8 = OpJmpnzGroup or 0x04

    OpJmpcT*     : uint8 = OpJmpcGroup or 0x00
    OpJmpcA*     : uint8 = OpJmpcGroup or 0x01
    OpJmpcAbs*   : uint8 = OpJmpcGroup or 0x04

    OpJmpncT*    : uint8 = OpJmpncGroup or 0x00
    OpJmpncA*    : uint8 = OpJmpncGroup or 0x01
    OpJmpncAbs*  : uint8 = OpJmpncGroup or 0x04

    OpPop*       : uint8 = OpPopGroup or 0x00
    OpApop*      : uint8 = OpPopGroup or 0x02
    OpRet*       : uint8 = OpPopGroup or 0x03

    OpSetStatus* : uint8 = OpSetRegGroup or 0x00
    OpSetDsp*    : uint8 = OpSetRegGroup or 0x01
    OpSetAsp*    : uint8 = OpSetRegGroup or 0x02
    OpSetUsp*    : uint8 = OpSetRegGroup or 0x03
    OpSetA*      : uint8 = OpSetRegGroup or 0x04

    OpApush*     : uint8 = OpMiscGroup or 0x00
    
    OpMask*      : uint8 = 0xF8

    OpEnd*       : uint8 = 0xFF


const mnemonics* = {
    OpAdd: "ADD",
    OpSub: "SUB",
    OpOr: "OR",
    OpXor: "XOR",
    OpLsr: "LSR",
    OpCpr: "CPR",
    OpPushT: "PUSH T",
    OpPushA: "PUSH A",
    OpPushN: "PUSH N",
    OpPushUsp: "PUSH USP",
    OpPushI or 0: "PUSH",
    OpPushI or 1: "PUSH",
    OpPushI or 2: "PUSH",
    OpPushI or 3: "PUSH",
    OpPushS: "PUSH STATUS",
    OpPushDsp: "PUSH DSP",
    OpPushAsp: "PUSH ASP",
    OpPushPc: "PUSH PC",
    OpFetchT: "FETCH T",
    OpFetchA: "FETCH A",
    OpFetchU: "FETCH",
    OpFetchAbs or 0: "FETCH",
    OpFetchAbs or 1: "FETCH",
    OpFetchAbs or 2: "FETCH",
    OpFetchAbs or 3: "FETCH",
    OpStoreT: "STORE T",
    OpStoreA: "STORE A",
    OpStoreU: "STORE U",
    OpStoreAbs or 0: "STORE",
    OpStoreAbs or 1: "STORE",
    OpStoreAbs or 2: "STORE",
    OpStoreAbs or 3: "STORE",
    OpJmpT: "JMP T",
    OpJmpA: "JMP A",
    OpJmpAbs or 0: "JMP",
    OpJmpAbs or 1: "JMP",
    OpJmpAbs or 2: "JMP",
    OpJmpAbs or 3: "JMP",
    OpBraT: "BRA T",
    OpBraA: "BRA A",
    OpInt: "INT",
    OpBraAbs or 0: "BRA",
    OpBraAbs or 1: "BRA",
    OpBraAbs or 2: "BRA",
    OpBraAbs or 3: "BRA",
    OpJmpzT: "JMPZ T",
    OpJmpzA: "JMPZ A",
    OpJmpzAbs or 0: "JMPZ",
    OpJmpzAbs or 1: "JMPZ",
    OpJmpzAbs or 2: "JMPZ",
    OpJmpzAbs or 3: "JMPZ",
    OpJmpnzT: "JMPNZ T",
    OpJmpnzA: "JMPNZ A",
    OpJmpnzAbs or 0: "JMPNZ",
    OpJmpnzAbs or 1: "JMPNZ",
    OpJmpnzAbs or 2: "JMPNZ",
    OpJmpnzAbs or 3: "JMPNZ",
    OpJmpcT: "JMPC T",
    OpJmpcA: "JMPC A",
    OpJmpcAbs or 0: "JMPC",
    OpJmpcAbs or 1: "JMPC",
    OpJmpcAbs or 2: "JMPC",
    OpJmpcAbs or 3: "JMPC",
    OpJmpncT: "JMPNC T",
    OpJmpncA: "JMPNC A",
    OpJmpncAbs or 0: "JMPNC",
    OpJmpncAbs or 1: "JMPNC",
    OpJmpncAbs or 2: "JMPNC",
    OpJmpncAbs or 3: "JMPNC",
    OpPop: "POP",
    OpApop: "APOP",
    OpRet: "RET",
    OpSetStatus: "SETSTATUS",
    OpSetDsp: "SETDSP",
    OpSetAsp: "SETASP",
    OpSetUsp: "SETUSP",
    OpSetA: "SETA",
    OpApush: "APUSH",
}.toTable()
