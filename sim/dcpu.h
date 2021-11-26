#ifndef __DCPU_H
#define __DCPU_H

#define MASK(width) ((1<<width)-1)


#define DST(r)    (r & MASK(4))
#define SRC(r)   ((r & MASK(4)) << 4)
#define OFFS5(o) ((o & MASK(5)) << 8)

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


#endif
