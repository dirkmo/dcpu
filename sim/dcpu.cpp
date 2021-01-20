#include <stdint.h>
#include <stdio.h>
#include <verilated_vcd_c.h>
#include "Vdcpu.h"
#include "verilated.h"

VerilatedVcdC *pTrace;
Vdcpu *pCore;
uint64_t tickcount;

void opentrace(const char *vcdname) {
    if (!pTrace) {
        pTrace = new VerilatedVcdC;
        pCore->trace(pTrace, 99);
        pTrace->open(vcdname);
    }
}

void tick() {
    tickcount++;

    pCore->i_clk = 0;
    pCore->eval();
    
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(10*tickcount-2));

    pCore->i_clk = 1;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(10*tickcount));

    pCore->i_clk = 0;
    pCore->eval();
    if (pTrace) {
        pTrace->dump(static_cast<vluint64_t>(10*tickcount+5));
        pTrace->flush();
    }
}

void reset() {
    pCore->i_reset = 1;
    tick();
    pCore->i_reset = 0;
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vdcpu();
    opentrace("trace.vcd");

    reset();

    while(tickcount < 100) {
        tick();
    }


    return 0;
}