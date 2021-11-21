#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vdcpu.h"
#include "Vdcpu_dcpu.h"
#include "dcpu.h"

using namespace std;

#define ARRSIZE(a) (sizeof(a) / sizeof(a[0]))

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
    pCore->i_clk = 1;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
    tickcount += ts / 2;
    pCore->i_clk = 0;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
    tickcount += ts / 2;
}

void reset() {
    pCore->i_reset = 1;
    tick();
    tick();
    pCore->i_reset = 0;
}

uint16_t mem[0x10000];

int handle(Vdcpu *pCore) {
    if (pCore->o_cs) {
        pCore->i_dat = mem[pCore->o_addr];
        if (pCore->o_we) {
            mem[pCore->o_addr] = pCore->o_dat;
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
    memset(mem, 0, sizeof(prog));
    memcpy(mem, prog, len);
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
    bool res = true;
    if (t->pc >= 0) 
        res &= (t->pc == pCore->dcpu->r_pc);
    if (t->t >= 0) 
        res &= (t->t == pCore->dcpu->T);
    if (t->n >= 0) 
        res &= (t->n == pCore->dcpu->N);
    if (t->r >= 0) 
        res &= (t->r == pCore->dcpu->R);
    if (t->dsp >= 0) 
        res &= (t->dsp == pCore->dcpu->r_dsp);
    if (t->rsp >= 0) 
        res &= (t->rsp == pCore->dcpu->r_rsp);
    
    if (res) {
        printf("ok.\n");
    } else {
        printf("FAIL.\n");
    }
    return res;
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

    // uint16_t prog[] = {
    //     0x0001, 0x0002, ALU(ADD) | DST(DST_T),
    //     0xffff
    // };
    // memset(mem, 0, sizeof(prog));
    // memcpy(mem, prog, sizeof(prog));

    // reset();

    // int old_clk = -1;
    // while(!Verilated::gotFinish()) {
    //     handle(pCore);
    //     tick();

    //     if (tickcount > ts * 100) {
    //         printf("Ende\n");
    //         break;
    //     }
    // }
    int testcount = 0;
    {
        uint16_t prog[] = { 0, 0xffff};
        test_t t = { .pc = 2, .dsp = 1, .rsp = -1, .t = -1, .n = -1, .r = -1 };
        test(testcount++, prog, ARRSIZE(prog), &t);
    }

    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}