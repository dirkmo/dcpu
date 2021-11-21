#ifndef __DCPU_H__
#define __DCPU_H__

#define OP 0x8000

#define DST(n) (OP | ((n) << DST_SHIFT))
#define DST_SHIFT 12
#define DST_T    DST(0)
#define DST_N    DST(1)
#define DST_R    DST(2)
#define DST_PC   DST(3)
#define DST_MEMT DST(4)
#define DST_MEMR DST(5)

#define DSP(n) (OP | ((n) << DSP_SHIFT))
#define DSP_SHIFT 4
#define DSP_I DSP(1)
#define DSP_D DSP(2)

#define RSP(n) (OP | ((n) << RSP_SHIFT))
#define RSP_SHIFT 2
#define RSP_I   RSP(1)
#define RSP_D   RSP(2)
#define RSP_RPC RSP(3)

#define ALU(n) (OP | ((n) << ALU_SHIFT))
#define ALU_SHIFT 6
#define ALU_T       ALU(0)
#define ALU_N       ALU(1)
#define ALU_R       ALU(2)
#define ALU_ADD     ALU(3)
#define ALU_SUB     ALU(4)
#define ALU_AND     ALU(5)
#define ALU_OR      ALU(6)
#define ALU_XOR     ALU(7)
#define ALU_INV     ALU(8)
#define ALU_LSHIFT  ALU(10)
#define ALU_RSHIFT  ALU(11)
#define ALU_MEMT    ALU(12)
#define ALU_MEMR    ALU(13)
#define ALU_CONDR   ALU(14)
#define ALU_CONDT   ALU(15)
#define ALU_LSHIFT8 ALU(16)
#define ALU_RSHIFT8 ALU(17)

#define PICK(n) (OP | ((1<<(ALU_SHIFT+5)) | n))

#endif
