/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
module regfile(
    i_clk, i_reset,

    i_sel_a,
    i_sel_b,

    i_wr_a,
    i_wr_b,

    i_reg_a,
    i_reg_b,
    o_reg_a,
    o_reg_b,
    o_reg_cc,
    o_reg_pc
);


input i_clk;
input i_reset;

input [3:0] i_sel_a;
input [3:0] i_sel_b;
input i_wr_a;
input i_wr_b;

output [31:0] o_reg_a;
output [31:0] o_reg_b;
output [31:0] o_reg_cc;
output [31:0] o_reg_pc;

input [31:0] i_reg_a;
input [31:0] i_reg_b;

reg [31:0] registers[15:0];

assign o_reg_a = registers[i_sel_a];
assign o_reg_b = registers[i_sel_b];
assign o_reg_cc = registers[4'd14];
assign o_reg_pc = registers[4'd15];

integer i;

always @(posedge i_clk)
begin
    if( i_wr_a ) begin
        registers[i_sel_a] <= i_reg_a;
    end
    if( i_wr_b ) begin
        registers[i_sel_b] <= i_reg_b;
    end

    if( i_reset == 1'b1 ) begin
        for( i = 0; i < 16; i = i+1 ) begin
            registers[i] <= 32'd0;
        end
    end
end


endmodule
