#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vdcpu.h"
#include "dcpu.h"

using namespace std;

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
    tickcount += ts;
    if ((tickcount % (ts)) == 0) {
        pCore->i_clk = !pCore->i_clk;
    }
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
}

void reset() {
    pCore->i_reset = 1;
    for ( int i = 0; i < 20; i++) {
        tick();
    }
    pCore->i_reset = 0;
}

uint16_t mem[0x10000];

void handle(Vdcpu *pCore) {
    if (pCore->o_cs) {
        pCore->i_dat = mem[pCore->o_addr];
        if (pCore->o_we) {
            mem[pCore->o_addr] = pCore->o_dat;
        }
    } else {
        pCore->i_dat = 0;
    }
    pCore->i_ack = pCore->o_cs;
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

    uint16_t prog[] = {
        0x0001, 0x0002, ALU(ADD) | DST(DST_T),
    };
    memset(mem, 0, sizeof(prog));
    memcpy(mem, prog, sizeof(prog));

    reset();

    int old_clk = -1;
    while(1) {
        tick();
        handle(pCore);
        old_clk = pCore->i_clk;

        if (tickcount > ts * 1000) {
            printf("Ende\n");
            break;
        }
    }

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}