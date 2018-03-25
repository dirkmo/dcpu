/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
module fetcher(
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

    i_fetch,
    i_pc,
    o_pc,
    o_pc_wr,
    
    o_instruction,
    o_valid,
    o_error
);

input i_clk;
input i_reset;

input [31:0] i_wb_dat;
output reg [31:0] o_wb_dat;
output reg [31:0] o_wb_addr;
output reg o_wb_cyc;
output reg [3:0] o_wb_stb;
output reg o_wb_we;
input i_wb_ack;
input i_wb_err;

input i_fetch; // shall be high for one clock cycle
input [31:0] i_pc;
output reg [31:0] o_pc;
output reg o_pc_wr;

output reg o_valid;
output reg o_error;

output [47:0] o_instruction;

// 47..43 opcode
// 42..40 cc
// 39..36 Ra
// 35 unused
// 34..32 amode

parameter
    AMODE16 = 3'b000,
    AMODE32 = 3'b001,
    AMODE48 = 3'b010;

wire [2:0] amode = r_instruction[34:32];

assign o_instruction = amode == AMODE16 ? { r_instruction[47:32], 32'd0 }
                     : amode == AMODE32 ? { r_instruction[47:16], 16'd0 }
                     : r_instruction[47:0];

reg [47:0] r_instruction;

reg fetch_next; // shall be high for one clock cycle

reg [2:0] fetchcount; // number of halfwords fetched
reg first_fetched; // =1 if first fetch has been performed

reg just_fetched;
always @(posedge i_clk)
    if( i_reset ) begin
        just_fetched <= 0;
    end else begin
        just_fetched <= o_wb_cyc && i_wb_ack;
    end

wire aligned = ~i_pc[1];

always @(posedge i_clk) begin
    o_pc_wr <= 0;
    if( just_fetched ) begin
        o_pc <= i_pc + (aligned ? 4 : 2);
        if( amode == AMODE16 ) begin
            //o_pc <= i_pc + 2;
        end
        o_pc_wr <= 1;
    end
end

wire [2:0] next_fetchcount = fetchcount + (aligned ? 2 : 1);

always @(posedge i_clk) begin
    if( i_fetch || i_reset ) begin
        fetchcount <= 0;
        first_fetched <= 0;
        o_valid <= 0;
    end else if( just_fetched ) begin
        fetchcount <= next_fetchcount;
        first_fetched <= 1;
        if( (next_fetchcount > 0 && amode == AMODE16)
            || (next_fetchcount > 1 && amode == AMODE32)
            || (next_fetchcount > 2 && amode == AMODE48 )) begin
            o_valid <= 1;
        end
    end
end

always @(posedge i_clk) begin
    if( i_fetch ) begin
        o_error <= 0;
        o_wb_addr <= i_pc;
        o_wb_cyc <= 1;
        o_wb_stb <= aligned ? 4'b1111 : 4'b0011;
    end else if( fetch_next ) begin
        o_wb_addr <= i_pc;
        o_wb_cyc <= 1;
        o_wb_stb <= 4'b1111;
    end

    if( i_reset || (o_wb_cyc && (i_wb_err || i_wb_ack)) ) begin
        o_wb_addr <= 0;
        o_wb_cyc <= 0;
        o_wb_stb <= 0;
        o_error <= 0;
        if( i_wb_err )
            o_error <= 1;
    end
end

always @(posedge i_clk) begin
    if(o_wb_cyc && i_wb_ack) begin
        if( fetchcount==0 ) begin
            if( aligned ) begin
                r_instruction[47:16] <= i_wb_dat;
            end else begin
                r_instruction[47:32] <= i_wb_dat[15:0];
            end
        end if( fetchcount == 1 ) begin
            r_instruction[31:0] <= i_wb_dat;
        end else if( fetchcount == 2 ) begin
            r_instruction[15:0] <= i_wb_dat[31:16];
        end
    end
end

always @(posedge i_clk) begin
    fetch_next <= 0;
    if( first_fetched ) begin
        if( amode==AMODE16 ) begin
            // nothing to do
        end else if( amode==AMODE32 ) begin
            if( fetchcount < 2 && just_fetched)
                fetch_next <= 1;
        end else if( amode==AMODE48 ) begin
            if( fetchcount < 3 && just_fetched)
                fetch_next <= 1;
        end
    end
end

/*
op(5) cc(3) ra(4) am(3) | [Immediates...]


Short Instruction:
    op(5) cc(3) ra(4) 000

    NOP, INC, DEC


12/28 Bit immediate:
    op(5) cc(3) ra(4) 001 | rb(4) imm(12)
    op(5) cc(3) ra(4) 010 | rb(4) imm(12) imm(16)

    ADD rb+#imm, ra
    LD  (rb+#imm), ra
    ST  rb, (ra+#imm)


32Bit immediate:
    op(5) cc(3) ra(4) 011 | imm(32)

    ADD #imm, ra
    LD  (#imm), ra
    ST  ra, (#imm)

*/


endmodule
