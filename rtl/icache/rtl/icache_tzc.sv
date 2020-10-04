/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_tzc.sv
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
module icache_tzc(
  input  logic         [ICACHE_N_WAY-1:0] in_i          ,
  output logic [$clog2(ICACHE_N_WAY)-1:0] inval_way_o   ,
  output logic                            empty_o         //- Asserted if all bits in 
                                                          // in_i are zero
);

// zeros counter
always_comb begin
    inval_way_o    = '0;
    for (int unsigned i = 0; i < ICACHE_N_WAY; i++) begin
        if (in_i[i]) begin
            inval_way_o = i[$clog2(ICACHE_N_WAY)-1:0];
            break ;
        end
    end
end

assign empty_o = ~(|in_i);

endmodule 
