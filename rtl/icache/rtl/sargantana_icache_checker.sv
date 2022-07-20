/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_checker.sv
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


//`include "../includes/drac_config.v"

module sargantana_icache_checker
    import sargantana_icache_pkg::*;
(
    input  logic                           cmp_enable_q     ,
    input  logic    [ICACHE_TAG_WIDTH-1:0] cline_tag_d      , //- From mmu, paddr.
    input  logic        [ICACHE_N_WAY-1:0] way_valid_bits_i ,    
    //input  logic [ICACHE_OFFSET_WIDTH-1:0] cline_offset_q   , // offset in cache line
    input  logic           [WAY_WIDHT-1:0] ifill_data_i     , //- Cache line. 
    output logic        [ICACHE_N_WAY-1:0] cline_hit_o      ,
    output logic         [FETCH_WIDHT-1:0] data_o           ,
    
    input  logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] read_tags_i,
    input  logic [ICACHE_N_WAY-1:0][WAY_WIDHT-1:0] data_rd_i    //- Cache lines read.

);

logic          [$clog2(ICACHE_N_WAY)-1:0] idx      ;
logic [ICACHE_N_WAY-1:0][FETCH_WIDHT-1:0] cline_sel;
    
genvar i;
generate
for (i=0;i<ICACHE_N_WAY;i++) begin : tag_cmp
    assign cline_hit_o[i]  = (read_tags_i[i] == cline_tag_d) & way_valid_bits_i[i];
    //assign cline_sel[i]  = data_rd_i[i][{cline_offset_q,3'b0} +: FETCH_WIDHT];
    assign cline_sel[i]    = data_rd_i[i][FETCH_WIDHT-1:0];
end
endgenerate

// find valid cache line
icache_tzc_idx tzc_idx (
    .in_i  ( cline_hit_o  ),
    .way_o ( idx          )
);

//`ifdef FETCH_ONE_INST
//assign data_o = ( cmp_enable_q ) ? cline_sel[idx] :
//                                   ifill_data_i[{cline_offset_q,3'b0} +: FETCH_WIDHT];
//`else
//logic [FETCH_WIDHT-1:0] data_sel;
//assign data_sel = (cline_offset_q[ICACHE_OFFSET_WIDTH-1]) ? 
//                                        ifill_data_i[WAY_WIDHT-1:FETCH_WIDHT] :
//                                        ifill_data_i[FETCH_WIDHT-1:0] ;

//assign data_o = ( cmp_enable_q ) ? cline_sel[idx] : data_sel;
assign data_o = cline_sel[idx] ;

//`endif
                                 
endmodule
