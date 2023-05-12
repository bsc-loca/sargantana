/* -----------------------------------------------
* Project Name   : DRAC
* File           : perfect_memory_hex.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP |
*  0.2        | Victor S.P.| Adapt interface to 128 line
*  0.3        | Arnau B.S. | Adapt to verilator DPI
* -----------------------------------------------
*/
import drac_pkg::*;

// this is a specific module to read hexdumps of riscv tests 
module perfect_imem #(
    parameter LINE_SIZE = 128,
    parameter ADDR_SIZE = 40,
    parameter DELAY = 20

) (
    input logic                     clk_i,
    input logic                     rstn_i,
    input logic  [25:0]             addr_i,
    input logic                     valid_i,
    output logic [LINE_SIZE-1:0]    line_o,
    output logic                    ready_o,
    output logic                    valid_o,
    output logic [1:0]              seq_num_o
);
    logic [$clog2(DELAY)+1:0] counter;
    logic [$clog2(DELAY)+1:0] next_counter;

    logic  [25:0]    addr_int;
    logic request_q;

    // counter stuff
    assign next_counter = (counter > 0) ? counter-1 : 0;
    assign seq_num_o = 2'b11 - counter[1:0];

    // counter procedure
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_counter
        if(~rstn_i) begin
            counter <= 'h0;
            request_q <= 1'b0;
	        valid_o <= 1'b0;
        end else if (valid_i && !request_q) begin
            counter <= DELAY + 4;
	        valid_o  <= 1'b0;
	        request_q <= 1'b1;
   	        addr_int <= addr_i;
        end else if (request_q && counter > 0) begin
            counter <= next_counter;
	        addr_int <= addr_i;
   	        request_q <= 1'b1;
	        if ((next_counter < 4) && (!valid_i)) begin
	            valid_o <= 1'b1;
	        end else begin
	            valid_o <= 1'b0;
	        end
        end else begin
        	valid_o  <= 1'b0;
	        request_q <= 1'b0;
        end
    end 

    import "DPI-C" function bit memory_read (input bit [31:0] addr, output bit [LINE_SIZE-1:0] data);

    always_comb begin
        if (valid_o) begin
            memory_read({addr_int[25:0], 2'b11 - counter[1:0], 4'h0}, line_o);
        end else begin
            line_o = 0;
        end
    end

endmodule