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

import drac_pkg::*;

module perfect_memory #(
    parameter SIZE = 8*1024 * 8,
    parameter LINE_SIZE = 32,
    parameter ADDR_SIZE = 32,
    localparam HEX_LOAD_ADDR = 'h0100
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
        end //else begin
            //for (integer i = 0; i < LINE_SIZE/8; i++) begin
            //    memory[addr + i] 
            //end
        //end
    end
endmodule : perfect_memory
