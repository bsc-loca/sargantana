/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_tzc_idx.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Neiel I. Leyva Santes. 
 * Email(s)       : neiel.leyva@bsc.es
 * References     : 
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Commit | Description
 *  ******     | Neiel L.  |        | 
 *  0.1        | Gerard C. |        | Changed the method to a decoder
 * -----------------------------------------------
 */

import drac_icache_pkg::*;

// A trailing zero counter
module icache_tzc_idx(
  input  logic         [ICACHE_N_WAY-1:0] in_i          ,
  output logic [ICACHE_N_WAY_CLOG2-1:0] way_o   
);

// The above solution gives too many warnings, we should opt for a decoder
// THIS ONLY WORKS BECAUSE ICACHE_N_WAY = 4
// If the parameter changes this should change accordingly

always_comb begin
    way_o    = '0;
    if (in_i[0]) way_o = 2'b00;
    else if (in_i[1]) way_o = 2'b01;
    else if (in_i[2]) way_o = 2'b10;
    else if (in_i[3]) way_o = 2'b11;
    else way_o = '0;
end



endmodule 
