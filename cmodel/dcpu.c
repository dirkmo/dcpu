#include <stdio.h>
#include <assert.h>
#include <string.h>

#include "dcpu.h"


static uint16_t imm(cpu_t *cpu) {
    // ir2[6:0] ir1[6:0] {op[7:2], x, y} --> imm = {ir2[6:0], ir1[6:0], x, y }
    const uint16_t xy = (cpu->ir[0] & 0x03);
    const uint16_t hi = (cpu->ir[2] & 0x7f);
    const uint16_t lo = (cpu->ir[1] & 0x7f);
    return (hi << 9) | (lo << 2) | xy;
}

static void alu(cpu_t *cpu) {
    int op = cpu->ir[0];
    uint32_t r = 0;
    switch(op) {
        case OP_ADD:  r = cpu->n  + cpu->t; break;
        case OP_SUB:  r = cpu->n  - cpu->t; break;
        case OP_AND:  r = cpu->n  & cpu->t; break;
        case OP_OR:   r = cpu->n  | cpu->t; break;
        case OP_XOR:  r = cpu->n  ^ cpu->t; break;
        case OP_LSR:  r = cpu->n >> cpu->t; break;
        case OP_CPR:  r = (cpu->n << 8) | (cpu->t & 0xff); break;
        case OP_SWAP: r = cpu->n; cpu->n = cpu->t; break;
        default:
            printf("undefined alu op (%02X)\n", op);
            assert(0);
    }
    cpu->t = r & 0xFFFF;
    cpu->status = (cpu->status & ~FLAG_CARRY) | ((r > 0xFFFF) ? FLAG_CARRY : 0);
    cpu->status = (cpu->status & ~FLAG_ZERO) | ((cpu->t == 0) ? FLAG_ZERO : 0);
}

static uint16_t usp_ofs(cpu_t *cpu) {
    uint16_t ofs = (cpu->ir[2] << 7) | cpu->ir[1];
    return cpu->usp + ofs;
}

static void execute_stackop(cpu_t *cpu) {
    const uint16_t _im = imm(cpu);
    const uint16_t src[] = { cpu->t, cpu->a, cpu->n, cpu->usp, _im, _im, _im, _im, cpu->status, cpu->dsp, cpu->asp, cpu->pc };
    const uint8_t idx = cpu->ir[0] & 7;
    if( idx >= ARRCOUNT(src)) {
        printf("push: index out of range (%d)\n", idx);
        assert(0);
    }
    // push n to ds
    cpu->busaddr = cpu->dsp;
    *cpu->bus(cpu) = cpu->n;
    // inc dsp
    cpu->dsp+=2;
    // put t to n
    cpu->n = cpu->t;
    // set t to new value from src
    cpu->t = src[idx];
}

static void execute_fetchop(cpu_t *cpu) {
    const uint16_t _im = imm(cpu);
    const uint16_t uspofs = usp_ofs(cpu);
    const uint16_t addr[] = { cpu->t, cpu->a, cpu->n, uspofs, _im, _im, _im, _im };
    const uint8_t idx = cpu->ir[0] & 7;
    if( idx >= ARRCOUNT(addr) ) {
        printf("fetch: invalid index (%d)\n", idx);
        assert(0);
    }
    // set memory source addr
    cpu->busaddr = addr[idx];
    // read from memory into t
    cpu->t = *cpu->bus(cpu);
    // setting zero flag
    cpu->status = cpu->t ? (cpu->status & ~FLAG_ZERO) : (cpu->status | FLAG_ZERO);
}

static void execute_storeop(cpu_t *cpu) {
    const uint8_t op = cpu->ir[0];
    const uint16_t _im = imm(cpu);
    const uint16_t uspofs = usp_ofs(cpu);
    const uint16_t destaddr[] = { cpu->t, cpu->a, cpu->n, uspofs, _im, _im, _im, _im };
    const uint8_t idx = cpu->ir[0] & 7;
    const uint16_t src[] = { cpu->n, cpu->t};
    if( idx >= ARRCOUNT(destaddr) ) {
        printf("store: invalid index (%d)\n", idx);
        assert(0);
    }
    // set memory dest addr
    cpu->busaddr = destaddr[idx];
    // store
    *cpu->bus(cpu) = (op == OP_STORET) ? src[0] : src[1];
}

static uint16_t jmpaddr(cpu_t *cpu) {
    const uint16_t _im = imm(cpu);
    const uint16_t addr[] = { cpu->t, cpu->a, ADDR_INT, cpu->n, _im, _im, _im, _im };
    const uint8_t idx = cpu->ir[0] & 7;
    if( idx >= ARRCOUNT(addr) ) {
        printf("store: invalid index (%d)\n", idx);
        assert(0);
    }
    return addr[idx];
}

static void execute_jump(cpu_t *cpu) {
    cpu->pc = jmpaddr(cpu);
}

