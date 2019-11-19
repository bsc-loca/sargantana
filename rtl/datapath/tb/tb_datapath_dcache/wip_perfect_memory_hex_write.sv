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
* -----------------------------------------------
*/
//`include "drac_pkg.sv"
import drac_pkg::*;

// TODO: use interfaces
// TODO: create a write
// this is a specific module to read hexdumps of riscv tests 
module perfect_memory_hex_write #(
    parameter SIZE = 32*1024 * 8,
    parameter LINE_SIZE = 64,
    parameter ADDR_SIZE = 32,
    parameter DELAY = 3,
    localparam HEX_LOAD_ADDR = 'h0F0

) (
    input logic                     clk_i,
    input logic                     rstn_i,
    input addr_t                    addr_i,
    input logic                     valid_i,
    input logic                     wr_ena_i,
    input bus64_t                   wr_data_i,
    output logic [LINE_SIZE-1:0]    line_o,
    output logic                    ready_o
);
    localparam BASE = 128;
    logic [BASE-1:0] memory [SIZE/BASE];
    logic [$clog2(DELAY)-1:0] counter;
    logic [$clog2(DELAY)-1:0] next_counter;

    logic  [ADDR_SIZE-1:0]    addr_int;
    assign addr_int = 'h100+({4'b0,addr_i[31:4]}-'h010);

    // counter stuff
    assign next_counter = (counter > 0) ? counter-1 : 0;
    assign ready_o = (counter == 0);

    // counter procedure
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_counter
        if(~rstn_i) begin
            counter  <= 0;
        end else if (ready_o && valid_i) begin
            counter <= DELAY;
        end else begin
            counter <= next_counter;
        end
     end 


    always_comb begin
        // this case is quite harcoded following the hex 
        // hexadecimal dump of riscv isa test that has
        // 128 bits per line
        case (addr_i[3])
            1'b0: begin
                line_o = memory[addr_int][63:0];
            end
            1'b1: begin
                line_o = memory[addr_int][127:64];
            end
        endcase 
        
    end

    // Here we could add a write in order to also check the saving of data
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_load_memory
        if(~rstn_i) begin
            $readmemh("test.riscv.hex", memory, HEX_LOAD_ADDR);
        end else if (wr_ena_i) begin
            // TODO enable half and byte
            /*for (integer i = 0; i < LINE_SIZE/8; i++) begin
                memory[addr + i] 
            end*/
            case (addr_i[3])
                1'b0: begin
                    memory[addr_int][63:0] = wr_data_i;
                end
                1'b1: begin
                    memory[addr_int][127:64] = wr_data_i;
                end
            endcase
        end
    end
endmodule : perfect_memory_hex_write
