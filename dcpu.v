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

// bit index in ST register
`define ST_ZERO  0
`define ST_CARRY 1

reg r_inten; // interrupts enable
wire ub = r_inten; // User Bit
// PC: r15, SP: r14, ST: r13
reg [31:0] registers[0:31]; // 0..15 supervisor regs, 16..31 user regs
wire [31:0] pc = r_inten ? registers[31] : registers[15];
wire [31:0] st = registers[13];

wire [4:0] pc_idx = { ub, 4'hF }; // index of pc

reg [15:0] ir;
reg [31:0] immediate;

wire [4:0] opcode = ir[15:11];
wire [4:0] imm_Rd = { ub, ir[10:7] };
wire [4:0] imm_Rs = { ub, ir[6:3] };
wire [2:0] imm3 = ir[2:0];
wire [3:0] imm4 = ir[6:3]; // #imm for alu-op
wire [6:0] imm7 = ir[6:0];
wire [7:0] imm8 = ir[7:0];
wire [15:0] imm18_3 = immediate[15:0];
wire [31:0] imm32 = immediate[31:0];
wire [2:0] imm_cc = ir[10:8];
wire [3:0] alu_op = { ir[11], ir[2:0] };
wire [4:0] mov_imm_Rd = { ir[2], ir[10:7] };
wire [4:0] mov_imm_Rs = { ir[1], ir[10:7] };

wire pc_inc2 = i_ack && (state==FETCH1 || state==FETCH2 || state==FETCH3);

wire op_len32 = ir[15:13] == 3'b111;   // instruction is at least 32-bit
wire op_len48 = ir[15:11] == 5'b11111; // instruction is 48-bit

reg [31:0] alu_result;

localparam
    OP__ST_RD_IMM3_RS  = 5'b10010,
    OP__LDB_RD_RS_IMM3 = 5'b11000,
    OP__LDH_RD_RS_IMM3 = 5'b11001,
    OP__LD_RD_RS_IMM3  = 5'b11010,
    OP__LD_RD_IMM7     = 5'b11011;


//---------------------------------------------------------------
// main state machine

localparam
    RESET    = 'h0,
    FETCH1   = 'h1,
    FETCH2   = 'h2,
    FETCH3   = 'h3,
    EXECUTE1 = 'h4,
    EXECUTE2 = 'h5;

reg [3:0] state;

always @(posedge i_clk)
begin
    case( state )
        RESET: state <= FETCH1;
        FETCH1: begin
            if( i_ack ) begin
                ir <= i_dat[15:0];
                state <= i_dat[15:13] == 3'b111 ? FETCH2 : EXECUTE1; // use i_dat because ir is not updated yet
            end
        end
        FETCH2: begin
            if( i_ack ) begin
                immediate[15:0] <= i_dat[15:0];
                state <= opcode[1:0] == 2'b11 ? FETCH3 : EXECUTE1;
            end
        end
        FETCH3: begin
            if( i_ack ) begin
                immediate[31:16] <= i_dat[15:0];
                state <= EXECUTE1;
            end    
        end
        EXECUTE1: begin
            if( opcode == OP__LD_RD_RS_IMM3 || opcode == OP__ST_RD_IMM3_RS )
                state <= EXECUTE2;
            else
                state <= FETCH1;
        end
        EXECUTE2: begin
            state <= FETCH1;
        end
    endcase
    if( i_reset ) begin
        state <= RESET;
    end
end

//---------------------------------------------------------------
// o_addr, o_cyc, o_stb

assign o_cyc = |o_stb;

// LDB Rd, (Rs+#imm(3))     11000 Rd(4) Rs(4) imm(3)
// LDH Rd, (Rs+#imm(3))     11001 Rd(4) Rs(4) imm(3)
// LD  Rd, (Rs+#imm(3))     11010 Rd(4) Rs(4) imm(3)
// STB (Rd+#imm(3)), Rs     10000 Rd(4) Rs(4) imm(3)
// STH (Rd+#imm(3)), Rs     10001 Rd(4) Rs(4) imm(3)
// ST  (Rd+#imm(3)), Rs     10010 Rd(4) Rs(4) imm(3)

// LDB Rd, (Rs+#imm(19))    11100 Rd(4) Rs(4) imm(3) | imm(19..16)
// LDH Rd, (Rs+#imm(19))    11101 Rd(4) Rs(4) imm(3) | imm(19..16)
// LD  Rd, (Rs+#imm(19))    11110 Rd(4) Rs(4) imm(3) | imm(19..16)
// STB (Rd+#imm(19)), Rs    10100 Rd(4) Rs(4) imm(3) | imm(19..16)
// STH (Rd+#imm(19)), Rs    10101 Rd(4) Rs(4) imm(3) | imm(19..16)
// ST  (Rd+#imm(19)), Rs    10110 Rd(4) Rs(4) imm(3) | imm(19..16)

reg [31:0] ldst_addr; // calculated load/store address

wire [31:0] addr_Rd_imm3  = registers[imm_Rd] + { 29'h0, imm3 };
wire [31:0] addr_Rd_imm19 = registers[imm_Rd] + { 13'h0, imm18_3, imm3 };

always @( opcode )
begin
    if( opcode[4] && opcode[2] ) ldst_addr = addr_Rd_imm19;
    else if( opcode[4] == 1'b1 ) ldst_addr = addr_Rd_imm3;
end

reg [1:0] ldst_stb;
always @(state,opcode)
begin
    if( (state == EXECUTE1) && opcode[4] ) begin
        // LD, ST instruction
        ldst_stb = 2'b11;
        if( opcode[1:0] == 2'b00 ) begin
            ldst_stb = ldst_addr[0] ? 2'b10 : 2'b01;
        end
    end
end

always @(state)
begin
    if( state == FETCH1 ) begin
        o_addr = pc;
        o_stb = 2'b11;
    end else if( state == FETCH2 ) begin
        o_addr = pc;
        o_stb = 2'b11;
    end else if( state == FETCH3 ) begin
        o_addr = pc;
        o_stb = 2'b11;
    end else if( state == EXECUTE1 ) begin
        o_cyc = opcode[4];
        o_stb = opcode[4] ? ldst_stb
                          : 2'b00;
        o_addr = opcode[4] ? ldst_addr // ld/st address
                           : 32'hx;
    end else if( state == EXECUTE2 ) begin
        // EXECUTE2 needed for 32-bit load or store
        o_stb = 2'b11;
    end else begin
        o_stb = 2'b00;
    end
end

//---------------------------------------------------------------
// Register file

wire [7:0] ldb_dat = o_addr[0] ? i_dat[7:0] : i_dat[15:8];

always @(posedge i_clk)
begin
    if( pc_inc2 ) registers[pc_idx] <= registers[pc_idx] + 'd2;
    if( state == EXECUTE1 ) begin
        if( opcode == OP__LD_RD_IMM7 ) begin
            // LD Rd, #imm(7)   11011 Rd(4) imm(7)
            registers[imm_Rd] <= { 25'd0, imm7 };
        end else if( opcode[4:3] == 2'b11 ) begin
            // LDB Rd, (Rs+#imm(3))    11000 Rd(4) Rs(4) imm(3)
            // LDH Rd, (Rs+#imm(3))    11001 Rd(4) Rs(4) imm(3)
            // LD  Rd, (Rs+#imm(3))    11010 Rd(4) Rs(4) imm(3)
            // LDB Rd, (Rs+#imm(19))   11100 Rd(4) Rs(4) imm(3) | imm(19..16)
            // LDH Rd, (Rs+#imm(19))   11101 Rd(4) Rs(4) imm(3) | imm(19..16)
            // LD  Rd, (Rs+#imm(19))   11110 Rd(4) Rs(4) imm(3) | imm(19..16)
            registers[imm_Rd][15:0] <= { 8'd0, o_stb[0] ? i_dat[7:0] : i_dat[15:8] };
            if( opcode[1:0] != 2'b00 ) begin
                registers[imm_Rd][15:7] <= i_dat[15:7]; // LDH or LD
            end
        end else if( opcode == 5'b00000 ) begin
            // MOV Rd, Rs    00000 Rd(4) Rs(4) d s 0
            registers[mov_imm_Rd] <= registers[mov_imm_Rs];
        end
    end else if( state == EXECUTE2 ) begin
        if( opcode[4:3] == 2'b11 ) begin
            // LD  Rd, (Rs+#imm(3))    11010 Rd(4) Rs(4) imm(3)
            // LD  Rd, (Rs+#imm(19))   11110 Rd(4) Rs(4) imm(3) | imm(19..16)
            registers[imm_Rd][31:16] <= i_dat[15:0];
        end
    end
    if( i_reset ) begin
        registers[15] <= 0;
    end
end

//---------------------------------------------------------------
// Alu

localparam
    ALU_ADD = 4'h0,
    ALU_ADC = 4'h1,
    ALU_SUB = 4'h2,
    ALU_SBC = 4'h3,
    ALU_AND = 4'h4,
    ALU_OR  = 4'h5,
    ALU_XOR = 4'h6,
    ALU_NOT = 4'h7,
    ALU_LSL = 4'h8,
    ALU_LSR = 4'h9;

wire [32:0] alu_left = { 1'b0, registers[imm_Rd] };
wire [32:0] alu_right = ir[12] ? { 1'b0, registers[imm_Rs] } : { 29'd0, imm4 };

reg carry;

always @(alu_left, alu_right, alu_op)
begin
    case( alu_op )
        ALU_ADD: { carry, alu_result } = alu_left + alu_right;
        ALU_ADC: { carry, alu_result } = alu_left + alu_right + {32'd0, st[`ST_CARRY] };
        ALU_SUB: { carry, alu_result } = alu_left - alu_right;
        ALU_SBC: { carry, alu_result } = alu_left - alu_right - { 32'd0, st[`ST_CARRY] };
        ALU_AND: alu_result = alu_left[31:0] & alu_right[31:0];
        ALU_OR:  alu_result = alu_left[31:0] | alu_right[31:0];
        ALU_XOR: alu_result = alu_left[31:0] ^ alu_right[31:0];
        ALU_NOT: alu_result = ~alu_left[31:0];
        ALU_LSL: { carry, alu_result } = alu_left[32:0] << alu_right[4:0];
        ALU_LSR: { alu_result, carry } = { alu_left[31:0], 1'b0 } >> alu_right[4:0];
        default: alu_result = 32'dX;
    endcase
end



endmodule
