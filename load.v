/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
module load(
    i_clk,
    i_reset,

    o_wb_addr,
    o_wb_cyc,
    o_wb_stb,
    o_wb_we,
    o_wb_dat,
    i_wb_dat,
    i_wb_ack,
    i_wb_err,

    i_load,
    i_addr,

    o_data,
    o_valid,
    o_error
);

input i_clk;
input i_reset;

input [31:0] i_wb_dat;
output [31:0] o_wb_addr;
output reg o_wb_cyc;
output reg [3:0] o_wb_stb;
output o_wb_we;
output [31:0] o_wb_dat;
input i_wb_ack;
input i_wb_err;

input [1:0] i_load;
input [31:0] i_addr;

output reg[31:0] o_data;
output reg o_valid;
output reg o_error;

assign o_wb_dat = 0;
assign o_wb_addr = { i_addr[31:2], 2'b00 };
assign o_wb_we = 1'b0;

reg r_load;

assign o_wb_cyc = r_load;

always @(posedge i_clk)
begin
    r_load <= 0;
    if( i_load != 0 ) begin
        r_load <= 1;
    end
    if( i_reset || i_wb_ack || i_wb_err ) begin
        r_load <= 0;
    end
end

always @(posedge i_clk)
begin
    if( i_wb_err && r_load ) begin
        o_error <= 1;
    end
    if( i_load != 0 || i_reset ) begin
        o_error <= 0;
    end
end

always @(posedge i_clk)
begin
    o_valid <= 0;
    if( i_wb_ack ) begin
        o_data <= i_wb_dat;
        o_valid <= 1;
    end
end

always @(posedge i_clk)
begin
    case( i_load )
        2'b01: o_wb_stb <= i_addr[1:0] == 2'b00 ? 4'b1000 : // 8 bit load
                           i_addr[1:0] == 2'b01 ? 4'b0100 :
                           i_addr[1:0] == 2'b10 ? 4'b0010 : 4'b0001;
        2'b10: o_wb_stb <= i_addr[1] ? 4'b0011 : 4'b1100; // 16 bit load
        2'b11: o_wb_stb <= 4'b1111; // 32 bit load
        default: o_wb_stb <= 0;
    endcase
    if( i_reset ) begin
        o_wb_stb <= 0;
    end
end

endmodule