static void execute_branch(cpu_t *cpu) {
    // save a to as
    cpu->busaddr = cpu->asp;
    *cpu->bus(cpu) = cpu->a;
    cpu->asp+=2;
    // save pc+1 to a
    cpu->a = cpu->pc; // pc is already incremented
    cpu->pc = jmpaddr(cpu);
}

static void execute_pop(cpu_t *cpu) {
    const uint8_t op = cpu->ir[0];
    switch(op) {
        case OP_POP:
            cpu->dsp-=2;
            cpu->t = cpu->n;
            cpu->busaddr = cpu->dsp;
            cpu->n = *cpu->bus(cpu);
            break;
        case OP_RET:
            cpu->pc = cpu->a;
            // intended fallthrough
        case OP_APOP:
            cpu->asp-=2;
            cpu->busaddr = cpu->asp;
            cpu->a = *cpu->bus(cpu);
            break;
        default:
            printf("Invalid opcode (%02X)\n", op);
            assert(0);
    }
}

static void execute_setregister(cpu_t *cpu) {
    int idx = cpu->ir[0] & 0x7;
    uint16_t *dst[] = { &cpu->status, &cpu->dsp, &cpu->asp, &cpu->usp, &cpu->a  };
    if (idx >= ARRCOUNT(dst)) {
        printf("setregister: invalid index (%d)\n", idx);
        assert(0);
    }
    *dst[idx] = cpu->t;
}

static void execute(cpu_t *cpu) {
    const uint8_t op = cpu->ir[0];
    const uint8_t opgroup = cpu->ir[0] & OP_MASK;
    switch(opgroup) {
        case OP_ALU:
            alu(cpu);
            break;
        case OP_STACKGROUP1:
        case OP_STACKGROUP2:
            execute_stackop(cpu);
            break;
        case OP_FETCHGROUP:
            execute_fetchop(cpu);
            break;
        case OP_STOREGROUP:
            execute_storeop(cpu);
            break;
        case OP_JMPGROUP:
            execute_jump(cpu);
            break;
        case OP_BRANCHGROUP:
            execute_branch(cpu);
            break;
        case OP_JMPZGROUP:
            if ((cpu->status & FLAG_ZERO)) {
                execute_jump(cpu);
            }
            break;
        case OP_JMPNZGROUP:
            if ((cpu->status & FLAG_ZERO) == 0) {
                execute_jump(cpu);
            }
            break;
        case OP_JMPCGROUP:
            if ((cpu->status & FLAG_CARRY)) {
                execute_jump(cpu);
            }
            break;
        case OP_JMPNCGROUP:
            if ((cpu->status & FLAG_CARRY) == 0) {
                execute_jump(cpu);
            }
            break;
        case OP_POPGROUP:
            execute_pop(cpu);
            break;
        case OP_SETREGISTERGROUP:
            execute_setregister(cpu);
            break;
        case OP_MISC:
            if (op == OP_APUSH) {
                // save a to as
                cpu->busaddr = cpu->asp;
                *cpu->bus(cpu) = cpu->a;
                cpu->asp+=2;
                cpu->a = cpu->t;
            }
            break;
        default: printf("unknown opcode %02X\n", op);
    }
}

