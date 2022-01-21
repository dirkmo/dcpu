`default_nettype none

module top(
    input i_clk,
    input i_reset,
    output [15:0] o_addr,
    output [15:0] o_dat,
    input  [15:0] i_dat,
    input          i_ack,
    output         o_we,
    output         o_cs,
    output         o_uart_tx,
    input          i_uart_rx
);

wire [15:0] cpu_addr;
wire [15:0] o_cpu_dat;
wire [15:0] i_cpu_dat;
wire i_cpu_ack;
wire cpu_we;
wire cpu_cs;

// wire [15:0] i_master_data
// wire [15:0] o_master_data
// wire [15:0] o_master_addr
// wire i_master_ack;
// wire o_master_we;
// wire o_master_cs;
wire [15:0] i_uart_slave_dat;
wire [7:0] o_uart_slave_dat;
wire o_uart_slave_ack;
wire i_uart_slave_we;
reg uart_slave_cs;
wire o_uart_uart_reset;
wire o_uart_uart_int;
wire o_slave_ack;
reg mem_cs;
wire o_uart_int;
wire o_uart_reset;

dcpu cpu0(
    .i_reset(i_reset),
    .i_clk(i_clk),
    .o_addr(cpu_addr),
    .o_dat(o_cpu_dat),
    .i_dat(i_cpu_dat),
    .i_ack(i_cpu_ack),
    .o_we(cpu_we),
    .o_cs(cpu_cs),
    .i_irq(o_uart_int)
);

UartMasterSlave uart0(
    .i_clk(i_clk),
    .i_reset(i_reset),

    .i_master_data(0),
    .o_master_data(),
    .o_master_addr(),
    .i_master_ack(0),
    .o_master_we(),
    .o_master_cs(),

    .i_slave_data(o_cpu_dat[7:0]),
    .o_slave_data(o_uart_slave_dat),
    .i_slave_addr(cpu_addr[0]),
    .o_slave_ack(o_uart_slave_ack),
    .i_slave_we(cpu_we),
    .i_slave_cs(uart_slave_cs),
    .o_int(o_uart_int),

    .i_uart_rx(i_uart_rx),
    .o_uart_tx(o_uart_tx),

    .o_reset(o_uart_reset)
);

always @(posedge i_clk) begin
    uart_slave_cs <= 0;
    mem_cs <= 0;
    if (cpu_cs) begin
        if (cpu_addr >= 16'hfffe) begin
            uart_slave_cs <= 1;
        end else begin
            mem_cs <= 1;
        end
    end
end

assign i_cpu_dat = uart_slave_cs ? {8'h00, o_uart_slave_dat} : i_dat;
assign i_cpu_ack = uart_slave_cs ? o_slave_ack : i_ack;
assign o_dat = o_cpu_dat;
assign o_we = cpu_we;


endmodule
