#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vdcpu.h"
#include "Vdcpu_dcpu.h"
#include "dcpu.h"

using namespace std;

#define ARRSIZE(a) (sizeof(a) / sizeof(a[0]))
#define RED "\033[31m"
#define GREEN "\033[32m"
#define NORMAL "\033[0m"

VerilatedVcdC *pTrace = NULL;
Vdcpu *pCore;

uint64_t tickcount = 0;
uint64_t ts = 1000;

void opentrace(const char *vcdname) {
    if (!pTrace) {
        pTrace = new VerilatedVcdC;
        pCore->trace(pTrace, 99);
        pTrace->open(vcdname);
    }
}

void tick() {
    pCore->i_clk = 0;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
    tickcount += ts / 2;
    pCore->i_clk = 1;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
    tickcount += ts / 2;
}

void reset() {
    pCore->i_reset = 1;
    pCore->i_dat = 0;
    pCore->i_ack = 0;
    tick();
    pCore->i_reset = 0;
}

uint16_t mem[0x10000];

int handle(Vdcpu *pCore) {
    if (pCore->o_cs) {
        pCore->i_dat = mem[pCore->o_addr];
        if (pCore->o_we) {
            mem[pCore->o_addr] = pCore->o_dat;
            printf("write [%04x] <- %04x\n", pCore->o_addr, pCore->o_dat);
        }
        // if (Verilated::gotFinish()) {
        if ((pCore->i_dat == 0xffff) && (pCore->dcpu->r_state == 0)) {
            return 1;
        }
    } else {
        pCore->i_dat = 0;
    }
    pCore->i_ack = pCore->o_cs;
    return 0;
}

typedef struct {
    int r[16];
    int interrupt_cycle;
    int mem[0x10000];
} test_t;

void printregs(int count, test_t *t) {
    printf("%d: pc:%04x ", count, pCore->dcpu->R[REG_PC]);
    for ( int i = 0; i<15; i++) {
        if (t->r[i]>=0)
            printf("r%d:%04x ", i, pCore->dcpu->R[i]);
    }
    printf("\n");
}

bool test(const uint16_t *prog, int len, test_t *t) {
    memset(mem, 0, sizeof(mem));
    memcpy(mem, prog, len*sizeof(*prog));
    reset();
    int i = 0;
    while(i < 50) {
        if(!pCore->dcpu->r_state) {
            printregs(i, t);
            i++;
        }
        if(handle(pCore)) {
            break;
        }
        pCore->i_int = (t->interrupt_cycle == i);
        tick();
    }

    bool total = true;
    bool res;

    for ( i = 0; i<16; i++) {
        if (t->r[i] >= 0) {
            total &= res = (t->r[i] == pCore->dcpu->R[i]);
            if (!res)
                printf("%sR[%d]:%s%04x (%d)%s ", NORMAL, i, RED, pCore->dcpu->R[i], pCore->dcpu->R[i], NORMAL);
        }
    }

    for ( i = 0; i<ARRSIZE(mem); i++) {
        if (t->mem[i] >= 0 && t->mem[i] != mem[i]) {
            printf("%sBad memory value at address %04x: %04x%s\n", RED, i, mem[i], NORMAL);
            total = false;
        }
    }

    if (total) {
        printf("%sok%s.\n", GREEN, NORMAL);
    } else {
        printf("\n%sFAIL%s.\n", RED, NORMAL);
    }
    printf("\n");
    return total;
}

