module top(
    i_clk,
    i_reset
);

input i_clk;
input i_reset;

wire [15:0] o_cpu_dat;
wire [15:0] i_cpu_dat;
wire [31:0] addr;
wire cyc;
wire we;
wire intr = 1'b0;
wire [1:0] stb;

`define MEMAW 16
`define NSLAVES 1
wire [`NSLAVES-1:0] slaveselect;

wire [15:0] blkmem0_dat;
wire blkmem0_ack;
wire blkmem0_cyc = slaveselect[0];

assign i_cpu_dat = slaveselect[0] ? blkmem0_dat :
                                    16'dX;

wire ack = slaveselect[0] ? blkmem0_ack :
                            1'b0;

syscon #(.NSLAVES(`NSLAVES)) syscon0 (
    .i_addr(addr),
    .i_cyc(cyc),
    .o_slaveselect(slaveselect)
);

blkmem #(.AW(`MEMAW-1)) blkmem0 (
    .i_clk(i_clk),
    .i_dat(o_cpu_dat),
    .o_dat(blkmem0_dat),
    .i_addr(addr[`MEMAW-1:1]),
    .i_we(we),
    .i_cyc( blkmem0_cyc ),
    .i_stb( stb ),
    .o_ack( blkmem0_ack )
);

dcpu cpu0(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_ack(ack),
    .i_dat(i_cpu_dat),
    .o_cyc(cyc),
    .o_stb(stb),
    .o_dat(o_cpu_dat),
    .o_addr(addr),
    .o_we(we),
    .i_int(intr)
);

endmodule

