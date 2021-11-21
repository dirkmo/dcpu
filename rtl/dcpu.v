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

reg r_state /* verilator public */; // state machine
reg [W-1:0] r_pc /* verilator public */; // program counter

wire s_fetch   = (r_state == FETCH);
wire s_execute = (r_state == EXECUTE);

reg [W-1:0] r_op; // instruction register
always @(posedge i_clk)
    if (s_fetch && i_ack)
        r_op <= i_dat;

reg [W-1:0] T /* verilator public */; // top of dstack
reg [W-1:0] N /* verilator public */; // 2nd on dstack
reg [W-1:0] R /* verilator public */; // top of rstack

/*
Instruction types:

0 <lit:15 bits>                              # push literal to dstack
1 <dst:3> <alu:6> <dsp:2> <rsp:2> <unused:2> # write alu output to dst
*/
wire w_op_literal   = (r_op[15] == 0);
wire w_op_normal    = r_op[15];
wire [2:0] w_op_dst = r_op[14:12];
wire [5:0] w_op_alu = r_op[11:6];
wire [1:0] w_op_dsp = r_op[5:4];
wire [1:0] w_op_rsp = r_op[3:2];
wire [1:0] w_unused = r_op[1:0];

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
    case (w_op_alu[4:0])
        5'h00: w_alu = {1'b0, T};
        5'h01: w_alu = {1'b0, N};
        5'h02: w_alu = {1'b0, R};
        5'h03: w_alu = {1'b0, N} + {1'b0, T};
        5'h04: w_alu = {1'b0, N} - {1'b0, T};
        5'h05: w_alu = {1'b0, N & T};
        5'h06: w_alu = {1'b0, N | T};
        5'h07: w_alu = {1'b0, N ^ T};
        5'h08: w_alu = {1'b0, ~T};
        5'h09: w_alu = 0;
        5'h0a: w_alu = {2'b00, T[15:1]}; // T >> 1
        5'h0b: w_alu = { T[15:0], 1'b0}; // T << 1
        5'h0c: w_alu = {1'b0, i_dat}; // [T]
        5'h0d: w_alu = {1'b0, i_dat}; // [R]
        5'h0e: w_alu = |T ? {1'b0, r_pc} : {1'b0, R}; // condition for JZ R
        5'h0f: w_alu = |T ? {1'b0, r_pc} : {1'b0, T}; // condition for JZ T
        5'h10: w_alu = {9'b0, T[15:8]};
        5'h11: w_alu = {1'b0, T[7:0], 8'h00};
        default: w_alu = 0;
    endcase

reg [W-1:0] r_pick;
always @(posedge i_clk)
    if (s_fetch)
        r_pick <= r_dstack[w_alu[4:0]];

wire [W-1:0] w_src = w_op_alu[5] ? r_pick : w_alu[W-1:0];

wire w_op_alu_MEMT = (w_op_alu == 6'h0c);
wire w_op_alu_MEMR = (w_op_alu == 6'h0d);
wire w_op_alu_COND_PC_R = (w_op_alu == 6'h0e);
wire w_op_alu_COND_PC_T = (w_op_alu == 6'h0f);

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
    else if (w_op_dst_PC)
        w_pcn = w_src;
    else 
        w_pcn = r_pc + 1;

always @(posedge i_clk)
    if(s_execute)
        r_pc <= w_pcn;


// DSP
reg [DSS-1:0] r_dsp /* verilator public */;
reg [DSS-1:0] w_dspn;
always @(*)
    if (i_reset)
        w_dspn = 0;
    else casez ( { w_op_normal, w_op_dsp_inc, w_op_dsp_dec } )
        3'b0??:  w_dspn = r_dsp + 1;
        3'b101:  w_dspn = r_dsp + 1;
        3'b110:  w_dspn = r_dsp - 1;
        default: w_dspn = r_dsp;
    endcase

always @(posedge i_clk)
    if(s_execute)
        r_dsp <= w_dspn;

// dstack
reg [W-1:0] r_dstack[0:DSS**2];
always @(posedge i_clk)
    if (s_execute) begin
        if (w_op_literal)
            r_dstack[w_dspn] <= r_op;
        else if (w_op_dst_T || w_op_dst_N)
            r_dstack[w_dspn] <= w_alu[15:0];
    end

// RSP
reg [RSS-1:0] r_rsp /* verilator public */;
reg [RSS-1:0] w_rspn;
always @(*)
    casez ( { w_op_normal, w_op_rsp_inc, w_op_rsp_dec } )
        3'b101:  w_rspn = r_rsp + 1;
        3'b110:  w_rspn = r_rsp - 1;
        3'b111:  w_rspn = r_rsp + 1;
        default: w_rspn = r_rsp;
    endcase

always @(posedge i_clk)
    if (s_execute)
        r_rsp <= w_rspn;

// rstack
reg [W-1:0] r_rstack[0:RSS**2];
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


// state machine
always @(posedge i_clk)
begin
    case (r_state)
        FETCH: begin
            if (i_ack) begin
                r_state <= EXECUTE;
                //if (i_dat == 16'hffff) $finish();
            end
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

wire w_mem_access = s_fetch || (s_execute && (w_op_dst_MEMT || w_op_dst_MEMR || w_op_alu_MEMT || w_op_alu_MEMR));
assign o_cs = i_reset ? 0 : w_mem_access;

endmodule
