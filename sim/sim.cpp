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
} test_t;

bool test(const uint16_t *prog, int len, test_t *t) {
    memset(mem, 0, sizeof(mem));
    memcpy(mem, prog, len*sizeof(*prog));
    reset();
    int i = 0;
    while(i < 50) {
        if(handle(pCore)) {
            break;
        }
        tick();
        printf("%d: pc:%04x ", i, pCore->dcpu->R[15]);
        for ( int i = 0; i<15; i++) {
            if (t->r[i]>=0)
                printf("r%c:%04x ", '0'+i, pCore->dcpu->R[i]);
        }
        printf("\n");
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
        t.r[0] = 0x3423; t.r[15] = 2;
        if (!test(prog, sizeof(prog), &t)) goto done;
    }

    {
        printf("Test %d: LD r4, (r0+5)\n", count++);
        uint16_t prog[] = { LDIMML(0,3), LD(4,0,2), 0xffff, 0, 0, 0xabcd, 0 };
        test_t t = new_test();
        t.r[0] = 3; t.r[4] = 0xabcd; t.r[15] = 2;
        if (!test(prog, sizeof(prog), &t)) goto done;
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
        t.r[3] = 2; t.r[7] = 0xffff; t.r[15] = 4;
        if (!test(prog, sizeof(prog), &t)) goto done;
    }

done:
    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}