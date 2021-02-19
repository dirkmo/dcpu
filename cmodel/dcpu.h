#ifndef _DCPU_H
#define _DCPU_H

#include <stdint.h>
#include <stdbool.h>

#define ARRCOUNT(a) (sizeof(a) / sizeof((a)[0]))

#define FLAG_ZERO 1
#define FLAG_CARRY 2
#define FLAG_INTEN 4 // interrupt enable

#define ADDR_RESET 0x0100
#define ADDR_INT   0xFFF0

// ## memory accesses are little endian:
// addr 0: low byte
// addr 1: high byte

// ## Instruction set

typedef enum {
    OP_MASK     = 0xF8,

    // Immediate instruction pushes data into ir
    // 0IIIIIII   ir[23:0] <= {ir[15:0], 0iiiiiii}
    // after every non-immediate instruction, ir[23:0] will be cleared.
    OP_IMM_MASK = 0x80,
    

    // # Alu Ops    T <- N op T
    OP_ALU      = 0x80,            // 1000 0xxx
    OP_ADD      = OP_ALU | 0x0,    // 1000 0000 plus
    OP_SUB      = OP_ALU | 0x1,    // 1000 0001 minus
    OP_AND      = OP_ALU | 0x2,    // 1000 0010 and
    OP_OR       = OP_ALU | 0x3,    // 1000 0011 or
    OP_XOR      = OP_ALU | 0x4,    // 1000 0100 xor
    OP_LSR      = OP_ALU | 0x5,    // 1000 0101 lsr
    OP_CPR      = OP_ALU | 0x6,    // 1000 0110 cpr  ; t <- { n[7:0], t[7:0] } (compress 2 chars into one word)
    OP_SWAP     = OP_ALU | 0x07,   // 1000 0111

    // # Stack
    OP_STACKGROUP1  = 0x90,           // 1001 xxxx
    OP_PUSHT        = OP_STACKGROUP1 | 0x0,  // 1001 0000 push t            ; mem[dsp] <- n, dsp++, n <- t
    OP_PUSHA        = OP_STACKGROUP1 | 0x1,  // 1001 0001 push a            ; mem[dsp] <- n, dsp++, n <- t, t <- a
    OP_PUSHUSP      = OP_STACKGROUP1 | 0x2,  // 1001 0010 push usp          ; mem[dsp] <- n, dsp++, n <- t, t <- usp
    OP_PUSHN        = OP_STACKGROUP1 | 0x3,  // 1001 0011 push n            ; mem[dsp] <- n, dsp++, n <- t, t <- n
    OP_PUSHI        = OP_STACKGROUP1 | 0x4,  // 1001 01xy push #im          ; mem[dsp] <- n, dsp++, n <- t, t <- {ir[22:16], ir[14:8], ir[1:0]}

    OP_STACKGROUP2  = 0x98,
    OP_PUSHS        = OP_STACKGROUP2 | 0x8, // 1001 1000 push status       ; mem[dsp] <- n, dsp++, n <- t, t <- status
    OP_PUSHDSP      = OP_STACKGROUP2 | 0x9, // 1001 1001 push dsp          ; mem[dsp] <- n, dsp++, n <- t, t <- dsp
    OP_PUSHASP      = OP_STACKGROUP2 | 0xA, // 1001 1010 push asp          ; mem[dsp] <- n, dsp++, n <- t, t <- asp
    OP_PUSHPC       = OP_STACKGROUP2 | 0xB, // 1001 1011 push pc+1         ; mem[dsp] <- n, dsp++, n <- t, t <- pc+1
    // OP_PUSHx     = OP_STACKGROUP2 | 0xC, // 1001 1100 
    // OP_PUSHx     = OP_STACKGROUP2 | 0xD, // 1001 1101 
    // OP_PUSHx     = OP_STACKGROUP2 | 0xE, // 1001 1110
    // OP_PUSHx     = OP_STACKGROUP2 | 0xF, // 1001 1111 

    // # Memory
    OP_FETCHGROUP   = 0xA0,
    OP_FETCHT       = OP_FETCHGROUP | 0x0, // 1010 0000 fetch t           ; t <- mem[t]
    OP_FETCHA       = OP_FETCHGROUP | 0x1, // 1010 0001 fetch a           ; t <- mem[a]
    OP_FETCHU       = OP_FETCHGROUP | 0x2, // 1010 0010 fetch u+#ofs      ; t <- mem[usp+#ofs]
    OP_FETCHN       = OP_FETCHGROUP | 0x3, // 1010 0011 fetch n           ; t <- mem[n]
    OP_FETCHABS     = OP_FETCHGROUP | 0x4, // 1010 01xy fetch #imm        ; t <- mem[#imm] mit #imm = {ir[22:16], ir[14:8], ir[1:0]}

    OP_STOREGROUP   = 0xA8,
    OP_STORET       = OP_STOREGROUP | 0x0, // 1010 1000 store t           ; mem[t] <- n
    OP_STOREA       = OP_STOREGROUP | 0x1, // 1010 1001 store a           ; mem[a] <- t
    OP_STOREU       = OP_STOREGROUP | 0x2, // 1010 1010 store u+#ofs      ; mem[usp+#ofs] <- t
    OP_STOREN       = OP_STOREGROUP | 0x3, // 1010 1011 store n           ; mem[n] <- t
    OP_STOREABS     = OP_STOREGROUP | 0x4, // 1010 11xy store #imm        ; mem[#imm] <- t mit #imm = {ir[22:16], ir[14:8], ir[1:0]}

    // # Jumps
    OP_JMPGROUP     = 0xB0,
    OP_JMPT         = OP_JMPGROUP | 0x0, // 1011 0000 jmp t             ; pc <- t
    OP_JMPA         = OP_JMPGROUP | 0x1, // 1011 0001 jmp a             ; pc <- a
    OP_JMPU         = OP_JMPGROUP | 0x2, // 1011 0010 jmp u             ; pc <- usp
    OP_JMPN         = OP_JMPGROUP | 0x3, // 1011 0011 jmp n             ; pc <- n
    OP_JMPABS       = OP_JMPGROUP | 0x4, // 1011 01xy jmp #im           ; pc <- #im mit #im =  {ir[22:16], ir[14:8], ir[1:0]}

    OP_BRANCHGROUP  = 0xB8,
    OP_BRAT         = OP_BRANCHGROUP | 0x0, // 1011 1000 bra t             ; mem[asp] <- a, a <- pc+1, asp++, pc <- t
    OP_BRAA         = OP_BRANCHGROUP | 0x1, // 1011 1001 bra a             ; mem[asp] <- a, a <- pc+1, asp++, pc <- t
    OP_INT          = OP_BRANCHGROUP | 0x2, // 1011 1010 int               ; mem[asp] <- a, a <- pc+1, asp++, pc <- int-vec
    OP_BRAN         = OP_BRANCHGROUP | 0x3, // 1011 1011 bra n
    OP_BRAABS       = OP_BRANCHGROUP | 0x4, // 1011 11xy bra #im           ; mem[asp] <- a, a <- pc+1, asp++, pc <- {ir[22:16], ir[14:8], ir[1:0]}

    OP_JMPZGROUP    = 0xC0,
    OP_JMPZT        = OP_JMPZGROUP | 0x0, // 1100 0000 jz t                ; pc <- t
    OP_JMPZA        = OP_JMPZGROUP | 0x1, // 1100 0001 jz a                ; pc <- a
    OP_JMPZU        = OP_JMPZGROUP | 0x2, // 1100 0010 jz u
    OP_JMPZN        = OP_JMPZGROUP | 0x3, // 1100 0011 jz  n
    OP_JMPZABS      = OP_JMPZGROUP | 0x4, // 1100 01xy jz #im              ; pc <- {ir[22:16], ir[14:8], ir[1:0]}

    OP_JMPNZGROUP   = 0xC8,
    OP_JMPNZT       = OP_JMPNZGROUP | 0x0, // 1100 1000 jnz t              ; pc <- t or pc+1
    OP_JMPNZA       = OP_JMPNZGROUP | 0x1, // 1100 1001 jnz a              ; pc <- a or pc+1
    OP_JMPNZU       = OP_JMPNZGROUP | 0x2, // 1100 1010 jnz u
    OP_JMPNZN       = OP_JMPNZGROUP | 0x3, // 1100 1011 jnz n
    OP_JMPNZABS     = OP_JMPNZGROUP | 0x4, // 1100 11xy jnz #im            ; pc <- #im or pc+1

    OP_JMPCGROUP    = 0xD0,
    OP_JMPCT        = OP_JMPCGROUP | 0x0, // 1101 0000 jc t
    OP_JMPCA        = OP_JMPCGROUP | 0x1, // 1101 0001 jc a
    OP_JMPCU        = OP_JMPCGROUP | 0x2, // 1101 0010 jc u
    OP_JMPCN        = OP_JMPCGROUP | 0x3, // 1101 0011 jc n
    OP_JMPCABS      = OP_JMPCGROUP | 0x4, // 1101 01xy jc #im            ; #im =  {ir[22:16], ir[14:8], ir[1:0]}

    OP_JMPNCGROUP   = 0xD8,
    OP_JMPNCT       = OP_JMPNCGROUP | 0x0, // 1101 1000 jnc t
    OP_JMPNCA       = OP_JMPNCGROUP | 0x1, // 1101 1001 jnc a
    OP_JMPNCU       = OP_JMPNCGROUP | 0x2, // 1101 1010 jnc u
    OP_JMPNCN       = OP_JMPNCGROUP | 0x3, // 1101 1011 jnc n
    OP_JMPNCABS     = OP_JMPNCGROUP | 0x4, // 1101 11xy jnc #im          ; #im =  {ir[22:16], ir[14:8], ir[1:0]}

    OP_POPGROUP     = 0xE0,
    OP_POP          = OP_POPGROUP | 0x0, // 1110 0000 pop       ; t <- n, n <- mem[dsp-1], dsp--
    // OP_POPx      = OP_POPGROUP | 0x1, // 1110 0001 
    OP_APOP         = OP_POPGROUP | 0x2, // 1110 0010 popa      ; a <- mem[asp-1], asp--
    OP_RET          = OP_POPGROUP | 0x3, // 1110 0011 ret       ; pc <- a, a <- mem[asp-1], asp--
        
    // Registers
    OP_SETREGISTERGROUP = 0xF0,
    OP_SETSTATUS    = OP_SETREGISTERGROUP | 0x0, // 1111 0000 status       ; status <- t
    OP_SETDSP       = OP_SETREGISTERGROUP | 0x1, // 1111 0001 dsp          ; dsp <- t
    OP_SETASP       = OP_SETREGISTERGROUP | 0x2, // 1111 0010 asp          ; asp <- t
    OP_SETUSP       = OP_SETREGISTERGROUP | 0x3, // 1111 0011 usp          ; usp <- t
    OP_SETA         = OP_SETREGISTERGROUP | 0x4, // 1111 0100 a            ; a <- t

    OP_MISC         = 0xF8,
    OP_APUSH        = OP_MISC | 0x0, // 1111 1000 apush        ; mem[asp] <- a, a <- t, asp++

    OP_END = 0xFF
} opcode_t;

typedef enum {
    ST_RESET = 0,
    ST_FETCH = 1,
    ST_EXECUTE = 2,
} state_t;

typedef struct cpu_t cpu_t;

struct cpu_t {
    
    // instruction + immediate registers
    uint8_t ir[3];
    
    // program counter, byte addresses
    uint16_t pc;
    
    // data stack
    uint16_t t;
    uint16_t n;
    uint16_t dsp; // byte address
    
    // address stack
    uint16_t asp; // byte address
    uint16_t a;
    
    // user stack pointer
    uint16_t usp; // byte address

    uint16_t status; // incl. carry

    // memory access
    uint16_t* (*bus)(cpu_t *cpu);
    uint16_t busaddr; // byte address

    // state machine state
    state_t state;
};

const char *disassemble(cpu_t *cpu);
void statemachine(cpu_t *cpu);
void reset(cpu_t *cpu);

#endif
