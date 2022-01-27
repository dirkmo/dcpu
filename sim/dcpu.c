#include "dcpu.h"
#include <stdio.h>

static char buf[64];

static const char *rjp_cond(uint16_t op) {
    uint16_t cond = (op >> 10) & MASK(3);
    switch(cond) {
        case COND_RJP_ZERO: return "RJ.Z";
        case COND_RJP_NONZERO: return "RJ.NZ";
        case COND_RJP_NEG: return "RJ.N";
        case COND_RJP_NONNEG: return "RJ.NN";
        default: ;
    }
    return "RJ";
}

static void disasm_alu(char *s, uint16_t op) {
    const char *s_dst[] = {"T", "R", "PC", "MEM"};
    const char *s_dsp[] = {"", "D+", "D-", ""};
    const char *s_rsp[] = {"", "R+", "R-", "R+PC"};
    const char *s_ret[] = {"", "[ret]"};
    const char *s_aluop[] = {
        "a:T", "a:N", "a:R", "a:MEM", "a:ADD", "a:SUB", "a:MUL", "a:AND",
        "a:OR", "a:XOR", "a:LTS", "a:LT", "a:SR", "a:SRW", "a:SL", "a:SLW",
        "a:JZ", "a:JNZ", "a:CARRY", "a:INV", "a:NOP"
    };
    int aluop = (op >> 7) & MASK(5);
    int ret   = (op >> 6) & MASK(1);
    int dst   = (op >> 4) & MASK(2);
    int dsp   = (op >> 2) & MASK(2);
    int rsp   = (op >> 0) & MASK(2);
    sprintf(s, "%s %s %s %s %s", s_aluop[aluop], s_dst[dst], s_dsp[dsp], s_rsp[rsp], s_ret[ret]);
}

const char *dcpu_disasm(uint16_t op) {
    switch(op & 0xe000) {
        case OP_CALL: sprintf(buf, "CALL $%04x", op); break;
        case OP_LITL: sprintf(buf, "LIT.L $%x", op & MASK(13)); break;
        case OP_LITH:
            if (op & OP_LITH_UNUSED(0xf))
                sprintf(buf, "SIM_END");
            else
                sprintf(buf, "LIT.H $%02x", op & MASK(8));
            break;
        case OP_RJP:  sprintf(buf, "%s $%03x", rjp_cond(op), op & MASK(10)); break;
        case OP_ALU:  disasm_alu(buf, op); break;
        default: sprintf(buf, "invald opcode"); break;
    }
    return buf;
}
