/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : idata_memory.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Neiel I. Leyva Santes. 
 * Email(s)       : neiel.leyva@bsc.es
 * References     : 
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Commit | Description
 *  ******     | Neiel L.  |        | 
 * -----------------------------------------------
 */



//Build the ways.
module sargantana_idata_memory 
    import sargantana_icache_pkg::*;
(
    input  logic                                   clk_i         ,
    input  logic                                   rstn_i        ,
    input  logic                [ICACHE_N_WAY-1:0] req_i         ,
    input  logic                                   we_i          ,
    input  logic                   [SET_WIDHT-1:0] data_i        ,
    input  logic                  [ADDR_WIDHT-1:0] addr_i        ,
    output logic [ICACHE_N_WAY-1:0][SET_WIDHT-1:0] data_way_o      //-One for each way 
);

//The ways are constructed according to the number of ways required.
genvar i;
generate
for ( i=0; i<ICACHE_N_WAY; i++ )begin:n_way
sargantana_icache_way way(
    .clk_i       ( clk_i          ),
    .rstn_i      ( rstn_i         ),
    .req_i       ( req_i[i]       ),
    .we_i        ( we_i           ),
    .data_i      ( data_i         ),
    .addr_i      ( addr_i         ),
    .data_o      ( data_way_o[i]  )
);
end
endgenerate


endmodule
