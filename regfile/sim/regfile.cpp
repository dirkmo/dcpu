#include <stdint.h>
#include <stdio.h>
#include <verilated_vcd_c.h>
#include "Vregfile.h"
#include "verilated.h"

VerilatedVcdC *pTrace;
Vregfile *pCore;
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

void loadreg(int reg, uint8_t val) {
    pCore->i_dat = val;
    pCore->i_load_reg_sel = reg;
    pCore->i_load = 1;
    tick();
    pCore->i_load = 0;
    tick();
}

void alul(int reg) {
    pCore->i_alu_l_sel = reg;
    tick();
}

void alur(int reg) {
    pCore->i_alu_r_sel = reg;
    tick();
}

void addr(int reg) {
    pCore->i_addr_sel = reg;
    tick();
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vregfile();
    opentrace("trace.vcd");

    pCore->i_dat = 0;
    pCore->i_load_reg_sel = 0;
    pCore->i_load = 0;
    pCore->i_alu_l_sel = 0;
    pCore->i_alu_r_sel = 0;
    pCore->i_addr_sel = 0;
    tick();

    for( int i = 0; i < 12; i++ ) {
        loadreg(i,i*2);
        alur(i);
        assert(pCore->o_alu_r == i*2);
    }

    for( int i = 0; i < 12; i++ ) {
        loadreg(i, i);
        alul(i);
        assert(pCore->o_alu_l == i);
    }

    for( int i = 0; i < 12; i += 2 ) {
        addr(i/2);
        printf("%d: %d\n", (i | (i+1)), pCore->o_addr);
        assert( pCore->o_addr == (i | (i+1) << 8) );
    }

    if (pTrace) {
        pTrace->close();
        pTrace = NULL;
    }
    return 0;
}
