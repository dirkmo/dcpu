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
#define T 0
#define N 1
#define R 2
#define ADD 3
#define SUB 4
#define AND 5
#define OR 6
#define XOR 7
#define INV 8
#define LSHIFT 10
#define RSHIFT 11
#define MEMT 12
#define MEMR 13
#define CONDR 14
#define CONDT 15
#define LSHIFT8 16
#define RSHIFT8 17

#define PICK(n) (OP | ((1<<(ALU_SHIFT+5)) | n))

#endif
