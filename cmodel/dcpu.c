#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>

#include "dcpu.h"

#define ARRCOUNT(a) (sizeof(a) / sizeof((a)[0]))

typedef enum {
    ST_RESET = 0,
    ST_FETCH = 1,
    ST_EXECUTE = 2,
} state_t;

typedef struct cpu_t cpu_t;

struct cpu_t {
    
    // instruction + immediate registers
    uint8_t ir[3];
    
    // program counter, byte addresses
    uint16_t pc;
    
    // data stack
    uint16_t t;
    uint16_t n;
    uint16_t dsp; // byte address
    
    // address stack
    uint16_t asp; // byte address
    uint16_t a;
    
    // user stack pointer
    uint16_t usp; // byte address

    uint16_t status; // incl. carry

    // memory access
    uint16_t* (*bus)(cpu_t *cpu);
    uint16_t busaddr; // byte address

    // state machine state
    state_t state;
};

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
        [OP_FETCHU] = "FETCH USP+#ofs",
        [OP_FETCHABS] = "FETCH %04X",
        [OP_FETCHABS|1] = "FETCH %04X",
        [OP_FETCHABS|2] = "FETCH %04X",
        [OP_FETCHABS|3] = "FETCH %04X",
        [OP_STORET] = "STORE T",
        [OP_STOREA] = "STORE A",
        [OP_STOREU] = "STORE U+#ofs",
        [OP_STOREABS] = "STORE %04X",
        [OP_STOREABS|1] = "STORE %04X",
        [OP_STOREABS|2] = "STORE %04X",
        [OP_STOREABS|3] = "STORE %04X",
        [OP_JMPT] = "JMP T",
        [OP_JMPA] = "JMP A",
        [OP_JMPABS] = "JMP %04X",
        [OP_JMPABS|1] = "JMP %04X",
        [OP_JMPABS|2] = "JMP %04X",
        [OP_JMPABS|3] = "JMP %04X",
        [OP_BRAT] = "BRA T",
        [OP_BRAA] = "BRA A",
        [OP_INT] = "INT",
        [OP_BRAABS] = "BRA %04X",
        [OP_BRAABS|1] = "BRA %04X",
        [OP_BRAABS|2] = "BRA %04X",
        [OP_BRAABS|3] = "BRA %04X",
        [OP_JMPZT] = "JMPZ T",
        [OP_JMPZA] = "JMPZ A",
        [OP_JMPZABS] = "JMPZ %04X",
        [OP_JMPZABS|1] = "JMPZ %04X",
        [OP_JMPZABS|2] = "JMPZ %04X",
        [OP_JMPZABS|3] = "JMPZ %04X",
        [OP_JMPNZT] = "JMPNZ T",
        [OP_JMPNZA] = "JMPNZ A",
        [OP_JMPNZABS] = "JMPNZ %04X",
        [OP_JMPNZABS|1] = "JMPNZ %04X",
        [OP_JMPNZABS|2] = "JMPNZ %04X",
        [OP_JMPNZABS|3] = "JMPNZ %04X",
        [OP_JMPCT] = "JMPC T",
        [OP_JMPCA] = "JMPC A",
        [OP_JMPCABS] = "JMPC %04X",
        [OP_JMPCABS|1] = "JMPC %04X",
        [OP_JMPCABS|2] = "JMPC %04X",
        [OP_JMPCABS|3] = "JMPC %04X",
        [OP_JMPNCT] = "JMPNC T",
        [OP_JMPNCA] = "JMPNC A",
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
        [OP_CPR] = "CPR",
    };
    uint16_t imm(cpu_t *cpu);
    sprintf(buf, "%s", mnemonics[op]);
    sprintf(s, buf, imm(cpu));
    return s;
}

