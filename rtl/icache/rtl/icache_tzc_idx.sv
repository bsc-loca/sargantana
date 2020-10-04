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
 * -----------------------------------------------
 */

import drac_icache_pkg::*;

// A trailing zero counter
module icache_tzc_idx(
  input  logic         [ICACHE_N_WAY-1:0] in_i          ,
  output logic [$clog2(ICACHE_N_WAY)-1:0] way_o   
);

// zeros counter
always_comb begin
    way_o    = '0;
    for (int unsigned i = 0; i < ICACHE_N_WAY; i++) begin
        if (in_i[i]) begin
            way_o = i[$clog2(ICACHE_N_WAY)-1:0];
            break ;
        end
    end
end

endmodule 
