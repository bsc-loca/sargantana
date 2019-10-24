/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : bypass.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */

`default_nettype none
`include "definitions.vh"

module bypass (
    input  [4:0]      exe_src_i,
    input  `DATA      exe_data_i,

    input  `DATA      wb_data_i,
    input  [4:0]      wb_dst_i,
    input             wb_we_i,

    output reg `DATA  bypass_o
);


wire need_bypass;
assign need_bypass = ((exe_src_i == wb_dst_i) & wb_we_i) ?  1'b1 : 1'b0;

assign bypass_o = need_bypass ? wb_data_i : exe_data_i;

endmodule

