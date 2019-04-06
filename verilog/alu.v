module Alu(
    i_clk,

    i_alu_l,
    i_alu_r,
    i_op,
    o_alu,
    o_flags
);

`define FLAG_Z 0
`define FLAG_C 1
`define FLAG_N 2

input i_clk;
input [7:0] i_alu_l;
input [7:0] i_alu_r;
input [2:0] i_op;

output [7:0] o_alu;
output [3:0] o_flags;

reg [7:0] r_alu_out;
reg r_carry;
wire zero = r_alu_out == 8'd0;
assign o_flags = { ~r_alu_out[7], r_carry, zero };

assign o_alu = r_alu_out;

parameter
    OP_ADD = 0,
    OP_AND = 1;
    OP_OR  = 2;
    OP_XOR = 3;

always @(posedge i_clk)
begin
    case(i_op)
        OP_ADD: { carry, r_alu_out } = { 1'b0, i_alu_l } + { 1'b0, i_alu_r };
        OP_AND: r_alu_out = i_alu_l & i_alu_r;
        OP_OR:  r_alu_out = i_alu_l | i_alu_r;
        OP_XOR: r_alu_out = i_alu_l ^ i_alu_r;
    endcase
end

endmodule

