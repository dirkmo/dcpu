#include "dcpu.h"

const char *disassembly[] = {
    "CALL $%04x",
    "LITL $%02x",
    "LITL $%02x",
    "LIT $%04x",
    "RJ $%x",
    "RJ.Z $%x",
    "RJ.NZ $%x",
    "RJ.N $%x",
    "RJ.NN $%x",
    "A:%s %s [%s] %s %s"
};
