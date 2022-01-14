module dcpu(
    input i_reset,
    input i_clk,

    output     [15:0] o_addr,
    output reg [15:0] o_dat,
    input      [15:0] i_dat,
    input              i_ack,
    output             o_we,
    output             o_cs,

    input              i_irq
);

parameter
    DSS = 6, // data stack size: 2^DSS
    RSS = 6; // return stack size: 2^RSS

localparam
    FETCH = 0,
    EXECUTE = 1;

reg r_state /* verilator public */; // state machine
reg [15:0] r_pc /* verilator public */; // program counter

wire s_fetch   = (r_state == FETCH);
wire s_execute = (r_state == EXECUTE);

reg [15:0] r_op; // instruction register
always @(posedge i_clk)
    if (s_fetch && i_ack)
        r_op <= i_dat;

reg [15:0] T /* verilator public */; // top of dstack
reg [15:0] N /* verilator public */; // 2nd on dstack
reg [15:0] R /* verilator public */; // top of rstack

/*
Instruction types:

0 <addr:15>                             call
1 00 <imm:13>                           imm.l
1 01 <unused:4> <return:1> <imm:8>      imm.h

1 10 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>

1 11 <cond:3> <imm:10>                  rjp

*/
wire w_op_call = (r_op[15] == 0);
wire w_op_imm  = (r_op[15:14] == 2'b10);
wire w_op_imml = w_op_imm & ~r_op[13];
wire w_op_immh = w_op_imm &  r_op[13];
wire w_op_alu  = (r_op[15:13] == 3'b110);
wire w_op_rjp  = (r_op[] == 3'b111);

// imml field
wire [14:0] w_op_imml_lit = r_op[14:0];

// immh field
wire [7:0] w_op_immh_lit = r_op[7:0];

// rjp fields
wire [1:0] w_op_rjp_cond = r_op[12:10];
wire [1:0] w_op_rjp_imm  = r_op[9:0];

// alu-op fields
wire       w_op_alu_unused = r_op[12];
wire [4:0] w_op_alu_op  = r_op[11:7];
wire       w_op_alu_ret = r_op[6];
wire [2:0] w_op_alu_dst = r_op[5:4];
wire [1:0] w_op_alu_dsp = r_op[3:2];
wire [1:0] w_op_alu_rsp = r_op[1:0];

/* alu-op dst: destination of write operation
    00 T (top of dstack)
    01 R
    10 PC
    11 [T]
*/
wire w_op_alu_dst_T    = (w_op_alu_dst == 2'b00);
wire w_op_alu_dst_R    = (w_op_alu_dst == 2'b01);
wire w_op_alu_dst_PC   = (w_op_alu_dst == 2'b10);
wire w_op_alu_dst_MEMT = (w_op_alu_dst == 2'b11);

/*
alu: alu operation
*/
reg [16:0] w_alu;
wire carry = w_alu[16];
always @(*)
    case (w_op_alu[4:0])
        5'h00: w_alu = {1'b0, T};
        5'h01: w_alu = {1'b0, N};
        5'h02: w_alu = {1'b0, R};
        5'h03: w_alu = {1'b0, i_dat}; // [T]

        5'h04: w_alu = {1'b0, N} + {1'b0, T};
        5'h05: w_alu = {1'b0, N} - {1'b0, T};
        5'h06: w_alu = 0; // TODO: N * T

        5'h07: w_alu = {1'b0, N & T};
        5'h08: w_alu = {1'b0, N | T};
        5'h09: w_alu = {1'b0, N ^ T};
        5'h0a: w_alu = {15'h00, $signed(N) < signed(T)};
        5'h0b: w_alu = {15'h00, N < T};
        5'h0c: w_alu = {15'h00, N < T};
        5'h0d: w_alu = {T[0], 1'b0, T[15:1]}; // T >> 1
        5'h0e: w_alu = {9'h00, T[15:8]}; // T >> 8
        5'h0f: w_alu = {T[15:0], 1'b0}; // T << 1
        5'h10: w_alu = {1'b0, T[7:0], 8'h00}; // T << 8
        5'h11: w_alu = (T==0) ? {1'b0, N} : {1'b0, r_pc}; // condition for JZ R
        5'h12: w_alu = (T!=0) ? {1'b0, N} : {1'b0, r_pc}; // condition for JZ R

        5'h13: w_alu = {15'h00, carry};
        default: w_alu = 0;
    endcase