test_t new_test(void) {
    test_t t;
    for (int i = 0; i<16; t.r[i++] = -1);
    for (int i = 0; i<ARRSIZE(t.mem); t.mem[i++] = -1);
    t.interrupt_cycle = -1;
    return t;
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vdcpu();

    if (argc > 1) {
        if( string(argv[1]) == "-t" ) {
            printf("Trace enabled\n");
            opentrace("trace.vcd");
        }
    }

    int count = 0;    

    {
        printf("Test %d: LD r0, 0x123 ; LDH r0,0x34\n", count++);
        uint16_t prog[] = { LDIMML(0,0x123), LDIMMH(0,0x34), 0xffff, 0 };
        test_t t = new_test();
        t.r[0] = 0x3423; t.r[REG_PC] = 2;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: LD r4, (r0+5)\n", count++);
        uint16_t prog[] = { LDIMML(0,3), LD(4,0,2), 0xffff, 0, 0, 0xabcd, 0 };
        test_t t = new_test();
        t.r[0] = 3; t.r[4] = 0xabcd; t.r[REG_PC] = 2;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }
    
    {
        printf("Test %d: ST (r3+2), r7\n", count++);
        uint16_t prog[] = {
            LDIMML(3,2),      // r3 = 2
            LDIMML(7,0xfff),  // r7 = 0x2ff
            LDIMMH(7,0xff),   // r7 = 0xffff
            ST(3,2,7),        // st (r3+2), r7
            0,
            0xffff };
        test_t t = new_test();
        t.r[3] = 2; t.r[7] = 0xffff; t.r[REG_PC] = 4; t.mem[4] = 0xffff;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJ #2\n", count++);
        uint16_t prog[] = {
            RJP(NONE,2),    // RJP #2
            0xffff,
            LDIMML(0,0x19d),
            0xffff };
        test_t t = new_test();
        t.r[0] = 0x19d; t.r[REG_PC] = 3;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJ.Z #2\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(13, 0),  // clear zero flag
            /*1*/ RJP(ZERO,4),    // RJ.Z #4
            /*2*/ LDIMML(0, 0x123), // LD r0, 0x123
            /*3*/ LDIMML(13, 1),  // set zero flag
            /*4*/ RJP(ZERO,2),    // RJ.Z #2
            /*5*/ 0xffff,
            /*6*/ LDIMML(1,0x555),
            /*7*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x123&MASK(10); t.r[1] = 0x555 & MASK(10); t.r[13] = 1; t.r[REG_PC] = 7;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJ.NZ #2\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(13, 1),  // set zero flag
            /*1*/ RJP(NONZERO,4),    // RJ.NZ #4
            /*2*/ LDIMML(0, 0x123), // LD r0, 0x123
            /*3*/ LDIMML(13, 0),  // clear zero flag
            /*4*/ RJP(NONZERO,2),    // RJ.NZ #2
            /*5*/ 0xffff,
            /*6*/ LDIMML(1,0x555),
            /*7*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x123&MASK(10); t.r[1] = 0x555 & MASK(10); t.r[13] = 0; t.r[REG_PC] = 7;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJ.C #2\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(13, 0),  // clear carry flag
            /*1*/ RJP(CARRY,4),    // RJ.C #4
            /*2*/ LDIMML(0, 0x123), // LD r0, 0x123
            /*3*/ LDIMML(13, 2),  // set carry flag
            /*4*/ RJP(CARRY,2),    // RJC #2
            /*5*/ 0xffff,
            /*6*/ LDIMML(1,0x555),
            /*7*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x123&MASK(10); t.r[1] = 0x555 & MASK(10); t.r[13] = 2; t.r[REG_PC] = 7;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJ.NC #2\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(13, 2),  // set carry flag
            /*1*/ RJP(NOCARRY,4),    // RJ.NC #4
            /*2*/ LDIMML(0, 0x123), // LD r0, 0x123
            /*3*/ LDIMML(13, 0),  // clear carry flag
            /*4*/ RJP(NOCARRY,2),    // RJ.NC #2
            /*5*/ 0xffff,
            /*6*/ LDIMML(1,0x555),
            /*7*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x123&MASK(10); t.r[1] = 0x555 & MASK(10); t.r[13] = 0; t.r[REG_PC] = 7;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJ -2\n", count++);
        uint16_t prog[] = {
            /*0*/ RJP(NONE,3),    // RJP +3
            /*1*/ LDIMML(0,0x2af),
            /*2*/ 0xffff,
            /*3*/ LDIMML(1,0x19d),
            /*4*/ RJP(NONE,-3),   // RJP -3
            /*5*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x2af & MASK(10); t.r[1] = 0x19d & MASK(10); t.r[REG_PC] = 2;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: JP r10\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(10, 4),
            /*1*/ JMP(10, NONE),
            /*2*/ 0xffff,
            /*3*/ LDIMML(10, 0x82),
            /*4*/ LDIMML(12, 0xaf),
            /*5*/ 0xffff };
        test_t t = new_test();
        t.r[10] = 4; t.r[12] = 0xaf; t.r[REG_PC] = 5;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: BR r0\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(0, 5),  // r0 = 5
            /*1*/ LDIMML(14, 0), // SP = 0
            /*2*/ BR(0, NONE),  // BR r0
            /*3*/ LDIMML(3, 0x8c), // r3 = 0x8c
            /*4*/ 0xffff,
            /*5*/ LDIMML(3, 0xc1), // r3 = 0xc1
            /*6*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 5; t.r[14] = 1; t.r[3] = 0xc1; t.r[REG_PC] = 6; t.mem[0] = 3;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ret\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(0, 5),  // r0 = 5
            /*1*/ LDIMML(14, 0), // SP = 0
            /*2*/ BR(0, NONE),   // BR r0
            /*3*/ LDIMML(3, 0x8c), // r3 = 0x8c
            /*4*/ 0xffff,
            /*5*/ LDIMML(4, 0xc1), // r3 = 0xc1
            /*6*/ RET,
            /*7*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 5; t.r[14] = 1; t.r[3] = 0x8c; t.r[4] = 0xc1; t.r[14] = 0; t.r[REG_PC] = 4; t.mem[0] = 3;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: push pop\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(0, 0xff),
            /*1*/ LDIMML(1, 0xee),
            /*2*/ LDIMML(14, 0x10),
            /*3*/ PUSH(0),
            /*4*/ PUSH(1),
            /*5*/ POP(0),
            /*6*/ POP(1),
            /*7*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0xee; t.r[1] = 0xff; t.r[14] = 0x10; t.r[REG_PC] = 7;
        t.mem[0x10] = 0xff; t.mem[0x11] = 0xee;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    // ALU tests
    {
        printf("Test %d: ld r0, r1\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(0, 0xff),
            /*1*/ LDIMML(1, 0xee),
            /*2*/ ALU(0,1,COPY),
            /*3*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0xee; t.r[1] = 0xee; t.r[REG_PC] = 3;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: add r0, r1, no resulting carry flag\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0xff),
            /*2*/ LDIMML(1, 0xee),
            /*3*/ ALU(0,1,ADD),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0xee + 0xff; t.r[1] = 0xee; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: add r0, r1, resulting carry+zero flag\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0x2ff),
            /*2*/ LDIMMH(0, 0xff),
            /*3*/ LDIMML(1, 0x1),
            /*4*/ ALU(0,1,ADD),
            /*5*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0; t.r[1] = 1; t.r[REG_ST] = 3; t.r[REG_PC] = 5;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: add r0, r1, using carry flag\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 2),
            /*1*/ LDIMML(0, 0x2),
            /*2*/ LDIMML(1, 0x1),
            /*3*/ ALU(0,1,ADD),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 4; t.r[1] = 1; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: sub r0, r1, no resulting carry flag\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0xff),
            /*2*/ LDIMML(1, 0xee),
            /*3*/ ALU(0,1,SUB),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0xff - 0xee; t.r[1] = 0xee; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: sub r0, r1, with resulting carry flag\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0x1),
            /*2*/ LDIMML(1, 0x2),
            /*3*/ ALU(0,1,SUB),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = uint16_t(1-2); t.r[1] = 2; t.r[REG_ST] = 2; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: sub r0, r1, using carry flag\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 2),
            /*1*/ LDIMML(0, 10),
            /*2*/ LDIMML(1, 1),
            /*3*/ ALU(0,1,SUB),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 8; t.r[1] = 1; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: and r0, r1\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0xff),
            /*2*/ LDIMML(1, 0x17),
            /*3*/ ALU(0,1,AND),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x17; t.r[1] = 0x17; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: or r0, r1\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0x100),
            /*2*/ LDIMML(1, 0xfa),
            /*3*/ ALU(0,1,OR),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x1fa; t.r[1] = 0xfa; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: xor r0, r1\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0xf0),
            /*2*/ LDIMML(1, 0x0f),
            /*3*/ ALU(0,1,XOR),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0xff; t.r[1] = 0x0f; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: CMP r0, r1\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(0, 0x1),
            /*1*/ LDIMML(1, 0x1),
            /*2*/ LDIMML(REG_ST, 0), // clear st
            /*3*/ ALU(0,1,CMP),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 1; t.r[1] = 1; t.r[REG_ST] = 1; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: CMP r0, r1\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(0, 0x15),
            /*1*/ LDIMML(1, 0x1),
            /*2*/ LDIMML(REG_ST, 0), // clear st
            /*3*/ ALU(0,1,CMP),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x15; t.r[1] = 1; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: lsr r0\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0x11),
            /*2*/ ALU(0,0,LSR),
            /*3*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x8; t.r[REG_ST] = 2; t.r[REG_PC] = 3;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: lsl r0\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0x01),
            /*2*/ LDIMMH(0, 0x80),
            /*3*/ ALU(0,0,LSL),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x2; t.r[REG_ST] = 2; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: lsr.w r0\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0x33),
            /*2*/ LDIMMH(0, 0xad),
            /*3*/ ALU(0,0,WLSR),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0xad; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: lsl.w r0\n", count++);
        uint16_t prog[] = {
            /*0*/ LDIMML(REG_ST, 0),
            /*1*/ LDIMML(0, 0x33),
            /*2*/ LDIMMH(0, 0xad),
            /*3*/ ALU(0,0,WLSL),
            /*4*/ 0xffff };
        test_t t = new_test();
        t.r[0] = 0x3300; t.r[REG_ST] = 0; t.r[REG_PC] = 4;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: Interrupt\n", count++);
        uint16_t prog[0x10000];
        prog[0x0000] = LDIMML(REG_SP, 0x04);
        prog[0x0001] = LDIMML(0, 0x01);
        prog[0x0002] = JMP(0, NONE);
        prog[0x0003] = 0xffff;
        prog[0xFFF0] = LDIMML(1, 0x7c);
        prog[0xFFF1] = 0xffff;
        test_t t = new_test();
        t.r[0] = 0x01; t.r[1] = 0x7c; t.r[REG_SP] = 0x05; t.r[REG_PC] = 0xfff1;
        t.interrupt_cycle = 5;
        t.mem[4] = t.interrupt_cycle / 2;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RETI\n", count++);
        uint16_t prog[0x10000];
        prog[0x0000] = LDIMML(REG_SP, 0x010);
        prog[0x0001] = LDIMML(0, 0x01);
        prog[0x0002] = LDIMML(1, 0x02);
        prog[0x0003] = LDIMML(2, 0x03);
        prog[0x0004] = LDIMML(3, 0x04);
        prog[0x0005] = 0xffff;
        prog[0xFFF0] = LDIMML(1, 0x7c);
        prog[0xFFF1] = LDIMML(2, 0x8d);
        prog[0xFFF2] = LDIMML(3, 0x9e);
        prog[0xFFF3] = RETI;
        prog[0xFFF4] = 0xffff;
        test_t t = new_test();
        t.r[0] = 0x01;
        t.r[1] = 0x7c;
        t.r[2] = 0x8d;
        t.r[3] = 0x04;
        t.r[REG_SP] = 0x10;
        t.r[REG_PC] = 0x0005;
        t.interrupt_cycle = 5;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

done:
    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}