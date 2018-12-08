#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include "Vtop.h"
#include "testbench.h"

using namespace std;

struct CpuInternals {
    uint32_t regs[32];
};

class TestData {
    public:
    TestData( const CpuInternals& _cpu, const vector<uint16_t>& _prog ) : cpu(_cpu), prog(_prog) {}

    CpuInternals cpu;
    vector<uint16_t> prog;
};

class Test : public TESTBENCH<Vtop> {
public:

    Test() {
        opentrace("trace.vcd");
    }

    void addTest( TestData td ) {
        m_vTests.push_back( td );
    }

    bool checkResult(int idx) {
        TestData& td = m_vTests[idx];
        for( int i = 0; i < 32; i++ ) {
            if( m_core->top__DOT__cpu0__DOT__registers[i] != td.cpu.regs[i] ) {
                printf("r%02i should be %08X\n", i, td.cpu.regs[i]);
                return false;
            }
        }
        return true;
    }

    bool doTestcase(int idx) {
        cout << endl << "======Executing test " << idx << "======" << endl;
        TestData& td = m_vTests[idx];
        reset();
        int icount = 0;
        while(!done() && icount++ < 50) {
            for( int i = 0; i < 32; i++ ) {
                printf("r%02i %08X ", i, m_core->top__DOT__cpu0__DOT__registers[i]);
                if( i == 15 || i == 31 ) printf("\n");
            }
            tick();
        }
        cout << "Simulation finished" << endl;
        return checkResult(idx);
    }

private:
    vector<TestData> m_vTests;
};




int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);


    return 0;
}
