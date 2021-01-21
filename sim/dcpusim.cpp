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

// void busoperation() {
//     uint16_t addr = pCore->o_addr & 0xfffe;
//     if (addr < 0xF000) {
//         if (pCore->o_rw) {
//             pCore->i_dat = *(uint16_t*)&mem[addr];
//         } else {
//             printf("write: [%04X] <- %04X", addr, pCore->o_dat);
//             pCore->i_dat = 0;
//             *(uint16_t*)&mem[addr] = pCore->o_dat;
//         }
//     } else {
//         //
//     }
// }

void setprogram(uint16_t byteaddr, const std::vector<uint8_t>& prog) {
    for (uint8_t op: prog) {
        uint16_t val = pCore->top__DOT__ram0__DOT__mem[byteaddr/2];
        // printf("op: %02X ",op);
        if (byteaddr & 1 ) {
            val |= op << 8;
        } else {
            val = op;
        }
        pCore->top__DOT__ram0__DOT__mem[byteaddr/2] = val;
        byteaddr++;
    }
    // printf("\n");
    // for (int i = 0x100; i < 0x110; i++) {
    //     printf("%02X ", ((uint8_t*)pCore->top__DOT__ram0__DOT__mem)[i] );
    // }
    // printf("\n");
}

void printregs() {
    printf("\npc:%04X t:%04X n:%04X a:%04X ", pCore->top__DOT__cpu__DOT__pc, pCore->top__DOT__cpu__DOT__t, pCore->top__DOT__cpu__DOT__n, pCore->top__DOT__cpu__DOT__a);
    printf("dsp:%04X asp:%04X usp:%04X\n", pCore->top__DOT__cpu__DOT__dsp, pCore->top__DOT__cpu__DOT__asp, pCore->top__DOT__cpu__DOT__usp);
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vdcpu();
    opentrace("trace.vcd");

    std::vector<uint8_t> program = { 0x14, 0x15, OP_PUSHI, 0x1, OP_PUSHI, OP_ADD, 0x5, OP_STOREABS, OP_END };
    setprogram(0x100, program);

    reset();

    while(tickcount < 50 && !Verilated::gotFinish()) {
        if( pCore->i_clk == 0) {
            printregs();
        }
        // busoperation();
        tick();
    }

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}