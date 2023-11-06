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

`default_nettype none

module register #(
    parameter WIDTH = 64
) (
    input wire clk_i,
    input wire rstn_i,
    input wire flush_i,
    input wire load_i,
    input wire [WIDTH-1:0] input_i,
    output reg [WIDTH-1:0] output_o
);
    
    always @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            output_o <= 0;
        end else if (flush_i) begin
            output_o <= 0;
        end else if (load_i) begin
            output_o <= input_i;
        end else begin
            output_o <= output_o;
        end
    end

endmodule

`default_nettype wire

