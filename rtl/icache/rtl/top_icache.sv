/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : top_icache.sv
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

import drac_icache_pkg::*;
//`include "../includes/drac_config.v"

module top_icache (
    input  logic          clk_i              ,
    input  logic          rstn_i             ,
    input  logic          flush_i            , 
    // Core interface                           
    input  ireq_i_t       lagarto_ireq_i     , //- From Lagarto.
    output iresp_o_t      icache_resp_o      , //- To Lagarto.
    // MMU interface                         
    input  tresp_i_t      mmu_tresp_i        , //- From MMU.
    output treq_o_t       icache_treq_o      , //- To MMU.
    // iFill interface
    input  ifill_resp_i_t ifill_resp_i       , //- From upper levels.
    output ifill_req_o_t  icache_ifill_req_o   //- To upper levels. 
);

logic     [ICACHE_TAG_WIDTH-1:0] cline_tag_d      ; //- Cache-line tag
logic     [ICACHE_TAG_WIDTH-1:0] cline_tag_q      ; //- Cache-line tag
logic     [ICACHE_TAG_WIDTH-1:0] tag_paddr        ; //- Cache-line tag
logic     [ICACHE_IDX_WIDTH-1:0] vaddr_index      ;
logic           [VADDR_SIZE-1:0] vaddr_d          ;
logic           [VADDR_SIZE-1:0] vaddr_q          ;
logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_q ;
logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_d ;

logic     [ICACHE_N_WAY-1:0] tag_req_valid   ;      
logic     [ICACHE_N_WAY-1:0] data_req_valid  ;      
logic     [ICACHE_N_WAY-1:0] way_valid_bits  ;      
logic [ICACHE_IDX_WIDTH-1:0] addr_valid      ;
logic     [ICACHE_N_WAY-1:0] cline_hit       ;

logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] way_tags     ;
logic [ICACHE_N_WAY-1:0][WAY_WIDHT-1:0] cline_data_rd;


icache_idx_t idx_d ;
icache_idx_t idx_q ;
icache_vpn_t vpn_d ;
icache_vpn_t vpn_q ;

logic flush_d           ;
logic flush_q           ;
logic paddr_is_nc       ;
logic a_valid_ireq      ;
logic flush_enable      ;
logic cache_rd_ena      ;
logic cache_wr_ena      ;
logic req_valid         ;
logic tag_we_valid      ;
logic cmp_enable        ;
logic cmp_enable_q      ;

logic ifill_req_was_sent_d;
logic ifill_req_was_sent_q;

//- It can only accept a request from the core if the cache is free.
assign a_valid_ireq = icache_resp_o.ready & lagarto_ireq_i.valid;

assign is_flush = flush_i;

//vaddr keeps available during all processes.
assign vaddr_d = ( a_valid_ireq ) ? {lagarto_ireq_i.vpn,lagarto_ireq_i.idx} : 
                                                          vaddr_q;

assign vpn_d = ( a_valid_ireq ) ? {lagarto_ireq_i.vpn} : vpn_q;
assign idx_d = ( a_valid_ireq ) ? {lagarto_ireq_i.idx} : idx_q;
                                                      
assign icache_treq_o.vpn = vpn_d;

//- Split virtual address into index and offset to address cache arrays.
assign vaddr_index = ( cache_wr_ena ) ?
        {idx_d[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH+2],ifill_resp_i.beat} :
        //{idx_d[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH],ifill_resp_i.beat} :
         idx_d[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH];
                     
assign cline_tag_d  = mmu_tresp_i.ppn ;
                                                                
// vaddr in fly 
assign icache_resp_o.vaddr = {vpn_q,idx_q};

// pass exception through
assign icache_resp_o.xcpt = mmu_tresp_i.xcpt;


//---------------------------------------------------------------------
//------------------------------------------------------ IFILL request.

assign icache_ifill_req_o.paddr = {cline_tag_d, 
                                   idx_q[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH+2]};

//-----------------------------------------------------------------------
assign valid_ifill_resp = ifill_resp_i.valid & ifill_resp_i.ack;

assign ifill_req_was_sent_d = icache_ifill_req_o.valid | 
                              (ifill_req_was_sent_q & ~valid_ifill_resp);

