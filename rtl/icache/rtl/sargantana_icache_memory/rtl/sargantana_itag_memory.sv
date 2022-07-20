/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : itag_memory.sv
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

import sargantana_icache_pkg::*;

module sargantana_itag_memory(
    input  logic                                   clk_i      ,
    input  logic                                   rstn_i     ,
    input  logic                [ICACHE_N_WAY-1:0] req_i      ,
    input  logic                                   we_i       ,
    input  logic                                   vbit_i     ,
    input  logic                                   flush_i    ,
    input  logic                   [TAG_WIDHT-1:0] data_i     ,
    input  logic                  [TAG_ADDR_WIDHT-1:0] addr_i     ,
    output logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] tag_way_o  , //- one for each way.
    output logic                [ICACHE_N_WAY-1:0] vbit_o       
);

//logic [ICACHE_N_WAY-1:0] mem_ready;

//- To build a memory of tags for each path.
genvar i;
generate
for ( i=0; i<ICACHE_N_WAY; i++ )begin:tag_way
sargantana_tag_way_memory tag_way (
    .clk_i   ( clk_i        ),
    .rstn_i  ( rstn_i       ),
    .req_i   ( req_i[i]     ),
    .we_i    ( we_i         ),
    .vbit_i  ( vbit_i       ),
    .flush_i ( flush_i      ),
    .data_i  ( data_i       ),
    .addr_i  ( addr_i       ),
    .data_o  ( tag_way_o[i] ),
    .vbit_o  ( vbit_o[i]    )
);
end
endgenerate


endmodule





