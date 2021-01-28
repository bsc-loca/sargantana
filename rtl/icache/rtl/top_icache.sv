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
    output ifill_req_o_t  icache_ifill_req_o , //- To upper levels. 

    // PMU
    output logic imiss_time_pmu_o            , 
    output logic imiss_kill_pmu_o           
);

logic     [ICACHE_TAG_WIDTH-1:0] cline_tag_d      ; //- Cache-line tag
logic     [ICACHE_TAG_WIDTH-1:0] cline_tag_q      ; //- Cache-line tag
logic     [ICACHE_TAG_WIDTH-1:0] tag_paddr        ; //- Cache-line tag
logic     [ICACHE_IDX_WIDTH-1:0] vaddr_index      ;
//logic           [VADDR_SIZE-1:0] vaddr_d          ;
//logic           [VADDR_SIZE-1:0] vaddr_q          ;
logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_q ;
logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_d ;

logic     [ICACHE_N_WAY-1:0] tag_req_valid   ;      
logic     [ICACHE_N_WAY-1:0] data_req_valid  ;      
logic     [ICACHE_N_WAY-1:0] way_valid_bits  ;      
logic [ICACHE_IDX_WIDTH-1:0] addr_valid      ;
logic     [ICACHE_N_WAY-1:0] cline_hit       ;

logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] way_tags     ;
logic [ICACHE_N_WAY-1:0][WAY_WIDHT-1:0] cline_data_rd;


drac_pkg::icache_idx_t idx_d ;
drac_pkg::icache_idx_t idx_q ;
drac_pkg::icache_vpn_t vpn_d ;
drac_pkg::icache_vpn_t vpn_q ;

logic ifill_req_valid   ;
logic flush_d           ;
logic flush_q           ;
logic paddr_is_nc       ;
logic replay_valid      ;
logic valid_ireq_d      ;
logic valid_ireq_q      ;
logic ireq_kill_d       ;
logic ireq_kill_q       ;
logic flush_enable      ;
logic cache_rd_ena      ;
logic cache_wr_ena      ;
logic req_valid         ;
logic tag_we_valid      ;
logic cmp_enable        ;
logic cmp_enable_q      ;
logic treq_valid        ;

logic ifill_req_was_sent_d;
logic ifill_req_was_sent_q;

tresp_i_t  mmu_tresp_d;  
tresp_i_t  mmu_tresp_q; 

//- It can only accept a request from the core if the cache is free.
assign valid_ireq_d = lagarto_ireq_i.valid || replay_valid ;

assign is_flush_d = flush_i;

assign ireq_kill_d = lagarto_ireq_i.kill ; 

//vaddr keeps available during all processes.
assign vpn_d = ( lagarto_ireq_i.valid ) ? {lagarto_ireq_i.vpn} : vpn_q;
assign idx_d = ( lagarto_ireq_i.valid ) ? {lagarto_ireq_i.idx} : idx_q;
                                                      
//assign icache_treq_o.vpn = vpn_d;
assign icache_treq_o.vpn = vpn_d;
assign icache_treq_o.valid = treq_valid || valid_ireq_d ;

assign mmu_tresp_d = mmu_tresp_i;

//- Split virtual address into index and offset to address cache arrays.
assign vaddr_index = ( cache_wr_ena ) ?
        {idx_d[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH+2],ifill_resp_i.beat} :
         idx_d[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH];
                     
assign cline_tag_d  = mmu_tresp_q.ppn ;
                                                                
// vaddr in fly 
assign icache_resp_o.vaddr = {vpn_q,idx_q};

// pass exception through
logic icache_resp_valid ; 
assign icache_resp_o.xcpt = mmu_tresp_q.xcpt && icache_resp_valid;

assign icache_resp_o.valid = icache_resp_valid && !ireq_kill_d;       
//assign icache_resp_o.valid = icache_resp_valid;       

//---------------------------------------------------------------------
//------------------------------------------------------ IFILL request.

assign icache_ifill_req_o.paddr = {cline_tag_d, 
                                   idx_q[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH+2]};

assign icache_ifill_req_o.valid = ifill_req_valid  && !ireq_kill_d ;

//-----------------------------------------------------------------------
assign valid_ifill_resp = ifill_resp_i.valid & ifill_resp_i.ack;

