module Regfile(
);

input clk;
input [7:0] i_dat;

output [7:0] o_alu_l;
output [7:0] o_alu_r;
output [15:0] o_addr;

input [2:0] i_reg_sel; // load i_dat to reg
input i_load;
input i_inc;
input i_dec;
input i_inc16;
input i_dec16;

input [2:0] i_alu_l_sel; // which reg to output on alu_l
input [2:0] i_alu_r_sel; // which reg to output on alu_r
input [1:0] i_addr_sel; // which reg pair to output on addr

reg [7:0] registers[0:7];

assign o_alu_l = registers[i_alu_l_sel];
assign o_alu_r = registers[i_alu_r_sel];

always @(posedge clk)
begin
    if( i_load ) begin
        registers[i_reg_sel] <= i_dat;
    end

    if( i_inc ) begin
        registers[i_reg_sel] <= registers[i_reg_sel] + 1;
    end

    if( i_dec ) begin
        registers[i_reg_sel] <= registers[i_reg_sel] - 1;
    end

    if( i_inc16 ) begin
        //registers[i_reg_sel] <= registers[i_reg_sel] + 1;
    end

    if( i_dec16 ) begin
        //registers[i_reg_sel] <= registers[i_reg_sel] - 1;
    end
    
    if( i_reset ) begin
        // registers[] <= 0;
    end
end


endmodule

