/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : top_memory.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Neiel I. Leyva S. 
 * Email(s)       : neiel.leyva@bsc.es
 * References     : 
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Commit | Description
 *  ******     | Neiel L.  |        | 
 * -----------------------------------------------
 */

import drac_icache_pkg::*;
//`include "../../../includes/drac_config.v"

module top_memory(
    input  logic                    clk_i        ,
    input  logic                    rstn_i       ,
    input  logic [ICACHE_N_WAY-1:0] tag_req_i    ,//- Valid request.  
    input  logic [ICACHE_N_WAY-1:0] data_req_i   ,//- Valid request.  
    input  logic                    tag_we_i     ,//- Write enabled.            
    input  logic                    data_we_i    ,//- Write enabled.            
    input  logic                    flush_en_i   ,//- Flush enabled.            
    input  logic                    valid_bit_i  ,//- The valid bit to be written.
    input  logic    [WAY_WIDHT-1:0] cline_i      ,//- The cache line to be written.
    input  logic    [TAG_WIDHT-1:0] tag_i        ,//- The tag of the cache line 
                                                  //  to be written.
    input  logic   [ADDR_WIDHT-1:0] addr_i       ,//- Address to write or read.     
    //output logic                    flush_done_o ,
    output logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] tag_way_o   , //- Tags reads
    output logic [ICACHE_N_WAY-1:0][WAY_WIDHT-1:0] cline_way_o , //- Cache lines read. 
    output logic                [ICACHE_N_WAY-1:0] valid_bit_o   //- Validity bits read.
);


//- Data memory
idata_memory idata_memory(
    .clk_i          ( clk_i         ),
    .rstn_i         ( rstn_i        ),
    .req_i          ( data_req_i    ),
    .we_i           ( data_we_i     ),
    .data_i         ( cline_i       ),
    .addr_i         ( addr_i        ),
    .data_way_o     ( cline_way_o   ) 
);

//- Tags memory
`ifndef SRAM_MEMORIES
    itag_memory itag_memory(
        .clk_i      ( clk_i       ),
        .rstn_i     ( rstn_i      ),
        .req_i      ( tag_req_i   ),
        .we_i       ( tag_we_i    ),
        .vbit_i     ( valid_bit_i ),
        .flush_i    ( flush_en_i  ),
        .data_i     ( tag_i       ),
        .addr_i     ( addr_i      ),
        .tag_way_o  ( tag_way_o   ),
        .vbit_o     ( valid_bit_o )
    );
`else
    itag_memory_sram64x80 itag_memory(
        .clk_i      ( clk_i       ),
        .rstn_i     ( rstn_i      ),
        .req_i      ( tag_req_i   ),
        .we_i       ( tag_we_i    ),
        .vbit_i     ( valid_bit_i ),
        .flush_i    ( flush_en_i  ),
        .data_i     ( tag_i       ),
        .addr_i     ( addr_i      ),
        .tag_way_o  ( tag_way_o   ),
        .vbit_o     ( valid_bit_o )
    );

`endif

endmodule
