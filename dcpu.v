/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off PINCONNECTEMPTY */

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
wire [47:0] instruction;
wire instruction_valid;
wire fetcher_error;
wire [31:0] pc_fetcher;
wire pc_wr_fetcher;

wire wb_we_fetcher;
wire wb_cyc_fetcher;
wire [31:0] wb_addr_fetcher;
wire [3:0] wb_stb_fetcher;

// load wires
wire wb_cyc_load;
wire wb_we_load;
wire [1:0] load_start; // determines size of load
wire valid_load;
wire error_load;
wire [31:0] wb_addr_load;
wire [31:0] addr_load;
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
wire [1:0] store_start;
wire [31:0] addr_store;


//-----------------------------------------------
// Registers

reg [31:0] registers[31:0];
reg reg_ie = 1'b0; // interrupt enable (=user mode)
reg [31:0] bus_a;
reg [31:0] bus_b;


wire [4:0] pc_idx = { reg_ie, 4'd15 };
assign pc = registers[ pc_idx ];

reg reg_wr_a;
reg reg_wr_b = 0;
reg [4:0] reg_sel_a;
reg [4:0] reg_sel_b;

// bus a
always @(*)
begin
    if( pc_wr_fetcher ) begin
        reg_wr_a = 1'b1;
        bus_a = pc_fetcher;
        reg_sel_a = pc_idx;
    end else begin
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

reg [3:0] r_state;

localparam
    RESET         = 0,
    FETCH_START   = 1,
    FETCH_WAIT    = 2,
    EXECUTE_START = 3,
    EXECUTE_WAIT  = 4,
    WRITEBACK     = 5;


wire fetch_start = (r_state == FETCH_START);

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
        FETCH_WAIT: if( instruction_valid ) r_state <= EXECUTE_START;
        EXECUTE_START: begin
            r_state <= EXECUTE_WAIT;
        end
        EXECUTE_WAIT: r_state <= WRITEBACK;
        WRITEBACK: r_state <= FETCH_START;
        default: r_state <= RESET;
    endcase

    if( i_reset ) begin
        r_state <= RESET;
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
    .o_raw_immediate(),
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
    .i_addr( addr_load ),

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
    .i_addr( addr_store ),

    .o_done( done_store ),
    .o_error( error_store )
);

endmodule
