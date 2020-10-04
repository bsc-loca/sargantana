/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_ff.sv
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

module icache_ff(
    input  logic                            clk_i            ,
    input  logic                            rstn_i           ,
    input  logic           [VADDR_SIZE-1:0] vaddr_d          ,
    output logic           [VADDR_SIZE-1:0] vaddr_q          ,
    input   icache_idx_t                     idx_d            ,
    output  icache_idx_t                     idx_q            ,
    input   icache_vpn_t                     vpn_d            ,
    output  icache_vpn_t                    vpn_q            ,
    //input  logic  [ICACHE_OFFSET_WIDTH-1:0] cline_offset_d   ,
    //output logic  [ICACHE_OFFSET_WIDTH-1:0] cline_offset_q   ,
    input  logic     [ICACHE_TAG_WIDTH-1:0] cline_tag_d      , 
    output logic     [ICACHE_TAG_WIDTH-1:0] cline_tag_q      , 
    input  logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_d ,
    output logic [$clog2(ICACHE_N_WAY)-1:0] way_to_replace_q ,
    input  logic                            cmp_enable_d     ,
    output logic                            cmp_enable_q     ,                          
    input  logic                            flush_d          ,
    output logic                            flush_q          ,                          
    input  logic                            cache_enable_d   ,
    output logic                            cache_enable_q                             
);


always_ff @(posedge clk_i or negedge rstn_i) begin 
    if(!rstn_i) begin
        cache_enable_q   <= '0;
        cmp_enable_q     <= '0;
        vaddr_q          <= '0;
        vpn_q            <= '0;
        idx_q            <= '0;
        flush_q          <= '0;
        //cline_offset_q   <= '0; 
        cline_tag_q      <= '0; 
        way_to_replace_q <= '0; 
    end
    else begin
        cache_enable_q   <= cache_enable_d   ;
        cmp_enable_q     <= cmp_enable_d     ;
        vaddr_q          <= vaddr_d          ;
        vpn_q            <= vpn_d            ;
        idx_q            <= idx_d            ;
        flush_q          <= flush_d          ;
        //cline_offset_q   <= cline_offset_d   ; 
        cline_tag_q      <= cline_tag_d      ; 
        way_to_replace_q <= way_to_replace_d ; 
    end
end

endmodule
