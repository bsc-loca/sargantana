/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : ras.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : David Álvarez
 * Email(s)       : david.alvarez@bsc.es
 * References     :
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

// log_2 of the number of entries in the RAS.
localparam _LENGTH_RAS_  = 2;

// Number of entries of the RAS.
localparam _NUM_RAS_ENTRIES_ = 2 ** _LENGTH_RAS_;

// Bits needed to store a single address location
localparam _ADDRESS_LENGTH_ = 40;

module return_address_stack(
    input            rstn_i,                        // Negative reset input signal
    input            clk_i,                         // Clock input signal
    input   addr_t   pc_execution_i,                // Program counter at Execution Stage (for push)
    input            push_i,                        // Push enable bit
    input            pop_i,                         // Pop enable bit
    output  addr_t   return_address_o               // Address popped from the stack
);

    // Registers representing the actual address stack.
    reg [_ADDRESS_LENGTH_ -1:0] address_stack [0:_NUM_RAS_ENTRIES_ -1];
    // Head pointer
    reg [_LENGTH_RAS_ - 1: 0] head_pointer;
    // Latched value to return
    reg [_ADDRESS_LENGTH_ -1:0] return_address;

    `ifndef SYNTHESIS
        // Initialize entries to 0.
        integer i;
        initial
        begin
            for(i = 0; i < _NUM_RAS_ENTRIES_ ; i = i + 1) begin
                address_stack[i] = 0;
            end
        end
    `endif

    always@(posedge clk_i)
    begin
        if(~rstn_i) begin
            return_address <= 0;
            head_pointer <= 0;
        end else if (push_i && pop_i) begin
            return_address <= pc_execution_i;
        end else if(push_i) begin
            address_stack[(head_pointer + 1)%_NUM_RAS_ENTRIES_] <= pc_execution_i;
            head_pointer <= head_pointer + 1;
        end else if(pop_i) begin
            return_address <= address_stack[head_pointer];
            head_pointer <= head_pointer - 1;
        end
    end

    assign return_address_o = return_address;

endmodule