#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <ctype.h>
#include "dcpu.h"

static uint8_t mem[0x10000];

uint16_t *bus(cpu_t *cpu) {
    assert(cpu->busaddr < sizeof(mem));
    return (uint16_t*)&mem[cpu->busaddr & 0xFFFe];
}

void copy(cpu_t *cpu, uint8_t *prog, int len) {
    for (int i = 0; i < len; i+=2) {
        cpu->busaddr = ADDR_RESET + i;
        *bus(cpu) = prog[i] | (prog[i+1] << 8);
    }
}

uint16_t convertHexnumber(const char *s, int len) {
    uint16_t num = 0;
    for (int i = 0; i < len; i++) {
        char c = toupper(s[i]);
        if (c >= '0' && c <= '9') {
            c -= '0';
        } else if (c >= 'A' && c <= 'F') {
            c -= 'A' - 10;
        }
        num = (num << 4) | c;
    }
    return num;
}

int loadHex(const char *fn, uint8_t *mem) {
    //  Hexfile format:
    //  : COUNT ADDRESS TYPE DATA CHKSUM
    char line[300];
    FILE *f = fopen(fn, "r");
    if (f == NULL) {
        return 3;
    }
    while (!feof(f)) {
        if( fgets(line, sizeof(line), f) == 0) {
            break;
        }
        if (line[0] != ':') {
            return 1;
        }
        uint8_t len = convertHexnumber(line+1, 2);
        uint16_t addr = convertHexnumber(line+3, 4);
        uint8_t type = convertHexnumber(line+7, 2);
        uint8_t chksum = convertHexnumber(line+9+len*2, 2);
        for ( int i = 0; i<len; i++) {
            uint8_t dat = convertHexnumber(line+9+i*2, 2);
            mem[addr+i] = dat;
            chksum += dat;
        }
        chksum += len + type + (addr & 0xff) + ((addr >> 8) & 0xff);
        if (chksum) {
            return 2;
        }
    }
    fclose(f);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: sim <hex-file>\n");
        return 1;
    }
    cpu_t cpu;
    cpu.bus = bus;

    reset(&cpu);

    if (loadHex(argv[1], mem)) {
        printf("ERROR: Failed to load hex-file %s\n",argv[1]);
        return 2;
    }


    // int count = 0;
    // while(count++ < 100 && cpu.ir[0] != OP_END) {
    //     statemachine(&cpu);
    // }

    return 0;
}
