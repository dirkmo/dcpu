module dcpu(
    i_clk
);

input i_clk;

wire [7:0] alu_l;
wire [7:0] alu_r;
wire [7:0] databus;
wire [15:0] addrbus;
wire [2:0] op;
wire [2:0] flags;

wire load;
wire [3:0] load_reg_sel;
wire [3:0] alu_l_sel;
wire [3:0] alu_r_sel;
wire [2:0] addr_sel;


Alu alu0(
    .i_clk(i_clk),

    .i_alu_l(alu_l),
    .i_alu_r(alu_r),
    .i_op(op),
    .o_alu(databus),
    .o_flags(flags)
);


Regfile regfile0(
    .i_clk(i_clk),
    .i_dat(databus),

    .o_alu_l(alu_l),
    .o_alu_r(alu_r),
    .o_addr(addrbus),

    .i_load_reg_sel(load_reg_sel),
    .i_load(load),

    .i_alu_l_sel(alu_l_sel),
    .i_alu_r_sel(alu_r_sel),
    .i_addr_sel(addr_sel)
);

endmodule
