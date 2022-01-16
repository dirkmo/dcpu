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
    printf("%d: pc:%04x ", count, pCore->dcpu->r_pc);
    printf("T:%04x ", pCore->dcpu->T);
    printf("N:%04x ", pCore->dcpu->N);
    printf("R:%04x ", pCore->dcpu->R);
    printf("dsp:%d ", pCore->dcpu->r_dsp);
    printf("rsp:%d ", pCore->dcpu->r_rsp);
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
    printregs(i, t);

    bool total = true;
    bool res;
    Vdcpu_dcpu *d = pCore->dcpu;
    total &= checkval(t->pc, d->r_pc, "PC");
    total &= checkval(t->t, d->r_dstack[d->r_dsp], "T");
    total &= checkval(t->n, d->r_dstack[d->r_dsp-1], "N");
    total &= checkval(t->r, d->r_rstack[d->r_rsp], "R");
    total &= checkval(t->dsp, d->r_dsp, "dsp");
    total &= checkval(t->rsp, d->r_rsp, "rsp");
    printf("\n");
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
        t.t = 0x2; t.n = 0; t.r = -1; t.pc = 4; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJZ, branch not taken\n", count++);
        uint16_t prog[] = { LIT_L(0xf), RJP(COND_RJP_ZERO, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = 0x1; t.r = -1; t.pc = 4; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJNZ, branch taken\n", count++);
        uint16_t prog[] = { LIT_L(0xf), RJP(COND_RJP_NONZERO, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = 0xf; t.r = -1; t.pc = 4; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJNZ, branch not taken\n", count++);
        uint16_t prog[] = { LIT_L(0x0), RJP(COND_RJP_NONZERO, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = 0x1; t.r = -1; t.pc = 4; t.dsp = 2; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJN, branch taken\n", count++);
        uint16_t prog[] = { LIT_L(0x00), LIT_H(0x80), RJP(COND_RJP_NEG, 2), LIT_L(0x3), LIT_L(0x4), 0xffff };
        test_t t = new_test();
        t.t = 0x4; t.n = 0x8000; t.r = -1; t.pc = 5; t.dsp = 1; t.rsp = -1;
        if (!test(prog, ARRSIZE(prog), &t)) goto done;
    }

    {
        printf("Test %d: RJNN, branch not taken\n", count++);
        uint16_t prog[] = { LIT_L(0x0), RJP(COND_RJP_NEG, 2), LIT_L(0x1), LIT_L(0x2), 0xffff };
        test_t t = new_test();
        t.t = 0x2; t.n = 0x1; t.r = -1; t.pc = 4; t.dsp = 2; t.rsp = -1;
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