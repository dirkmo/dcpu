/* verilator lint_off PINCONNECTEMPTY */

`timescale 1ns / 1ps

module blkmem(
    i_clk,

    i_dat,
    o_dat,
    i_addr,
    i_we,
    i_cyc,
    i_stb,
    o_ack
);

//`define ROM

parameter AW = 15;

input i_clk;

input      [15:0] i_dat;
output reg [15:0] o_dat;
input [AW-1:0] i_addr;
input i_we;
input i_cyc;
input [1:0] i_stb;
output o_ack;

reg [15:0] memout;
assign o_dat[15:8] = i_stb[1] ? memout[15:8] : 8'hZ;
assign o_dat[7:0]  = i_stb[0] ? memout[7:0]  : 8'hZ;
assign o_ack = i_cyc;

reg [15:0] mem[2**AW-1:0];

// read access with ROM
always @(i_addr)
begin
    case(i_addr)
`ifdef ROM
`include "romdata.inc"
`endif
        default: memout = mem[i_addr];
    endcase
end

// write access
always @(posedge i_clk)
begin
    if( i_cyc && i_we ) begin
        if( i_stb[0] ) mem[i_addr][7:0] <= i_dat[7:0];
        if( i_stb[1] ) mem[i_addr][15:8] <= i_dat[15:8];
    end
end

endmodule
