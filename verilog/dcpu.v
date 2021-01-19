module dcpu(
    i_clk,
    i_reset,
    i_int,
    o_addr,
    i_dat,
    o_dat,
    o_rw
);

input i_clk;
input i_reset;
input i_int;

output reg [15:0] o_addr;
input [15:0] i_dat;
output [15:0] o_dat;
output reg o_rw;

`define INT_ADDR        16'hfffa
`define RESET_ADDR      16'h0100
`define STATUS_CARRY     1'b1

reg [15:0] pc;
reg [15:0] t, n, a;
reg [15:0] dsp, asp, usp;
reg [0:0] status;
reg [23:0] ir;

wire [7:0] op = (state == FETCH) ? pc[0] ? i_dat[15:8] : i_dat[7:0]
                                 : ir[7:0];

wire [15:0] ir_abs16 = { op[1], ir[22:16], op[0], ir[14:8]};
wire [13:0] ir_offs13 = { ir[22:16], ir[14:8]};
reg [15:0] stackgroup_src;
reg [15:0] fetch_store_group_addr;
reg [15:0] jumpgroup_addr;

localparam 
    OP_MASK         = 5'b11111,
    OP_ALU          = 5'b10000,
    OP_STACKGROUP1  = 5'b10010,
    OP_STACKGROUP2  = 5'b10011,
    OP_FETCHGROUP   = 5'b10100,
    OP_STOREGROUP   = 5'b10101,
    OP_JMPGROUP     = 5'b10110,
    OP_BRANCHGROUP  = 5'b10111,
    OP_JMPZGROUP    = 5'b11000,
    OP_JMPNZGROUP   = 5'b11001,
    OP_JMPCGROUP    = 5'b11010,
    OP_JMPNCGROUP   = 5'b11011,
    OP_POPGROUP     = 5'b11100,
    OP_SETREGISTERGROUP = 5'b11110,
    OP_MISC         = 5'b11111;

localparam 
    RESET = 0,
    FETCH = 1,
    EXECUTE = 2;

reg [1:0] state;

// state
always @(posedge i_clk)
begin
    case (state)
        RESET: state <= FETCH;
        FETCH: begin
            ir[23:0] <= { ir[15:0], op[7:0] };
            state <= op[7] ? EXECUTE : FETCH;
        end
        EXECUTE: begin
            state <= FETCH;
        end
    endcase
    if( i_reset ) begin
        state <= RESET;
    end
end

// o_addr
always @(state)
begin
    if (state == FETCH) begin
        o_addr = pc;
    end else if (state == EXECUTE) begin
        case(op[7:3])
            OP_STACKGROUP1: o_addr = dsp;
            OP_FETCHGROUP:  o_addr = fetch_store_group_addr;
            OP_STOREGROUP:  o_addr = fetch_store_group_addr;
            OP_JMPGROUP:    o_addr = jumpgroup_addr;
            OP_BRANCHGROUP: o_addr = jumpgroup_addr;
            OP_JMPZGROUP:   o_addr = (t == 0) ? jumpgroup_addr : pc;
            OP_JMPNZGROUP:  o_addr = t ? jumpgroup_addr : pc;
            OP_JMPCGROUP:   o_addr = status[`STATUS_CARRY] ? jumpgroup_addr : pc;
            OP_JMPNCGROUP:  o_addr = ~status[`STATUS_CARRY] ? jumpgroup_addr : pc;
            OP_POPGROUP:    o_addr = |op[1:0] ? (asp - 1) : (dsp - 1);
            OP_SETREGISTERGROUP: o_addr = 0;
            OP_MISC:        o_addr = asp;
        endcase
    end

    if (state == RESET) begin
        o_addr = `RESET_ADDR;
    end
end




always @(state)
begin
    case (op[3:0])
        4'b0000: stackgroup_src = t;
        4'b0001: stackgroup_src = a;
        4'b0010: stackgroup_src = n;
        4'b0011: stackgroup_src = usp;
        4'b01??: stackgroup_src = ir_abs16;
        4'b1000: stackgroup_src = { 14'h0, status };
        4'b1001: stackgroup_src = dsp;
        4'b1010: stackgroup_src = asp;
        4'b1011: stackgroup_src = pc;
    endcase
end

always @(state)
begin
    case (op[2:0])
        3'b000: fetch_store_group_addr = t;
        3'b001: fetch_store_group_addr = a;
        3'b010: fetch_store_group_addr = usp + {2'b00, ir_offs13};
        3'b011: fetch_store_group_addr = usp;
        3'b1??: fetch_store_group_addr = ir_abs16;
    endcase
end

always @(state)
begin
    case (op[2:0])
        3'b000: jumpgroup_addr = t;
        3'b001: jumpgroup_addr = a;
        3'b010: jumpgroup_addr = `INT_ADDR;
        // 3'b011: jumpgroup_addr = 0; // unused
        3'b1??: jumpgroup_addr = ir_abs16;
    endcase
end

endmodule