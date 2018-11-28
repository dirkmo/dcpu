#include <stdint.h>
#include <verilated_vcd_c.h>
#include <stdio.h>
#include <vector>

using namespace std;

template<class MODULE>	class TESTBENCH {
public:
	uint64_t m_tickcount;
	VerilatedVcdC *m_trace;
	MODULE	*m_core;

	TESTBENCH(void) {
		Verilated::traceEverOn(true);
		m_core = new MODULE();
		m_trace = NULL;
		m_tickcount = 0l;
		//tickcounter = &m_tickcount;
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
		this->tick();
		m_core->i_reset = 0;
	}

	virtual void tick() {
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

	virtual bool done() {
        return Verilated::gotFinish();
    }

    virtual uint64_t getTickCounter() {
        return m_tickcount;
    }
};
