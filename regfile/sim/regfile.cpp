#include <stdint.h>
#include <stdio.h>
#include <verilated_vcd_c.h>
#include "Vregfile.h"
#include "verilated.h"

VerilatedVcdC *m_trace;
Vregfile *m_core;

void opentrace(const char *vcdname) {
    if (!m_trace) {
        m_trace = new VerilatedVcdC;
        m_core->trace(m_trace, 99);
        m_trace->open(vcdname);
    }
}

void reset() {
    m_core->i_reset = 1;
    tick();
    m_core->i_reset = 0;
}

void tick() {
    m_tickcount++;

    m_core->i_clk = 0;
    m_core->eval();
    
    if(m_trace) m_trace->dump(static_cast<vluint64_t>(10*m_tickcount-2));

    m_core->i_clk = 1;
    m_core->eval();
    if(m_trace) m_trace->dump(static_cast<vluint64_t>(10*m_tickcount));

    m_core->i_clk = 0;
    m_core->eval();
    if (m_trace) {
        m_trace->dump(static_cast<vluint64_t>(10*m_tickcount+5));
        m_trace->flush();
    }
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    m_core = new Vregfile();

    if (m_trace) {
        m_trace->close();
        m_trace = NULL;
    }
    return 0;
}
