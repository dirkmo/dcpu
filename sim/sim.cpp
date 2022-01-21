#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vtop.h"

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
        if (pCore->i_dat == 0xffff && (pCore->dcpu->r_state == 0)) {
            return 1;
        }
    } else {
        pCore->i_dat = 0;
    }
    pCore->i_ack = pCore->o_cs;
    return 0;
}

typedef struct {
    int pc;
    int dsp, rsp;
    int t, n, r;
} test_t;

bool test(int count, const uint16_t *prog, int len, test_t *t) {
    printf("Test %d\n", count);
    memcpy(mem, prog, len*sizeof(*prog));
    reset();
    int i = 0;
    while(1) {
        if(handle(pCore)) {
            break;
        }
        tick();
        printf("%d: pc: %04x, dsp: %x, T: %04x, N: %04x\n", i, pCore->dcpu->r_pc, pCore->dcpu->r_dsp, pCore->dcpu->T, pCore->dcpu->N);
        i++;
    }
    tick();
    // printf("%d: pc: %04x, dsp: %x, T: %04x, N: %04x\n", i, pCore->dcpu->r_pc, pCore->dcpu->r_dsp, pCore->dcpu->T, pCore->dcpu->N);
    printf("%d: ",i);
    bool total = true;
    bool res;
    if (t->pc >= 0) {
        total &= res = (t->pc == pCore->dcpu->r_pc);
    }
    printf("%spc: %04x%s, ", res ? NORMAL : RED, pCore->dcpu->r_pc, NORMAL);

    if (t->t >= 0) {
        total &= res = (t->t == pCore->dcpu->T);
    }
    printf("%sT: %04x%s, ", res ? NORMAL : RED, pCore->dcpu->T, NORMAL);

    if (t->n >= 0) {
        total = res &= (t->n == pCore->dcpu->N);
    }
    printf("%sN: %04x%s, ", res ? NORMAL : RED, pCore->dcpu->N, NORMAL);

    if (t->r >= 0) {
        total &= res = (t->r == pCore->dcpu->R);
    }
    printf("%sR: %04x%s, ", res ? NORMAL : RED, pCore->dcpu->R, NORMAL);

    if (t->dsp >= 0) {
        total &= res = (t->dsp == pCore->dcpu->r_dsp);
    }
    printf("%sdsp: %04x%s, ", res ? NORMAL : RED, pCore->dcpu->r_dsp, NORMAL);

    if (t->rsp >= 0) {
        total &= res = (t->rsp == pCore->dcpu->r_rsp);
    }
    printf("%srsp: %04x%s\n", res ? NORMAL : RED, pCore->dcpu->r_rsp, NORMAL);
    
    if (total) {
        printf("%sok%s.\n", GREEN, NORMAL);
    } else {
        printf("%sFAIL%s.\n", RED, NORMAL);
    }
    return total;
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

    int testcount = 0;
    bool res = true;

    {
        printf("push 2 literals\n");
        uint16_t prog[] = { 1, 2, 0xffff};
        test_t t = { .pc = 2, .dsp = 2, .rsp = -1, .t = 2, .n = 1, .r = -1 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }

    // DST tests
    {
        printf("push 2 literals, add -> T\n");
        uint16_t prog[] = { 1, 2, DST_T | ALU_ADD, 0xffff};
        test_t t = { .pc = 3, .dsp = 2, .rsp = 0, .t = 3, .n = 1, .r = -1 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }

    {
        printf("push 2 literals, add -> N\n");
        uint16_t prog[] = { 1, 2, DST_N | ALU_ADD, 0xffff};
        test_t t = { .pc = 3, .dsp = 2, .rsp = 0, .t = 2, .n = 3, .r = -1 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }

    {
        printf("push 2 literals, add -> R\n");
        uint16_t prog[] = { 1, 2, DST_R | ALU_ADD, 0xffff};
        test_t t = { .pc = 3, .dsp = 2, .rsp = 0, .t = 2, .n = 1, .r = 3 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }

    {
        printf("push 2 literals, add -> PC\n");
        uint16_t prog[] = { 3, 2, DST_PC | ALU_ADD, 0, 0, 0xffff};
        test_t t = { .pc = 5, .dsp = 2, .rsp = 0, .t = 2, .n = 3, .r = -1 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }

    {
        printf("push 2 literals, N -> [T]\n");
        uint16_t prog[] = { 0, DST_T | ALU_INV, 5, DST_MEMT | ALU_N, 13, 0, 0xffff};
        test_t t = { .pc = 5, .dsp = 3, .rsp = 0, .t = 13, .n = 5, .r = -1 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }
    
    {
        printf("push 2 literals, N -> [R]\n");
        uint16_t prog[] = { 0, DST_T | ALU_INV, 6, DST_R, DST_MEMR | ALU_N | DSP_D, 13, 0, 0, 0xffff};
        test_t t = { .pc = 6, .dsp = 3, .rsp = 0, .t = 13, .n = 0xffff, .r = 6 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }

    // dsp+/- tests
    {
        printf("push 2 literals, add dsp+\n");
        uint16_t prog[] = { 0x10, 0x20, DST_T | ALU_ADD | DSP_I, 0xffff};
        test_t t = { .pc = 3, .dsp = 3, .rsp = -1, .t = 0x30, .n = 0x20, .r = -1 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }

    {
        printf("push 2 literals, add dsp-\n");
        uint16_t prog[] = { 0x10, 0x20, DST_T | ALU_ADD | DSP_D, 0xffff};
        test_t t = { .pc = 3, .dsp = 1, .rsp = -1, .t = 0x30, .n = 0, .r = -1 };
        res &= test(testcount++, prog, ARRSIZE(prog), &t);
        if (!res) goto done;
    }

done:
    printf("Test %s\n", res ? GREEN "successful" NORMAL : RED "failed." NORMAL);

    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}