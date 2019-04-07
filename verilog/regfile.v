module Regfile(
    i_clk,
    i_dat,

    o_alu_l,
    o_alu_r,
    o_addr,

    i_load_reg_sel,
    i_load,

    i_alu_l_sel,
    i_alu_r_sel,
    i_addr_sel
);

`define REGCOUNT 12

input i_clk;
input [7:0] i_dat;

output [7:0] o_alu_l;
output [7:0] o_alu_r;
output [15:0] o_addr;

input [3:0] i_load_reg_sel; // load reg
input i_load; // load i_dat to reg

input [3:0] i_alu_l_sel; // which reg to output on alu_l
input [3:0] i_alu_r_sel; // which reg to output on alu_r
input [2:0] i_addr_sel; // which reg pair to output on addr bus

reg [7:0] registers[0:`REGCOUNT]; // AB(0,1) CD(2,3) EF(4,5) GH(6,7) SP(8,9) PC(10,11)

assign o_alu_l = i_alu_l_sel < `REGCOUNT ? registers[i_alu_l_sel] : i_dat;
assign o_alu_r = i_alu_r_sel < `REGCOUNT ? registers[i_alu_r_sel] : i_dat;
assign o_addr  = { registers[{i_addr_sel,1}], registers[{i_addr_sel,0}] };

always @(posedge i_clk)
begin
    if( i_load )
        registers[i_load_reg_sel] <= i_dat;
end


endmodule

