module ctrlunit(
    i_clk,
    i_reset,

    o_regsel_a,
    o_regsel_b,
    o_regwb_b,

    o_memaccess,
    o_memaddr,
    i_memack
);

input i_clk;
input i_reset;

output o_memaccess;
output [31:0] o_memaddr;
input i_memack;

parameter REG_PC = 4'd15;

reg [31:0] instruction;

localparam
    NONE,
    FETCH,
    EXECUTE;

reg [3:0] state;
reg [3:0] next_state;

always @(posedge i_clk) begin
    state <= next_state;
    if( reset == 1'b1) begin
        state <= 'd0;
    end
end

always @(*) begin
    case( state )
        FETCH: begin
            if( fetch_done ) begin
                next_state = EXECUTE;
            end
        end
        EXECUTE:
        default:
    endcase

end



endmodule
