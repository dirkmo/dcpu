/* verilator lint_off UNUSED */
`default_nettype none

module uart_tx(
    i_clk,
    i_reset,
    i_dat,
    i_start,
    o_ready,
    tx
);


input i_clk;
input i_reset;
input [7:0] i_dat;
input i_start;
output o_ready;
output tx;

parameter TICK = 21; // TICK = SYS_FREQ/BAUDRATE

//---------------------------------------------

reg [7:0] r_data;
always @(posedge i_clk)
    if (i_start)
        r_data <= i_dat;

//---------------------------------------------
// uart tx

// tx baudrate generator
reg [8:0] baud_tx;

wire tick_tx = (baud_tx[8:0] == TICK[8:0]);
wire idle;
always @(posedge i_clk) begin
	if(idle || tick_tx) begin
		baud_tx <= 0;
	end else begin
		baud_tx <= baud_tx + 1;
	end
end


//---------------------------------------------
// State machine

localparam
    SEND      = 4'd0,
    STOPBIT1  = 4'd8,
    STOPBIT2  = 4'd9,
    INTERRUPT = 4'd10,
    IDLE      = 4'd11,
    STARTBIT  = 4'd12;

reg [3:0] state_tx = IDLE;
wire [2:0] bit_idx = state_tx[2:0];

assign tx = (state_tx  < STOPBIT1) ? r_data[ bit_idx ] :
            (state_tx == STARTBIT) ? 1'b0 : // start bit
                                     1'b1;  // idle & stop bit

assign idle = (state_tx == IDLE);

always @(posedge i_clk)
begin
    case( state_tx )
        INTERRUPT: // interrupt
            begin
                state_tx <= IDLE;
            end
        IDLE: // idle, wait for start_tx
            if( i_start ) begin
                state_tx <= STARTBIT;
            end
        STARTBIT: // start bit
            if( tick_tx ) begin
                state_tx <= SEND;
            end
        default:
            if( tick_tx ) begin
                state_tx <= state_tx + 1;
            end
    endcase

    if( i_reset ) begin
        state_tx <= IDLE;
    end
end

assign o_ready = idle;

endmodule