assign ifill_req_was_sent_d = icache_ifill_req_o.valid | 
                              (ifill_req_was_sent_q & ~valid_ifill_resp);

icache_ctrl  icache_ctrl (
    .clk_i              ( clk_i                     ),
    .rstn_i             ( rstn_i                    ),
    .cache_enable_i     ( 1'b1                      ),
    .paddr_is_nc_i      ( paddr_is_nc               ),
    .flush_i            ( is_flush_q                ),
    .flush_done_i       ( 1'b0                      ),
    .cmp_enable_o       (  cmp_enable               ),
    .cache_rd_ena_o     ( cache_rd_ena              ),
    .cache_wr_ena_o     ( cache_wr_ena              ),
    .ireq_valid_i       ( valid_ireq_q              ),
    .ireq_kill_i        ( ireq_kill_q               ),
    .ireq_kill_d        ( ireq_kill_d               ),
    .iresp_ready_o      ( icache_resp_o.ready       ),
    .iresp_valid_o      ( icache_resp_valid         ),
    .mmu_miss_i         ( mmu_tresp_q.miss          ),
    .mmu_ptw_valid_i    ( mmu_tresp_q.ptw_v         ),
    .mmu_ex_valid_i     ( mmu_tresp_q.xcpt          ),
    .treq_valid_o       ( treq_valid                ),
    .valid_ifill_resp_i ( valid_ifill_resp          ),
    .ifill_resp_valid_i ( ifill_resp_i.valid        ),
    .ifill_sent_ack_i   ( ifill_req_was_sent_d      ),
    .ifill_req_valid_o  ( ifill_req_valid           ),
    .cline_hit_i        ( cline_hit                 ),   
    .miss_o             ( imiss_time_pmu_o          ),                       
    .miss_kill_o        ( imiss_kill_pmu_o          ),                       
    .replay_valid_o     ( replay_valid              ),                       
    .flush_en_o         (flush_enable               )        
);                                          


top_memory icache_memory(
    .clk_i       ( clk_i  ),
    .rstn_i      ( rstn_i ),
    .tag_req_i   ( tag_req_valid  ),
    .data_req_i  ( data_req_valid ),
    .tag_we_i    ( tag_we_valid & (ifill_resp_i.beat == 2'b00) ),
    .data_we_i   ( cache_wr_ena ),
    .flush_en_i  ( is_flush_d ),
    .valid_bit_i ( cache_wr_ena & (ifill_resp_i.beat == 2'b00)),
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
    .cache_rd_ena_i ( valid_ireq_d | cache_rd_ena ),
    .cache_wr_ena_i ( cache_wr_ena     ),
    .flush_ena_i    ( flush_enable     ),
    .way_valid_bits_i ( way_valid_bits      ),
    .we_valid_o     ( tag_we_valid ),
    .addr_valid_o   ( addr_valid       ),
    .cmp_en_q       ( cmp_enable_q       ),
    .way_to_replace_q ( way_to_replace_q      ),
    .way_to_replace_d ( way_to_replace_d      ),
    .way_to_replace_o ( icache_ifill_req_o.way ),
    .data_req_valid_o ( data_req_valid        ),
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
    //.vaddr_d            ( vaddr_d           ),
    //.vaddr_q            ( vaddr_q           ),
    .vpn_d              ( vpn_d             ),
    .vpn_q              ( vpn_q             ),
    .idx_d              ( idx_d             ),
    .idx_q              ( idx_q             ),
    .flush_d            ( is_flush_d        ),
    .flush_q            ( is_flush_q        ),
    .cline_tag_d        ( cline_tag_d       ),
    .cline_tag_q        ( cline_tag_q       ),
    .cmp_enable_d       ( cmp_enable        ),
    .cmp_enable_q       ( cmp_enable_q      ),
    .way_to_replace_q   ( way_to_replace_q  ),
    .way_to_replace_d   ( way_to_replace_d  ),
    .valid_ireq_d       (valid_ireq_d),
    .valid_ireq_q       (valid_ireq_q),
    .ireq_kill_d        (ireq_kill_d ),
    .ireq_kill_q        (ireq_kill_q ),
    .mmu_tresp_d        (mmu_tresp_d),
    .mmu_tresp_q        (mmu_tresp_q),
    .cache_enable_d     ( ifill_req_was_sent_d ),
    .cache_enable_q     ( ifill_req_was_sent_q )
);



endmodule
