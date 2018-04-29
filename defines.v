`ifndef	DEFINES_V
`define	DEFINES_V

`default_nettype none


`define REG_CC_SUPER 4'd14
`define REG_PC_SUPER 4'd15

`define REG_CC_USER 4'd30
`define REG_PC_USER 4'd31

`define CC_Z 0
`define CC_C 1
`define CC_N 2
`define CC_O 3

`define CC_STEP    8 // interrupt after every instruction (only in user mode)

`define CC_IE     16 // int enable (aka user mode)
`define CC_DIV0   17 // div by 0 trap
`define CC_BE     18 // bus error trap
`define CC_II     19 // illegal instruction trap
`define CC_TRAP   20 // User interrupt

`endif
