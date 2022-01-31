`default_nettype none

module dcpu(
    input i_reset,
    input i_clk,

    output [15:0] o_addr,
    output [15:0] o_dat,
    input  [15:0] i_dat,
    input          i_ack,
    output         o_we,
    output         o_cs,

    input          i_irq // TODO: implement interrupt handling
);

parameter
    DSS /* verilator public */ = 4, // data stack size: 2^DSS
    RSS /* verilator public */ = 4; // return stack size: 2^RSS

localparam
    FETCH = 0,
    EXECUTE = 1;

reg r_state /* verilator public */; // state machine
reg r_state_prev;
wire w_state_changed /* verilator public */ = (r_state_prev != r_state);
always @(posedge i_clk)
    r_state_prev <= r_state;


reg [15:0] r_pc /* verilator public */; // program counter

wire s_fetch   /* verilator public */ = (r_state == FETCH);
wire s_execute /* verilator public */ = (r_state == EXECUTE);

`ifdef SIM
wire w_sim_next /* verilator public */ = w_state_changed && s_execute;
`endif


reg [15:0] r_op /* verilator public */; // instruction register
always @(posedge i_clk)
    if (i_reset)
        r_op <= 0;
    else if (s_fetch && i_ack)
        r_op <= i_dat;

reg [15:0] T /* verilator public */; // top of dstack
reg [15:0] N /* verilator public */; // 2nd on dstack
reg [15:0] R /* verilator public */; // top of rstack

/* Instruction types:

0 <addr:15>                             call
1 00 <imm:13>                           lit.l
1 01 <unused:4> <return:1> <imm:8>      lit.h

1 10 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>  alu

1 11 <cond:3> <imm:10>                  rjp
*/

// call: 0 <addr:15>
wire w_op_call = ~r_op[15];
// call addr field
wire [14:0] w_op_call_addr = r_op[14:0];

// push literal
wire w_op_lit  = (r_op[15:14] == 2'b10);

// literal lower part: 100 <imm:13>
wire w_op_litl = w_op_lit & ~r_op[13];
// imml field
wire [12:0] w_op_litl_val = r_op[12:0];

// literal upper part: 101 <unused:4> <return:1> <imm:8>
`ifdef SIM
wire w_op_lith = w_op_lit && r_op[13] && (r_op[12:9] != 4'b1111);
`else
wire w_op_lith = w_op_lit && r_op[13];
`endif

// immh field
wire [7:0] w_op_lith_val = r_op[7:0];
// return field
wire w_op_lith_return = r_op[8];

`ifdef SIM
// for simulation
wire w_op_sim_end = w_op_lit && (r_op[13:9] == 5'b11111) && (r_op[8:0] == 9'h0);
`endif

// relative jumps: 111 <cond:3> <offs:10>
// hint: rjumps with condition pop the dstack
wire w_op_rjp  = (r_op[15:13] == 3'b111);
// rjp fields
wire [2:0] w_op_rjp_cond = r_op[12:10];
wire [9:0] w_op_rjp_offs  = r_op[9:0];

// alu ops: 110 <unused:1> <alu:5> <return:1> <dst:2> <dsp:2> <rsp:2>
wire w_op_alu  = (r_op[15:13] == 3'b110);
// alu-op fields
wire       w_op_alu_unused = r_op[12];
wire [4:0] w_op_alu_op  = r_op[11:7];
wire       w_op_alu_ret = r_op[6];
wire [1:0] w_op_alu_dst = r_op[5:4];
wire [1:0] w_op_alu_dsp = r_op[3:2];
wire [1:0] w_op_alu_rsp = r_op[1:0];

/* alu-op dst: destination of write operation
    00 T (top of dstack)
    01 R
    10 PC
    11 [T]
*/
wire w_op_alu_dst_T    = w_op_alu && (w_op_alu_dst == 2'b00);
wire w_op_alu_dst_R    = w_op_alu && (w_op_alu_dst == 2'b01);
wire w_op_alu_dst_PC   = w_op_alu && (w_op_alu_dst == 2'b10);
wire w_op_alu_dst_MEMT = w_op_alu && (w_op_alu_dst == 2'b11);


// w_return: is true when return shall be performed
wire w_return = (w_op_alu && w_op_alu_ret) || (w_op_lith && w_op_lith_return);


/*
alu: alu operation
*/
reg [16:0] w_alu;
reg r_carry;
wire carry = w_alu[16];

always @(posedge i_clk)
    if (s_execute)
        r_carry <= carry;

always @(*)
    case (w_op_alu_op[4:0])
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
        5'h0a: w_alu = {17{($signed(N) < $signed(T))}};
        5'h0b: w_alu = {17{(N < T)}};
        5'h0c: w_alu = {T[0], 1'b0, T[15:1]}; // T >> 1
        5'h0d: w_alu = {9'h00, T[15:8]}; // T >> 8
        5'h0e: w_alu = {T[15:0], 1'b0}; // T << 1
        5'h0f: w_alu = {1'b0, T[7:0], 8'h00}; // T << 8
        5'h10: w_alu = (T==0) ? {1'b0, N} : {1'b0, r_pc+16'b1}; // condition for JZ
        5'h11: w_alu = (T!=0) ? {1'b0, N} : {1'b0, r_pc+16'b1}; // condition for JNZ
        5'h12: w_alu = {16'h00, r_carry};
        5'h13: w_alu = {1'b0, ~T};
        5'h14: w_alu = {1'b0, T}; // for NOP
        default: w_alu = 0;
    endcase

