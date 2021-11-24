module dcpu(
    input  i_clk,
    input  i_reset,
    input  [15:0] i_dat,
    output [15:0] o_dat,
    output reg [15:0] o_addr,
    output o_we,
    output o_cs,
    input  i_ack,
    input  i_int
);

/*
0 00 <dst:4> <src:4> <offs:4> ld r0, r1+offs
0 01 <dst:4> <src:4> <offs:4> ld r0, r1+r2
0 10 <dst:4> <src:4> <offs:4> st r0+offs, r1
0 11 <dst:4> <src:4> <offs:4> st r0+r1, r2
*/

reg [15:0] r_op;
wire w_ld       =         (r_op[15:14] == 2'b00);
wire w_st       =         (r_op[15:14] == 2'b01);
wire w_ld_offs  = w_ld && (r_op[13]    == 1'b0);
wire w_ld_roffs = w_ld && (r_op[13]    == 1'b1);
wire w_st_offs  = w_st && (r_op[13]    == 1'b0);
wire w_st_roffs = w_st && (r_op[13]    == 1'b1);

/*
1 00 <dst:4> <imm:9>          ld r0, #0x1ff lower 9 bits
1 01 <dst:4> <imm:9>          ld r0, #0xff upper 8 bits (overwrite bit #9)

1 10 <dst:4> <src:4> 0 <aluop:4>  alu r0, r1

1 11 <reg:4> <op:4>  0 0000    jmp, branch

1 11 0000    0000    1 0000    int
1 11 0000    0000    1 0001    ret
1 11 0000    0000    1 0010    reti
*/

parameter
    ST = 13,
    SP = 14,
    PC = 15;

reg [15:0] R[0:15];

parameter
    FETCH   = 0,
    EXECUTE = 1;

reg  r_state;
wire s_fetch   = (r_state == FETCH);
wire s_execute = (r_state == EXECUTE);


always @(posedge i_clk)
    if (i_reset)
        R[PC] <= 0;
    else if (s_execute) begin
        R[PC] <= R[PC] + 1;
    end

always @(posedge i_clk)
    if (i_reset) {
        r_state <= FETCH;
    } else begin
        r_state <= r_state + 1'b1;
    end

always @(posedge i_clk) begin
    if (s_fetch)
        o_addr = R[PC];
    else if (w_ld) begin
        o_addr = 
    end else if (w_st) begin
        s
    end
end

endmodule
