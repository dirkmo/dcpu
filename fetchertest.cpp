#include "Vfetcher.h"
#include "verilated.h"
#include "testbench.h"
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

class wishbone {
public:
    uint32_t addr;
    bool cyc;
    bool we;
    bool ack;
    bool err;
    uint8_t stb;
    uint32_t dat;

    uint32_t mask() {
        return ((stb>>0)&1)*0xFF | ((stb>>1)&1)*0xFF00 |
            ((stb>>2)&1)*0xFF0000 | ((stb>>3)&1)*0xFF000000;
    }
};

class fetchertest : public TESTBENCH<Vfetcher> {
public:
    void i_pc(uint32_t pc) { m_core->i_pc = pc; }
    uint32_t o_pc() { return m_core->o_pc; }
    void i_fetch() {
        m_core->i_fetch = 1;
        tick();
        m_core->i_fetch = 0;
    }
    void updateBusState(wishbone *bus) {
        bus->addr = m_core->o_wb_addr;
        bus->we = m_core->o_wb_we;
        bus->cyc = m_core->o_wb_cyc;
        bus->stb = m_core->o_wb_stb;
        m_core->i_wb_err = bus->err;
        m_core->i_wb_ack = bus->ack;
        if( bus->stb>0) {
            if(bus->we) {
                bus->dat = m_core->o_wb_dat & bus->mask();
            } else {
                m_core->i_wb_dat = bus->dat & bus->mask();
            }
        }
    }
};

class memory {
public:
    uint32_t m_mem[1024];

    void task(bool sel, wishbone *bus) {
        if( sel ) {
            if( bus->cyc && bus->stb>0 ) {
                assert( bus->addr < sizeof(m_mem)/sizeof(m_mem[0]));
                if( bus->we ) {
                    m_mem[bus->addr] = bus->dat & bus->mask();
                } else {
                    bus->dat = m_mem[bus->addr] & bus->mask();
                }
                bus->ack = true;
            }
        }
    }
};


int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);

    fetchertest *tb = new fetchertest();
    tb->opentrace("trace.vcd");
    
    wishbone *bus = new wishbone;
    memory mem;
    mem.m_mem[0] = 0x1001;
    uint32_t pc = 2;

    tb->reset();
    tb->i_pc(pc);
    tb->tick();

    tb->i_fetch();

    while( !tb->done() && tb->m_tickcount < 5000 ) {
        tb->updateBusState(bus);
        bus->ack = false;
        mem.task( (bus->addr < 1024) && bus->cyc, bus);
        tb->tick();
    }
    
    delete bus;
    
    return 0;
}
