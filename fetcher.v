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
    o_immediate,
    o_rb_idx,
    o_valid,
    o_error
);

input i_clk;
input i_reset;

input [31:0] i_wb_dat;
output reg [31:0] o_wb_dat;
output [31:0] o_wb_addr;
output reg o_wb_cyc;
output reg [3:0] o_wb_stb;
output reg o_wb_we;
input i_wb_ack;
input i_wb_err;

input i_fetch; // shall be high for one clock cycle
input [31:0] i_pc;
output reg [31:0] o_pc;
output reg o_pc_wr;

output [3:0] o_rb_idx;
output reg o_valid;
output reg o_error;

output [47:0] o_instruction;
output [31:0] o_immediate;

reg [47:0] r_instruction;

// r_instruction bits:
// 47..42 opcode
// 41..39 cc
// 38..35 Ra
// 34..32 amode

parameter
    AMODE16 = 3'b000,
    AMODE32 = 3'b001,
    AMODE48 = 3'b010;

wire [2:0] amode = r_instruction[34:32];

wire data_avail = i_wb_ack && o_wb_cyc;

// instruction and immediate
assign o_instruction = amode == AMODE16 ? { r_instruction[47:32], 32'd0 }
                     : amode == AMODE32 ? { r_instruction[47:16], 16'd0 }
                     : r_instruction[47:0];

assign o_wb_addr = { i_pc[31:2], 2'b00 };

// immediate (and sign extension)
wire is = r_instruction[27]; // immediate sign
assign o_immediate = amode == AMODE16 ? { is ? 20'hFFFFF : 20'h00000, r_instruction[27:16] } // [27:16]
                   : amode == AMODE32 ? { is ? 4'hF : 4'h0, r_instruction[27:0] } // [27:0]
                   : r_instruction[31:0]; // [31:0] 

assign o_rb_idx = r_instruction[31:28];

/*
12 bit immediate:
    op(6) cc(3) ra(4) 001 | rb(4) imm(12)

28 bit immediate:
    op(6) cc(3) ra(4) 010 | rb(4) imm(12) imm(16)
*/

//------------------------------------------------------------------
// master state machine
reg do_fetch;
reg [3:0] state;
always @(posedge i_clk) begin
    o_wb_cyc <= 0;
    o_wb_stb <= 4'b0000;
    o_error <= 0;
    o_pc_wr <= 0;
    o_valid <= 0;
    case( state )
        0: if( i_fetch ) state <= 1;
        1: begin
            if( ~data_avail ) begin
                // fetch instruction halfword
                o_wb_cyc <= 1;
                o_wb_stb <= i_pc[1] ? 4'b0011 : 4'b1100;
            end else begin
                // save instruction
                r_instruction[47:32] <= i_pc[1] ? i_wb_dat[15:0] : i_wb_dat[31:16];
                // increment pc
                o_pc <= i_pc + 2;
                o_pc_wr <= 1;
                // next state
                state <= 2;
            end
        end
        2: begin
            // decode
            if( amode == AMODE16 ) begin
                // 16 bit instruction fetched
                o_valid <= 1;
                state <= 0;
            end else begin
                // 32 bit or 48 bit instruction
                if( ~data_avail ) begin
                    // fetch next halfword
                    o_wb_cyc <= 1;
                    o_wb_stb <= o_pc[1] ? 4'b0011 : 4'b1100;
                end else begin
                    // save immediate data
                    r_instruction[31:16] <= o_pc[1] ? i_wb_dat[15:0] : i_wb_dat[31:16];
                    // increment pc
                    o_pc <= o_pc + 2;
                    o_pc_wr <= 1;
                    // next state
                    state <= 3;
                end
            end
        end
        3: begin
            if( amode == AMODE32 ) begin
                // 32 bit instruction fetched
                o_valid <= 1;
                state <= 0;
            end else begin
                // 32 bit or 48 bit instruction
                if( ~data_avail ) begin
                    // fetch next halfword
                    o_wb_cyc <= 1;
                    o_wb_stb <= o_pc[1] ? 4'b0011 : 4'b1100;
                end else begin
                    // save immediate data
                    r_instruction[15:0] <= o_pc[1] ? i_wb_dat[15:0] : i_wb_dat[31:16];
                    // increment pc
                    o_pc <= o_pc + 2;
                    o_pc_wr <= 1;
                    // next state
                    state <= 4;
                end
            end
        end
        4: begin
            // 48 bit instruction fetched
            o_valid <= 1;
            state <= 0;
        end
    endcase
    if( i_reset ) begin
        state <= 0;
    end
end



/*

Big endian data expected.

Instruction format:

op(6) cc(3) ra(4) am(3) | [Immediates...]


Short Instruction:
    op(6) cc(3) ra(4) 000

    NOP, INC, DEC


12/28 Bit immediate:
    op(6) cc(3) ra(4) 001 | rb(4) imm(12)
    op(6) cc(3) ra(4) 010 | rb(4) imm(12) imm(16)

    ADD rb+#imm, ra
    LD  (rb+#imm), ra
    ST  rb, (ra+#imm)


32Bit immediate:
    op(6) cc(3) ra(4) 011 | imm(32)

    ADD #imm, ra
    LD  (#imm), ra
    ST  ra, (#imm)

*/


endmodule
