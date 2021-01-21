module top(
    i_clk,
    i_reset
);

input i_clk;
input i_reset;

wire [15:0] dat_to_cpu;
wire [15:0] dat_from_cpu;
wire [15:0] cpu_addr;
wire rw;

dcpu cpu(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_int(0),
    .o_addr(cpu_addr),
    .i_dat(dat_to_cpu),
    .o_dat(dat_from_cpu),
    .o_rw(rw)
);

ram64k_16 ram0(
    .i_clk(i_clk),
    .i_addr(cpu_addr[15:0]),
    .i_dat(dat_from_cpu),
    .o_dat(dat_to_cpu),
    .i_we(~rw),
    .i_cs(1'b1)
);

endmodule