module dcpu(
    input i_reset,
    input i_clk,

    output [W-1:0] o_addr,
    output [W-1:0] o_dat,
    input  [W-1:0] i_dat,
    input          i_ack,
    output         o_we,
    output         o_cs,

    input          i_irq
);

parameter
    W   = 16, // data path width
    DSS = 5, // data stack size: 2^DSS
    RSS = 5; // return stack size: 2^RSS

localparam
    FETCH = 0,
    EXECUTE = 1;

reg r_state; // state machine
reg [W-1:0] r_pc; // program counter

wire s_fetch   = (r_state == FETCH);
wire s_execute = (r_state == EXECUTE);

reg [W-1:0] r_op; // instruction register
always @(posedge i_clk)
    if (s_fetch && i_ack)
        r_op <= i_dat;

wire [W-1:0] T; // top of dstack
wire [W-1:0] N; // 2nd on dstack
wire [W-1:0] R; // top of rstack

/*
Instruction types:

0 <lit:15 bits>                              # push literal to dstack
1 <dst:3> <alu:5> <dsp:2> <rsp:2> <unused:3> # write alu output to dst
*/
wire w_op_literal   = (r_op[15] == 0);
wire w_op_normal    = r_op[15];
wire [2:0] w_op_dst = r_op[14:12];
wire [4:0] w_op_alu = r_op[11:7];
wire [1:0] w_op_dsp = r_op[6:5];
wire [1:0] w_op_rsp = r_op[4:3];
wire [2:0] w_unused = r_op[2:0];

/*
dst: destination of write operation
     000 T (top of dstack)
     001 N (2nd element of dstack)
     010 R (top of rstack)
     011 PC
     100 [T] (memory write to address T)
     101 [R] (memory write to address R)
     110
     111
*/
wire w_op_dst_T    = (w_op_dst == 3'b000);
wire w_op_dst_N    = (w_op_dst == 3'b001);
wire w_op_dst_R    = (w_op_dst == 3'b010);
wire w_op_dst_PC   = (w_op_dst == 3'b011);
wire w_op_dst_MEMT = (w_op_dst == 3'b100);
wire w_op_dst_MEMR = (w_op_dst == 3'b101);

/*
alu: alu operation
*/
reg [W:0] w_alu;
wire carry = w_alu[W];
always @(*)
    case (w_op_alu)
        5'h00: w_alu = {1'b0, T};
        5'h01: w_alu = {1'b0, N};
        5'h02: w_alu = {1'b0, R};
        5'h03: w_alu = {1'b0, N} + {1'b0, T};
        5'h04: w_alu = {1'b0, N} - {1'b0, T};
        5'h05: w_alu = {1'b0, N & T};
        5'h06: w_alu = {1'b0, N | T};
        5'h07: w_alu = {1'b0, N ^ T};
        5'h08: w_alu = {1'b0, N & T};
        5'h09: w_alu = {1'b0, ~T};
        5'h0a: w_alu = {2'b00, T[15:1]}; // T >> 1
        5'h0b: w_alu = { T[15:0], 1'b0}; // T << 1
        5'h0c: w_alu = i_dat; // [T]
        5'h0d: w_alu = i_dat; // [R]
        5'h0e: w_alu = T ? r_pc : R; // condition for JZ R
        5'h0f: w_alu = T ? r_pc : T; // condition for JZ T
    endcase

wire w_op_alu_MEMT = (w_op_alu == 5'h0c);
wire w_op_alu_MEMR = (w_op_alu == 5'h0d);
wire w_op_alu_COND_PC_R = (w_op_alu == 5'h0e);
wire w_op_alu_COND_PC_T = (w_op_alu == 5'h0f);

/*
dsp: dstack pointer handling
     00 nothing
     01 dsp+1
     10 dsp-1
     11 nothing
*/
wire w_op_dsp_inc = (w_op_dsp == 2'b01);
wire w_op_dsp_dec = (w_op_dsp == 2'b10);

/*
rsp: rstack pointer handling and push PC to rstack
     00 nothing
     01 rsp+
     10 rsp-
     11 R <- PC (for CALL: push PC to rstack an rsp+)
*/
wire w_op_rsp_inc = (w_op_rsp == 2'b01);
wire w_op_rsp_dec = (w_op_rsp == 2'b10);
wire w_op_rsp_RPC = (w_op_rsp == 2'b11);


// PC
reg [W-1:0] w_pcn;
always @(*)
    if (i_reset)
        w_pcn = 0;
    else if (s_fetch && i_ack)
        w_pcn = r_pc + 1;

always @(posedge i_clk)
    r_pc <= w_pcn;


// DSP
reg [DSS-1:0] r_dsp;
reg [DSS-1:0] w_dspn;
always @(*)
    casez ( { w_op_normal, w_op_dsp_inc, w_op_dsp_dec } )
        3'b0??: w_dspn = r_dsp + 1;
        3'b101: w_dspn = r_dsp + 1;
        3'b110: w_dspn = r_dsp - 1;
        default: w_dspn = r_dsp;
    endcase

always @(posedge i_clk)
    if (s_execute)
        r_dsp <= w_dspn;

// dstack
reg [W-1:0] r_dstack[0:DSS**2];
always @(posedge i_clk)
    if (s_execute) begin
        if (w_op_literal)
            r_dstack[w_dspn] <= r_op;
    end

assign T = r_dstack[r_dsp];
assign N = r_dstack[r_dsp-1];


// RSP
reg [RSS-1:0] r_rsp;
reg [RSS-1:0] w_rspn;
always @(*)
    casez ( { w_op_normal, w_op_rsp_inc, w_op_rsp_dec } )
        3'b101: w_rspn = r_rsp + 1;
        3'b110: w_rspn = r_rsp - 1;
        3'b111: w_rspn = r_rsp + 1;
        default: w_rspn = r_rsp;
    endcase

always @(posedge i_clk)
    if (s_execute)
        r_rsp <= w_rspn;

// rstack
reg [W-1:0] r_rstack[0:RSS**2];
always @(posedge i_clk)
    if (s_execute) begin
    end

assign R = r_rstack[r_rsp];


// state machine
always @(posedge i_clk)
begin
    case (r_state)
        FETCH: begin
            if (i_ack)
                r_state <= EXECUTE;
        end
        EXECUTE: begin
            r_state <= FETCH;
        end
    endcase
    
    if (i_reset) begin
        r_state <= FETCH;
    end
end

assign o_addr = s_fetch ? r_pc : 0;

endmodule