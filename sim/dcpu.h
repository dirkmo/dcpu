#ifndef __DCPU_H
#define __DCPU_H

#define DST(r) (r&0xf)
#define SRC(r) ((r&0xf) << 4)
#define IMM(v) ((v&((1<<12)-1)) << 4)

#endif
