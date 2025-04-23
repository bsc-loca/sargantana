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

module alu_count_zeros_BNE (
    input logic[7:0] data_i,
    output logic q_o,
    output logic[2:0] y_o
);

assign q_o = data_i[0] & data_i[1] & data_i[2] & data_i[3] & data_i[4] & data_i[5] & data_i[6] & data_i[7];
assign y_o[2] = data_i[0] & data_i[1] & data_i[2] & data_i[3];
assign y_o[1] = data_i[0] & data_i[1] & (~data_i[2] | ~data_i[3] | (data_i[4] & data_i[5]));
assign y_o[0] = (data_i[0] & (~data_i[1] | (data_i[2] & ~data_i[3]))) | (data_i[0] & data_i[2] & data_i[4] & (~data_i[5] | data_i[6]));
endmodule