`default_nettype none

module UartMasterSlave(
    input  i_clk,
    input  i_reset,

    input  [15:0] i_master_data,
    output [15:0] o_master_data,
    output [15:0] o_master_addr,
    input  i_master_ack,
    output o_master_we,
    output o_master_cs,

    input  [7:0] i_slave_data,
    output [7:0] o_slave_data,
    input        i_slave_addr,
    output       o_slave_ack,
    input        i_slave_we,
    input        i_slave_cs,
    output       o_int,

    input  i_uart_rx,
    output o_uart_tx,

    output o_reset
);

parameter
    BAUDRATE /* verilator public */ = 25000000 / 2,
    SYS_FREQ /* verilator public */ = 25000000;

wire uart_tx_ready /* verilator public */;
wire uart_rx_received_pulse /* verilator public */;
wire uart_tx_start /* verilator public */;
wire received_pulse_to_protocol;
wire fifo_rx_push_pulse;
wire fifo_rx_pop;
wire fifo_tx_push;
reg  r_fifo_tx_pop;
wire prot_push;
wire fifo_tx_full;
wire fifo_rx_full;
wire fifo_rx_empty;
wire fifo_tx_empty;
reg  r_prot_buffer_full;
wire [7:0] uart_rx_dat;
wire [7:0] uart_tx_dat;
wire [7:0] uart_prot_tx_dat;
wire [7:0] fifo_tx_dat;
wire [7:0] fifo_rx_dat;

UartProtocol uartprotocol0 (
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_ack(i_master_ack),
    .i_dat(i_master_data),
    .o_dat(o_master_data),
    .o_addr(o_master_addr),
    .o_we(o_master_we),
    .o_cs(o_master_cs),
    .i_uart_received_pulse(received_pulse_to_protocol),
    .i_uart_dat( {1'b0, uart_rx_dat[6:0]} ),
    .i_uart_send_ready(~r_prot_buffer_full),
    .o_uart_send_pulse(prot_push),
    .o_uart_dat(uart_prot_tx_dat),
    .o_reset(o_reset)
);

fifo #(.DEPTH(3)) fifo_rx(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_dat(uart_rx_dat),
    .o_dat(fifo_rx_dat),
    .i_push(fifo_rx_push_pulse),
    .i_pop(fifo_rx_pop),
    .o_empty(fifo_rx_empty),
    .o_full(fifo_rx_full)
);

uart_rx #(.TICK(SYS_FREQ/BAUDRATE)) uart_rx0(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .o_dat(uart_rx_dat),
    .o_received_pulse(uart_rx_received_pulse),
    .rx(i_uart_rx)
);

assign received_pulse_to_protocol =  uart_rx_dat[7] && uart_rx_received_pulse;
assign fifo_rx_push_pulse         = ~uart_rx_dat[7] && uart_rx_received_pulse;


fifo #(.DEPTH(2)) fifo_tx(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_dat(i_slave_data),
    .o_dat(fifo_tx_dat),
    .i_push(fifo_tx_push),
    .i_pop(r_fifo_tx_pop),
    .o_empty(fifo_tx_empty),
    .o_full(fifo_tx_full)
);

reg [7:0] prot_buffer;
always @(posedge i_clk)
    if(~r_prot_buffer_full)
        prot_buffer <= uart_prot_tx_dat;

always @(posedge i_clk)
    if(prot_push)
        r_prot_buffer_full <= 1'b1;
    else if(prot_pop)
        r_prot_buffer_full <= 1'b0;


assign uart_tx_dat   = ~fifo_tx_empty ? {1'b0, fifo_tx_dat[6:0]} : {1'b1, prot_buffer[6:0]};
assign uart_tx_start = (~fifo_tx_empty || r_prot_buffer_full) && uart_tx_ready;
wire prot_pop        =   fifo_tx_empty && r_prot_buffer_full  && uart_tx_ready;

always @(posedge i_clk)
    r_fifo_tx_pop <= ~r_fifo_tx_pop && ~fifo_tx_empty && uart_tx_ready;

uart_tx #(.TICK(SYS_FREQ/BAUDRATE)) uart_tx0(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_dat(uart_tx_dat),
    .i_start(uart_tx_start),
    .o_ready(uart_tx_ready),
    .tx(o_uart_tx)
);

//--------------------------------------------
// bus slave

// 0: status
// 1: rx/tx register

wire [7:0] status = { 4'd0, fifo_tx_full, fifo_tx_empty, fifo_rx_full, fifo_rx_empty };

assign o_slave_data = i_slave_addr ? fifo_rx_dat : status;

assign o_slave_ack = i_slave_cs;

assign fifo_tx_push = i_slave_cs && i_slave_we && i_slave_addr;
assign fifo_rx_pop = i_slave_cs && ~i_slave_we && ~i_slave_addr;
        

endmodule
