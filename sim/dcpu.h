#ifndef __DCPU_H
#define __DCPU_H

#define DST(r) (r&0xf)
#define SRC(r) ((r&0xf) << 4)

#define LDIMML(v,dst) ((0<<14) | ((v & ((1<<11)-1)) << 4) | DST(dst))
#define LDIMMH(v,dst) ((1<<14) | ((v & 0xff) << 4)        | DST(dst))

#endif
