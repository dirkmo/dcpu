#include <stdint.h>
#include <stdio.h>
#include <verilated_vcd_c.h>
#include <vector>
#include "Vdcpu.h"
#include "verilated.h"
#include "../cmodel/dcpu.h"

VerilatedVcdC *pTrace;
Vdcpu *pCore;
uint64_t tickcount;

uint8_t mem[0x10000];

void opentrace(const char *vcdname) {
    if (!pTrace) {
        pTrace = new VerilatedVcdC;
        pCore->trace(pTrace, 99);
        pTrace->open(vcdname);
    }
}

void tick() {
    tickcount++;
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(10*tickcount-1));
    pCore->i_clk = !pCore->i_clk;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(10*tickcount));
}

void reset() {
    pCore->i_reset = 1;
    tick();
    pCore->i_reset = 0;
}

void busoperation() {
    uint16_t addr = pCore->o_addr & 0xfffe;
    if (addr < 0xF000) {
        if (pCore->o_rw) {
            pCore->i_dat = *(uint16_t*)&mem[addr];
        } else {
            printf("write: [%04X] <- %04X", addr, pCore->o_dat);
            pCore->i_dat = 0;
            *(uint16_t*)&mem[addr] = pCore->o_dat;
        }
    } else {
        //
    }
}

void setprogram(uint16_t addr, const std::vector<uint8_t>& prog) {
    for (uint8_t op: prog) {
        mem[addr++] = op;
    }
}

void printregs() {
    printf("\npc:%04X t:%04X n:%04X a:%04X ", pCore->dcpu__DOT__pc, pCore->dcpu__DOT__t, pCore->dcpu__DOT__n, pCore->dcpu__DOT__a);
    printf("dsp:%04X asp:%04X usp:%04X\n", pCore->dcpu__DOT__dsp, pCore->dcpu__DOT__asp, pCore->dcpu__DOT__usp);
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vdcpu();
    opentrace("trace.vcd");

    std::vector<uint8_t> program = { 0x14, 0x15, OP_PUSHI, 0x1, OP_PUSHI, OP_ADD, OP_END };
    setprogram(0x100, program);

    reset();

    while(tickcount < 200 && !Verilated::gotFinish()) {
        if( pCore->i_clk == 0) {
            printregs();
        }
        busoperation();
        tick();
    }

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}