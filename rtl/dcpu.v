module dcpu(
    input  i_clk,
    input  i_reset,
    input  [15:0] i_dat,
    output [15:0] o_dat,
    output reg [15:0] o_addr,
    output reg o_we,
    output reg o_cs,
    input  i_ack,
    input  i_int
);

reg [15:0] r_op;

/*
0 <imm:11> <dst:4>                  ld r0, #0x1ff lower 11 bits
*/

wire     w_op_ld_imm = ~r_op[15];
wire [10:0] w_ld_imm = r_op[14:4];

/*
100   <offs:5> <src:4> <dst:4>      ld rd, (rs+offs)
101   <offs:5> <src:4> <dst:4>      st (rs+offs), rd
*/

wire [3:0] w_dst   = r_op[3:0];
wire [3:0] w_src   = r_op[7:4];
wire [4:0] w_offs  = r_op[12:8];

wire w_op_ldst     = (r_op[15:14] == 2'b10);
wire w_op_ld       = w_op_ldst && ~r_op[13];
wire w_op_st       = w_op_ldst &&  r_op[13];

// ld/st addressing mode with constant offset?
// ld rd, (rs+offs)
// st (rs+offs), rd
wire w_am_offs = ~r_op[13];
wire [15:0]  w_offs_addr = (R[w_src] + {11'h0, w_offs}); // TODO: w_offs als signed number

/*
11* noch verfügar

1100 <aluop:4> <src:4> <dst:4>   alu rd, rs

1101 0 <cond:3> <op:4> <dst:4>   jmp rd, branch rd. Conditions: none, c, z, nc, nz

push pop

ret
*/

parameter
    ST = 13,
    SP = 14,
    PC = 15;

reg [15:0] R[0:15] /* verilator public */;

parameter
    FETCH   = 0,
    EXECUTE = 1;

reg  r_state /* verilator public */;
wire s_fetch   = (r_state == FETCH);
wire s_execute = (r_state == EXECUTE);


// R[]
always @(posedge i_clk)
    if (i_reset)
        R[PC] <= 0;
    else if (s_fetch && i_ack) begin
        R[PC] <= R[PC] + 1;
    end else if (s_execute) begin
        if (w_op_ld_imm)
            R[w_dst] <= {5'h0, w_ld_imm};
    end

always @(posedge i_clk)
begin
    if (s_fetch) begin
        if (i_ack) begin
            r_state <= EXECUTE;
        end
    end else if (s_execute) begin
        if (~w_op_ldst || i_ack ) begin
            r_state <= FETCH;
        end
    end
    if (i_reset)
        r_state <= FETCH;
end

// r_op
always @(posedge i_clk)
    if (i_reset)
        r_op <= 0;
    else if (s_fetch && i_ack)
        r_op <= i_dat;
    else if (s_execute)
        if (r_op == 16'hffff)
            $finish();


// o_addr
always @(*) begin
    if (s_fetch)
        o_addr = R[PC];
    else if (w_op_ldst) begin
        o_addr = w_offs_addr;
    end else begin
        o_addr = 0;
    end

end


// o_cs
always @(*)
    if      (i_reset)   o_cs = 0;
    else if (s_fetch)   o_cs = 1;
    else if (w_op_ldst) o_cs = 1;
    else                o_cs = 0;
    
// o_we
always @(*)
    if      (i_reset) o_we = 0;
    else if (w_op_st) o_we = 1;
    else              o_we = 0;



endmodule
