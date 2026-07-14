/*
 * Copyright 2026 BSC*
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

module vclmul
    import drac_pkg::*;
(
    input  instr_type_t instr_type_i,
    input  bus64_t      data_vs1_i,
    input  bus64_t      data_vs2_i,
    output bus64_t      data_vd_o
);

localparam int unsigned DW = $bits(bus64_t);

logic [DW-1:0] a, b;
logic [DW-1:0] y;

// Reverse input bits on clmulh
always_comb begin
    if (instr_type_i == VCLMUL) begin
        a = data_vs1_i;
        b = data_vs2_i;
    end else if (instr_type_i == VCLMULH) begin
        a = {<<{data_vs1_i}};
        b = {<<{data_vs2_i}};
    end else begin
        a = 'b0;
        b = 'b0;
    end
end

// Half-tree carry-less multiplication
always_comb begin
    y = 'b0;
    for (int unsigned i = 0; i < DW; i++) begin
        // NOTE: a << i will chop-off bits above WIDTH. That's on purpose: we
        // only want the lower half of the full 2*WIDTH-bit carry-less tree.
        if (b[i]) y ^= (a << i);
    end
end

// Reverse output bits on clmulh
always_comb begin
    if (instr_type_i == VCLMULH) begin
        data_vd_o = {<<{y}};
        data_vd_o >>= 1;
    end else begin
        data_vd_o = y;
    end
end

endmodule
