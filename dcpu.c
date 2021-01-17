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

    // alu
    uint16_t alu_output;
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
        [OP_APUSH] = "APUSH",
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
        default:
            printf("undefined alu op (%02X)\n", op);
            assert(0);
    }
    cpu->alu_output = r & 0xFFFF;
    cpu->status = (cpu->status & ~FLAG_CARRY) | ((r > 0xFFFF) ? FLAG_CARRY : 0);
    cpu->status = (cpu->status & ~FLAG_ZERO) | ((cpu->alu_output == 0) ? FLAG_ZERO : 0);
}

void reset(cpu_t *cpu) {
    cpu->ir[0] = cpu->ir[1] = cpu->ir[2] = 0;
    cpu->pc = ADDR_RESET;
    cpu->a = cpu->t = cpu->n = 0;
    cpu->usp = cpu->asp = cpu->dsp = 0;
    cpu->alu_output = 0;
    cpu->status = 0;
    cpu->busaddr = 0;
    cpu->state = ST_RESET;
    // not setting cpu->bus
}

uint16_t imm(cpu_t *cpu) {
    const uint16_t hi = cpu->ir[2] | ((cpu->ir[0] & 2) << 6);
    const uint16_t lo = cpu->ir[1] | ((cpu->ir[0] & 1) << 7);
    return lo | (hi << 8);;
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
    cpu->dsp++;
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
    cpu->asp++;
    // save pc+1 to a
    cpu->a = cpu->pc; // pc is already incremented
    cpu->pc = jmpaddr(cpu);
}

void execute_pop(cpu_t *cpu) {
    const uint8_t op = cpu->ir[0];
    switch(op) {
        case OP_POP:
            cpu->dsp--;
            cpu->t = cpu->n;
            cpu->busaddr = cpu->dsp;
            cpu->n = *cpu->bus(cpu);
            break;
        case OP_RET:
            cpu->pc = cpu->a;
            // intended fallthrough
        case OP_APOP:
            cpu->asp--;
            cpu->busaddr = cpu->asp;
            cpu->a = *cpu->bus(cpu);
            break;
        default:
            printf("Invalid opcode (%02X)\n", op);
            assert(0);
    }
}

void execute(cpu_t *cpu) {
    const uint8_t op = cpu->ir[0];
    const uint8_t opgroup = cpu->ir[0] & OP_MASK;
    switch(opgroup) {
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
        case OP_MISCGROUP:
            if (op == OP_SETSTATUS) {
                cpu->status = cpu->t;
            } else if (op == OP_SETDSP) {
                cpu->dsp = cpu->t;
            } else if (op == OP_SETASP) {
                cpu->asp = cpu->t;
            } else if (op == OP_SETUSP) {
                cpu->usp = cpu->t;
            } else if (op == OP_APUSH) {
                // save a to as
                cpu->busaddr = cpu->asp;
                *cpu->bus(cpu) = cpu->a;
                cpu->asp++;
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
            cpu->pc++; // first increase pc. pc might again be overwritten by jumps
            break;
        case ST_EXECUTE:
            printf("%s\n",disassemble(cpu));
            execute(cpu);
            // finally clear ir[]
            cpu->ir[1] = cpu->ir[0] = 0;
            cpu->state = ST_FETCH;
            break;
        default:;
    }
}

static uint8_t mem[0x1000];

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
    return t & n & a & dsp & asp & usp;
}

int main(int argc, char *argv[]) {
    cpu_t cpu, res;
    cpu.bus = bus;

    reset(&cpu);
    int testnr = 1;
    {
        // 1
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x7e, 0x7f, OP_PUSHI, OP_END };
        reset(&res);
        res.t = 0x7f | (0x7e << 8);
        res.dsp = 1;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }

    {
        // 2
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x7f, 0x7e, OP_PUSHI, OP_PUSHT, OP_END};
        reset(&res);
        res.t = 0x7e | (0x7f << 8);
        res.n = res.t;
        res.dsp = 2;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }

    {
        // 3
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x12, 0x34, OP_PUSHI, OP_APUSH, OP_END};
        reset(&res);
        res.t = 0x34 | (0x12 << 8);
        res.a = res.t;
        res.dsp = 1;
        res.asp = 1;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }

    {
        // 4
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x12, 0x34, OP_PUSHI, OP_PUSHN, OP_END};
        reset(&res);
        res.n = 0x34 | (0x12 << 8);
        res.t = 0;
        res.dsp = 2;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }

    {
        // 5
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x34, OP_PUSHI, OP_SETUSP, OP_PUSHUSP, OP_END};
        reset(&res);
        res.t = 0x34;
        res.n = 0x34;
        res.dsp = 2;
        res.usp = 0x34;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }

    {
        // 6
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x34, OP_PUSHI, OP_FETCHT, OP_END};
        reset(&res);
        res.t = 0x99;
        res.n = 0;
        res.dsp = 1;
        mem[0x34] = 0x99;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }

     {
        // 7
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = {0x23, OP_PUSHI|0x1, OP_APUSH, OP_FETCHA, OP_END};
        // push 0xa3, a <- 0xa3
        reset(&res);
        res.t = 0xcc00; // not 16-bit unaligned --> 0xcc on MSB
        res.n = 0;
        res.a = 0xa3;
        res.dsp = 1;
        res.asp = 1;
        mem[0xa3] = 0xcc;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }
   
    {
        // 8
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 1, OP_PUSHI, // T <- 1, dsp++
            OP_SETUSP, // usp <- T
            0x5, OP_FETCHU, // t <- mem[usp+5] = mem[6]
            OP_END
        };
        reset(&res);
        res.t = 0xb4ea;
        res.n = 0;
        res.dsp = 1;
        res.usp = 1;
        mem[0x6] = 0xea;
        mem[0x7] = 0xb4;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }

    {
        // 9
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x33, 0x44, OP_PUSHI, // T <- 0x3344, dsp=1
            0x05, 0x16, OP_STOREABS, // mem[0x1516] <- T
            OP_PUSHI, // T <- 0, dsp=2
            0x05, 0x16, OP_FETCHABS, // T <- mem[0x1516]
            OP_END
        };
        reset(&res);
        res.t = 0x3344;
        res.n = 0x3344;
        res.dsp = 2;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }

        {
        // 10
        printf("\nTest %d\n", testnr++);
        uint8_t prog[] = { 0x33, 0x44, OP_PUSHI, // T <- 0x3344, dsp=1
            OP_END
        };
        reset(&res);
        res.t = 0;
        res.n = 0;
        res.dsp = 0;
        if (!test(&cpu, prog, sizeof(prog), &res)) {
            printf("fail\n");
        }
    }
    return 0;
}