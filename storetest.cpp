#include "Vstore.h"
#include "verilated.h"
#include "testbench.h"
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

class storetest : public TESTBENCH<Vstore> {
public:
    bool o_done() {
        return m_core->o_done;
    }

    bool o_error() {
        return m_core->o_error;
    }

    void store(uint32_t addr, uint8_t size, uint32_t data) {
        m_core->i_addr = addr;
        m_core->i_store = size;
        m_core->i_data = data;
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

    storetest *tb = new storetest();
    tb->opentrace("trace.vcd");
    
    Wishbone *bus = new Wishbone;
    uint8_t big_endian_data[256];
    for( int i=0; i<sizeof(big_endian_data); i++) {
        big_endian_data[i] = 0;
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
    for( int i = 0; i<2; i++ ) {
        tb->store( i*4, 3, 0x12345678 << i);
        while( !tb->o_done() ) {
            tb->updateBusState(bus);
            bus->ack = false;
            mem.task( (bus->addr < 1024) && bus->cyc, bus);
            tb->updateBusState(bus);
            tb->tick();
        }
        printf("%08X: %08X\n", i*4, mem.get32(i*4) );
        tb->store( 0, 0, 0);
        tb->tick();
    }
 
    // 16 bit access
    printf("16 bit access\n");
    for( int i = 0; i<2; i++ ) {
        tb->store( 8 + i*2, 2, 0x1234 << i);
        while( !tb->o_done() ) {
            tb->updateBusState(bus);
            bus->ack = false;
            mem.task( (bus->addr < 1024) && bus->cyc, bus);
            tb->updateBusState(bus);
            tb->tick();
        }
        printf("%08X: %04X\n", 8 + i*2, mem.get16(8+i*2) );
        tb->store( 0, 0, 0);
        tb->tick();
    }

    // 8 bit access
    printf("8 bit access\n");
    for( int i = 0; i<4; i++ ) {
        tb->store( 0xC + i, 1, 0x1 << i);
        while( !tb->o_done() ) {
            tb->updateBusState(bus);
            bus->ack = false;
            mem.task( (bus->addr < 1024) && bus->cyc, bus);
            tb->updateBusState(bus);
            tb->tick();
        }
        printf("%08X: %04X\n", 0xC + i, mem.get8(0xC + i) );
        tb->store( 0, 0, 0);
        tb->tick();
    }

    delete bus;
    
    return 0;
}
