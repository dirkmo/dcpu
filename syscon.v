module syscon(
    i_addr,
    i_cyc,
    o_slaveselect
);

parameter NSLAVES = 1;

input [31:0] i_addr;
input i_cyc;
output reg [NSLAVES-1:0] o_slaveselect;

always @(*)
begin
    o_slaveselect = 0;
    if( i_cyc ) begin
        if( i_addr < 32'h10000 )            o_slaveselect = 1; // blkmem0
        //else if( i_addr[15:4] == 12'hFF0 ) o_slaveselect = 2; // uart0
    end
end

endmodule
