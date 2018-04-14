module dcpu(
    i_clk,
    i_reset
);

input i_clk;
input i_reset;

localparam
    RESET,
    FETCH_START,
    FETCH_WAIT,
    EXECUTE_START,
    EXECUTE_WAIT,
    WRITEBACK;

reg [3:0] state;

always @(posedge i_clk)
begin
    r_fetch <= 0;

    case( state )
        RESET: begin
            // reset
            r_state <= FETCH;
        end
        FETCH_START: begin
            r_fetch <= 1;
            r_state <= FETCH_WAIT;
        end
        FETCH_WAIT: if( i_instruction_valid ) r_state <= EXECUTE_START;
        EXECUTE_START: begin
            r_state <= EXECUTE_WAIT;
        end
        EXECUTE_WAIT: r_state <= WRITEBACK;
        WRITEBACK: r_state <= FETCH_START;
        default: r_state <= RESET;
    endcase

    if( i_reset ) begin
        r_state <= RESET;
    end
end



endmodule