wire w_op_alu_MEMT = (w_op_alu == 4'h03);

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
reg [15:0] w_pcn;
always @(*)
    if (w_op_alu_dst_PC)
        w_pcn = w_alu[15:0];
    else 
        w_pcn = r_pc + 1;

always @(posedge i_clk)
    if(i_reset)
        r_pc <= 0;
    else if(s_execute)
        r_pc <= w_pcn;


// DSP
reg [DSS-1:0] r_dsp /* verilator public */;
reg [DSS-1:0] w_dspn;
always @(*)
    casez ( { w_op_alu, w_op_dsp } )
        3'b0??:  w_dspn = r_dsp + 1;
        3'b101:  w_dspn = r_dsp + 1;
        3'b110:  w_dspn = r_dsp - 1;
        default: w_dspn = r_dsp;
    endcase

always @(posedge i_clk)
    if (i_reset)
        r_dsp <= 0;
    else if(s_execute)
        r_dsp <= w_dspn;

// dstack
reg [15:0] r_dstack[0:DSS**2-1] /* verilator public */;
always @(posedge i_clk)
    if (s_execute) begin
        if (w_op_imml)
            r_dstack[w_dspn] <= {1'b0, w_op_imml_lit[14:0]};
        else if (w_op_immh)
            r_dstack[w_dspn] <= {w_op_immh_lit[7:0], r_dstack[w_dsp_n][7:0]};
        else if (w_op_dst_T)
            r_dstack[w_dspn] <= w_alu[15:0];
    end

// RSP
reg [RSS-1:0] r_rsp /* verilator public */;
reg [RSS-1:0] w_rspn;
always @(*) begin
    if (i_reset)
        w_rspn = 0;
    else begin
        if (w_op_alu) begin
            if (w_op_rsp_inc) begin
                w_rspn = r_rsp + 1;
            end else if (w_op_rsp_dec) begin
                w_rspn = r_rsp - 1;
            end
        end
    end
end

always @(posedge i_clk)
    if (i_reset)
        r_rsp <= 0;
    else if (s_execute)
        r_rsp <= w_rspn;

// rstack
reg [15:0] r_rstack[0:RSS**2-1] /* verilator public */;
always @(posedge i_clk)
    if (s_execute) begin
        r_rstack[w_rspn] <= w_op_rsp_RPC ? w_pcn :
                            w_op_dst_R   ? w_src : r_rstack[w_rspn];
    end

always @(posedge i_clk)
    if (s_fetch) begin
        R <= r_rstack[r_rsp];
        T <= r_dstack[r_dsp];
        N <= r_dstack[r_dsp - 1];
    end

wire w_mem_access_MEMT  = (w_op_alu_MEMT || w_op_alu_dst_MEMT);
wire w_op_mem_access    = s_execute && w_mem_access_MEMT;
wire w_all_mem_accesses = s_fetch || w_op_mem_access;

// state machine
always @(posedge i_clk)
begin
    case (r_state)
        FETCH: begin
            if (i_ack) begin
                r_state <= EXECUTE;
            end
        end
        EXECUTE: begin
            if (~w_all_mem_accesses || i_ack)
                r_state <= FETCH;
        end
    endcase
    
    if (i_reset) begin
        r_state <= FETCH;
    end
end

assign o_addr = s_fetch ? r_pc :
      w_mem_access_MEMT ? T    : 0;

assign o_cs = i_reset ? 0 : w_all_mem_accesses;

assign o_we = w_op_mem_access && w_op_alu_dst_MEMT;

assign o_dat = w_alu[15:0];

endmodule
