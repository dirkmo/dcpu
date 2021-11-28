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

uint16_t mem[0x10000];


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

void printregs(int count) {
    printf("%d: pc:%04x ", count, pCore->dcpu->R[REG_PC]);
    for ( int i = 0; i<15; i++) {
        if (i == 13) 
            printf("ST:%04x ", pCore->dcpu->R[i]);
        else if (i == 14)
            printf("SP:%04x ", pCore->dcpu->R[i]);
        else
            printf("r%d:%04x ", i, pCore->dcpu->R[i]);
    }
    printf("\n");
}


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

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vdcpu();

    if (argc > 1) {
        if( string(argv[1]) == "-t" ) {
            printf("Trace enabled\n");
            opentrace("trace.vcd");
        }
    }

    uint16_t prog[] = { 0, 0xffff };

    memset(mem, 0, sizeof(mem));
    memcpy(mem, prog, sizeof(prog));
    reset();

    int i = 0;
    while(i < 50) {
        if(!pCore->dcpu->r_state) {
            printregs(i);
            i++;
        }
        if(handle(pCore)) {
            break;
        }
        tick();
    }

    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}