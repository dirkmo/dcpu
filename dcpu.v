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
wire ub = r_inten; // User Bit
reg [15:0] registers[0:31]; // 0..15 supervisor regs, 16..31 user regs
wire [15:0] pc = r_inten ? registers[31] : registers[15];

wire pc_idx = { ub, 4'hF }; // index of pc

reg [15:0] ir;
reg [31:0] immediate;

reg r_pc_inc2;

//---------------------------------------------------------------
// main state machine

localparam
    RESET = 'h0,
    FETCH1 = 'h1,
    FETCH2 = 'h2,
    FETCH3 = 'h3,
    EXECUTE = 'h4;

reg [3:0] state;

always @(posedge i_clk)
begin
    r_pc_inc2 <= 0;
    case( state )
        RESET: state <= FETCH1;
        FETCH1: begin
            if( i_ack ) begin
                ir <= pc[1] ? i_dat[15:0] : i_dat[31:16];
                r_pc_inc2 <= 1;
                state <= FETCH2;
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

//---------------------------------------------------------------
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

//---------------------------------------------------------------
// Register file

always @(posedge i_clk)
begin
    if( r_pc_inc2 ) registers[pc_idx] <= registers[pc_idx] + 1'b2;
    
    if( i_reset ) begin
        registers[15] <= 0;
    end
end

endmodule

