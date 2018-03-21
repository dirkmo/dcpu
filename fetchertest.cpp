#include "Vfetcher.h"
#include "verilated.h"
#include "testbench.h"
#include <stdint.h>
#include <stdio.h>

class fetchertest : public TESTBENCH<Vfetcher> {
public:
    void i_pc(uint32_t pc) { m_core->i_pc = pc; }
    uint32_t o_pc() { return m_core->o_pc; }
    void i_fetch() {
        m_core->i_fetch = 1;
        tick();
        m_core->i_fetch = 0;
    }
};


int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);

    fetchertest *bench = new fetchertest();
    bench->opentrace("trace.vcd");
     
    bench->reset();
    bench->i_pc(0);
    bench->tick();

    bench->i_fetch();

    while( !bench->done() && bench->m_tickcount < 100000 ) {
        bench->tick();
    }
    
    return 0;
}
