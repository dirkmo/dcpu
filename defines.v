`ifndef	DEFINES_V
`define	DEFINES_V

`default_nettype none


`define REG_CC_SUPER 4'd14
`define REG_PC_SUPER 4'd15

`define REG_CC_USER 4'd30
`define REG_PC_USER 4'd31

`define CC_Z 0 // Zero flag
`define CC_C 1 // Carry flag
`define CC_N 2 // Negative flag
`define CC_V 3 // Overflow flag

`define CC_STEP    8 // interrupt after every instruction (only in user mode)

`define CC_IE     16 // int enable (aka user mode)
`define CC_DIV0   17 // div by 0 trap
`define CC_BE     18 // bus error trap
`define CC_II     19 // illegal instruction trap
`define CC_TRAP   20 // User interrupt

//-----------------------------------------------
// conditions
`define COND_NONE   3'h0
`define COND_Z      3'h1
`define COND_LT     3'h2
`define COND_C      3'h3
`define COND_V      3'h4
`define COND_NZ     3'h5
`define COND_GE     3'h6
`define COND_NC     3'h7


//-----------------------------------------------
// Opcodes

// load
`define OP_LDB    6'h20
`define OP_LDH    6'h21
`define OP_LD     6'h22

// move
`define OP_MOV    6'h23

// store
`define OP_STB    6'h24
`define OP_STH    6'h25
`define OP_ST     6'h26


`endif
