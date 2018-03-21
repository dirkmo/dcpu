#include "Vregfile.h"
#include "verilated.h"
#include "testbench.h"
#include <stdint.h>
#include <stdio.h>

class regtest : public TESTBENCH<Vregfile> {

public:
    void sel_a( uint8_t reg ) {
        m_core->i_sel_a = reg;
    }
    void sel_b( uint8_t reg ) {
        m_core->i_sel_b = reg;
    }
    void wr_b(bool en) {
        m_core->i_wr_b = en;
    }
    uint32_t rega() {
        return m_core->o_reg_a;
    }
    uint32_t regb() {
        return m_core->o_reg_b;
    }
    void set_reg_b(uint32_t val) {
        m_core->i_reg_b = val;
        tick();
        wr_b(true);
        tick();
        wr_b(false);
    }
};


int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);
    regtest *bench = new regtest();
 
    bench->sel_a(0);
    bench->sel_b(1);
    bench->wr_b(false);
    bench->reset();
    printf("A: %08X, B: %08X\n", bench->m_core->o_reg_a, bench->m_core->o_reg_b);
    bench->set_reg_b(0x1A);
    printf("A: %08X, B: %08X\n", bench->m_core->o_reg_a, bench->m_core->o_reg_b);



    // while( !bench->done() ) {
    //     bench->tick();
    // }
    
    return 0;
}
