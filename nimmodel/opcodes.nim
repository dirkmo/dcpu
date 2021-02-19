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
    OpSwap*      : uint8 = OpAlu or 0x07

    OpPushT*     : uint8 = OpStackGroup1 or 0x00
    OpPushA*     : uint8 = OpStackGroup1 or 0x01
    OpPushN*     : uint8 = OpStackGroup1 or 0x02
    OpPushU*     : uint8 = OpStackGroup1 or 0x03
    OpPushI*     : uint8 = OpStackGroup1 or 0x04

    OpPushS*     : uint8 = OpStackGroup2 or 0x00
    OpPushDsp*   : uint8 = OpStackGroup2 or 0x01
    OpPushAsp*   : uint8 = OpStackGroup2 or 0x02
    OpPushPc*    : uint8 = OpStackGroup2 or 0x03

    OpFetchT*    : uint8 = OpFetchGroup or 0x00
    OpFetchA*    : uint8 = OpFetchGroup or 0x01
    OpFetchU*    : uint8 = OpFetchGroup or 0x02
    OpFetchN*    : uint8 = OpFetchGroup or 0x03
    OpFetchAbs*  : uint8 = OpFetchGroup or 0x04

    OpStoreT*    : uint8 = OpStoreGroup or 0x00
    OpStoreA*    : uint8 = OpStoreGroup or 0x01
    OpStoreU*    : uint8 = OpStoreGroup or 0x02
    OpStoreN*    : uint8 = OpStoreGroup or 0x03
    OpStoreAbs*  : uint8 = OpStoreGroup or 0x04

    OpJmpT*      : uint8   = OpJmpGroup or 0x00
    OpJmpA*      : uint8   = OpJmpGroup or 0x01
    OpJmpU*      : uint8   = OpJmpGroup or 0x02
    OpJmpN*      : uint8   = OpJmpGroup or 0x03
    OpJmpAbs*    : uint8   = OpJmpGroup or 0x04

    OpBraT*      : uint8   = OpBraGroup or 0x00
    OpBraA*      : uint8   = OpBraGroup or 0x01
    OpInt*       : uint8   = OpBraGroup or 0x02
    OpBraN*      : uint8   = OpBraGroup or 0x03
    OpBraAbs*    : uint8   = OpBraGroup or 0x04

    OpJmpzT*     : uint8  = OpJmpzGroup or 0x00
    OpJmpzA*     : uint8  = OpJmpzGroup or 0x01
    OpJmpzU*     : uint8  = OpJmpzGroup or 0x02
    OpJmpzN*     : uint8  = OpJmpzGroup or 0x03
    OpJmpzAbs*   : uint8  = OpJmpzGroup or 0x04

    OpJmpnzT*    : uint8 = OpJmpnzGroup or 0x00
    OpJmpnzA*    : uint8 = OpJmpnzGroup or 0x01
    OpJmpnzU*    : uint8 = OpJmpnzGroup or 0x02
    OpJmpnzN*    : uint8 = OpJmpnzGroup or 0x03
    OpJmpnzAbs*  : uint8 = OpJmpnzGroup or 0x04

    OpJmpcT*     : uint8 = OpJmpcGroup or 0x00
    OpJmpcA*     : uint8 = OpJmpcGroup or 0x01
    OpJmpcU*     : uint8 = OpJmpcGroup or 0x02
    OpJmpcN*     : uint8 = OpJmpcGroup or 0x03
    OpJmpcAbs*   : uint8 = OpJmpcGroup or 0x04

    OpJmpncT*    : uint8 = OpJmpncGroup or 0x00
    OpJmpncA*    : uint8 = OpJmpncGroup or 0x01
    OpJmpncU*    : uint8 = OpJmpncGroup or 0x02
    OpJmpncN*    : uint8 = OpJmpncGroup or 0x03
    OpJmpncAbs*  : uint8 = OpJmpncGroup or 0x04

    OpPop*       : uint8 = OpPopGroup or 0x00
    OpApop*      : uint8 = OpPopGroup or 0x02
    OpRet*       : uint8 = OpPopGroup or 0x03

    OpSetStatus* : uint8 = OpSetRegGroup or 0x00
    OpSetDsp*    : uint8 = OpSetRegGroup or 0x01
    OpSetAsp*    : uint8 = OpSetRegGroup or 0x02
    OpSetU*      : uint8 = OpSetRegGroup or 0x03
    OpSetA*      : uint8 = OpSetRegGroup or 0x04

    OpApush*     : uint8 = OpMiscGroup or 0x00
    
    OpMask*      : uint8 = 0xF8

    OpEnd*       : uint8 = 0xFF


