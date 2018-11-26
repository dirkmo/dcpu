module dcpu(
    i_clk,
    i_reset,
    i_ack,
    i_dat,
    o_cyc,
    o_stb,
    o_dat,
    o_addr,
    o_we,
    i_int
);

input i_clk;
input i_reset;
input i_ack;
input [31:0] i_dat;
input i_int;
output o_cyc;
output [3:0] o_stb;
output [31:0] o_dat;
output reg [31:0] o_addr;
output o_we;

reg r_inten; // interrupts enable
reg [15:0] sreg[0:15];
reg [15:0] ureg[0:15];
wire [15:0] pc = r_inten ? ureg[15] : sreg[15];


localparam
    RESET = 'h0,
    FETCH1 = 'h1,
    FETCH2 = 'h2,
    FETCH3 = 'h3,
    EXECUTE = 'h4;

reg [3:0] state;

always @(posedge i_clk)
begin
    case( state )
        RESET: state <= FETCH1;
        FETCH1: begin
            if( i_ack ) begin
                state <= FETCH2;
                // pc+=2
            end
        end
        FETCH2: begin
        end
        FETCH3: begin
        end
        EXECUTE: begin
        end
    endcase
    if( i_reset ) begin
        state <= RESET;
    end
end

// o_addr
always @(state)
begin
    if( state == FETCH1 ) begin
        o_addr = pc;
    end else if( state == FETCH2 ) begin
        o_addr = pc;
    end else if( state == FETCH3 ) begin
        o_addr = pc;
    end else if( state == EXECUTE ) begin

    end
end

endmodule
