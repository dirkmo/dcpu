/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
module store(
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

    i_store,
    i_addr,
    i_data,
    
    o_done,
    o_error
);

input i_clk;
input i_reset;

input [31:0] i_wb_dat;
output [31:0] o_wb_addr;
output reg o_wb_cyc;
output reg [3:0] o_wb_stb;
output reg o_wb_we;
output [31:0] o_wb_dat;
input i_wb_ack;
input i_wb_err;

input [1:0] i_store;
input [31:0] i_addr;

input reg[31:0] i_data;
output reg o_done;
output reg o_error;

assign o_wb_addr = { i_addr[31:2], 2'b00 };

assign o_wb_dat[31:0] = r_store == 2'b01 ? { i_data[7:0], i_data[7:0], i_data[7:0], i_data[7:0] } :
                        r_store == 2'b10 ? { i_data[15:0], i_data[15:0] } :
                                             i_data[31:0];

// r_store: data size to store.
// 2'b00: nothing to store
// 2'b01: store a byte (8 bits)
// 2'b10: store a halfword (16 bits)
// 2'b11: store a word (32 bits)
reg [1:0] r_store;

always @(posedge i_clk)
begin
    r_store <= 0;
    if( i_store != 0 ) begin
        r_store <= i_store;
    end
    if( i_reset || i_wb_ack || i_wb_err ) begin
        r_store <= 0;
    end
end

// o_error
always @(posedge i_clk)
begin
    if( i_wb_err && o_wb_cyc ) begin
        o_error <= 1;
    end
    if( o_wb_cyc || i_reset ) begin
        o_error <= 0;
    end
end

// o_done
always @(posedge i_clk)
begin
    o_done <= 0;
    if( |r_store && i_wb_ack && ~o_done ) begin
        o_done <= 1;
    end
end

always @(posedge i_clk)
begin
    if( |r_store ) begin
        if( o_wb_cyc ) begin
            if( i_wb_ack ) begin
                o_wb_cyc <= 0;
                o_wb_we <= 0;
            end
        end else begin
            o_wb_cyc <= 1;
            o_wb_we <= 1;
        end
    end
    if( i_reset ) begin
        o_wb_cyc <= 0;
        o_wb_we <= 0;
    end
end

always @(posedge i_clk)
begin
    case( r_store )
        2'b01: o_wb_stb <= i_addr[1:0] == 2'b00 ? 4'b1000 : // 8 bit store
                            i_addr[1:0] == 2'b01 ? 4'b0100 :
                            i_addr[1:0] == 2'b10 ? 4'b0010 : 4'b0001;
        2'b10: o_wb_stb <= i_addr[1] ? 4'b0011 : 4'b1100; // 16 bit store
        2'b11: o_wb_stb <= 4'b1111; // 32 bit store
        default: o_wb_stb <= 0;
    endcase
    if( i_reset ) begin
        o_wb_stb <= 0;
    end
end

endmodule
