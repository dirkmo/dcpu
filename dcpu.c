#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>





typedef enum {
    ST_RESET = 0,
    ST_FETCH = 1,
    ST_EXECUTE = 2,
} state_t;

typedef struct {
    uint16_t ir[2];
    uint16_t pc;
    // data stack
    uint16_t t;
    uint16_t n;
    uint16_t dsp;
    // address stack
    uint16_t asp;
    uint16_t a;
    // misc
    uint16_t usp;
    uint16_t alu_output;
    uint16_t *bus;
    uint16_t busaddr;
    uint16_t status; // incl. carry
    state_t state;
} cpu_t;

void reset(cpu_t *cpu) {

}


void statemachine(cpu_t *cpu) {

}


static uint16_t mem[0x10000];

int main(int argc, char *argv[]) {
    cpu_t cpu;
    reset(&cpu);

    uint16_t prog[] = { };
    memcpy(mem, prog, sizeof(prog));
    int count = 0;
    while(count++ < 10) {
        statemachine(&cpu);
    }
    return 0;
}