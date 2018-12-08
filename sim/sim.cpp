#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include "sim.h"

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
            //tb->options.trace = true;
        } else if( s == "-d" ) {
            //tb->options.debug = true;
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

int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);

    sim tb;
    
    parseCommandLine(&tb, argc, argv);

    /*
    LD r0, #imm(32)  F800 | Rd << 7
    LD r1, 0x12345678
    F880 5678 1234

    LDB Rd, (Rs+#imm(3))    11000 Rd(4) Rs(4) imm(3)
                            C000 | Rd << 7 | Rs << 3 | imm
    LDB r2, (r0+6)          C000 | 100 | 0 | 6
    C106
    LDB r3, (r0+7)          C000 | 180 | 0 | 6
    C187
    
    LDH Rd, (Rs+#imm(3))    11001 Rd(4) Rs(4) imm(3)
                            C900 | Rd << 7 | Rs << 3 | imm
    LD  Rd, (Rs+#imm(3))     11010 Rd(4) Rs(4) imm(3)


    */

    vector<uint16_t> prog {
        // 0xF880, 0x5678, 0x1234, 0x0000 // LD r1, 0x12345678
        // 0xC106, 0xC187, 0x0000, 0x1234, 0x5678 // LDB r2, (r0+6); LDB r3, (r0+7)

    };
    for( int i = 0; i < prog.size(); i++ ) {
        tb.setMem(i, prog[i]);
    }
    tb.opentrace("trace.vcd");

    tb.reset();
    
    tb.tick();

    uint32_t icount = 0;

    while(!tb.done() && icount++ < 10) {
        tb.tick();
    }
    return 0;
}
