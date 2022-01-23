#ifndef __DCPU_H__
#define __DCPU_H__

#define MASK(b) ((1<<b)-1)

// call 0: <addr:15>
#define OP_CALL 0x0000
#define CALL(a) (OP_CALL | (a & MASK(15)))

// lit.l: 100 <imm:13> 
#define OP_LITL 0x8000
#define OP_LITL_VAL(n) (n & MASK(13))
#define LIT_L(v) (OP_LITL | OP_LITL_VAL(v))

// lit.h: 101 <unused:4> <return:1> <imm:8>
#define OP_LITH 0xa000
#define OP_LITH_VAL(n) (n & MASK(8))
#define OP_LITH_RET(r) ((r & 1) << 8)
#define OP_LITH_UNUSED(u) ((r & 0xf) << 9)
#define LIT_H(v) (OP_LITH | OP_LITH_RET(0) | OP_LITH_VAL(v))
#define LIT_H_RET(v) (OP_LITH | OP_LITH_RET(1) | OP_LITH_VAL(v))

// rjp: 111 <cond:3> <offs:10>
#define OP_RJP  0xe000
#define OP_RJP_OFFS(o) (o & MASK(10))
#define OP_RJP_COND(c) ((c & MASK(3)) << 10)
#define RJP(c,offs) (OP_RJP | OP_RJP_COND(c) | OP_RJP_OFFS(offs))

#define COND_RJP_NONE 0
#define COND_RJP_ZERO 4
#define COND_RJP_NONZERO 5
#define COND_RJP_NEG 6
#define COND_RJP_NONNEG 7

// alu: 110 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>
#define OP_ALU  0xc000
#define RSP(n)     ((n & MASK(2)) << 0)
#define DSP(n)     ((n & MASK(2)) << 2)
#define DST(n)     ((n & MASK(2)) << 4)
#define ALU_RET(r) ((r & MASK(1)) << 6)
#define ALU_OP(o)  ((o & MASK(5)) << 7)
#define ALU(op, ret, dst, dsp, rsp) (OP_ALU | ALU_OP(op) | ALU_RET(ret) | DST(dst) | DSP(dsp) | RSP(rsp))

#define DST_T    0
#define DST_R    1
#define DST_PC   2
#define DST_MEMT 3

#define DSP_I 1
#define DSP_D 2

#define RSP_I   1
#define RSP_D   2
#define RSP_RPC 3

#define RET 1

#define ALU_T       0
#define ALU_N       1
#define ALU_R       2
#define ALU_MEMT    3
#define ALU_ADD     4
#define ALU_SUB     5
#define ALU_MUL     6
#define ALU_AND     7
#define ALU_OR      8
#define ALU_XOR     9
#define ALU_LTS     10 // less than signed
#define ALU_LT      11 // less than
#define ALU_SR      12
#define ALU_SRW     13
#define ALU_SL      14
#define ALU_SLW     15
#define ALU_JZ      16
#define ALU_JNZ     17
#define ALU_CARRY   18
#define ALU_INV     19

// for simulation
#define OP_SIM_END (OP_LITH | OP_LITH_UNUSED(0xf))

#endif
