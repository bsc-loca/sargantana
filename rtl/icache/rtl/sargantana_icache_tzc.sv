/* ------------------------------------------------------------------
 * Project Name   : DRAC
 * File           : icache_tzc.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Neiel I. Leyva Santes. 
 * Email(s)       : neiel.leyva@bsc.es
 * References     : 
 * ------------------------------------------------------------------
 * Revision History
 *  Revision   | Author    | Commit | Description
 *  ******     | Neiel L.  |        | 
 *  0.1        | Gerard C. |        | Changed the method to a decoder
 * ------------------------------------------------------------------
 */



// A trailing zero counter
module sargantana_icache_tzc
  import sargantana_icache_pkg::*;
(
  input  logic         [ICACHE_N_WAY-1:0] in_i          ,
  output logic [ICACHE_N_WAY_CLOG2-1:0] inval_way_o   ,
  output logic                            empty_o         //- Asserted if all bits in 
                                                          // in_i are zero
);

// The above solution gives too many warnings, we should opt for a decoder
// THIS ONLY WORKS BECAUSE ICACHE_N_WAY = 4
// If the parameter changes this should change accordingly

always_comb begin
    inval_way_o    = '0;
    if (in_i[0]) inval_way_o = 2'b00;
    else if (in_i[1]) inval_way_o = 2'b01;
    else if (in_i[2]) inval_way_o = 2'b10;
    else if (in_i[3]) inval_way_o = 2'b11;
    else inval_way_o = '0;
end

assign empty_o = ~(|in_i);

endmodule 
