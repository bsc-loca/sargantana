/*
 * Copyright 2025 BSC*
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
 
 module register #(
    parameter WIDTH = 64
) (
    input logic clk_i,
    input logic rstn_i,
    input logic flush_i,
    input logic load_i,
    input logic [WIDTH-1:0] input_i,
    output logic [WIDTH-1:0] output_o
);
logic [WIDTH-1:0] register_q;
    
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            register_q <= 0;
        end else if (flush_i) begin
            register_q <= 0;
        end else if (load_i) begin
            register_q <= input_i;
        end else begin
            register_q <= register_q;
        end
    end

    assign output_o = register_q;

endmodule

`default_nettype wire

