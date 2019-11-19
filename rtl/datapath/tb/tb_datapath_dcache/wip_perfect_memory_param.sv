/* -----------------------------------------------
* Project Name   : DRAC
* File           : perfect_memory.sv
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
`include "drac_pkg.sv"
import drac_pkg::*;

module perfect_memory #(
    parameter SIZE = 8*1024 * 8,
    parameter LINE_SIZE = 128,
    parameter ADDR_SIZE = 32,
    parameter CYCLES_WAIT = 1,
    localparam HEX_LOAD_ADDR = 'h1000

) (
    input logic clk_i,
    input logic rstn_i,
    input logic [ADDR_SIZE-1:0] addr_i,
    output logic [LINE_SIZE-1:0] line_o
);
    localparam BASE = 8;
    logic [BASE-1:0] memory [SIZE/BASE];

    always_comb begin
        //for (integer i = 0; i < LINE_SIZE/8; i++) begin
        //    line_o[i*BASE +: BASE] = memory[addr_i + i];
        //end
        for (integer i = 0; i < LINE_SIZE/BASE; i++) begin
            //int index_left = LINE_SIZE-BASE
            line_o[i*BASE +: BASE] = memory[addr_i + LINE_SIZE/BASE - i -1];
        end
    end

    // Here we could add a write in order to also check the saving of data
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_load_memory
        if(~rstn_i) begin
            $readmemh("test.hex", memory, HEX_LOAD_ADDR);
        end else begin
            for (integer i = 0; i < LINE_SIZE/8; i++) begin
                memory[addr + i] 
            end
        end
    end
endmodule : perfect_memory
