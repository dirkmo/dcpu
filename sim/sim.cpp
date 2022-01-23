#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vtop.h"
#include "Vtop_top.h"
#include "Vtop_dcpu.h"
#include "dcpu.h"
#include <vector>

using namespace std;

#define ARRSIZE(a) (sizeof(a) / sizeof(a[0]))
#define RED "\033[31m"
#define GREEN "\033[32m"
#define NORMAL "\033[0m"

VerilatedVcdC *pTrace = NULL;
Vtop *pCore;

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

int handle(Vtop *pCore) {
    if (pCore->o_cs) {
        pCore->i_dat = mem[pCore->o_addr];
        if (pCore->o_we) {
            mem[pCore->o_addr] = pCore->o_dat;
            printf("write [%04x] <- %04x\n", pCore->o_addr, pCore->o_dat);
        }
        if (pCore->i_dat == 0xffff && (pCore->top->cpu0->r_state == 0)) {
            return 1;
        }
    } else {
        pCore->i_dat = 0;
    }
    pCore->i_ack = pCore->o_cs;
    return 0;
}

int program_load(const char *fn, vector<uint16_t>& prog) {
    FILE *f = fopen(fn, "rb");
    if (!f) {
        fprintf(stderr, "Failed to open file\n");
        return -1;
    }
    fseek(f, 0, SEEK_END);
    size_t size = ftell(f);
    if (size % 2) {
        fprintf(stderr, "Odd program size!\n");
        return -2;
    }
    prog.resize(size/2);
    fseek(f, 0, SEEK_SET);
    for (int i = 0; i < size/2; i++) {
        uint16_t word;
        fread(&word, sizeof(uint16_t), 1, f);
        prog[i] = (word >> 8) | ((word & 0xff) << 8);
    }
    fclose(f);
    return 0;
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vtop();

    opentrace("trace.vcd");

    if (argc < 2) {
        fprintf(stderr, "Missing file name\n");
        return -1;
    }
    
    vector<uint16_t> prog;
    if (program_load(argv[1], prog)) {
        fprintf(stderr, "ERROR: Failed to load file '%s'\n", argv[1]);
        return -2;
    }

    for (auto& v: prog) {
        printf("%04x ", v);
    }
    printf("\n");
    reset();
    int step = 0;
    while(step < 4) {
        if(handle(pCore)) {
            break;
        }
        tick();
        printf("%d: pc: %04x, dsp: %x, T: %04x, N: %04x\n", step, pCore->top->cpu0->r_pc, pCore->top->cpu0->r_dsp, pCore->top->cpu0->T, pCore->top->cpu0->N);
        step++;
    }


    pCore->final();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }
    return 0;
}