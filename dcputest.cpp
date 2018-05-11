#include "Vdcpu.h"
#include "verilated.h"
#include "testbench.h"
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

class dcputest : public TESTBENCH<Vdcpu> {
public:

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

    dcputest *tb = new dcputest();
    tb->opentrace("trace.vcd");
    
    Wishbone *bus = new Wishbone;
    uint8_t big_endian_data[256] = {
        0x8C, 0x03, 0x12, 0x34, 0x56, 0x78, // mov 0x12345678, r0
        // amode12
        0x80, 0x01, 0x10, 0x0A, // ld r1+10, r0
        0x80, 0x01, 0x0F, 0xF6, // ld r0-10, r0
        // amode28
        0x80, 0x02, 0x30, 0x00, 0x00, 0x0A, // ld r3+10, r0
        0x80, 0x02, 0x4F, 0xFF, 0xFF, 0xF6, // ld r4-10, r0
        // amode32
        0x80, 0x03, 0x10, 0x02, 0x30, 0x04, // ld 10, r0
    };



    Memory mem(1024);
    mem.set(0, big_endian_data, sizeof(big_endian_data));
    
    uint32_t pc = 0;
    tickcounter = &tb->m_tickcount;

    tb->reset();
    tb->tick();

    for( int i = 0; i<60; i++) {
        tb->updateBusState(bus);
        bus->ack = false;
        mem.task( (bus->addr < 1024) && bus->cyc, bus);
        tb->updateBusState(bus);
        tb->tick();
    }


    delete bus;
    
    return 0;
}
