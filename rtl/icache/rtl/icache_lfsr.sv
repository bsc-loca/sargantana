/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_lfsr.sv
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

// Linear feedback shift register 8bit (LFSR)
module icache_lfsr (
    input  logic                            clk_i,
    input  logic                            rst_ni,
    input  logic                            en_i,
    output logic [$clog2(ICACHE_N_WAY)-1:0] refill_way_o
);

logic [7:0] shift_d, shift_q;

always_comb begin
    automatic logic shift_in;
    shift_in = !(shift_q[7] ^ shift_q[3] ^ shift_q[2] ^ shift_q[1]);
    shift_d  = shift_q;

    if (en_i) shift_d = {shift_q[6:0], shift_in};
    
    refill_way_o = shift_q[$clog2(ICACHE_N_WAY)-1:0];
end

always_ff @(posedge clk_i or negedge rst_ni) begin : proc_
    if (!rst_ni) shift_q <= '0;
    else         shift_q <= shift_d;
end


endmodule
