/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : set_ram.sv
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


/* Memory used to build a set*/
module sargantana_set_ram
    import sargantana_icache_pkg::*;
(
    input  logic                  clk_i       ,
    input  logic                  rstn_i      ,
    input  logic                  req_i       ,
    //input  logic  [ICACHE_N_SET-1:0] control_i       ,
    input  logic                  we_i        ,
    input  logic  [SET_WIDHT-1:0] data_i      ,
    input  logic [ADDR_WIDHT-1:0] addr_i      ,
    output logic  [SET_WIDHT-1:0] data_o
);

logic [SET_WIDHT-1:0] memory [0:ICACHE_DEPTH-1];

always_ff @(posedge clk_i) begin
    if(!rstn_i) begin
        data_o <= '0;
    end
    else if(req_i) begin
        if(we_i) memory[addr_i] <= data_i;
        else data_o <= memory[addr_i];
    end
end

//genvar i;
//generate
//for ( i=0; i<ICACHE_N_SET; i++ )begin:n_set
//ram ram(
//    .clk_i ( clk_i       ),
//    .rstn_i( rstn_i      ),
//    .req_i ( control_i[i]  ),
//    .we_i  ( we_i        ),
//    .addr_i( addr_i      ),
//    .data_i( data_i      ),   
//    .data_o( data_o [i*SET_WIDHT +: SET_WIDHT ])  //- The acquired data are organized 
//                                                 //  into one vector.
//);
//end
//endgenerate


endmodule

//**************************************************************************
//**************************************************************************


//module ram (
//    input  logic                  clk_i       ,
//    input  logic                  rstn_i      ,
//    input  logic                  req_i       ,
//    input  logic                  we_i        ,
//    input  logic  [SET_WIDHT-1:0] data_i      ,
//    input  logic [ADDR_WIDHT-1:0] addr_i      ,
//    output logic  [SET_WIDHT-1:0] data_o
//);
//
//logic [SET_WIDHT-1:0] memory [0:ICACHE_DEPTH-1];
//
//always_ff @(posedge clk_i) begin
//    if(!rstn_i) begin
//        data_o <= '0;
//    end
//    else if(req_i) begin
//        if(we_i) memory[addr_i] <= data_i;
//        else data_o <= memory[addr_i];
//    end
//end



//endmodule
