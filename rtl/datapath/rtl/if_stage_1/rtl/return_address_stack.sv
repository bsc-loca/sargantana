/*
 * Copyright 2023 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
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
    localparam _ADDRESS_LENGTH_ = 40;

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
