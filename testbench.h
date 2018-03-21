#include <stdint.h>
#include <verilated_vcd_c.h>

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
