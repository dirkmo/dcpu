#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>


/*
## Instruction set

0IIIIIII   ir[23:0] <= {ir[15:0], 0iiiiiii}

# Alu Ops

T <- N op T

1000 0000 plus
1000 0001 minus
1000 0010 and
1000 0011 or
1000 0100 xor
1000 0101 lsr
1000 0110
1000 0111

# Stack

1001 0000 push t            ; mem[dsp] <- n, dsp++, n <- t
1001 0001 push a            ; mem[dsp] <- n, dsp++, n <- t, t <- a
1001 0010 push n            ; mem[dsp] <- n, dsp++, n <- t, t <- n
1001 0011 push usp          ; mem[dsp] <- n, dsp++, n <- t, t <- usp
1001 01xy push #im          ; mem[dsp] <- n, dsp++, n <- t, t <- {x, ir[22:16], y, ir[14:8]}

1001 1000 push status       ; mem[dsp] <- n, dsp++, n <- t, t <- status
1001 1001
1001 1010 
1001 1011 
1001 1100 pop               ; t <- n, n <- mem[dsp-1], dsp--
1001 1101 popa              ; a <- mem[asp-1], asp--
1001 1110 usp++             ; usp++
1001 1111 usp--             ; usp--

# Memory

1010 0000 fetch t           ; t <- mem[t]
1010 0001 fetch a           ; t <- mem[a]
1010 0010 fetch u+#ofs      ; t <- mem[usp+#ofs]
1010 0011
1010 01xy fetch #ofs        ; t <- mem[#ofs] mit #ofs = {x, ir[22:16], y, ir[14:8]}

1010 1000 store t           ; mem[t] <- n
1010 1001 store a           ; mem[a] <- t
1010 1010 store u+#ofs      ; mem[usp+#ofs] <- t
1010 1011
1010 11xy store #ofs        ; mem[#ofs] <- t mit #ofs = {x, ir[22:16], y, ir[14:8]}

# Jumps
1011 0000 jmp t             ; pc <- t
1011 0001 jmp a             ; pc <- a
1011 0010
1011 0011
1011 01xy jmp #im           ; pc <- #im mit #im =  {x, ir[22:16], y, ir[14:8]}

1011 1000 bra t
1011 1001 bra a
1011 1010
1011 1011
1011 11xy bra #im           ; #im =  {x, ir[22:16], y, ir[14:8]}

1100 0000 jc t
1100 0001 jc a
1100 0010
1100 0011
1100 01xy jc #im           ; #im =  {x, ir[22:16], y, ir[14:8]}

1100 1000 bc t
1100 1001 bc a
1100 1010
1100 1011
1100 11xy bc #im

1101 0000 jz t
1101 0001 jz a
1101 0010
1101 0011
1101 01xy jz #im

1101 1000 bz t
1101 1001 bz a
1101 1010
1101 1011
1101 11xy bz #im

1110 0000 jnz t
1110 0001 jnz a
1110 0010
1110 0011
1110 01xy jnz #im

1110 1000 bnz t
1110 1001 bnz a
1110 1010
1110 1011
1110 11xy bnz #im

# Misc
1111 0000 status                ; status <- t
1111 1000 int                   ; pc <- int-addr

*/


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