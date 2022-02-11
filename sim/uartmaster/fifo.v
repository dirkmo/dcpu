// 4 bytes FIFO

module fifo(
    input i_clk,
    input i_reset,
    input  [DW-1:0] i_dat,
    output reg [DW-1:0] o_dat,
    input i_push,
    input i_pop,
    output o_empty,
    output o_full
);

parameter
    DEPTH = 2,
    DW = 8;

reg [DW-1:0] buffer[2**DEPTH-1:0];
reg [DEPTH-1:0] rd_idx;
reg [DEPTH-1:0] wr_idx;
reg empty_n;

assign o_empty = ~empty_n;
assign o_full = ( wr_idx == rd_idx ) && ~o_empty;

wire [DEPTH-1:0] rd_idx_next = rd_idx + 'd1;
wire [DEPTH-1:0] wr_idx_next = wr_idx + 'd1;

always @(posedge i_clk) begin
    o_dat <= buffer[rd_idx];
    if( i_push && ~o_full ) begin
        wr_idx <= wr_idx_next;
        buffer[wr_idx] <= i_dat;
        empty_n <= 1'b1;
    end
    if( i_pop && ~o_empty ) begin
        rd_idx <= rd_idx_next;
        if (~i_push) begin
            empty_n <= (wr_idx != rd_idx_next);
        end
        o_dat <= buffer[rd_idx+1];
    end
    if( i_reset ) begin
        rd_idx <= 'd0;
        wr_idx <= 'd0;
        empty_n <= 1'b0;
    end
end

endmodule
