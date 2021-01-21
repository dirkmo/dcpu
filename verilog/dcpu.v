module dcpu(
    i_clk,
    i_reset,
    i_int,
    o_addr,
    i_dat,
    o_dat,
    o_rw
);


`define INT_ADDR        16'hfffa
`define RESET_ADDR      16'h0100

`define STATUS_CARRY     0
`define STATUS_INTEN     1

input i_clk;
input i_reset;
input i_int;

output reg [15:0] o_addr;
input [15:0] i_dat;
output reg [15:0] o_dat;
output reg o_rw;

reg r_int;

reg [15:0] pc;
reg [15:0] t, n, a;
reg [14:0] dsp, asp, usp; // stack pointers are word aligned
reg [ 1:0] status;
/* verilator lint_off UNUSED */
reg [23:0] ir;
/* verilator lint_on UNUSED */

wire [15:0] wdsp    = { dsp, 1'b0 };
wire [15:0] wdsp_m1 = { dsp-1'b1, 1'b0 };
wire [15:0] wasp    = { asp, 1'b0 };
wire [15:0] wasp_m1 = { asp-1'b1, 1'b0 };
wire [15:0] wusp    = { usp, 1'b0 };
wire [15:0] pc_p1   =   pc + 1'b1;

wire [7:0] op = (state == FETCH) ? pc[0] ? i_dat[15:8] : i_dat[7:0]
                                 : ir[7:0];

wire [15:0] ir_abs16 = { op[1], ir[22:16], op[0], ir[14:8]};
wire [13:0] ir_offs13 = { ir[22:16], ir[14:8]};
reg  [15:0] stackgroup_src;
reg  [15:0] fetch_store_group_addr;
reg  [15:0] jumpgroup_addr;
reg  [16:0] alu_output;

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
    OP_SETSTATUS = { OP_SETREGISTERGROUP, 3'b000 },
    OP_SETASP    = { OP_SETREGISTERGROUP, 3'b010 },
    OP_SETUSP    = { OP_SETREGISTERGROUP, 3'b011 },
    OP_END       = 8'hff;
    

localparam 
    RESET     = 0,
    FETCH     = 1,
    EXECUTE   = 2,
    INTERRUPT = 3;

reg [1:0] state;

// r_int
always @(posedge i_clk)
begin
    if (i_int && status[`STATUS_INTEN]) begin
        r_int <= 1'b1;
    end
    if (i_reset || state == INTERRUPT || ~status[`STATUS_INTEN]) begin
        r_int <= 1'b0;
    end
end

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
            state <= r_int ? INTERRUPT : FETCH;
            ir [15:0] <= 16'd0;
            if( op == OP_END) $finish;
        end
        INTERRUPT: state <= EXECUTE;
    endcase
    if( i_reset ) begin
        state <= RESET;
    end
end

always @(*)
begin
    casez (op[3:0])
        4'b0000: stackgroup_src = t;
        4'b0001: stackgroup_src = a;
        4'b0010: stackgroup_src = n;
        4'b0011: stackgroup_src = wusp;
        4'b01??: stackgroup_src = ir_abs16;
        4'b1000: stackgroup_src = { 14'h0, status };
        4'b1001: stackgroup_src = wdsp;
        4'b1010: stackgroup_src = wasp;
        4'b1011: stackgroup_src = pc;
        default: stackgroup_src = 0;
    endcase
end

always @(*)
begin
    casez (op[2:0])
        3'b000:  fetch_store_group_addr = t;
        3'b001:  fetch_store_group_addr = a;
        3'b010:  fetch_store_group_addr = wusp + {2'b00, ir_offs13};
        3'b011:  fetch_store_group_addr = wusp;
        3'b1??:  fetch_store_group_addr = ir_abs16;
        default: fetch_store_group_addr = t;
    endcase
end

always @(*)
begin
    casez (op[2:0])
        3'b000:  jumpgroup_addr = t;
        3'b001:  jumpgroup_addr = a;
        3'b010:  jumpgroup_addr = `INT_ADDR;
        3'b1??:  jumpgroup_addr = ir_abs16;
        default: jumpgroup_addr = t;
    endcase
end

// o_addr
always @(*)
begin
    o_addr = pc;
    if (state == EXECUTE) begin
        case(op[7:3])
            OP_STACKGROUP1: o_addr = wdsp;
            OP_STACKGROUP2: o_addr = wdsp;
            OP_FETCHGROUP:  o_addr = fetch_store_group_addr;
            OP_STOREGROUP:  o_addr = fetch_store_group_addr;
            OP_BRANCHGROUP: o_addr = wasp_m1;
            OP_POPGROUP:    o_addr = |op[1:0] ? wasp_m1 : wdsp_m1;
            OP_MISC:        o_addr = wasp;
            default:        o_addr = 0;
        endcase
    end
end

// o_rw
always @(*)
begin
    o_rw = 1'b1;
    if (state == EXECUTE) begin
        case(op[7:3])
            OP_STACKGROUP1: o_rw = 1'b0;
            OP_STACKGROUP2: o_rw = 1'b0;
            OP_STOREGROUP:  o_rw = 1'b0;
            OP_BRANCHGROUP: o_rw = 1'b0;
            OP_MISC: o_rw = ~(|op[2:0] == 0); // OP_APUSH
            default: o_rw = 1'b1;
        endcase
    end
end

// o_dat
always @(*)
begin
    if (state == EXECUTE) begin
        case(op[7:3])
            OP_STACKGROUP1: o_dat = n;
            OP_STACKGROUP2: o_dat = n;
            OP_STOREGROUP:  o_dat = |op[2:0] ? t : n;
            OP_BRANCHGROUP: o_dat = a;
            OP_MISC: if (op[2:0] == 3'b000) o_dat = a; // OP_APUSH
            default: o_dat = 0;
        endcase
    end
end

// dojump (=1 if should jump)
reg dojump;
always @(*)
begin
    dojump = 0;
    if (state == EXECUTE) begin
        case(op[7:3])
            OP_JMPGROUP:    dojump = 1;
            OP_BRANCHGROUP: dojump = 1;
            OP_JMPZGROUP:   dojump = t == 16'd0;
            OP_JMPNZGROUP:  dojump = t != 16'd0;
            OP_JMPCGROUP:   dojump = status[`STATUS_CARRY];
            OP_JMPNCGROUP:  dojump = ~status[`STATUS_CARRY];
            default: dojump = 0;
        endcase
    end
end

// pc
always @(posedge i_clk)
begin
    case (state)
        RESET: pc <= `RESET_ADDR;
        FETCH: pc <= pc_p1;
        EXECUTE: pc <= dojump ? jumpgroup_addr : pc;
    endcase
end

// t
always @(posedge i_clk)
begin
    if (state == EXECUTE) begin
        case (op[7:3])
            OP_ALU: t <= alu_output[15:0];
            OP_STACKGROUP1: t <= stackgroup_src;
            OP_STACKGROUP2: t <= stackgroup_src;
            OP_FETCHGROUP: t <= i_dat;
            OP_POPGROUP: if (op[2:0] == 3'd0) t <= n; // OP_POP
            default: t <= t;
        endcase
    end
    if (state == RESET) begin
        t <= 16'd0;
    end
end

// n
always @(posedge i_clk)
begin
    if (state == EXECUTE) begin
        case (op[7:3])
            OP_STACKGROUP1: n <= t;
            OP_STACKGROUP2: n <= t;
            default: n <= n;
        endcase
    end
    if (state == RESET) begin
        n <= 16'd0;
    end
end

// a
always @(posedge i_clk)
begin
    if (state == EXECUTE) begin
        case (op[7:3])
            OP_BRANCHGROUP:      a <= pc;
            OP_POPGROUP:         if (op[1]) a <= i_dat; // OP_APOP, OP_RET
            OP_SETREGISTERGROUP: if (op[2]) a <= t; // OP_SETA
            OP_MISC:             a <= t; // OP_APUSH
            default: a <= a;
        endcase
    end
    if (state == RESET) begin
        a <= 16'd0;
    end
end


// dsp
always @(posedge i_clk)
begin
    if (state == EXECUTE) begin
        case (op[7:3])
            OP_STACKGROUP1: dsp <= dsp + 1;
            OP_STACKGROUP2: dsp <= dsp + 1;
            OP_POPGROUP: if (op[2:0] == 3'b000) dsp <= dsp - 1; // OP_POP
            OP_SETREGISTERGROUP: if (op[2:0] == 3'b001) dsp <= t[15:1]; // OP_SETDSP
            default: dsp <= dsp;
        endcase
    end
    if (state == RESET) begin
        dsp <= 15'd0;
    end
end

// asp
always @(posedge i_clk)
begin
    if (state == EXECUTE) begin
        case (op[7:3])
            OP_BRANCHGROUP: asp <= asp + 1;
            OP_POPGROUP: if (op[2:1] == 2'b01) asp <= asp - 1; // OP_APOP, OP_RET
            OP_SETREGISTERGROUP: if (op[2:0] == 3'b010) asp <= t[15:1]; // OP_SETASP
            default: asp <= asp;
        endcase
    end
    if (state == RESET) begin
        asp <= 15'd0;
    end
end

// usp
always @(posedge i_clk)
begin
    if (state == EXECUTE) begin
        if (op[7:0] == OP_SETUSP)
            usp <= t[15:1];
    end
    if (state == RESET) begin
        usp <= 15'd0;
    end
end

// alu_output
wire [16:0] lsr = { {n, 1'b0} >> t[3:0] };
always @(*)
begin
    alu_output = 0;
    case (op[3:0])
        4'b0000: alu_output = { 1'b0, n } + { 1'b0, t };
        4'b0001: alu_output = { 1'b0, n } - { 1'b0, t };
        4'b0010: alu_output = { 1'b0, n & t };
        4'b0011: alu_output = { 1'b0, n | t };
        4'b0100: alu_output = { 1'b0, n ^ t };
        4'b0101: alu_output = { lsr[0], lsr[16:1] };
        4'b0110: alu_output = { 1'b0, n[7:0], t[7:0]};
        default: alu_output = 0;
    endcase
end

// status
always @(posedge i_clk)
begin
    if (op[7:3] == OP_ALU) begin
        status[`STATUS_CARRY] <= alu_output[16];
    end else if (op[7:0] == OP_SETSTATUS) begin
        status[1:0] <= t[1:0];
    end
    
end

endmodule