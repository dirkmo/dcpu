#include <stdint.h>
#include <verilated_vcd_c.h>
#include <stdio.h>

uint64_t* tickcounter = NULL;

uint64_t tickcount() {
    if( tickcounter ) {
        return *tickcounter*10;
    }
	return 0;
}

template<class MODULE>	class TESTBENCH {
public:
	uint64_t m_tickcount;
	VerilatedVcdC *m_trace;
	MODULE	*m_core;

	TESTBENCH(void) {
		Verilated::traceEverOn(true);
		m_core = new MODULE;
		m_trace = NULL;
		m_tickcount = 0l;
	}

	virtual ~TESTBENCH() {
		delete m_core;
		m_core = NULL;
	}

		// Open/create a trace file
	virtual	void opentrace(const char *vcdname) {
		if (!m_trace) {
			m_trace = new VerilatedVcdC;
			m_core->trace(m_trace, 99);
			m_trace->open(vcdname);
		}
	}

	// Close a trace file
	virtual void close(void) {
		if (m_trace) {
			m_trace->close();
			m_trace = NULL;
		}
	}

	virtual void reset() {
		m_core->i_reset = 1;
		// Make sure any inheritance gets applied
		this->tick();
		m_core->i_reset = 0;
	}

	virtual void tick() {
		// Increment our own internal time reference
		m_tickcount++;

		// Make sure any combinatorial logic depending upon
		// inputs that may have changed before we called tick()
		// has settled before the rising edge of the clock.
		m_core->i_clk = 0;
		m_core->eval();
		
		if(m_trace) m_trace->dump(static_cast<vluint64_t>(10*m_tickcount-2));

		// Toggle the clock

		// Rising edge
		m_core->i_clk = 1;
		m_core->eval();
		if(m_trace) m_trace->dump(static_cast<vluint64_t>(10*m_tickcount));

		// Falling edge
		m_core->i_clk = 0;
		m_core->eval();
		if (m_trace) {
			// This portion, though, is a touch different.
			// After dumping our values as they exist on the
			// negative clock edge ...
			m_trace->dump(static_cast<vluint64_t>(10*m_tickcount+5));
			//
			// We'll also need to make sure we flush any I/O to
			// the trace file, so that we can use the assert()
			// function between now and the next tick if we want to.
			m_trace->flush();
		}
	}

	virtual bool done() {
        return Verilated::gotFinish();
    }
};

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
