#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vdcpu.h"
#include "Vdcpu_dcpu.h"
#include "dcpu-opcodes.h"

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

void tick_() {
    pCore->i_clk = 0;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
    tickcount += ts / 2;
    pCore->i_clk = 1;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
    tickcount += ts / 2;
}

void tick() {
    pCore->i_clk = !pCore->i_clk;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
    tickcount += ts / 2;
}


void reset() {
    pCore->i_reset = 1;
    pCore->i_dat = 0;
    pCore->i_ack = 0;
    tick();
    tick();
    pCore->i_reset = 0;
}

uint16_t mem[0x10000];

int handle(Vdcpu *pCore) {
    // if (Verilated::gotFinish()) {
    if ((pCore->dcpu->r_op == 0xffff) /*&& (pCore->dcpu->r_state == 1)*/) {
        return 1;
    }
    if (pCore->o_cs) {
        pCore->i_dat = mem[pCore->o_addr];
        if (pCore->o_we) {
            mem[pCore->o_addr] = pCore->o_dat;
            printf("write [%04x] <- %04x\n", pCore->o_addr, pCore->o_dat);
        }
    } else {
        pCore->i_dat = 0;
    }
    pCore->i_ack = pCore->o_cs;

    return 0;
}

typedef struct {
    int pc;
    int t, n, r;
    int dsp, rsp;
    int interrupt_cycle;
    int mem[0x10000];
} test_t;

void printregs(int count, test_t *t) {
    Vdcpu_dcpu *d = pCore->dcpu;
    printf("%d: pc:%04x ", count, d->r_pc);
    printf("T:%04x ", d->r_dstack[d->r_dsp]);
    printf("N:%04x ", d->r_dstack[d->r_dsp-1]);
    printf("R:%04x ", d->r_rstack[d->r_rsp]);
    printf("dsp:%d ", d->r_dsp);
    printf("rsp:%d ", d->r_rsp);
    printf("\n");
}

