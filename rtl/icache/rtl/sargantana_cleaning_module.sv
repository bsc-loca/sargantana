/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : cleaning_module.sv
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

import sargantana_icache_pkg::*;

module sargantana_cleaning_module(
    input  logic                    clk_i           ,
    input  logic                    rstn_i       ,
    input  logic                    flush_enable_i  ,
    output logic                    flush_done_o    ,
    output logic [ADDR_WIDHT-1:0]   addr_q              
);

logic [31:0] depth;
logic [ADDR_WIDHT-1:0] addr_d;

assign depth = ICACHE_DEPTH-1;

assign addr_d       = (flush_enable_i) ? addr_q + 1'b1 : addr_q;
assign flush_done_o = (addr_q==depth[ADDR_WIDHT-1:0]);

always_ff @(posedge clk_i) begin
    if(!rstn_i || flush_done_o ) begin
        addr_q     <= '0;
    end
    else begin
        addr_q     <= addr_d;
    end
end


endmodule
