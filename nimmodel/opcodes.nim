const
    OpAlu*              = 0x80
    OpStackGroup1*      = 0x90
    OpStackGroup2*      = 0x98
    OpFetchGroup*       = 0xA0
    OpStoreGroup*       = 0xA8
    OpJmpGroup*         = 0xB0
    OpBraGroup*         = 0xB8
    OpJmpzGroup*        = 0xC0
    OpJmpnzGroup*       = 0xC8
    OpJmpcGroup*        = 0xD0
    OpJmpncGroup*       = 0xD8
    OpPopGroup*         = 0xE0
    OpSetRegGroup*      = 0xF0
    OpMiscGroup*        = 0xF8

const
    OpAdd*              = OpAlu
    OpSub*              = OpAlu or 0x01
    OpAnd*              = OpAlu or 0x02
    OpOr*               = OpAlu or 0x03
    OpXor*              = OpAlu or 0x04
    OpLsr*              = OpAlu or 0x05
    OpCpr*              = OpAlu or 0x06

    OpPushT*            = OpStackGroup1 or 0x00
    OpPushA*            = OpStackGroup1 or 0x01
    OpPushN*            = OpStackGroup1 or 0x02
    OpPushUsp*          = OpStackGroup1 or 0x03
    OpPushI*            = OpStackGroup1 or 0x04

    OpPushS*            = OpStackGroup2 or 0x00
    OpPushDsp*          = OpStackGroup2 or 0x01
    OpPushAsp*          = OpStackGroup2 or 0x02
    OpPushPc*           = OpStackGroup2 or 0x03

    OpFetchT*           = OpFetchGroup or 0x00
    OpFetchA*           = OpFetchGroup or 0x01
    OpFetchU*           = OpFetchGroup or 0x02
    OpFetchAbs*         = OpFetchGroup or 0x04

    OpStoreT*           = OpStoreGroup or 0x00
    OpStoreA*           = OpStoreGroup or 0x01
    OpStoreU*           = OpStoreGroup or 0x02
    OpStoreAbs*         = OpStoreGroup or 0x04

    OpJmpT*             = OpJmpGroup or 0x00
    OpJmpA*             = OpJmpGroup or 0x01
    OpJmpAbs*           = OpJmpGroup or 0x04

    OpBraT*             = OpBraGroup or 0x00
    OpBraA*             = OpBraGroup or 0x01
    OpInt*              = OpBraGroup or 0x02
    OpBraAbs*           = OpBraGroup or 0x04

    OpJmpzT*            = OpJmpzGroup or 0x00
    OpJmpzA*            = OpJmpzGroup or 0x01
    OpJmpzAbs*          = OpJmpzGroup or 0x04

    OpJmpnzT*           = OpJmpnzGroup or 0x00
    OpJmpnzA*           = OpJmpnzGroup or 0x01
    OpJmpnzAbs*         = OpJmpnzGroup or 0x04

    OpJmpcT*            = OpJmpcGroup or 0x00
    OpJmpcA*            = OpJmpcGroup or 0x01
    OpJmpcAbs*          = OpJmpcGroup or 0x04

    OpJmpncT*           = OpJmpncGroup or 0x00
    OpJmpncA*           = OpJmpncGroup or 0x01
    OpJmpncAbs*         = OpJmpncGroup or 0x04

    OpPop*              = OpPopGroup or 0x00
    OpApop*             = OpPopGroup or 0x02
    OpRet*              = OpPopGroup or 0x03

    OpSetStatus*        = OpSetRegGroup or 0x00
    OpSetDsp*           = OpSetRegGroup or 0x01
    OpSetAsp*           = OpSetRegGroup or 0x02
    OpSetUsp*           = OpSetRegGroup or 0x03
    OpSetA*             = OpSetRegGroup or 0x04

    OpApush*            = OpMiscGroup or 0x00
    
    OpMask*             = 0xF8

    OpEnd*              = 0xFF
