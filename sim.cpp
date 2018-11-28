#include <iostream>
#include <fstream>
#include "testbench.h"

using namespace std;

void loadMemory(sim *tb, uint16_t addr, string fn) {
    ifstream ifs(fn, ios::binary);
    uint16_t data[0x10000];
    ifs.read((char*)data, sizeof(data));
    for( uint16_t i = 0; i < ifs.gcount()/2; i++ ) {
        tb->setMem(addr++, data[i]);
    }
}

void parseCommandLine(sim *tb, int argc, char **argv) {
    // -d debug mode
    // -t enable trace
    string fn = "boot.bin";
    for( int i = 1; i < argc; i++ ) {
        string s = argv[i];
        if ( s == "-t" ) {
            tb->options.trace = true;
        } else if( s == "-d" ) {
            tb->options.debug = true;
        } else if( s == "-i" ) {
            i++;
            if( i >= argc ) {
                cerr << "Missing filename." << endl;
                exit(1);
            }
            fn = argv[i];
        }
    }
    loadMemory(tb, 0, fn);
}

class sim : public TESTBENCH<Vtop> {
public:

    sim() {
    }

	virtual void tick() override {
		m_tickcount++;

		m_core->i_clk = 0;
		m_core->eval();

        //uart.task();
		
		if(m_trace) m_trace->dump(static_cast<vluint64_t>(10*m_tickcount-2));

		m_core->i_clk = 1;
		m_core->eval();
        //uart.task();
		if(m_trace) m_trace->dump(static_cast<vluint64_t>(10*m_tickcount));

		m_core->i_clk = 0;
		m_core->eval();
        //uart.task();
		if (m_trace) {
			m_trace->dump(static_cast<vluint64_t>(10*m_tickcount+5));
			m_trace->flush();
		}
	}

    uint16_t getPC() const { return m_core->top__DOT__cpu__DOT__pc; }

    uint16_t getMem(uint16_t addr) const {
        //return m_core->top__DOT__blkmem0__DOT__mem[addr];
        return 0;
    }

    void setMem(uint16_t addr, uint16_t dat ) {
        //m_core->top__DOT__blkmem0__DOT__mem[addr] = dat;
    }

    uint16_t getIR() const {
        //return m_core->top__DOT__cpu__DOT__ir;
    }

    //Uart uart;
};

int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);

    sim *tb = new sim();
    
    parseCommandLine(tb, argc, argv);
    
    tb->reset();
    
    if( tb->options.trace ) {
        tb->opentrace("trace.vcd");
    }

    tb->tick();

    int icount = 0;

    while(icount++ < 4) {
        tb->tick();
        tb->tick();
    }
    delete tb;
    return 0;
}
