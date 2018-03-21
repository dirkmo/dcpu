/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
module fetcher(
    i_clk,
    i_reset,


    o_wb_addr,
    o_wb_cyc,
    o_wb_stb,
    i_wb_dat,
    i_wb_ack,
    i_wb_err,


    i_fetch,
    i_pc,
    o_pc,
    o_pc_wr,
    

    o_instruction,
    o_done
);

input i_clk;
input i_reset;

input [31:0] i_wb_dat;
output reg [31:0] o_wb_addr;
output reg o_wb_cyc;
output reg [3:0] o_wb_stb;
input i_wb_ack;
input i_wb_err;

input i_fetch; // shall be high for one clock cycle
input [31:0] i_pc;
output reg [31:0] o_pc;
output reg o_pc_wr;

output reg [47:0] o_instruction;
output reg o_done;

reg fetch_next; // shall be high for one clock cycle

reg [1:0] fetchcount; // number of halfwords fetched

// 47..43 opcode
// 42..40 cc
// 39..36 Ra
// 35..33 amode

parameter
    AMODE16 = 3'b000,
    AMODE32 = 3'b001,
    AMODE48 = 3'b010;

wire aligned = ~i_pc[1];
wire [2:0] amode = o_instruction[35:33];

always @(posedge i_clk) begin
    o_pc_wr <= 0;
    if( fetch_next ) begin
        o_pc <= i_pc + (aligned ? 4 : 2);
        o_pc_wr <= 1;
    end
end

always @(posedge i_clk) begin
    if( i_fetch || i_reset ) begin
        fetchcount <= 0;
    end else if( i_wb_ack && o_wb_cyc ) begin
        fetchcount <= fetchcount + (aligned ? 2 : 1);
    end
end

always @(posedge i_clk) begin
    if( i_fetch ) begin
        o_wb_addr <= i_pc;
        o_wb_stb <= aligned ? 4'b1111 : 4'b0011;
    end else if( fetch_next ) begin
        o_wb_addr <= i_pc;
        o_wb_stb <= 4'b1111;
    end

    if( i_reset || (o_wb_cyc && (i_wb_err || i_wb_ack)) ) begin
        o_wb_addr <= 0;
        o_wb_cyc <= 0;
        o_wb_stb <= 0;
    end
end


/*
op(5) cc(3) ra(4) am(3) | [Immediates...]


Short Instruction:
    op(5) cc(3) ra(4) 000

    NOP, INC, DEC


12/28 Bit immediate:
    op(5) cc(3) ra(4) 001 | rb(4) imm(12)
    op(5) cc(3) ra(4) 010 | rb(4) imm(12) imm(16)

    ADD rb+#imm, ra
    LD  (rb+#imm), ra
    ST  rb, (ra+#imm)


32Bit immediate:
    op(5) cc(3) ra(4) 011 | imm(32)

    ADD #imm, ra
    LD  (#imm), ra
    ST  ra, (#imm)

*/


endmodule
