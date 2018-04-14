#include "Vload.h"
#include "verilated.h"
#include "testbench.h"
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

class loadtest : public TESTBENCH<Vload> {
public:
    bool o_valid() {
        return m_core->o_valid;
    }

    bool o_error() {
        return m_core->o_error;
    }

    uint32_t o_data() {
        return m_core->o_data;
    }

    void load(uint32_t addr, uint8_t size) {
        m_core->i_addr = addr;
        m_core->i_load = size;
    }

    void updateBusState(Wishbone *bus) {
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


int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);

    loadtest *tb = new loadtest();
    tb->opentrace("trace.vcd");
    
    Wishbone *bus = new Wishbone;
    uint8_t big_endian_data[256];
    for( int i=0; i<sizeof(big_endian_data); i++) {
        big_endian_data[i] = i;
    }

    Memory mem(1024);
    mem.set(0, big_endian_data, sizeof(big_endian_data));
    
    uint32_t pc = 0;
    tickcounter = &tb->m_tickcount;

    tb->reset();
    tb->tick();

    tb->updateBusState(bus);
    bus->ack = false;
    mem.task( (bus->addr < 1024) && bus->cyc, bus);
    tb->updateBusState(bus);

    // 32 bit access
    printf("32 bit access\n");
    tb->load(0, 3);
    while( !tb->o_valid() ) {
        tb->updateBusState(bus);
        bus->ack = false;
        mem.task( (bus->addr < 1024) && bus->cyc, bus);
        tb->updateBusState(bus);
        
        tb->tick();
    }
    printf("Read: %08X\n", tb->o_data());

    tb->tick();

    tb->load(4, 3);
    while( !tb->o_valid() ) {
        tb->updateBusState(bus);
        bus->ack = false;
        mem.task( (bus->addr < 1024) && bus->cyc, bus);
        tb->updateBusState(bus);
        tb->tick();
    }
    printf("Read: %08X\n", tb->o_data());
    tb->tick();

    // 16 bit access
    printf("\n16 bit access\n");    
    for( int i=0; i<2; i++) {
        tb->load(8+i*2, 2);
        while( !tb->o_valid() ) {
            tb->updateBusState(bus);
            bus->ack = false;
            mem.task( (bus->addr < 1024) && bus->cyc, bus);
            tb->updateBusState(bus);
            tb->tick();
        }
        printf("Read: %08X\n", tb->o_data());
        tb->tick();
    }

    // 8 bit access
    printf("\n8 bit access\n");
    for( int i=0; i<4; i++) {
        tb->load(12+i, 1);
        while( !tb->o_valid() ) {
            tb->updateBusState(bus);
            bus->ack = false;
            mem.task( (bus->addr < 1024) && bus->cyc, bus);
            tb->updateBusState(bus);
            tb->tick();
        }
        printf("Read: %08X\n", tb->o_data());
        tb->tick();
    }

    delete bus;
    
    return 0;
}
