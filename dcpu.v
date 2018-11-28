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

wire pc_inc2 = i_ack && (state==FETCH1 || state==FETCH2 || state==FETCH3);

reg [31:0] alu_result;


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
    case( state )
        RESET: state <= FETCH1;
        FETCH1: begin
            if( i_ack ) begin
                ir <= i_dat[15:0];
                state <= i_dat[15:13] == 3'b111 ? FETCH2 : EXECUTE;
            end
        end
        FETCH2: begin
            if( i_ack ) begin
                immediate[15:0] <= i_dat[15:0];
                state <= ir[12:11] == 2'b11 ? FETCH3 : EXECUTE;
            end
        end
        FETCH3: begin
            if( i_ack ) begin
                immediate[31:16] <= i_dat[15:0];
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
