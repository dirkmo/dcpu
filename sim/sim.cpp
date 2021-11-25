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
        // if (pCore->i_dat == 0xffff && (pCore->dcpu->r_state == 0)) {
        if (Verilated::gotFinish()) {
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
} test_t;

bool test(const uint16_t *prog, int len, test_t *t) {
    memcpy(mem, prog, len*sizeof(*prog));
    reset();
    int i = 0;
    while(i < 50) {
        if(handle(pCore)) {
            break;
        }
        tick();
        printf("%d: pc: %04x\n", i, pCore->dcpu->R[15]);
        i++;
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
    printf("\n");
    if (total) {
        printf("%sok%s.\n", GREEN, NORMAL);
    } else {
        printf("%sFAIL%s.\n", RED, NORMAL);
    }
    printf("\n");
    return total;
}

test_t new_test(void) {
    test_t t;
    for (int i = 0; i<16; t.r[i++] = -1);
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
        printf("Test %d: LD implicit\n", count++);
        uint16_t prog[] = { IMM(123) | DST(0), 0xffff };
        test_t t = new_test();
        t.r[0] = 123; t.r[15] = 2;
        test(prog, sizeof(prog), &t);
    }

    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}