/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : ras.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : David Álvarez
 * Email(s)       : david.alvarez@bsc.es
 * References     :
 * -----------------------------------------------
 *  Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 * v0.2        | Max D.   | modifications in the pop push conditions and to the output pc
 */

module return_address_stack
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input   logic      rstn_i,                        // Negative reset input signal
    input   logic      clk_i,                         // Clock input signal
    input   addrPC_t   pc_execution_i,                // Program counter at Execution Stage (for push)
    input   logic      push_i,                        // Push enable bit
    input   logic      pop_i,                         // Pop enable bit
    output  addrPC_t   return_address_o               // Address popped from the stack
);

    // log_2 of the number of entries in the RAS.
    localparam _LENGTH_RAS_  = 4;
    // Number of entries of the RAS.
    localparam _NUM_RAS_ENTRIES_ = 2 ** _LENGTH_RAS_;
    // Bits needed to store a single address location
    localparam _ADDRESS_LENGTH_ = PHY_VIRT_MAX_ADDR_SIZE;

    // Registers representing the actual address stack.
    addrPC_t address_stack [0:_NUM_RAS_ENTRIES_ -1];
    // Head pointer
    logic [_LENGTH_RAS_ - 1: 0] head_pointer;
    logic [_LENGTH_RAS_ - 1: 0] output_pointer;

    assign output_pointer = head_pointer - 'h1;

    always@(posedge clk_i)
    begin
        if(~rstn_i) begin
            head_pointer <= 0;
            for(integer i = 0; i < _NUM_RAS_ENTRIES_ ; i = i + 1) begin
                address_stack[i] <= 'h0;
            end
        end else if (push_i && pop_i) begin
            address_stack[head_pointer] <= pc_execution_i;
        end else if(push_i) begin
            address_stack[head_pointer] <= pc_execution_i;
            head_pointer <= head_pointer + 1;
        end else if(pop_i) begin
            head_pointer <= head_pointer - 1;
        end
    end

    assign return_address_o = address_stack[output_pointer];

endmodule
