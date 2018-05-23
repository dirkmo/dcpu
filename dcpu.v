`include "defines.v"

module dcpu(
    i_clk,
    i_reset,

    o_wb_addr,
    o_wb_cyc,
    o_wb_stb,
    o_wb_we,
    o_wb_dat,
    i_wb_dat,
    i_wb_ack,
    i_wb_err
);

input i_clk;
input i_reset;

// wishbone wires
input i_wb_ack;
input i_wb_err;
input  [31:0] i_wb_dat;
output [31:0] o_wb_addr;
output [31:0] o_wb_dat;
output [3:0] o_wb_stb;
output o_wb_we;
output o_wb_cyc;

// fetcher wires
wire [31:0] pc;
wire [15:0] instruction;
wire [2:0] condition = instruction[9:7];
wire instruction_valid;
wire fetcher_error;
wire [31:0] pc_fetcher;
wire pc_wr_fetcher;
wire [31:0] immediate_fetcher;
wire [3:0] rb_idx_fetcher;
wire [4:0] ra_idx = { reg_ie, instruction[6:3] };
wire [4:0] rb_idx = { reg_ie, rb_idx_fetcher };
wire rb_idx_valid;
wire [2:0] amode = instruction[2:0];
reg mov_im32, mov_rbra;
reg illegal_instruction;

wire wb_we_fetcher;
wire wb_cyc_fetcher;
wire [31:0] wb_addr_fetcher;
wire [3:0] wb_stb_fetcher;

// load wires
wire wb_cyc_load;
wire wb_we_load;
reg [1:0] load_start; // determines size of load
wire valid_load;
wire error_load;
wire [31:0] wb_addr_load;
reg  [31:0] addr_loadstore;
wire [31:0] data_load;
wire [3:0] wb_stb_load;

// store wires
wire [31:0] wb_addr_store;
wire [31:0] wb_dat_store;
wire [3:0] wb_stb_store;
wire wb_cyc_store;
wire wb_we_store;

wire error_store;
wire done_store;
wire [1:0] store_start; // determines size of store

//-----------------------------------------------
// Registers

reg [31:0] registers[31:0];
reg reg_ie = 1'b0; // interrupt enable (=user mode)
reg [31:0] bus_a;
reg [31:0] bus_b;

wire [4:0] pc_idx = { reg_ie, 4'd15 };
wire [4:0] cc_idx = { reg_ie, 4'd14 };
assign pc = registers[pc_idx];
wire [3:0] flags = registers[cc_idx][3:0];

reg reg_wr_a;
reg reg_wr_b = 0;
reg [4:0] reg_sel_a;
reg [4:0] reg_sel_b;

wire [31:0] rb_imm = registers[rb_idx] + immediate_fetcher;
wire [31:0] operant_b = (amode == `AMODE_IM32) ? immediate_fetcher : rb_imm;


// bus a
reg x, y; // helper

always @(*)
begin
    reg_wr_a = 1'b0;
    if( pc_wr_fetcher ) begin
        reg_wr_a = 1'b1;
        bus_a = pc_fetcher;
        reg_sel_a = pc_idx;
    end else if ( execute_wait ) begin
        if( valid_load ) begin
            reg_wr_a = 1'b1;
            bus_a = data_load;
            reg_sel_a = ra_idx;
        end else if ( mov_im32 ) begin
            reg_wr_a = 1'b1;
            bus_a = immediate_fetcher;
            reg_sel_a = ra_idx;
        end else if ( mov_rbra ) begin
            reg_wr_a = 1'b1;
            y = immediate_fetcher[0] ? reg_ie : 1'b1;
            bus_a = registers[{y, rb_idx_fetcher} ];
            x = immediate_fetcher[1] ? reg_ie : 1'b1;
            reg_sel_a = { x, ra_idx[3:0] };
        end
    end
end


// reg_ie
always @(posedge i_clk)
begin
    if( i_reset ) begin
        reg_ie <= 1'b0;
    end
end

integer i;

