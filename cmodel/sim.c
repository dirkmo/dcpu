#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "dcpu.h"

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

    // copy(&cpu, prog, len);
    // reset(cpu);
    // int count = 0;
    // while(count++ < 100 && cpu.ir[0] != OP_END) {
    //     statemachine(&cpu);
    // }

    return 0;
}
