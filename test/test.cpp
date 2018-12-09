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

struct TestData {
    CpuInternals cpu;
    vector<uint16_t> prog;
};

class Test : public TESTBENCH<Vtop> {
public:
    enum COLORS {
        DEFAULT = 0,
        RED = 31,
        GREEN = 32
    };
    Test() {
        opentrace("trace.vcd");
    }

    void addTest( TestData td ) {
        m_vTests.push_back( td );
    }

    bool checkResult(int idx) {
        bool error = false;
        TestData& td = m_vTests[idx];
        printf("Result: ");

        for( int i = 0; i < 32; i++ ) {
            if( m_core->top__DOT__cpu0__DOT__registers[i] != td.cpu.regs[i] ) {
                error = true;
            }
        }

        if( error ) {
            printf("%c[%dm", 27, RED); // red color
            printf("ERROR\n");
            for( int i = 0; i < 32; i++ ) {
                printf("%c[%dm", 27, DEFAULT); // default color
                if( m_core->top__DOT__cpu0__DOT__registers[i] != td.cpu.regs[i] ) {
                    printf("%c[%dm", 27, RED); // red color
                }
                if( (i % 8) == 0 && i ) printf("\n");
                printf("r%02i %08X ", i, m_core->top__DOT__cpu0__DOT__registers[i]);
            }
            printf("\n");
        } else {
            printf("%c[%dm", 27, GREEN); // green color
            printf("Success.\n");
            printf("%c[%dm", 27, DEFAULT); // default color
        }
        return !error;
    }

    bool doTestcase(int idx) {
        cout << endl << "======Executing test " << idx << "======" << endl;
        TestData& td = m_vTests[idx];
        copyProgToMem(td.prog);
        reset();
        int icount = 0;
        while(!done() && icount++ < 20) {
            int pcidx = m_core->top__DOT__cpu0__DOT__pc_idx;
            uint32_t pc = m_core->top__DOT__cpu0__DOT__registers[pcidx];
            printf("(%d) PC %08X\n", icount-1, pc);
            for( int i = 0; i < 32; i++ ) {
                if( (i % 8) == 0 && i ) printf("\n");
                printf("r%02i %08X ", i, m_core->top__DOT__cpu0__DOT__registers[i]);
            }
            printf("\n");
            tick();
        }
        cout << "Simulation finished" << endl;
        return checkResult(idx);
    }

    bool doTests() {
        for( int i = 0; i < m_vTests.size(); i++ ) {
            if( doTestcase(i) == false ) {
                return false;
            }
        }
        return true;
    }
    
private:
    void copyProgToMem(const vector<uint16_t>& prog) {
        for( size_t i = 0; i < prog.size(); i++ ) {
            m_core->top__DOT__blkmem0__DOT__mem[i] = prog[i];
        }
    }

    vector<TestData> m_vTests;
};


int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);

    Test tester;

    tester.addTest(
        (TestData) {
            { 0x00000000, 0x00000000, 0x00000034, 0x00000012, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
              0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000006,
              0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
              0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            },
            { 0xC106, 0xC187, 0x0000, 0x1234, 0x5678 }
        }
    );

    tester.doTests();

    return 0;
}
