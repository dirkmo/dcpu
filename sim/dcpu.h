#ifndef __DCPU_H__
#define __DCPU_H__

#define OP 0x8000

#define DST(n) (OP | ((n) << DST_SHIFT))
#define DST_SHIFT 12
#define DST_T 0
#define DST_N 1
#define DST_R 2
#define DST_PC 3
#define DST_MEMT 4
#define DST_MEMR 5

#define DSP(n) (OP | ((n) << DSP_SHIFT))
#define DSP_SHIFT 4
#define DSP_I 1
#define DSP_D 2

#define RSP(n) (OP | ((n) << RSP_SHIFT))
#define RSP_SHIFT 2
#define RSP_I 1
#define RSP_D 2
#define RSP_RPC 3

#define ALU(n) (OP | ((n) << ALU_SHIFT))
#define ALU_SHIFT 6
#define ALU_T 0
#define ALU_N 1
#define ALU_R 2
#define ALU_ADD 3
#define ALU_SUB 4
#define ALU_AND 5
#define ALU_OR 6
#define ALU_XOR 7
#define ALU_INV 8
#define ALU_LSHIFT 10
#define ALU_RSHIFT 11
#define ALU_MEMT 12
#define ALU_MEMR 13
#define ALU_CONDR 14
#define ALU_CONDT 15
#define ALU_LSHIFT8 16
#define ALU_RSHIFT8 17

#define PICK(n) (OP | ((1<<(ALU_SHIFT+5)) | n))

#endif
