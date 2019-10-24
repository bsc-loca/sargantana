/* -----------------------------------------------
* Project Name   : DRAC
* File           : decoder.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

//`default_nettype none
import drac_pkg::*;
import riscv_pkg::*;

module id_stage(
    input fetch_out_t decode_i,
    output instr_entry_t decode_instr_o
);
endmodule
