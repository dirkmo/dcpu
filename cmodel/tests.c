#include <stdio.h>
#include <assert.h>
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
