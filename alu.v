module alu(
    i_clk,
    i_reset,

    op,
    A,
    B,
    out,
    flags
);

input i_clk;
input i_reset;
input [4:0] op;

output [31:0] A;
output [31:0] B;
output [31:0] out;
output [7:0] flags;

parameter
    SUB    = 4'h0,
    AND    = 4'h1,
    ADD    = 4'h2,
    OR     = 4'h3,
    XOR    = 4'h4,
    LSR    = 4'h5,
    LSL    = 4'h6,
    ASR    = 4'h7;

reg [31:0] out_r;
assign out = out_r;

wire zflag = out_r == '32'd0;


always @(*) begin
    case( op ) begin
        SUB: out_r = A - B;
        AND: out_r = A & B;
        ADD: out_r = A + B;
        OR:  out_r = A | B;
        XOR: out_r = A ^ B;
        LSR: out_r = A << B;
        LSL: out_r = A >> B;
        ASR: out_r = 32'd0;
        BREV: out_r = ~A;
    end
end

endmodule
