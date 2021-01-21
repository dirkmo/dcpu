module ram64k_16(
    i_clk,
    i_addr,
    i_dat,
    o_dat,
    i_we,
    i_cs
);

input i_clk;

input  [15:0] i_dat;
output reg [15:0] o_dat;
input [15:0] i_addr;
input i_we;

input i_cs;

reg [15:0] mem[2**15-1:0];

// read access
always @(posedge i_clk or negedge i_clk)
begin
    case(i_addr)
// `ifdef ROM
// `include "romdata.inc"
// `endif
        default: o_dat <= mem[i_addr[15:1]];
    endcase
end

// write access
always @(posedge i_clk)
begin
    if( i_cs && i_we ) begin
        mem[i_addr[15:1]] <= i_dat;
        $display("write %04X <- %04X", i_addr, i_dat);
    end
end

endmodule