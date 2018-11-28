/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
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
input [15:0] i_dat;
input i_int;
output o_cyc;
output [1:0] o_stb;
output [15:0] o_dat;
output reg [31:0] o_addr;
output o_we;

reg r_inten; // interrupts enable
wire ub = r_inten; // User Bit
reg [31:0] registers[0:31]; // 0..15 supervisor regs, 16..31 user regs
wire [31:0] pc = r_inten ? registers[31] : registers[15];

wire [4:0] pc_idx = { ub, 4'hF }; // index of pc

reg [15:0] ir;
reg [31:0] immediate;

//reg r_pc_inc2;
wire pc_inc2 = i_ack && (state==FETCH1 || state==FETCH2 || state==FETCH3);

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
    //r_pc_inc2 <= 0;
    case( state )
        RESET: state <= FETCH1;
        FETCH1: begin
            if( i_ack ) begin
                ir <= i_dat[15:0];
                //r_pc_inc2 <= 1;
                state <= i_dat[15:13] == 3'b111 ? FETCH2 : EXECUTE;
            end
        end
        FETCH2: begin
            if( i_ack ) begin
                immediate[15:0] <= i_dat[15:0];
                //r_pc_inc2 <= 1;
                state <= ir[12:11] == 2'b11 ? FETCH3 : EXECUTE;
            end
        end
        FETCH3: begin
            if( i_ack ) begin
                immediate[31:16] <= i_dat[15:0];
                //r_pc_inc2 <= 1;
                state <= EXECUTE;
            end    
        end
        EXECUTE: begin
            state <= FETCH1;
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
        o_cyc = 1;
        o_stb = 2'b11;
    end else if( state == FETCH2 ) begin
        o_addr = pc;
        o_cyc = 1;
        o_stb = 2'b11;
    end else if( state == FETCH3 ) begin
        o_addr = pc;
        o_cyc = 1;
        o_stb = 2'b11;
    end else if( state == EXECUTE ) begin
        o_cyc = 0;
        o_stb = 2'b00;
    end else begin
        o_cyc = 0;
        o_stb = 2'b00;
    end
end

//---------------------------------------------------------------
// Register file

always @(posedge i_clk)
begin
    if( pc_inc2 ) registers[pc_idx] <= registers[pc_idx] + 'd2;
    
    if( i_reset ) begin
        registers[15] <= 0;
    end
end

//---------------------------------------------------------------
// Alu



endmodule

