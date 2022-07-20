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




//- Logical unit of cache replacement.
//- Valid bit invalidation and replacement strategy

module sargantana_icache_replace_unit 
    import sargantana_icache_pkg::*;
(
    input                                   clk_i            ,
    input                                   rstn_i           ,
    //input  inval_t                          inval_i          ,
    input  logic                          inval_i          ,
    input  logic                            flush_ena_i      ,
    input  logic                            cache_rd_ena_i   ,
    input  logic                            cache_wr_ena_i   ,
    input  logic         [ICACHE_N_WAY-1:0] way_valid_bits_i ,    
    input  logic                            cmp_en_q         ,
    input  logic     [ICACHE_IDX_WIDTH-1:0] cline_index_i    , //-From core 
    input  logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_q ,
    output logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_d ,
    output logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_o ,
    output logic                            we_valid_o       ,
    output logic     [ICACHE_IDX_WIDTH-1:0] addr_valid_o     , //Valid address to ram
    output logic         [ICACHE_N_WAY-1:0] data_req_valid_o ,    
    output logic         [ICACHE_N_WAY-1:0] tag_req_valid_o      

);

//logic inval_req;
logic lfsr_ena ;
logic all_ways_valid ;

//logic [ICACHE_IDX_WIDTH-1:0] addr_to_inval       ; 
//logic     [ICACHE_N_WAY-1:0] way_to_inval_oh     ;  // way to invalidate (onehot)
logic     [ICACHE_N_WAY-1:0] way_to_replace_q_oh ; // way to replace (onehot)

logic [$clog2(ICACHE_N_WAY)-1:0] a_random_way  ;
logic [$clog2(ICACHE_N_WAY)-1:0] a_invalid_way ;

//--------------------------------------------------------------------------
//----------------------------- Invalidation request from upper cache levels
//  A valid invalidation request
//  flushing takes precedence over invals
//assign inval_req     = ~flush_ena_i & inval_i.valid;
assign inval_req     = ~flush_ena_i & inval_i;
//assign addr_to_inval = inval_i.idx[ICACHE_INDEX_WIDTH-1:ICACHE_OFFSET_WIDTH];

//- Way to invalidate
// translate to Onehot
//always_comb begin
//   way_to_inval_oh = '0;
//   if (inval_req) way_to_inval_oh[inval_i.way] = 1'b1; 
//end

//--------------------------------------------------------------------------
//------------------------------------------------- Invalidation/Replacement
//assign addr_valid_o = (inval_req) ? addr_to_inval : cline_index_i;
assign addr_valid_o = cline_index_i;

//- To tag ram. In an invalidation only clear valid bits. 
                         // A valid read from core.
assign tag_req_valid_o = (cache_rd_ena_i )          ? '1 :
                         // Invalidation request to all ways.
                         //(inval_req && inval_i.all) ? '1 :
                         // Invalidation request to one way.
                         //(inval_req)                ? way_to_inval_oh : 
                         //(inval_req)                ? way_to_replace_q_oh : 
                                                      way_to_replace_q_oh;

assign we_valid_o = cache_wr_ena_i | inval_req ;

//- Chose random replacement if all are valid
//- Linear feedback shift register (LFSR)
assign lfsr_ena   = cache_wr_ena_i & all_ways_valid;

assign way_to_replace_o = (all_ways_valid) ? a_random_way : a_invalid_way;
assign way_to_replace_d = (cmp_en_q) ? way_to_replace_o : way_to_replace_q;

// translate to Onehot
always_comb begin
   way_to_replace_q_oh = '0;
   way_to_replace_q_oh[way_to_replace_q] = 1'b1; 
end

// enable signals for idata memory arrays
assign data_req_valid_o   = (cache_rd_ena_i ) ?                  '1 :
                            (cache_wr_ena_i ) ? way_to_replace_q_oh : '0;



// generate random cacheline index
sargantana_icache_lfsr lfsr (
    .clk_i          ( clk_i         ),
    .rst_ni         ( rstn_i        ),
    .en_i           ( lfsr_ena      ),
    .refill_way_o   ( a_random_way  )
);


// find invalid cache line
sargantana_icache_tzc tzc (
    .in_i           ( ~way_valid_bits_i  ),
    .inval_way_o    (  a_invalid_way     ),
    .empty_o        (  all_ways_valid    )
);





endmodule