// side effects for alu operations
wire w_op_alu_nop  = w_op_alu && (w_op_alu_op == 5'h14);
wire w_op_alu_MEMT = w_op_alu && (w_op_alu_op == 5'h3) && ~w_op_alu_nop;
wire w_op_alu_jz   = w_op_alu && (w_op_alu_op == 5'h10);
wire w_op_alu_jnz  = w_op_alu && (w_op_alu_op == 5'h11);
wire w_op_alu_j_cond_fullfilled = (w_op_alu_jz  && (T==0))
                               || (w_op_alu_jnz && (T!=0));
wire w_op_alu_RPC_branch_taken = w_op_alu && w_op_rsp_RPC && w_op_alu_j_cond_fullfilled;

/*
dsp: dstack pointer handling
     00 nothing
     01 dsp+1
     10 dsp-1
     11 nothing
*/
wire w_op_dsp_inc = (w_op_alu_dsp == 2'b01);
wire w_op_dsp_dec = (w_op_alu_dsp == 2'b10);

/*
rsp: rstack pointer handling and push PC to rstack
     00 nothing
     01 rsp+
     10 rsp-
     11 rsp+, R <- PC (for CALL: push PC to rstack an rsp+)
*/
wire w_op_rsp_RPC = (w_op_alu_rsp == 2'b11);
wire w_op_rsp_inc = (w_op_alu_rsp == 2'b01);
wire w_op_rsp_dec = (w_op_alu_rsp == 2'b10);

// rjp
wire [15:0] w_rjp_pc = r_pc + {{6{w_op_rjp_offs[9]}}, w_op_rjp_offs};

wire w_op_rjp_cond_always      = ~w_op_rjp_cond[2];
wire w_op_rjp_cond_zero        = (w_op_rjp_cond[2:0] == 3'b100) && (T==0);
wire w_op_rjp_cond_notzero     = (w_op_rjp_cond[2:0] == 3'b101) && (T!=0);
wire w_op_rjp_cond_negative    = (w_op_rjp_cond[2:0] == 3'b110) && T[15];
wire w_op_rjp_cond_notnegative = (w_op_rjp_cond[2:0] == 3'b111) && ~T[15];

wire w_op_rjp_with_cond = w_op_rjp && w_op_rjp_cond[2];

wire w_op_rjp_cond_fullfilled =
    w_op_rjp_cond_always ||
    w_op_rjp_cond_zero ||
    w_op_rjp_cond_notzero ||
    w_op_rjp_cond_negative ||
    w_op_rjp_cond_notnegative;


// PC
reg [15:0] w_pcn;
always @(*)
    if (w_op_alu_dst_PC)
        w_pcn = w_alu[15:0];
    else if (w_op_call)
        w_pcn = {1'b0, w_op_call_addr[14:0]};
    else if (w_op_rjp && w_op_rjp_cond_fullfilled)
        w_pcn = w_rjp_pc;
    else if (w_return)
        w_pcn = R;
    else 
        w_pcn = r_pc + 1;

always @(posedge i_clk)
    if(i_reset)
        r_pc <= 0;
    else if(s_execute && w_state_changed)
        r_pc <= w_pcn;


// DSP
reg [DSS-1:0] r_dsp /* verilator public */;
reg [DSS-1:0] w_dspn;
always @(*)
    if (w_op_alu) begin
        if (w_op_dsp_inc)
            w_dspn = r_dsp + 1;
        else if (w_op_dsp_dec)
            w_dspn = r_dsp - 1;
        else
            w_dspn = r_dsp;
    end else if (w_op_litl) begin
        w_dspn = r_dsp + 1;
    end else if (w_op_rjp_with_cond) begin
        w_dspn = r_dsp - 1;
    end else
        w_dspn = r_dsp;

always @(posedge i_clk)
    if (i_reset)
        r_dsp <= {DSS{1'b1}};
    else if(s_execute && w_state_changed)
        r_dsp <= w_dspn;

// dstack
reg [15:0] r_dstack[0:2**DSS-1] /* verilator public */;
always @(posedge i_clk)
    if (s_execute && w_state_changed) begin
        if (w_op_litl)
            r_dstack[w_dspn] <= {3'b000, w_op_litl_val[12:0]};
        else if (w_op_lith)
            r_dstack[w_dspn] <= {w_op_lith_val[7:0], r_dstack[r_dsp][7:0]};
        else if (w_op_alu_dst_T && ~w_op_alu_nop)
            r_dstack[w_dspn] <= w_alu[15:0];
    end

// RSP
reg [RSS-1:0] r_rsp /* verilator public */;
reg [RSS-1:0] w_rspn;
always @(*) begin
    if (w_op_alu) begin
        if (w_op_rsp_inc) begin
            w_rspn = r_rsp + 1;
        end else if (w_op_rsp_RPC && w_op_alu_j_cond_fullfilled) begin
            w_rspn = r_rsp + 1;
        end else if (w_op_rsp_dec || w_return) begin
            w_rspn = r_rsp - 1;
        end else begin
            w_rspn = r_rsp;
        end
    end else if (w_return) begin
        w_rspn = r_rsp - 1;
    end else if (w_op_call) begin
        w_rspn = r_rsp + 1;
    end else begin
        w_rspn = r_rsp;
    end
end

always @(posedge i_clk)
    if (i_reset)
        r_rsp <= {RSS{1'b1}};
    else if (s_execute && w_state_changed)
        r_rsp <= w_rspn;

// rstack
reg [15:0] r_rstack[0:2**RSS-1] /* verilator public */;
always @(posedge i_clk)
    if (s_execute && w_state_changed) begin
        r_rstack[w_rspn] <= w_op_call ? (r_pc+1) :
            w_op_alu_RPC_branch_taken ? (r_pc+1) :
      w_op_alu_dst_R && ~w_op_alu_nop ? w_alu[15:0] :
                                        r_rstack[w_rspn];
    end

always @(posedge i_clk)
    if (s_fetch) begin
        R <= r_rstack[r_rsp];
        T <= r_dstack[r_dsp];
        N <= r_dstack[r_dsp - 1];
    end

wire w_mem_access_MEMT  = (w_op_alu_MEMT || w_op_alu_dst_MEMT);
wire w_op_mem_access    = s_execute && w_op_alu && w_mem_access_MEMT;
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

`ifdef SIM
// for simulation
always @(posedge i_clk)
    if (w_op_sim_end)
        $finish();
`endif

endmodule
