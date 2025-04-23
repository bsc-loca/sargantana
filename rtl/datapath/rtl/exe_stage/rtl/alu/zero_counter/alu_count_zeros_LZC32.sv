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

module alu_count_zeros_LZC32 (
    input logic[31:0] data_i,
    output logic q_o,
    output logic[4:0] y_o
);

logic[7:0] a;
logic[1:0] z[7:0];

genvar i;
generate
    for (i = 0; i < 8; ++i) begin
        alu_count_zeros_NLC NLC_inst (
            .data_i(data_i[4*i +: 4]),
            .a_o(a[7-i]),
            .z_o(z[7-i])
        );
    end
endgenerate

logic[2:0] y;

alu_count_zeros_BNE BNE_inst (
    .data_i(a),
    .q_o(q_o),
    .y_o(y)
);

assign y_o[4:2] = y;
assign y_o[1:0] = z[y];

endmodule