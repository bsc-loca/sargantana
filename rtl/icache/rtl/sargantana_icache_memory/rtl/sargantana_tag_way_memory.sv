/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : tag_way_memory.sv
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



module sargantana_tag_way_memory
    import sargantana_icache_pkg::*;
(
    input  logic                  clk_i ,
    input  logic                  rstn_i,
    input  logic                  req_i ,
    input  logic                  we_i  ,
    input  logic                  vbit_i ,
    input  logic                  flush_i ,
    input  logic  [TAG_WIDHT-1:0] data_i,
    input  logic [TAG_ADDR_WIDHT-1:0] addr_i,
    output logic  [TAG_WIDHT-1:0] data_o,
    output logic                  vbit_o
);
    
logic [TAG_WIDHT-1:0] memory [0:TAG_DEPTH-1];

logic [TAG_DEPTH-1:0] vbit_vec;

//--TAG memory
always_ff @(posedge clk_i) begin
    if(!rstn_i)
        data_o <= '0; 
    else if(req_i) begin
        if(we_i) memory[addr_i] <= {data_i};
        else data_o <= memory[addr_i];
    end
end

//--VALID bit vector

always_ff @(posedge clk_i) begin
    if(!rstn_i || flush_i) vbit_vec <= '0; 
    else if(req_i) begin
        if(we_i) vbit_vec[addr_i] <= vbit_i;
        else vbit_o <= vbit_vec[addr_i];
    end
end





//assign data_o = data_aux[TAG_WIDHT-1:0];
//assign vbit_o = data_aux[TAG_WIDHT];

endmodule

