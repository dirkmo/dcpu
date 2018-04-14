#include "Vfetcher.h"
#include "verilated.h"
#include "testbench.h"
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

/*
class Wishbone {
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


class Memory {
public:
    uint8_t *mem = NULL;
    uint32_t size;
    
    Memory(uint32_t size) {
        mem = new uint8_t[size];
        this->size = size;
    }

    ~Memory() {
        delete[] mem;
    }

    void set(uint32_t addr, uint8_t *dat, uint32_t len) {
        assert(addr + len < size);
        while(len--) {
            mem[addr++] = *dat++;
        }
    }

    void task(bool sel, Wishbone *bus) {
        if( sel ) {
            if( bus->cyc && bus->stb>0 ) {
                uint32_t addr = bus->addr - (bus->addr%4);
                assert( bus->addr < size-3);
                if( bus->we ) {
                    if( bus->stb&8 ) mem[addr+0] = (bus->dat >> 24) & 0xFF;
                    if( bus->stb&4 ) mem[addr+1] = (bus->dat >> 16) & 0xFF;
                    if( bus->stb&2 ) mem[addr+2] = (bus->dat >>  8) & 0xFF;
                    if( bus->stb&1 ) mem[addr+3] = (bus->dat >>  0) & 0xFF;
                    printf("%lu: mem write %08X: %08X\n", tickcount(), addr, bus->dat);
                } else {
                    bus->dat = 0;
                    if( bus->stb&8 ) bus->dat |= (mem[addr+0] << 24);
                    if( bus->stb&4 ) bus->dat |= (mem[addr+1] << 16);
                    if( bus->stb&2 ) bus->dat |= (mem[addr+2] <<  8);
                    if( bus->stb&1 ) bus->dat |= (mem[addr+3] <<  0);
                    printf("%lu: mem read %08X: %08X\n", tickcount(), addr, bus->dat);
                }
                bus->ack = true;
            }
        }
    }
};
*/

class fetchertest : public TESTBENCH<Vfetcher> {
public:
    void i_pc(uint32_t pc) { m_core->i_pc = pc; }
    uint32_t o_pc() { return m_core->o_pc; }
    void i_fetch(bool fetch) {
        m_core->i_fetch = fetch;
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

    fetchertest *tb = new fetchertest();
    tb->opentrace("trace.vcd");
    
    Wishbone *bus = new Wishbone;
    uint8_t big_endian_data[] = {
        0x64, 0x00, // 16 bit
        0x65, 0x01, 0x00, 0x01, // 32 bit
        0x66, 0x02, 0x00, 0x01, 0x02, 0x03, // 48 bit
    };
    Memory mem(1024);
    mem.set(0, big_endian_data, sizeof(big_endian_data));
    
    uint32_t pc = 0;
    tickcounter = &tb->m_tickcount;

    tb->reset();
    tb->i_pc(pc);
    tb->tick();

    tb->i_fetch(true);

    while( !tb->done() && tb->m_tickcount < 50 ) {
        tb->updateBusState(bus);
        bus->ack = false;
        mem.task( (bus->addr < 1024) && bus->cyc, bus);
        tb->updateBusState(bus);
        tb->i_pc(pc);
        if( tb->m_core->o_valid ) {
            tb->i_fetch(true);
            printf("%u: Instruction: %lX\n", tickcount(), tb->m_core->o_instruction);
        }
        tb->tick();
        tb->i_fetch(false);
        if( tb->m_core->o_pc_wr ) {
            pc = tb->m_core->o_pc;
            printf("%u: PC: %08X\n", tickcount(), pc);
        }
    }
    
    delete bus;
    
    return 0;
}
