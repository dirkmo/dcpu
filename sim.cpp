#include <iostream>
#include <fstream>
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
    
    tb.opentrace("trace.vcd");

    tb.reset();
    
    tb.tick();

    uint32_t icount = 0;

    while(icount++ < 10) {
        tb.tick();
    }
    return 0;
}
