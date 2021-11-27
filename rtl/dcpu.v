module dcpu(
    input  i_clk,
    input  i_reset,
    input  [15:0] i_dat,
    output reg [15:0] o_dat,
    output reg [15:0] o_addr,
    output reg o_we,
    output reg o_cs,
    input  i_ack,
    input  i_int
);

reg [15:0] r_op /* verilator public */;

// register indices
localparam
    ST = 13,
    SP = 14,
    PC = 15;

// status bits
localparam
    FZ = 0, // zero flag
    FC = 1; // carry flag

// conditionals
localparam
    NONE    = 3'd0,
    ZERO    = 3'd1,
    NONZERO = 3'd2,
    CARRY   = 3'd3,
    NOCARRY = 3'd4;

reg [15:0] R[0:15] /* verilator public */;


/* Implicit register loading

Load 10 bit constant to register (upper 6 bits will be set 0):
    
    0 0 <imm:10> <dst:4>                ld r0, #0x3ff lower 10 bits

For values greater than 4095, a second load instruction is needed.
This will overwrite the upper 8 bits of the register, and won't change the lower 8 bits.

    0 1 <imm:10> <dst:4>                ld r0, #0xff upper 8 bits (won't overwrite lower 8 bits)
*/
wire  w_op_ld_imm = ~r_op[15];
wire  w_op_ld_imm_l = w_op_ld_imm && ~r_op[14];
wire  w_op_ld_imm_h = w_op_ld_imm &&  r_op[14];
wire [9:0] w_ld_imm = r_op[13:4];

/* Load/store instructions

The only instructions that access memory via data bus.

Load word from memory at address rs+offset to register rd.

    100   <offs:5> <src:4> <dst:4>      ld rd, (rs+offs)

Store word in register rd to address rs+offset. Here, rs is the destination register,
and rd is the source register. 

    101   <offs:5> <src:4> <dst:4>      st (rs+offs), rd

Offset is a 2s complement number for negative offsets
*/

wire [3:0] w_dst   = r_op[3:0];
wire [3:0] w_src   = r_op[7:4];
wire [4:0] w_offs  = r_op[12:8];

wire w_op_ldst     = (r_op[15:14] == 2'b10);
wire w_op_ld       = w_op_ldst && ~r_op[13];
wire w_op_st       = w_op_ldst &&  r_op[13];

// ld/st addressing mode with constant offset
// ld rd, (rs+offs)
// st (rs+offs), rd
wire w_am_offs = ~r_op[13];
wire [15:0] w_offs_addr = (R[w_src] + {11'h0, w_offs});

/* Relative jump

If condition is true, jump to relative position. offs is a 2s complement number.
    1100 <cond:3> <offs:9>   rjp offs, Conditions: none, c, z, nc, nz
*/
wire w_op_rjp = r_op[15:12] == 4'b1100;
wire [2:0] w_op_rjp_cond = r_op[11:9];
wire [8:0] w_rjp_offs = r_op[8:0];
wire w_rjp_cond =  (w_op_rjp_cond == NONE) ||
                  ((w_op_rjp_cond == ZERO)    &&  R[ST][FZ]) ||
                  ((w_op_rjp_cond == NONZERO) && ~R[ST][FZ]) ||
                  ((w_op_rjp_cond == CARRY)   &&  R[ST][FC]) ||
                  ((w_op_rjp_cond == NOCARRY) && ~R[ST][FC]);

wire [15:0] w_rjp_addr = R[PC] + { {8{w_rjp_offs[8]}}, w_rjp_offs[7:0] };

/*
    1101 0000 <op:1> <cond:3> <dst:4>   jmp rd, branch rd. Conditions: none, c, z, nc, nz
*/



/*
1101 <aluop:4> <src:4> <dst:4>   alu rd, rs
        ld rd, rs  (rd <- rs)


push pop

ret
*/

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
        if (w_op_ld_imm_l)
            R[w_dst] <= {6'h0, w_ld_imm};
        else if (w_op_ld_imm_h)
            R[w_dst] <= {w_ld_imm[7:0], R[w_dst][7:0]};
        else if (w_op_ld && i_ack)
            R[w_dst] <= i_dat;
        else if (w_op_rjp && w_rjp_cond)
            R[15] <= w_rjp_addr;
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
        if (r_op == 16'hffff) begin
            // $finish();
        end


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

// o_dat
always @(*) begin
    if (s_execute && w_op_st) begin
        o_dat = R[w_dst];
    end else begin
        o_dat = 0;
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
    o_we = (s_execute && w_op_st);


endmodule
