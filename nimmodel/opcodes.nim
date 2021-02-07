type
    Opcodes* = enum
        ImmediateMask       = 0x80,

        OpAlu               = 0x80,
        OpAdd               = OpAlu or 0x00,
        OpSub               = OpAlu or 0x01,
        OpAnd               = OpAlu or 0x02,
        OpOr                = OpAlu or 0x03,
        OpXor               = OpAlu or 0x04,
        OpLsr               = OpAlu or 0x05,
        OpCpr               = OpAlu or 0x06,

        OpStackGroup1       = 0x90
        OpPushT             = OpStackGroup1 or 0x00
        OpPushA             = OpStackGroup1 or 0x01
        OpPushN             = OpStackGroup1 or 0x02
        OpPushUsp           = OpStackGroup1 or 0x03
        OpPushI             = OpStackGroup1 or 0x04

        OpStackGroup2       = 0x98
        OpPushS             = OpStackGroup2 or 0x00
        OpPushDsp           = OpStackGroup2 or 0x01
        OpPushAsp           = OpStackGroup2 or 0x02
        OpPushPc            = OpStackGroup2 or 0x03

        OpFetchGroup        = 0xA0
        OpFetchT            = OpFetchGroup or 0x00
        OpFetchA            = OpFetchGroup or 0x01
        OpFetchU            = OpFetchGroup or 0x02
        OpFetchAbs          = OpFetchGroup or 0x04

        OpStoreGroup        = 0xA8
        OpStoreT            = OpStoreGroup or 0x00
        OpStoreA            = OpStoreGroup or 0x01
        OpStoreU            = OpStoreGroup or 0x02
        OpStoreAbs          = OpStoreGroup or 0x04

        OpJmpGroup          = 0xB0
        OpJmpT              = ObJmpGroup or 0x00
        OpJmpA              = ObJmpGroup or 0x01
        OpJmpAbs            = ObJmpGroup or 0x04

        OpBraGroup          = 0xB8
        OpBraT              = ObBraGroup or 0x00
        OpBraA              = ObBraGroup or 0x01
        OpInt               = OpBraGroup or 0x02
        OpBraAbs            = ObBraGroup or 0x04

        OpJmpzGroup         = 0xC0
        OpJmpzT             = ObJmpzGroup or 0x00
        OpJmpzA             = ObJmpzGroup or 0x01
        OpJmpzAbs           = ObJmpzGroup or 0x04

        OpJmpnzGroup         = 0xC8
        OpJmpnzT             = ObJmpnzGroup or 0x00
        OpJmpnzA             = ObJmpnzGroup or 0x01
        OpJmpnzAbs           = ObJmpnzGroup or 0x04

        OpJmpcGroup         = 0xD0
        OpJmpcT             = ObJmpcGroup or 0x00
        OpJmpcA             = ObJmpcGroup or 0x01
        OpJmpcAbs           = ObJmpcGroup or 0x04

        OpJmpncGroup        = 0xD8
        OpJmpncT            = ObJmpncGroup or 0x00
        OpJmpncA            = ObJmpncGroup or 0x01
        OpJmpncAbs          = ObJmpncGroup or 0x04

        OpPopGroup          = 0xE0
        OpPop               = OpPopGroup or 0x00
        OpApop              = OpPopGroup or 0x02
        OpRet               = OpPopGroup or 0x03

        OpSetRegGroup       = 0xF0
        OpSetStatus         = OpSetRegGroup or 0x00
        OpSetDsp            = OpSetRegGroup or 0x01
        OpSetAsp            = OpSetRegGroup or 0x02
        OpSetUsp            = OpSetRegGroup or 0x03
        OpSetA              = OpSetRegGroup or 0x04

        OpMiscGroup         = 0xF8
        OpApush             = OpMiscGroup or 0x00
        
        OpMask              = 0xF8

        OpEnd               = 0xFF