icache_ctrl  icache_ctrl (
    .clk_i              ( clk_i                     ),
    .rstn_i             ( rstn_i                    ),
    .paddr_is_nc_i      ( paddr_is_nc               ),
    .cache_enable_i     ( 1'b1                      ),
    .flush_i            ( is_flush                  ),
    .flush_done_i       ( 1'b0                      ),
    .cmp_enable_o       (  cmp_enable               ),
    .cache_rd_ena_o     ( cache_rd_ena              ),
    .cache_wr_ena_o     ( cache_wr_ena              ),
    .ireq_valid_i       ( a_valid_ireq              ),
    .ireq_kill_i        ( lagarto_ireq_i.kill       ),
    .iresp_ready_o      ( icache_resp_o.ready       ),
    .iresp_valid_o      ( icache_resp_o.valid       ),
    .mmu_miss_i         ( mmu_tresp_i.miss          ),
    .mmu_ptw_valid_i    ( mmu_tresp_i.ptw_v         ),
    .mmu_ex_valid_i     ( mmu_tresp_i.xcpt          ),
    .treq_valid_o       ( icache_treq_o.valid       ),
    .valid_ifill_resp_i  ( valid_ifill_resp ),
    .ifill_resp_valid_i ( ifill_resp_i.valid        ),
    .ifill_sent_ack_i   ( ifill_req_was_sent_d      ),
    .ifill_req_valid_o  ( icache_ifill_req_o.valid  ),
    .cline_hit_i        ( cline_hit                 ),   
    .miss_o             ( /* to monitor */          ),                       
    .flush_en_o         (flush_enable               )        
);                                          


top_memory icache_memory(
    .clk_i       ( clk_i  ),
    .rstn_i      ( rstn_i ),
    .tag_req_i   ( tag_req_valid  ),
    .data_req_i  ( data_req_valid ),
    .tag_we_i    ( tag_we_valid ),
    .data_we_i   ( cache_wr_ena ),
    .flush_en_i  ( flush_enable ),
    .valid_bit_i ( cache_wr_ena ),
    .cline_i     ( ifill_resp_i.data ),
    .tag_i       ( cline_tag_q ),
    .addr_i      ( addr_valid ),
    .tag_way_o   ( way_tags  ), 
    .cline_way_o ( cline_data_rd ), 
    .valid_bit_o ( way_valid_bits )  
);

icache_replace_unit replace_unit(
    .clk_i          ( clk_i            ),
    .rstn_i         ( rstn_i           ),
    .inval_i        ( '0 ),
    .cline_index_i  ( vaddr_index      ),
    .cache_rd_ena_i ( cache_rd_ena     ),
    .cache_wr_ena_i ( cache_wr_ena     ),
    .flush_ena_i    ( flush_enable     ),
    .way_valid_bits_i ( way_valid_bits      ),
    .we_valid_o     ( tag_we_valid     ),
    .addr_valid_o   ( addr_valid       ),
    .cmp_en_q       ( cmp_enable_q       ),
    .way_to_replace_q ( way_to_replace_q      ),
    .way_to_replace_d ( way_to_replace_d      ),
    .way_to_replace_o ( icache_ifill_req_o.way ),
    .data_req_valid_o  ( data_req_valid        ),
    .tag_req_valid_o  ( tag_req_valid        )
);


icache_checker ichecker(
    .read_tags_i        ( way_tags            ),
    .cmp_enable_q       ( cmp_enable_q        ),
    .cline_tag_d        ( cline_tag_d         ),
    .way_valid_bits_i   ( way_valid_bits      ),
    .data_rd_i          ( cline_data_rd       ),
    .cline_hit_o        ( cline_hit           ),
    .ifill_data_i       ( ifill_resp_i.data   ),
    .data_o             ( icache_resp_o.data  )
);


icache_ff icache_ff(
    .clk_i              ( clk_i             ),
    .rstn_i             ( rstn_i            ),
    .vaddr_d            ( vaddr_d           ),
    .vaddr_q            ( vaddr_q           ),
    .vpn_d              ( vpn_d             ),
    .vpn_q              ( vpn_q             ),
    .idx_d              ( idx_d             ),
    .idx_q              ( idx_q             ),
    .flush_d            ( /*flush_d*/           ),
    .flush_q            ( /*flush_q*/           ),
    .cline_tag_d        ( cline_tag_d       ),
    .cline_tag_q        ( cline_tag_q       ),
    .cmp_enable_d       ( cmp_enable        ),
    .cmp_enable_q       ( cmp_enable_q      ),
    .way_to_replace_q   ( way_to_replace_q  ),
    .way_to_replace_d   ( way_to_replace_d  ),
    .cache_enable_d     ( ifill_req_was_sent_d ),
    .cache_enable_q     ( ifill_req_was_sent_q )
);



endmodule