always @(posedge i_clk)
begin
    if( reg_wr_a ) begin
        registers[reg_sel_a] <= bus_a;
    end
    if( reg_wr_b ) begin
        registers[reg_sel_b] <= bus_b;
    end

    if( i_reset == 1'b1 ) begin
        for( i = 0; i < 16; i = i+1 ) begin
            registers[i] <= 32'd0;
        end
    end
end


//-----------------------------------------------
// main state machine

reg [2:0] r_state;

localparam
    RESET         = 3'd0,
    FETCH_START   = 3'd1,
    FETCH_WAIT    = 3'd2,
    EXECUTE_START = 3'd3,
    EXECUTE_WAIT  = 3'd4;


wire fetch_start = (r_state == FETCH_START);
wire execute_start = (r_state == EXECUTE_START);
wire execute_wait = (r_state == EXECUTE_WAIT);
wire condition_ok;
wire execute_done = valid_load || done_store || mov_im32 || mov_rbra;

always @(posedge i_clk)
begin

    case( r_state )
        RESET: begin
            // reset
            r_state <= FETCH_START;
        end
        FETCH_START: begin
            r_state <= FETCH_WAIT;
        end
        FETCH_WAIT: if( instruction_valid ) begin
            r_state <= condition_ok ? EXECUTE_START : FETCH_START;
        end
        EXECUTE_START: begin
            r_state <= EXECUTE_WAIT;
        end
        EXECUTE_WAIT: if( execute_done ) begin
            r_state <= FETCH_START;
        end
        default: r_state <= RESET;
    endcase

    if( i_reset ) begin
        r_state <= RESET;
    end
end


//-----------------------------------------------
// instruction decoder

wire [5:0] opcode = instruction[15:10];

assign condition_ok = (condition == `COND_Z)  && flags[`CC_Z]
                   || (condition == `COND_LT) && flags[`CC_N]
                   || (condition == `COND_C)  && flags[`CC_C]
                   || (condition == `COND_V)  && flags[`CC_V]
                   || (condition == `COND_NZ) && !flags[`CC_Z]
                   || (condition == `COND_GE) && !flags[`CC_N]
                   || (condition == `COND_NC) && !flags[`CC_C]
                   || (condition == `COND_NONE);

always @(posedge i_clk)
begin
    load_start <= `LOAD_NONE;
    mov_im32 <= 1'b0;
    mov_rbra <= 1'b0;
    illegal_instruction <= 1;
    if( execute_start ) begin
        addr_loadstore <= operant_b;
        case (opcode)
            `OP_LDB: load_start <= `LOAD_BYTE;
            `OP_LDH: load_start <= `LOAD_HALF;
            `OP_LD:  load_start <= `LOAD_WORD;
            `OP_MOV: begin
                if( amode == `AMODE_IM12 ) begin
                    // mov rb, ra
                    mov_rbra <= 1'b1;
                end else if( amode == `AMODE_IM32 ) begin
                    // mov #imm, ra
                    mov_im32 <= 1'b1;
                end else begin
                    // malformed instruction
                end
            end // OP_MOV
            `OP_STB: store_start <= `STORE_BYTE;
            `OP_STH: store_start <= `STORE_HALF;
            `OP_ST:  store_start <= `STORE_WORD;
            default: illegal_instruction <= 1; // illegal instruction
        endcase
    end else if(execute_wait) begin
        if( valid_load ) begin
        end
    end else begin
    end
end

//-----------------------------------------------
// Wishbone control

assign o_wb_cyc = wb_cyc_fetcher | wb_cyc_load;

assign o_wb_stb  = wb_cyc_fetcher ? wb_stb_fetcher
                 : wb_cyc_load    ? wb_stb_load
                 : wb_cyc_store   ? wb_stb_store
                 : 4'b0000;

assign o_wb_we   = wb_cyc_fetcher ? wb_we_fetcher
                 : wb_cyc_load    ? wb_we_load
                 : wb_cyc_store   ? wb_we_store
                 : 1'b0;

assign o_wb_addr = wb_cyc_fetcher ? wb_addr_fetcher
                 : wb_cyc_load    ? wb_addr_load
                 : wb_cyc_store   ? wb_addr_store
                 : 32'h0;

assign o_wb_dat  = wb_cyc_store   ? wb_dat_store
                 : 32'h0;


//-----------------------------------------------
// instruction fetcher

fetcher fetcher_inst(
    .i_clk(i_clk),
    .i_reset(i_reset),

    .o_wb_addr(wb_addr_fetcher),
    .o_wb_cyc(wb_cyc_fetcher),
    .o_wb_stb(wb_stb_fetcher),
    .o_wb_we(wb_we_fetcher),
    .o_wb_dat(),
    .i_wb_dat(i_wb_dat),
    .i_wb_ack(i_wb_ack),
    .i_wb_err(i_wb_err),

    .i_fetch( fetch_start ),
    .i_pc(pc),
    .o_pc(pc_fetcher),
    .o_pc_wr(pc_wr_fetcher),
    
    .o_instruction(instruction),
    .o_immediate(immediate_fetcher),
    .o_rb_idx(rb_idx_fetcher),
    .o_rb_idx_valid(rb_idx_valid),
    .o_valid(instruction_valid),
    .o_error(fetcher_error)
);

//-----------------------------------------------
// load

load Loader(
    .i_clk(i_clk),
    .i_reset(i_reset),

    .o_wb_addr(wb_addr_load),
    .o_wb_cyc(wb_cyc_load),
    .o_wb_stb(wb_stb_load),
    .o_wb_we(wb_we_load),
    .o_wb_dat(),
    .i_wb_dat(i_wb_dat),
    .i_wb_ack(i_wb_ack),
    .i_wb_err(i_wb_err),

    .i_load( load_start ),
    .i_addr( addr_loadstore ),

    .o_data( data_load ),
    .o_valid( valid_load ),
    .o_error( error_load )
);

//-----------------------------------------------
// store

store Storer(
    .i_clk(i_clk),
    .i_reset(i_reset),

    .o_wb_addr(wb_addr_store),
    .o_wb_cyc(wb_cyc_store),
    .o_wb_stb(wb_stb_store),
    .o_wb_we(wb_we_store),
    .o_wb_dat(wb_dat_store),
    .i_wb_dat(32'd0),
    .i_wb_ack(i_wb_ack),
    .i_wb_err(i_wb_err),

    .i_store( store_start ),
    .i_data( 32'd0 ),
    .i_addr( addr_loadstore ),

    .o_done( done_store ),
    .o_error( error_store )
);

endmodule