bool checkval(int gold, int v, const char *sR) {
    if (gold != -1 && (gold != v)) {
        printf("%s%s%s %04x (%04x)%s ", NORMAL, sR, RED, v, gold, NORMAL);
        return false;
    }
    return true;
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
        pCore->i_irq = (t->interrupt_cycle == i);
        tick();
    }

    bool total = true;
    bool res;
    Vdcpu_dcpu *d = pCore->dcpu;
    total &= checkval(t->pc, d->r_pc, "PC");
    total &= checkval(t->t, d->r_dstack[d->r_dsp], "T");
    total &= checkval(t->n, d->r_dstack[d->r_dsp-1], "N");
    total &= checkval(t->r, d->r_rstack[d->r_rsp], "R");
    total &= checkval(t->dsp, d->r_dsp, "dsp");
    total &= checkval(t->rsp, d->r_rsp, "rsp");
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
    t.pc = -1;
    t.t = -1;
    t.n = -1;
    t.r = -1;
    t.dsp = -1;
    t.rsp = -1;
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

    constexpr int DSS = (1 << pCore->dcpu->DSS);
    constexpr int RSS = (1 << pCore->dcpu->RSS);

    int count = 1;

    {
        printf("Test %d: LIT.L\n", count++);
        uint16_t prog[] = { LIT_L(0x123), LIT_L(0xa32), 0xffff, 0 };
        test_t t = new_test();
        t.t = 0xa32; t.n = 0x123; t.pc = 2; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: LIT.L, LIT.H\n", count++);
        uint16_t prog[] = { LIT_L(0x123), LIT_H(0x88), 0xffff, 0 };
        test_t t = new_test();
        t.t = 0x8823; t.n = -1; t.pc = 2; t.dsp = 0; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: CALL\n", count++);
        uint16_t prog[] = { CALL(2), 0xffff, LIT_L(0xabcd), 0xffff };
        test_t t = new_test();
        t.t = 0xabcd & MASK(13); t.n = -1; t.r = 1; t.pc = 3; t.dsp = 0; t.rsp = 0;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJP, pos offset\n", count++);
        uint16_t prog[] = { RJP(COND_RJP_NONE, 2), 0xffff, LIT_L(0xcd), 0xffff };
        test_t t = new_test();
        t.t = 0xcd; t.n = -1; t.r = -1; t.pc = 3; t.dsp = 0; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJP, neg offset\n", count++);
        uint16_t prog[] = { RJP(COND_RJP_NONE, 3), LIT_L(0xf5), 0xffff, LIT_L(0xf4), RJP(COND_RJP_NONE, -3), 0xffff };
        test_t t = new_test();
        t.t = 0xf5; t.n = 0xf4; t.r = -1; t.pc = 2; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJZ, branch taken\n", count++);
        uint16_t prog[] = { LIT_L(0x0), RJP(COND_RJP_ZERO, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = -1; t.r = -1; t.pc = 4; t.dsp = 0; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJZ, branch not taken\n", count++);
        uint16_t prog[] = { LIT_L(0xf), RJP(COND_RJP_ZERO, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = 0x1; t.r = -1; t.pc = 4; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJNZ, branch taken\n", count++);
        uint16_t prog[] = { LIT_L(0xf), RJP(COND_RJP_NONZERO, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = -1; t.r = -1; t.pc = 4; t.dsp = 0; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJNZ, branch not taken\n", count++);
        uint16_t prog[] = { LIT_L(0x0), RJP(COND_RJP_NONZERO, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = 0x1; t.r = -1; t.pc = 4; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJN, branch taken\n", count++);
        uint16_t prog[] = { LIT_L(0x00), LIT_H(0x80), RJP(COND_RJP_NEG, 2), LIT_L(0x3), LIT_L(0x4), 0xffff };
        test_t t = new_test();
        t.t = 0x4; t.n = -1; t.r = -1; t.pc = 5; t.dsp = 0; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJNN, branch not taken\n", count++);
        uint16_t prog[] = { LIT_L(0x0), RJP(COND_RJP_NEG, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = 0x1; t.r = -1; t.pc = 4; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: nop\n", count++);
        uint16_t prog[] = { ALU(ALU_T, 0, DST_T, 0, 0), 0xffff };
        test_t t = new_test();
        t.t = -1; t.n = -1; t.r = -1; t.pc = 1; t.dsp = DSS-1; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: rsp+\n", count++);
        uint16_t prog[] = { ALU(ALU_T, 0, DST_T, 0, RSP_I), 0xffff };
        test_t t = new_test();
        t.t = -1; t.n = -1; t.r = -1; t.pc = 1; t.dsp = DSS-1; t.rsp = 0;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: rsp+\n", count++);
        uint16_t prog[] = { ALU(ALU_T, 0, DST_T, 0, RSP_D), 0xffff };
        test_t t = new_test();
        t.t = -1; t.n = -1; t.r = -1; t.pc = 1; t.dsp = DSS-1; t.rsp = RSS-2;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: dsp+\n", count++);
        uint16_t prog[] = { ALU(ALU_T, 0, DST_T, DSP_I, 0), 0xffff };
        test_t t = new_test();
        t.t = -1; t.n = -1; t.r = -1; t.pc = 1; t.dsp = 0; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: dsp-\n", count++);
        uint16_t prog[] = { ALU(ALU_T, 0, DST_T, DSP_D, 0), 0xffff };
        test_t t = new_test();
        t.t = -1; t.n = -1; t.r = -1; t.pc = 1; t.dsp = DSS-2; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: return, no rsp-\n", count++);
        uint16_t prog[] = { CALL(3), LIT_L(2), 0xffff, ALU(ALU_T, RET, DST_T, 0, 0), LIT_L(1), 0xffff };
        test_t t = new_test();
        t.t = 2; t.n = -1; t.r = -1; t.pc = 2; t.dsp = 0; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: return, rsp-\n", count++);
        uint16_t prog[] = { CALL(3), LIT_L(2), 0xffff, ALU(ALU_T, RET, DST_T, 0, RSP_D), LIT_L(1), 0xffff };
        test_t t = new_test();
        t.t = 2; t.n = -1; t.r = -1; t.pc = 2; t.dsp = 0; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: T <- N, dsp+\n", count++);
        uint16_t prog[] = { LIT_L(1), LIT_L(2), ALU(ALU_N, 0, DST_T, DSP_I, 0), 0xffff };
        test_t t = new_test();
        t.t = 1; t.n = 2; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: T <- N, dsp-\n", count++);
        uint16_t prog[] = { LIT_L(1), LIT_L(2), LIT_L(3), ALU(ALU_N, 0, DST_T, DSP_D, 0), 0xffff };
        test_t t = new_test();
        t.t = 2; t.n = 1; t.r = -1; t.pc = 4; t.dsp = 1; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: T <- N\n", count++);
        uint16_t prog[] = { LIT_L(1), LIT_L(2), ALU(ALU_N, 0, DST_T, 0, 0), 0xffff };
        test_t t = new_test();
        t.t = 1; t.n = 1; t.r = -1; t.pc = 3; t.dsp = 1; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: R <- T\n", count++);
        uint16_t prog[] = { LIT_L(1), LIT_L(2), ALU(ALU_T, 0, DST_R, 0, 0), 0xffff };
        test_t t = new_test();
        t.t = 2; t.n = 1; t.r = 2; t.pc = 3; t.dsp = 1; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: R <- N, dsp-, rsp+\n", count++);
        uint16_t prog[] = { LIT_L(1), LIT_L(2), ALU(ALU_N, 0, DST_R, DSP_D, RSP_I), 0xffff };
        test_t t = new_test();
        t.t = 1; t.n = -1; t.r = 1; t.pc = 3; t.dsp = 0; t.rsp = 0;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: MEMT <- N\n", count++);
        uint16_t prog[] = { LIT_L(123), LIT_L(4), ALU(ALU_N, 0, DST_MEMT, 0, 0), 0xffff, 0 };
        test_t t = new_test();
        t.t = 4; t.n = 123; t.r = -1; t.pc = 3; t.dsp = 1; t.rsp = RSS-1;
        t.mem[4] = 123;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: N <- R\n", count++);
        uint16_t prog[] = {
            LIT_L(33),
            LIT_L(34),
            ALU(ALU_T, 0, DST_R, 0, RSP_I),
            0xffff
        };
        test_t t = new_test();
        t.t = 34; t.n = 33; t.r = 34; t.pc = 3; t.dsp = 1; t.rsp = 0;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: T <- MEMT\n", count++);
        uint16_t prog[] = {
            LIT_L(82),
            LIT_L(0),
            ALU(ALU_MEMT, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = LIT_L(82); t.n = 0; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }


    {
        printf("Test %d: ALU: ADD\n", count++);
        uint16_t prog[] = {
            LIT_L(1),
            LIT_L(10),
            ALU(ALU_ADD, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 11; t.n = 10; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: SUB\n", count++);
        uint16_t prog[] = {
            LIT_L(1),
            LIT_L(10),
            ALU(ALU_SUB, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = (uint16_t)(1-10); t.n = 10; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: AND\n", count++);
        uint16_t prog[] = {
            LIT_L(15),
            LIT_L(7),
            ALU(ALU_AND, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 7; t.n = 7; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: OR\n", count++);
        uint16_t prog[] = {
            LIT_L(0x0f),
            LIT_L(0x20),
            ALU(ALU_OR, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0x2f; t.n = 0x20; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: XOR\n", count++);
        uint16_t prog[] = {
            LIT_L(0xff),
            LIT_L(0x0f),
            ALU(ALU_XOR, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0xf0; t.n = 0x0f; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: LTS\n", count++);
        uint16_t prog[] = {
            LIT_L(1),
            LIT_L(2),
            ALU(ALU_LTS, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0xffff; t.n = 0x2; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: LTS\n", count++);
        uint16_t prog[] = {
            LIT_L(2),
            LIT_L(1),
            ALU(ALU_LTS, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0; t.n = 1; t.r = -1; t.pc = 3; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: LTS\n", count++);
        uint16_t prog[] = {
            LIT_L(0xff),
            LIT_H(0xff),
            LIT_L(1),
            ALU(ALU_LTS, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0xffff; t.n = 1; t.r = -1; t.pc = 4; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: LTS\n", count++);
        uint16_t prog[] = {
            LIT_L(1),
            LIT_L(0xff),
            LIT_H(0xff),
            ALU(ALU_LTS, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0; t.n = 0xffff; t.r = -1; t.pc = 4; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: LT\n", count++);
        uint16_t prog[] = {
            LIT_L(0xff),
            LIT_H(0xff),
            LIT_L(1),
            ALU(ALU_LT, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0; t.n = 1; t.r = -1; t.pc = 4; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: LT\n", count++);
        uint16_t prog[] = {
            LIT_L(0xff),
            LIT_H(0xff),
            LIT_L(1),
            ALU(ALU_LT, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0; t.n = 1; t.r = -1; t.pc = 4; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: SR\n", count++);
        uint16_t prog[] = {
            LIT_L(0xfe),
            LIT_H(0xfe),
            ALU(ALU_SR, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0xfefe>>1; t.n = 0xfefe; t.r = -1; t.pc = 3; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: SRW\n", count++);
        uint16_t prog[] = {
            LIT_L(0xfe),
            LIT_H(0xfe),
            ALU(ALU_SRW, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0xfefe>>8; t.n = 0xfefe; t.r = -1; t.pc = 3; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: SL\n", count++);
        uint16_t prog[] = {
            LIT_L(0xfe),
            LIT_H(0xfe),
            ALU(ALU_SL, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = (0xfefe<<1)&0xffff; t.n = 0xfefe; t.r = -1; t.pc = 3; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: SLW\n", count++);
        uint16_t prog[] = {
            LIT_L(0xfe),
            LIT_H(0xfe),
            ALU(ALU_SLW, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0xfe00; t.n = 0xfefe; t.r = -1; t.pc = 3; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: JZ, branch taken\n", count++);
        uint16_t prog[] = {
            LIT_L(0x4),
            LIT_L(0x0),
            ALU(ALU_JZ, 0, DST_PC, 0, RSP_RPC),
            0xffff,
            0xffff
        };
        test_t t = new_test();
        t.t = 0; t.n = 4; t.r = 3; t.pc = 4; t.dsp = 1; t.rsp = 0;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: JZ, branch not taken\n", count++);
        uint16_t prog[] = {
            LIT_L(0x4),
            LIT_L(0x1),
            ALU(ALU_JZ, 0, DST_PC, 0, RSP_RPC),
            0xffff,
            0xffff
        };
        test_t t = new_test();
        t.t = 1; t.n = 4; t.r = -1; t.pc = 3; t.dsp = 1; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: JNZ, branch taken\n", count++);
        uint16_t prog[] = {
            LIT_L(0x4),
            LIT_L(0x1),
            ALU(ALU_JNZ, 0, DST_PC, 0, RSP_RPC),
            0xffff,
            0xffff
        };
        test_t t = new_test();
        t.t = 1; t.n = 4; t.r = 3; t.pc = 4; t.dsp = 1; t.rsp = 0;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: JNZ, branch not taken\n", count++);
        uint16_t prog[] = {
            LIT_L(0x4),
            LIT_L(0x0),
            ALU(ALU_JNZ, 0, DST_PC, 0, RSP_RPC),
            0xffff,
            0xffff
        };
        test_t t = new_test();
        t.t = 0; t.n = 4; t.r = -1; t.pc = 3; t.dsp = 1; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: CARRY\n", count++);
        uint16_t prog[] = {
            LIT_L(0xff),
            LIT_H(0xff),
            LIT_L(0x3),
            ALU(ALU_ADD, 0, DST_T, DSP_I, 0),
            ALU(ALU_CARRY, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 1; t.n = 2; t.r = -1; t.pc = 5; t.dsp = 3; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: no CARRY\n", count++);
        uint16_t prog[] = {
            LIT_L(0xf0),
            LIT_H(0xff),
            LIT_L(0x3),
            ALU(ALU_ADD, 0, DST_T, DSP_I, 0),
            ALU(ALU_CARRY, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0; t.n = 0xfff3; t.r = -1; t.pc = 5; t.dsp = 3; t.rsp = RSS-1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: ALU: INV\n", count++);
        uint16_t prog[] = {
            LIT_L(0xff),
            ALU(ALU_INV, 0, DST_T, DSP_I, 0),
            0xffff
        };
        test_t t = new_test();
        t.t = 0xff00; t.n = 0xff; t.r = -1; t.pc = 2; t.dsp = 1; t.rsp = RSS-1;
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