const char *disassemble(cpu_t *cpu) {
    static char s[32];
    char buf[32];
    uint8_t op = cpu->ir[0];
    if ((op & 0x80) == 0) {
        op = 0;
    }
    const char *mnemonics[] = {
        [0] = "LIT %04X",
        [OP_ADD] = "ADD",
        [OP_SUB] = "SUB",
        [OP_AND] = "AND",
        [OP_OR] = "OR",
        [OP_XOR] = "XOR",
        [OP_LSR] = "LSR",
        [OP_CPR] = "CPR",
        [OP_SWAP] = "SWAP",
        [OP_PUSHT] = "PUSH T",
        [OP_PUSHA] = "PUSH A",
        [OP_PUSHN] = "PUSH N",
        [OP_PUSHUSP] = "PUSH USP",
        [OP_PUSHI] = "PUSH %04X",
        [OP_PUSHI|1] = "PUSH %04X",
        [OP_PUSHI|2] = "PUSH %04X",
        [OP_PUSHI|3] = "PUSH %04X",
        [OP_PUSHS] = "PUSH STATUS",
        [OP_PUSHDSP] = "PUSH DSP",
        [OP_PUSHASP] = "PUSH ASP",
        [OP_PUSHPC] = "PUSH PC",
        [OP_FETCHT] = "FETCH T",
        [OP_FETCHA] = "FETCH A",
        [OP_FETCHN] = "FETCH N",
        [OP_FETCHU] = "FETCH USP+#ofs",
        [OP_FETCHABS] = "FETCH %04X",
        [OP_FETCHABS|1] = "FETCH %04X",
        [OP_FETCHABS|2] = "FETCH %04X",
        [OP_FETCHABS|3] = "FETCH %04X",
        [OP_STORET] = "STORE T",
        [OP_STOREA] = "STORE A",
        [OP_STOREN] = "STORE N",
        [OP_STOREU] = "STORE U+#ofs",
        [OP_STOREABS] = "STORE %04X",
        [OP_STOREABS|1] = "STORE %04X",
        [OP_STOREABS|2] = "STORE %04X",
        [OP_STOREABS|3] = "STORE %04X",
        [OP_JMPT] = "JMP T",
        [OP_JMPA] = "JMP A",
        [OP_JMPN] = "JMP N",
        [OP_JMPABS] = "JMP %04X",
        [OP_JMPABS|1] = "JMP %04X",
        [OP_JMPABS|2] = "JMP %04X",
        [OP_JMPABS|3] = "JMP %04X",
        [OP_BRAT] = "BRA T",
        [OP_BRAA] = "BRA A",
        [OP_INT] = "INT",
        [OP_BRAN] = "BRA N",
        [OP_BRAABS] = "BRA %04X",
        [OP_BRAABS|1] = "BRA %04X",
        [OP_BRAABS|2] = "BRA %04X",
        [OP_BRAABS|3] = "BRA %04X",
        [OP_JMPZT] = "JMPZ T",
        [OP_JMPZA] = "JMPZ A",
        [OP_JMPZN] = "JMPZ N",
        [OP_JMPZABS] = "JMPZ %04X",
        [OP_JMPZABS|1] = "JMPZ %04X",
        [OP_JMPZABS|2] = "JMPZ %04X",
        [OP_JMPZABS|3] = "JMPZ %04X",
        [OP_JMPNZT] = "JMPNZ T",
        [OP_JMPNZA] = "JMPNZ A",
        [OP_JMPNZN] = "JMPNZ N",
        [OP_JMPNZABS] = "JMPNZ %04X",
        [OP_JMPNZABS|1] = "JMPNZ %04X",
        [OP_JMPNZABS|2] = "JMPNZ %04X",
        [OP_JMPNZABS|3] = "JMPNZ %04X",
        [OP_JMPCT] = "JMPC T",
        [OP_JMPCA] = "JMPC A",
        [OP_JMPCN] = "JMPC N",
        [OP_JMPCABS] = "JMPC %04X",
        [OP_JMPCABS|1] = "JMPC %04X",
        [OP_JMPCABS|2] = "JMPC %04X",
        [OP_JMPCABS|3] = "JMPC %04X",
        [OP_JMPNCT] = "JMPNC T",
        [OP_JMPNCA] = "JMPNC A",
        [OP_JMPNCN] = "JMPNC N",
        [OP_JMPNCABS] = "JMPNC %04X",
        [OP_JMPNCABS|1] = "JMPNC %04X",
        [OP_JMPNCABS|2] = "JMPNC %04X",
        [OP_JMPNCABS|3] = "JMPNC %04X",
        [OP_POP] = "POP",
        [OP_APOP] = "APOP",
        [OP_RET] = "RET",
        [OP_SETSTATUS] = "SETSTATUS",
        [OP_SETDSP] = "SETDSP",
        [OP_SETASP] = "SETASP",
        [OP_SETUSP] = "SETUSP",
        [OP_SETA] = "SETA",
        [OP_APUSH] = "APUSH",
    };
    if (op >= ARRCOUNT(mnemonics)) {
        sprintf(s, "unknown opcode %02X", op);
    } else {
        sprintf(buf, "%s", mnemonics[op]);
        sprintf(s, buf, imm(cpu));
    }
    return s;
}

void reset(cpu_t *cpu) {
    cpu->ir[0] = cpu->ir[1] = cpu->ir[2] = 0;
    cpu->pc = ADDR_RESET;
    cpu->a = cpu->t = cpu->n = 0;
    cpu->usp = 0;
    cpu->dsp = 0;
    cpu->asp = 0x40;
    cpu->status = 0;
    cpu->busaddr = 0;
    cpu->state = ST_RESET;
    // not setting cpu->bus
}


void statemachine(cpu_t *cpu) {
    switch(cpu->state) {
        case ST_RESET:
            reset(cpu);
            cpu->state = ST_FETCH;
            break;
        case ST_FETCH:
            cpu->busaddr = cpu->pc;
            cpu->ir[2] = cpu->ir[1];
            cpu->ir[1] = cpu->ir[0];
            cpu->ir[0] = (cpu->pc&1) ? (*cpu->bus(cpu) >> 8 ): *cpu->bus(cpu);
            cpu->state = (cpu->ir[0] & OP_IMM_MASK) ? ST_EXECUTE : ST_FETCH;
            printf("fetch %04X: %02X\n", cpu->pc, cpu->ir[0]);
            cpu->pc++; // first increase pc. pc might again be overwritten by jumps
            break;
        case ST_EXECUTE:
            printf("decode: %s\n",disassemble(cpu));
            execute(cpu);
            // finally clear ir[]
            cpu->ir[1] = cpu->ir[0] = 0;
            cpu->state = ST_FETCH;
            break;
        default:;
    }
}
