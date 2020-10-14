/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : itag_memory.sv
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

module itag_memory_sram64x80(
    input  logic                                   clk_i      ,
    input  logic                                   rstn_i     ,
    input  logic                [ICACHE_N_WAY-1:0] req_i      ,
    input  logic                                   we_i       ,
    input  logic                                   vbit_i     ,
    input  logic                                   flush_i    ,
    input  logic                   [TAG_WIDHT-1:0] data_i     ,
    input  logic                  [ADDR_WIDHT-1:0] addr_i     ,
    output logic [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] tag_way_o  , //- one for each way.
    output logic                [ICACHE_N_WAY-1:0] vbit_o       
);

//logic [ICACHE_N_WAY-1:0] mem_ready;

//- To build a memory of tags for each path.

//Valid bit wires
logic [ICACHE_DEPTH-1:0] vbit_vec [0:ICACHE_N_WAY-1];

//Tag array wires
logic [79:0] q_sram;
logic [79:0] write_mask, write_data, w_mask, w_data, mask;
logic write_enable;

//--VALID bit vector
genvar i;
generate
for ( i=0; i<ICACHE_N_WAY; i++ )begin
    always_ff @(posedge clk_i) begin
        if(!rstn_i || flush_i) vbit_vec[i] <= '0; 
        else if(req_i[i]) begin
            if(we_i) vbit_vec[i][addr_i] <= vbit_i;
            else vbit_o[i] <= vbit_vec[i][addr_i];
        end
    end
end
endgenerate


// Tag array SRAM implementation

assign mask[19:0] = 20'(req_i[0]);
assign mask[39:20] = 20'(req_i[1]);
assign mask[59:40] = 20'(req_i[2]);
assign mask[79:60] = 20'(req_i[3]);
assign w_mask = 20'(we_i) & mask;
    
assign w_data[19:0] = data_i;
assign w_data[39:20] = data_i;
assign w_data[59:40] = data_i;
assign w_data[79:60] = data_i;



`ifdef INCISIVE_SIMULATION
  assign #1 write_mask = ~w_mask;
  assign #1 write_data = w_data;
  assign #1 write_enable = ~we_i;
`else
  assign write_mask = ~w_mask;
  assign write_data = w_data;
  assign write_enable = ~we_i;
`endif

TS1N65LPA64X80M4 IC_tag_array (
    .A  (RW0A) ,
    .D  (write_data) ,
    .BWEB  (write_mask) ,
    .WEB  (write_enable) ,
    .CEB  (~(|req_i)) ,
    .CLK  (clk_i) ,
    .Q  (q_sram)
); 

assign tag_way_o[0] = q_sram[19:0];
assign tag_way_o[1] = q_sram[39:20];
assign tag_way_o[2] = q_sram[59:40];
assign tag_way_o[3] = q_sram[79:60];

endmodule





