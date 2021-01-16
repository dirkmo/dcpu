#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>


/*
## Instruction set

0IIIIIII   ir[23:0] <= {ir[15:0], 0iiiiiii}

# Alu Ops

1000 0000 plus
1000 0001 minus
1000 0010 and
1000 0011 or
1000 0100 xor
1000 0101 lsr
1000 0110
1000 0111

# Stack

1001 0000 push t
1001 0001 push a
1001 0010 push #imm
1001 0011 push n
1001 0100 push usp
1001 0101 push status
1001 0110
1001 0111

1001 1000
1001 1001
1001 1010 pop
1001 1011 popa
1001 1100 usp++
1001 1101 usp--
1001 1110
1001 1111

# Memory

1010 0000 fetch t
1010 0001 fetch a 
1010 0010 fetch #ofs
1010 0011 fetch u+#ofs

1010 0100 store t
1010 0101 store a
1010 0110 store #ofs
1010 0111 store u+#ofs

# Jumps
1011 0000 jmp t
1011 0001 jmp a
1011 0010 jmp #im

1011 0100 jc t
1011 0101 jc a
1011 0110 jc #im

1011 1000 jz t
1011 1001 jz a
1011 1010 jz #im

1011 1100 jnz t
1011 1101 jnz a
1011 1110 jnz #im

1100 bra t
1100 bra a
1100 bra #im

1100 bc t
1100 bc a
1100 bc #im

1100 bz t
1100 bz a
1100 bz #im

1100 bnz t
1100 bnz a
1100 bnz #im

# Misc
1111 0000 status
1111 1000 int



pop      pop ds
    dsp--
    t <- n
    n <- mem[dsp]

popa     pop as
    asp--
    a <- mem[asp]

upd     decrease usp
    usp--

upi     increase usp
    usp++

jmp im      jump to immediate address
    pc <- ir[]

jpz im      if zero, jump to immediate address
    pc <- zero ? IR : pc+1

jpc im      if carry, jump to immediate address
    pc <- carry ? IR : pc+1

jmp a       jump to a
    pc <- a

jmp t       jump to t
    pc <- t

bra, braz, brac
    mem[asp] <- a, asp++
    a <- pc + 1
    pc <- [im, a, t]

AND         logical and
    T <- T & N

int         jump to interrupt vector address
    pc <- INT-ADDR

push #imm   
    mem[dsp] <- n
    dsp++
    n <- t
    T <- ir[]

push t
    mem[dsp] <- n, dsp++
    n <- t

push n
    mem[dsp] <- n, dsp++
    n <- t, t <- n

push a
    mem[dsp] <- n, dsp++
    n <- t
    t <- a

push usp
    mem[dsp] <- n, dsp++
    n <- t
    t <- usp

push status
    mem[dsp] <- n, dsp++
    n <- t
    t <- status


fetch t   load from memory with address in t or a
    t <- mem[t]

fetch a
    t <- mem[a]

fetch #ofs  load from memory, address in ir[]
    t <- mem[#ofs]

fetch u+#ofs  load from usp+ofs (ofs in ir[])
    t <- mem[usp+ofs]

store n     store n to memory with address in t
    mem[t] <- n

store t     store t to memory with address in a
    mem[a] <- t

store #ofs  store t to memory address in ir[]
    mem[#ofs] <- t

store u+#ofs  store t to memory with address usp+ofs (ofs in ir[])
    mem[usp+ofs] <- t


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