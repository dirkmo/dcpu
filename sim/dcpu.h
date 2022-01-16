#ifndef __DCPU_H__
#define __DCPU_H__

#define MASK(b) ((1<<b)-1)

#define OP_CALL 0x0000
#define OP_LITL 0x8000
#define OP_LITH 0xa000
#define OP_ALU  0xc000
#define OP_RJP  0xe000

#define OP_LITL_VAL(n) (n & MASK(13))
#define LIT_L(v) (OP_LITL | OP_LITL_VAL(v))

#define OP_LITH_VAL(n) (n & MASK(8) | )
#define OP_LITH_RET(r) ((n & 1) << 8)
#define LIT_H(v,r) (OP_LITH | OP_LITH_VAL(v) | OP_LITH_RET(r))

#define OP_RJP_ADDR(a) (n & MASK(10))
#define OP_RJP_COND(c) ((n & MASK(3)) << 10)
#define COND_RJP_NONE 0
#define COND_RJP_ZERO 4
#define COND_RJP_NONZERO 5
#define COND_RJP_NEG 6
#define COND_RJP_NONNEG 7
#define RJP(c,offs) (OP_RJP_COND(c) | OP_RJP_ADDR(a))

#define ALU(op, ret, dst, dsp, rsp) (OP_ALU | )

#define DST(n) (OP | ((n) << DST_SHIFT))
#define DST_SHIFT 4
#define DST_T    DST(0)
#define DST_R    DST(1)
#define DST_PC   DST(2)
#define DST_MEMT DST(3)

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
