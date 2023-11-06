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

// this is a specific module to read hexdumps of riscv tests 
module perfect_memory_hex #(
    parameter SIZE = 32*1024 * 8,
    parameter LINE_SIZE = 32,
    parameter ADDR_SIZE = 32,
    parameter DELAY = 0,
    localparam HEX_LOAD_ADDR = 'h0F0

) (
    input logic                     clk_i,
    input logic                     rstn_i,
    input logic  [ADDR_SIZE-1:0]    addr_i,
    input logic                     valid_i,
    output logic [LINE_SIZE-1:0]    line_o,
    output logic                    ready_o
);
    localparam BASE = 128;
    logic [BASE-1:0] memory [SIZE/BASE];
    logic [$clog2(DELAY):0] counter;
    logic [$clog2(DELAY):0] next_counter;

    logic  [ADDR_SIZE-1:0]    addr_int;
    //assign addr_int = {addr_i[31:8],8'b0}+16;
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
        case (addr_i[3:2])
            2'b00: begin
                line_o = memory[addr_int][31:0];
            end
            2'b01: begin
                line_o = memory[addr_int][63:32];
            end
            2'b10: begin
                line_o = memory[addr_int][95:64];
            end
            2'b11: begin
                line_o = memory[addr_int][127:96];
            end
        endcase 
        
    end

    // Here we could add a write in order to also check the saving of data
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_load_memory
        if(~rstn_i) begin
            $readmemh("test.riscv.hex", memory, HEX_LOAD_ADDR);
        end //else begin
            //for (integer i = 0; i < LINE_SIZE/8; i++) begin
            //    memory[addr + i] 
            //end
        //end
    end
endmodule : perfect_memory_hex
