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
    const uint16_t hi = cpu->ir[1] | ((cpu->ir[0] & 2) << 6);
    const uint16_t lo = cpu->ir[2] | ((cpu->ir[0] & 1) << 7);
    return lo | (hi << 8);;
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
    *cpu->bus(cpu) = src[idx];
    // inc dsp
    cpu->dsp++;
    // put t to n
    cpu->n = cpu->t;
    // set t to new value from src
    cpu->t = src[idx];
}

void execute_fetchop(cpu_t *cpu) {
    const uint16_t _im = imm(cpu);
    const uint16_t uspofs = cpu->usp + imm(cpu);
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
    const uint16_t uspofs = cpu->usp + imm(cpu);
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
        case OP_POPA:
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


int main(int argc, char *argv[]) {
    cpu_t cpu;
    cpu.bus = bus;

    reset(&cpu);

    uint8_t prog[] = { 0x7e, 0x7f, OP_PUSHI, OP_END };
    
    for (int i = 0; i < sizeof(prog); i+=2) {
        cpu.busaddr = ADDR_RESET + i;
        *bus(&cpu) = prog[i] | (prog[i+1] << 8);
    }

    int count = 0;
    while(count++ < 10 && cpu.ir[0] != OP_END) {
        statemachine(&cpu);
    }
    return 0;
}