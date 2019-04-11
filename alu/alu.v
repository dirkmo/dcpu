module alu(
    i_alu_l,
    i_alu_r,
    i_op,
    o_alu,
    o_flags
);

`define FLAG_Z 0
`define FLAG_C 1
`define FLAG_N 2

input [7:0] i_alu_l;
input [7:0] i_alu_r;
input [2:0] i_op;

output [7:0] o_alu;
output [2:0] o_flags;

reg [7:0] r_alu_out;
reg r_carry;
wire zero = r_alu_out == 8'd0;
assign o_flags = { ~r_alu_out[7], r_carry, zero };

assign o_alu = r_alu_out;

parameter
    OP_ADD = 0,
    OP_ADC = 1,
    OP_AND = 2,
    OP_OR  = 3,
    OP_XOR = 4,
    OP_LSL = 5,
    OP_LSR = 6;

always @(*)
begin
    case(i_op)
        OP_ADD: { r_carry, r_alu_out } = { 1'b0, i_alu_l } + { 1'b0, i_alu_r };
        OP_ADC: { r_carry, r_alu_out } = { 1'b0, i_alu_l } + { 1'b0, i_alu_r } + { 8'd0, r_carry };
        OP_AND: r_alu_out = i_alu_l & i_alu_r;
        OP_OR:  r_alu_out = i_alu_l | i_alu_r;
        OP_XOR: r_alu_out = i_alu_l ^ i_alu_r;
        OP_LSL: { r_carry, r_alu_out } = { i_alu_l, 1'b0 } << i_alu_r;
        OP_LSR: { r_alu_out, r_carry } = { 1'b0, i_alu_l } >> i_alu_r;
    endcase
end

endmodule