const mnemonics* = {
    OpAdd: "ADD",
    OpSub: "SUB",
    OpAnd: "AND",
    OpOr: "OR",
    OpXor: "XOR",
    OpLsr: "LSR",
    OpCpr: "CPR",
    OpSwap: "SWAP",
    OpPushT: "PUSH T",
    OpPushA: "PUSH A",
    OpPushN: "PUSH N",
    OpPushU: "PUSH U",
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
    OpFetchN: "FETCH N",
    OpFetchU: "FETCH",
    OpFetchAbs or 0: "FETCH",
    OpFetchAbs or 1: "FETCH",
    OpFetchAbs or 2: "FETCH",
    OpFetchAbs or 3: "FETCH",
    OpStoreT: "STORE T",
    OpStoreA: "STORE A",
    OpStoreN: "STORE N",
    OpStoreU: "STORE U",
    OpStoreAbs or 0: "STORE",
    OpStoreAbs or 1: "STORE",
    OpStoreAbs or 2: "STORE",
    OpStoreAbs or 3: "STORE",
    OpJmpT: "JP T",
    OpJmpA: "JP A",
    OpJmpU: "JP U",
    OpJmpN: "JP N",
    OpJmpAbs or 0: "JP",
    OpJmpAbs or 1: "JP",
    OpJmpAbs or 2: "JP",
    OpJmpAbs or 3: "JP",
    OpBraT: "BRA T",
    OpBraA: "BRA A",
    OpInt: "INT",
    OpBraN: "BRA N",
    OpBraAbs or 0: "BRA",
    OpBraAbs or 1: "BRA",
    OpBraAbs or 2: "BRA",
    OpBraAbs or 3: "BRA",
    OpJmpzT: "JPZ T",
    OpJmpzA: "JPZ A",
    OpJmpzU: "JPZ U",
    OpJmpzN: "JPZ N",
    OpJmpzAbs or 0: "JPZ",
    OpJmpzAbs or 1: "JPZ",
    OpJmpzAbs or 2: "JPZ",
    OpJmpzAbs or 3: "JPZ",
    OpJmpnzT: "JPNZ T",
    OpJmpnzA: "JPNZ A",
    OpJmpnzU: "JPNZ U",
    OpJmpnzN: "JPNZ N",
    OpJmpnzAbs or 0: "JPNZ",
    OpJmpnzAbs or 1: "JPNZ",
    OpJmpnzAbs or 2: "JPNZ",
    OpJmpnzAbs or 3: "JPNZ",
    OpJmpcT: "JPC T",
    OpJmpcA: "JPC A",
    OpJmpcU: "JPC U",
    OpJmpcN: "JPC N",
    OpJmpcAbs or 0: "JPC",
    OpJmpcAbs or 1: "JPC",
    OpJmpcAbs or 2: "JPC",
    OpJmpcAbs or 3: "JPC",
    OpJmpncT: "JPNC T",
    OpJmpncA: "JPNC A",
    OpJmpncU: "JPNC U",
    OpJmpncN: "JPNC N",
    OpJmpncAbs or 0: "JPNC",
    OpJmpncAbs or 1: "JPNC",
    OpJmpncAbs or 2: "JPNC",
    OpJmpncAbs or 3: "JPNC",
    OpPop: "POP",
    OpApop: "APOP",
    OpRet: "RET",
    OpSetStatus: "SETSTATUS",
    OpSetDsp: "SETDSP",
    OpSetAsp: "SETASP",
    OpSetU: "SETU",
    OpSetA: "SETA",
    OpApush: "APUSH",
}.toTable()
