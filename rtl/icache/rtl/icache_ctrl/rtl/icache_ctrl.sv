/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_ctrl.sv
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

module icache_ctrl (
    input  logic clk_i              ,
    input  logic rstn_i             ,
    input  logic cache_enable_i     , //-From CSR
    input  logic paddr_is_nc_i      ,
    input  logic flush_i            ,
    input  logic flush_done_i       ,
    output logic cmp_enable_o       ,
    output logic cache_rd_ena_o     , //- Read enable
    output logic cache_wr_ena_o     , //- Read enable
    //----Lagarto interface                         
    input  logic ireq_valid_i       , //- A valid request. 
    input  logic ireq_kill_i        , //- Kill the current request. 
    output logic iresp_ready_o      , //- iCache is ready.  
    output logic iresp_valid_o      , //- A valid response.  
    //----iTLB interface                        
    input  logic mmu_ex_valid_i     , //- Some exception occurred.
    input  logic mmu_miss_i         , //- A tlb miss occurred.
    input  logic mmu_ptw_valid_i    , //- ptw valid response.
    output logic treq_valid_o       , //. A valid translation request.
    //---IFILL request to upper leveli                  
    input  logic valid_ifill_resp_i ,
    input  logic ifill_resp_valid_i , //- Packets delivered from an upper memory 
                                      //  level by an IFILL request are valid.
    input  logic ifill_sent_ack_i   , //- The IFILL request has been sent.
    output logic ifill_req_valid_o  , //- The IFILL request sent is valid.   
    input logic [ICACHE_N_WAY-1:0] cline_hit_i , //- A hit on any read cache line.  
    //---                                           
    output logic miss_o     ,
    output logic replay_valid_o,
    output logic flush_en_o                 
);                                          

logic new_request;
logic is_hit_or_excpt;
logic is_hit;
logic is_flush_or_kill;
logic valid_ifill_resp;
logic is_TLB_MISS;

//- A valid request from the core.
//- There doesn't have to be an IFILL response from the upper level and
//  there have to be a valid request from the core.
assign new_request =  ~ifill_resp_valid_i & ireq_valid_i ;

assign valid_ifill_resp = valid_ifill_resp_i;

assign is_hit = |cline_hit_i;

assign is_hit_or_excpt  = is_hit  | mmu_ex_valid_i;
assign is_flush_or_kill = flush_i | ireq_kill_i;


//------------------------------------------------------ FSM
ictrl_state_t state_d, state_q;

always_ff @(posedge clk_i or negedge rstn_i) begin
    if(!rstn_i) state_q <= NO_REQ;
    else        state_q <= state_d;
end

always_comb begin
    case (state_q)
        READ: begin//001
            state_d =  ( is_flush_or_kill || !new_request )                ? READ :
                       ( !is_hit_or_excpt && !mmu_miss_i && new_request )  ? MISS :
                       ( is_hit_or_excpt  && !mmu_miss_i && new_request)   ? READ :
                       //-The MMU has not responded due to PTE miss in TLB. 
                       // PTW starts walking...                                        
                                                            TLB_MISS ;
            // It avoids a valid translation request if a Kill arises.
            treq_valid_o      = 1'b0;
            cmp_enable_o      = cache_enable_i;
            cache_rd_ena_o    = 1'b0;
            iresp_ready_o     = !new_request;
            ifill_req_valid_o = ( !is_hit_or_excpt  && !mmu_miss_i   && 
                                  !is_flush_or_kill &&  new_request  );
            miss_o            = 1'b0; 
            iresp_valid_o     = ( is_hit && !mmu_miss_i && 
                                 !is_flush_or_kill && new_request) ;
            cache_wr_ena_o    = 1'b0  ;
            flush_en_o        = flush_i  ;
            replay_valid_o    = 1'b0;
        end
        MISS: begin//010
            //- Waiting for a valid cache line with requested data.
            state_d = (is_flush_or_kill || mmu_ex_valid_i ) ? KILL :
                      (valid_ifill_resp ) ? REPLAY                 :
                                            MISS                   ;
            iresp_valid_o  = 1'b0;
            cache_wr_ena_o = (ifill_resp_valid_i && !is_flush_or_kill ) ; 
            cmp_enable_o      = 1'b0  ;
            iresp_ready_o     = 1'b0  ;
            miss_o            = 1'b0  ;
            treq_valid_o      = 1'b0  ;
            ifill_req_valid_o = 1'b0  ;
            cache_rd_ena_o    = 1'b0  ;
            flush_en_o        = flush_i  ;
            replay_valid_o    = 1'b0;
        end
        TLB_MISS: begin//011
            state_d = ( is_flush_or_kill || mmu_ex_valid_i || !mmu_miss_i) ? READ      :
                                                                             TLB_MISS  ;
                                                                                     
            treq_valid_o      = ( !mmu_miss_i && !mmu_ex_valid_i && !is_flush_or_kill);
            cmp_enable_o      = cache_enable_i ;
            cache_rd_ena_o    = ( !mmu_miss_i && !mmu_ex_valid_i && !is_flush_or_kill) ;
            iresp_valid_o     = (mmu_ex_valid_i);
            miss_o            = 1'b0 ;
            iresp_ready_o     = 1'b0 ;
            ifill_req_valid_o = 1'b0 ;
            cache_wr_ena_o    = 1'b0 ;
            flush_en_o        = flush_i ;
            replay_valid_o    = ( is_flush_or_kill || mmu_ex_valid_i || !mmu_miss_i);
        end

        REPLAY: begin //100
            state_d           = READ   ;
            cmp_enable_o      = cache_enable_i ;
            iresp_ready_o     = 1'b0  ;
            iresp_valid_o     = mmu_ex_valid_i;
            cache_rd_ena_o    = (!is_flush_or_kill && !mmu_ex_valid_i ) ;
            cache_wr_ena_o    = 1'b0  ;
            miss_o            = 1'b0  ;
            treq_valid_o      = 1'b0  ;  
            ifill_req_valid_o = 1'b0  ;
            flush_en_o        = flush_i  ;
            replay_valid_o    = (!is_flush_or_kill && !mmu_ex_valid_i );
        end
        KILL: begin //101
            //- It must wait to translation response and data will be ignored.
            state_d = (!ifill_sent_ack_i) ? READ : KILL;
            cmp_enable_o      = 1'b0  ;
            iresp_ready_o     = 1'b0  ;
            iresp_valid_o     = mmu_ex_valid_i  ;
            cache_rd_ena_o    = 1'b0  ;
            cache_wr_ena_o    = 1'b0  ;
            miss_o            = 1'b0  ;
            treq_valid_o      = 1'b0  ;
            ifill_req_valid_o = 1'b0  ;
            flush_en_o        = 1'b0  ;
            replay_valid_o    = 1'b0;
        end
        default: begin
            state_d           = READ  ;
            cmp_enable_o      = 1'b0  ;
            iresp_ready_o     = 1'b0  ;
            iresp_valid_o     = 1'b0  ;
            cache_rd_ena_o    = 1'b0  ;
            cache_wr_ena_o    = 1'b0  ;
            miss_o            = 1'b0  ;
            treq_valid_o      = 1'b0  ;
            ifill_req_valid_o = 1'b0  ;
            flush_en_o        = 1'b0  ;
            replay_valid_o    = 1'b0;
        end
    endcase
end

assign is_TLB_MISS = (state_q == TLB_MISS);

endmodule




