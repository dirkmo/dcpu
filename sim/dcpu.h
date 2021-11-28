#ifndef __DCPU_H
#define __DCPU_H

#define REG_ST 13
#define REG_SP 14
#define REG_PC 15

#define MASK(width) ((1<<width)-1)

#define DST(r)    (r & MASK(4))
#define SRC(r)   ((r & MASK(4)) << 4)
#define OFFS5(o) ((o & MASK(5)) << 8)

#define NONE 0
#define ZERO 1
#define NONZERO 2
#define CARRY 3
#define NOCARRY 4
#define RETURN 7
#define JPCOND(cond) (cond << 4)

#define COPY 0
#define ADD 1
#define SUB 2
#define AND 3
#define OR  4
#define XOR 5
#define CMP 6
#define LSR 7
#define LSL 8
#define WLSR 9
#define WLSL 10

// helper macros for 2s complement
#define COMPLEMENT2(v,w) ( (((v)<0) ? ~(uint32_t)-(v+1) : v ) & MASK(w))
#define C(offs) COMPLEMENT2(offs-1,9)
// RJP: 1100 <offs:5> <cond:3> <offs:4>
#define RJPOFFSET(offs) ( ((C(offs) & 0x1f0) << 3) | (C(offs) & 0xf) )


// load implicit lower 10 bits of register
// ld rd, #0x3ff
#define LDIMML(rd,v) ((0<<14) | ((v & MASK(10)) << 4) | DST(rd))

// load implicit upper 8 bits of register
// ldh rd, #0xff
#define LDIMMH(rd,v) ((1<<14) | ((v & MASK(8))  << 4) | DST(rd))

// load from memory with address from register and offset
// ld rd, (rs+offs)
#define LD(rd, rs, offs) ((4<<13) | OFFS5(offs) | SRC(rs) | DST(rd))

// store to memory with address from register and offset
// st (rd+offs), rs (note: in verilog, dst is picked from src field)
#define ST(rd, offs, rs) ((5<<13) | OFFS5(offs) | SRC(rd) | DST(rs))

// relative jump with condition
// rj.cond -100
#define RJP(cond, offs) ((0xc<<12) | JPCOND(cond) | RJPOFFSET(offs))

// absolute jmp to register
// jp.cond r0
#define JMP(dst, cond) ((0xd<<12) | JPCOND(cond) | DST(dst))

// absolute branch to register
// br.cond r0
#define BR(dst, cond) ((0xd<<12) | (1<<7) | JPCOND(cond) | DST(dst))

// return
// ret
#define RET (0xd100 | (0<<4))

// push
// push r0
#define PUSH(dst) (0xd100 | (1<<4) | (DST(dst)))

// pop
// pop r0
#define POP(dst) (0xd100 | (2<<4) | (DST(dst)))

#define ALU(rd, rs, op) (0xe000 | (op << 8) | SRC(rs) | DST(rd))

#endif