void alu(cpu_t *cpu) {
    int op = cpu->ir[0];
    uint32_t r = 0;
    switch(op) {
        case OP_ADD: r = cpu->n  + cpu->t; break;
        case OP_SUB: r = cpu->n  - cpu->t; break;
        case OP_AND: r = cpu->n  & cpu->t; break;
        case OP_OR:  r = cpu->n  | cpu->t; break;
        case OP_XOR: r = cpu->n  ^ cpu->t; break;
        case OP_LSR: r = cpu->n >> cpu->t; break;
        case OP_CPR: r = (cpu->n << 8) | (cpu->t & 0xff); break;
        default:
            printf("undefined alu op (%02X)\n", op);
            assert(0);
    }
    cpu->t = r & 0xFFFF;
    cpu->status = (cpu->status & ~FLAG_CARRY) | ((r > 0xFFFF) ? FLAG_CARRY : 0);
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

uint16_t imm(cpu_t *cpu) {
    // ir2[6:0] ir1[6:0] {op[7:2], x, y} --> imm = {ir2[6:0], ir1[6:0], x, y }
    const uint16_t xy = (cpu->ir[0] & 0x03);
    const uint16_t hi = (cpu->ir[2] & 0x7f);
    const uint16_t lo = (cpu->ir[1] & 0x7f);
    return (hi << 9) | (lo << 2) | xy;
}

uint16_t usp_ofs(cpu_t *cpu) {
    uint16_t ofs = (cpu->ir[2] << 7) | cpu->ir[1];
    return cpu->usp + ofs;
}

void execute_stackop(cpu_t *cpu) {
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

void execute_fetchop(cpu_t *cpu) {
    const uint16_t _im = imm(cpu);
    const uint16_t uspofs = usp_ofs(cpu);
    const uint16_t addr[] = { cpu->t, cpu->a, uspofs, 0, _im, _im, _im, _im };
    const uint8_t idx = cpu->ir[0] & 7;
    if( idx >= ARRCOUNT(addr) || (idx == 3) ) {
        printf("fetch: invalid index (%d)\n", idx);
        assert(0);
    }
    // set memory source addr
    cpu->busaddr = addr[idx];
    // read from memory into t
    cpu->t = *cpu->bus(cpu);
}

void execute_storeop(cpu_t *cpu) {
    const uint8_t op = cpu->ir[0];
    const uint16_t _im = imm(cpu);
    const uint16_t uspofs = usp_ofs(cpu);
    const uint16_t destaddr[] = { cpu->t, cpu->a, uspofs, 0, _im, _im, _im, _im };
    const uint8_t idx = cpu->ir[0] & 7;
    const uint16_t src[] = { cpu->n, cpu->t};
    if( idx >= ARRCOUNT(destaddr) || (idx == 3) ) {
        printf("store: invalid index (%d)\n", idx);
        assert(0);
    }
    // set memory dest addr
    cpu->busaddr = destaddr[idx];
    // store
    *cpu->bus(cpu) = (op == OP_STORET) ? src[0] : src[1];
}

uint16_t jmpaddr(cpu_t *cpu) {
    const uint16_t _im = imm(cpu);
    const uint16_t addr[] = { cpu->t, cpu->a, ADDR_INT, 0, _im, _im, _im, _im };
    const uint8_t idx = cpu->ir[0] & 7;
    if( idx >= ARRCOUNT(addr) || (idx == 3) ) {
        printf("store: invalid index (%d)\n", idx);
        assert(0);
    }
    return addr[idx];
}

void execute_jump(cpu_t *cpu) {
    cpu->pc = jmpaddr(cpu);
}

void execute_branch(cpu_t *cpu) {
    // save a to as
    cpu->busaddr = cpu->asp;
    *cpu->bus(cpu) = cpu->a;
    cpu->asp+=2;
    // save pc+1 to a
    cpu->a = cpu->pc; // pc is already incremented
    cpu->pc = jmpaddr(cpu);
}

void execute_pop(cpu_t *cpu) {
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

void execute_setregister(cpu_t *cpu) {
    int idx = cpu->ir[0] & 0x7;
    uint16_t *dst[] = { &cpu->status, &cpu->dsp, &cpu->asp, &cpu->usp, &cpu->a  };
    if (idx >= ARRCOUNT(dst)) {
        printf("setregister: invalid index (%d)\n", idx);
        assert(0);
    }
    *dst[idx] = cpu->t;
}

void execute(cpu_t *cpu) {
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
            if (cpu->t == 0) {
                execute_jump(cpu);
            }
            break;
        case OP_JMPNZGROUP:
            if (cpu->t != 0) {
                execute_jump(cpu);
            }
            break;
        case OP_JMPCGROUP:
            if ((cpu->status & FLAG_CARRY) != 0) {
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

static uint8_t mem[0x10000];

uint16_t *bus(cpu_t *cpu) {
    assert(cpu->busaddr < sizeof(mem));
    return (uint16_t*)&mem[cpu->busaddr & 0xFFFe];
}

void copy(cpu_t *cpu, uint8_t *prog, int len) {
    for (int i = 0; i < len; i+=2) {
        cpu->busaddr = ADDR_RESET + i;
        *bus(cpu) = prog[i] | (prog[i+1] << 8);
    }
}

bool test(cpu_t *cpu, uint8_t *prog, int len, cpu_t *res) {
    copy(cpu, prog, len);
    reset(cpu);
    int count = 0;
    while(count++ < 100 && cpu->ir[0] != OP_END) {
        statemachine(cpu);
    }
    bool t = cpu->t == res->t;
    if (!t) printf("t wrong (%04X)\n", cpu->t);
    bool n = cpu->n == res->n;
    if (!n) printf("n wrong (%04X)\n", cpu->n);
    bool a = cpu->a == res->a;
    if (!a) printf("a wrong (%04X)\n", cpu->a);
    bool dsp = cpu->dsp == res->dsp;
    if (!dsp) printf("dsp wrong (%04X)\n", cpu->dsp);
    bool asp = cpu->asp == res->asp;
    if (!asp) printf("asp wrong (%04X)\n", cpu->asp);
    bool usp = cpu->usp == res->usp;
    if (!usp) printf("usp wrong (%04X)\n", cpu->usp);
    bool pc = cpu->pc == res->pc;
    if (!pc) printf("pc wrong (%04X)\n", cpu->pc);
    return t & n & a & dsp & asp & usp & pc;
}

int main(int argc, char *argv[]) {
    cpu_t cpu, res;
    cpu.bus = bus;

    int fail = 0;
    reset(&cpu);
    int testnr = 1;
    {
        // 1 PUSHI
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x7e, 0x7f, OP_PUSHI, OP_END };
        reset(&res);
        res.t = (0x7f<<2) | (0x7e << 9);
        res.dsp = 2;
        res.pc = 0x104;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 2 PUSHT
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x7f, 0x7e, OP_PUSHI, OP_PUSHT, OP_END};
        reset(&res);
        res.t = (0x7e<<2) | (0x7f << 9);
        res.n = res.t;
        res.dsp = 4;
        res.pc = 0x105;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 3 APUSH
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x12, 0x34, OP_PUSHI, OP_APUSH, OP_END};
        reset(&res);
        res.t = (0x34<<2) | (0x12 << 9);
        res.a = res.t;
        res.dsp = 2;
        res.asp = 0x42;
        res.pc = 0x105;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 4 PUSHN
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x12, 0x34, OP_PUSHI, OP_PUSHN, OP_END};
        reset(&res);
        res.n = (0x34<<2) | (0x12 << 9);
        res.t = 0;
        res.dsp = 4;
        res.pc = 0x105;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 5 SETUSP, PUSHUSP
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x34, OP_PUSHI, OP_SETUSP, OP_PUSHUSP, OP_END};
        reset(&res);
        res.t = 0x34<<2;
        res.n = 0x34<<2;
        res.dsp = 4;
        res.usp = 0x34<<2;
        res.pc = 0x105;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 6 FETCHT
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x34, OP_PUSHI, OP_FETCHT, OP_END};
        reset(&res);
        res.t = 0x99;
        res.n = 0;
        res.dsp = 2;
        mem[0x34<<2] = 0x99;
        res.pc = 0x104;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

     {
        // 7 APUSH, FETACHA
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x23, OP_PUSHI|0x1, OP_APUSH, OP_FETCHA, OP_END};
        reset(&res);
        res.t = 0xcc00; // fetch addr not 16-bit unaligned --> 0xcc on MSB
        res.n = 0;
        res.a = (0x23<<2)|1;
        res.dsp = 2;
        res.asp = 0x42;
        mem[res.a] = 0xcc;
        res.pc = 0x105;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }
   
    {
        // 8 SETUSP, FETCHU
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 1, OP_PUSHI, // T <- 4, dsp++
            OP_SETUSP, // usp <- T
            0x6, OP_FETCHU, // t <- mem[usp+5] = mem[6]
            OP_END
        };
        reset(&res);
        res.t = 0xb4ea;
        res.n = 0;
        res.dsp = 2;
        res.usp = 1<<2;
        mem[res.usp+6] = 0xea;
        mem[res.usp+7] = 0xb4;
        res.pc = 0x106;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 9 STOREABS, FETCHABS
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x33, 0x44, OP_PUSHI, // T <- ..., dsp=1
            0x05, 0x16, OP_STOREABS, // mem[addr] <- T
            OP_PUSHI, // T <- 0, dsp=2
            0x05, 0x16, OP_FETCHABS, // T <- mem[addr]
            OP_END
        };
        reset(&res);
        res.t = (0x33 << 9) | (0x44 << 2);
        res.n = res.t;
        res.dsp = 4;
        res.pc = 0x10b;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 10 JMPT
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x3f, OP_PUSHI | 3, // T <- 0xff, dsp=2
            0x70>>2, OP_STOREABS, // mem[0x70] <- T
            0x70>>2, OP_PUSHI, // T <- 0x70, dsp=2
            OP_JMPT,
            0xfe, // invalid op
            OP_END
        };
        reset(&res);
        res.t = 0x70;
        res.n = 0xff;
        res.dsp = 4;
        res.pc = 0x71;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 11  SETA, JMPA
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x3f, OP_PUSHI | 3, // T <- 0xff, dsp=2
            0x70>>2, OP_STOREABS, // mem[0x70] <- T
            0x70>>2, OP_PUSHI, // T <- 0x70, dsp=4
            OP_SETA, // a <- t
            OP_JMPA,
            0xfe, // invalid op
            OP_END
        };
        reset(&res);
        res.t = 0x70;
        res.n = 0xff;
        res.dsp = 4;
        res.a = 0x70;
        res.pc = 0x71;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 12 JMPABS
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x3f, OP_PUSHI | 3, // T <- 0xff, dsp=2
            0x70>>2, OP_STOREABS, // mem[0x70] <- T
            0x70>>2, OP_JMPABS,
            0xfe, // invalid op
            OP_END
        };
        reset(&res);
        res.t = 0xff;
        res.n = 0x0;
        res.dsp = 2;
        res.pc = 0x71;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 13 BRAABS, RET
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 
            0x105>>2, OP_BRAABS | 1, // branch 0x105
            0x14>>2, OP_PUSHI, // push 0x14
            OP_END,
            0x13>>2, OP_PUSHI|3, // push 0x13
            OP_RET
        };
        reset(&res);
        res.t = 0x14;
        res.n = 0x13;
        res.dsp = 4;
        res.pc = 0x105;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 14 INT
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 
            0x3f, OP_PUSHI | 3, // t < ff
            (ADDR_INT >> 9) & 0x7f, (ADDR_INT>>2) & 0x7f, OP_STOREABS, // mem[addr_int] = ff
            OP_INT
        };
        reset(&res);
        res.t = 0xff;
        res.n = 0;
        res.dsp = 2;
        res.pc = ADDR_INT+1;
        res.a = 0x106;
        res.asp = 0x42;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 15 JMPZ
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x3f, OP_PUSHI | 3, // T <- 0xff, dsp=1
            0x70>>2, OP_STOREABS, // mem[0x70] <- T
            0x40, OP_JMPZABS, // jmpz 0x100
            OP_PUSHI,
            0x70>>2, OP_JMPZABS,
            0xfe, // invalid op
            OP_END
        };
        reset(&res);
        res.t = 0x0;
        res.n = 0xff;
        res.dsp = 4;
        res.pc = 0x71;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 16 JMPNZ
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x3f, OP_PUSHI | 3, // T <- 0xff, dsp=1
            0x70>>2, OP_STOREABS, // mem[0x70] <- T
            OP_PUSHI, // T <- 0
            0x40, OP_JMPNZABS, // jmpz 0x100
            OP_PUSHI | 1, // T <- 1
            0x70>>2, OP_JMPNZABS,
            0xfe, // invalid op
            OP_END
        };
        reset(&res);
        res.t = 0x1;
        res.n = 0x0;
        res.dsp = 6;
        res.pc = 0x71;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 17 JMPC, JMPNC
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x3f, OP_PUSHI | 3, // T <- 0xff, dsp=1
            0x70>>2, OP_STOREABS, // mem[0x70] <- T
            0x7f, 0x7f, OP_PUSHI|3, // T <- 65535
            OP_PUSHI | 1, // T <- 1
            OP_ADD, // T <- 1 + 65535 = 0 -> carry = 1
            0x40, OP_JMPNCABS, // jmpz 0x100
            OP_PUSHI, // T <- 0
            0x70>>2, OP_JMPCABS,
            0xfe, // invalid op
            OP_END
        };
        reset(&res);
        res.t = 0x0;
        res.n = 0x0;
        res.dsp = 8;
        res.pc = 0x71;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
            fail++;
        }
    }

    {
        // 18 OP_POP, OP_APOP, 
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {
            OP_PUSHI | 0, OP_APUSH,
            OP_PUSHI | 1, OP_APUSH,
            OP_PUSHI | 2, OP_APUSH,
            OP_PUSHI | 3, OP_APUSH,
            OP_POP,
            OP_APOP,
            OP_POP,
            OP_APOP, 
            OP_END
        };
        reset(&res);
        res.t = 0x1;
        res.n = 0x0;
        res.a = 1;
        res.dsp = 4;
        res.asp = 0x44;
        res.pc = 0x10d;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
             fail++;
       }
    }

    printf("\nTests failed: %d\n", fail);

    return 0;
}