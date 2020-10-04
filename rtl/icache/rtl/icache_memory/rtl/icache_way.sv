/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : icache_way.sv
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

module icache_way (
    input  logic                  clk_i      ,
    input  logic                  rstn_i     ,
    input  logic                  req_i      ,
    input  logic                  we_i       ,
    input  logic  [SET_WIDHT-1:0] data_i     ,
    input  logic [ADDR_WIDHT-1:0] addr_i     ,
    output logic  [SET_WIDHT-1:0] data_o     
);

//Build the number of sets of one way.
//genvar i;
//generate
//for ( i=0; i<ICACHE_N_SET; i++ )begin:n_set
//set_ram sram(
//    .clk_i (clk_i ),
//    .rstn_i(rstn_i),
//    .req_i (req_i ),
//    .we_i  (we_i  ),
//    .addr_i(addr_i),
//    .data_i(data_i [i*SET_WIDHT +: SET_WIDHT]),  //- The data input is segmented 
//                                                 //  according to sets.
//    .data_o(data_o [i*SET_WIDHT +: SET_WIDHT ])  //- The acquired data are organized 
//                                                 //  into one vector.
//);
//end
//endgenerate

set_ram sram(
    .clk_i (clk_i ),
    .rstn_i(rstn_i),
    .req_i (req_i ),
    .we_i  (we_i  ),
    .addr_i(addr_i),
    .data_i(data_i),  
    .data_o(data_o) 
);

//logic  [WAY_WIDHT-1:0] data_aux;
//logic [ICACHE_N_SET-1:0] control;
//
//assign control[0] = !addr_i[1] && !addr_i[0] && req_i ; 
//assign control[1] = !addr_i[1] &&  addr_i[0] && req_i ; 
//assign control[2] =  addr_i[1] && !addr_i[0] && req_i ; 
//assign control[3] =  addr_i[1] &&  addr_i[0] && req_i ; 
//
//
//set_ram sram(
//    .clk_i ( clk_i  ),
//    .rstn_i( rstn_i ),
//    .req_i ( req_i  ),
//    .control_i(control),
//    .we_i  ( we_i   ),
//    .addr_i( addr_i[7:2] ),
//    .data_i( data_i ),  
//    .data_o( data_aux )
//);
//
//
//always_comb begin
//    case(addr_i[1:0])
//        2'b00:    data_o = data_aux [127:0];
//        2'b01:    data_o = data_aux [255:128];
//        2'b10:    data_o = data_aux [383:256];
//        2'b11:    data_o = data_aux [511:384];
//        default:  data_o = '0;
//    endcase
//end


endmodule
