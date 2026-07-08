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

logic [DW-1:0][2*DW-1:0] partials;

genvar i;
generate
    for (i = 0; i < DW; i++) begin : gen_partials
        assign partials[i] = data_vs2_i[i] ? {{DW{1'b0}}, data_vs1_i} << i : 'b0;
    end
endgenerate

always_comb begin
    data_vd_o = '0;
    for (int unsigned j = 0; j < DW; j++) begin
        if (instr_type_i == VCLMUL) begin
            data_vd_o ^= partials[j][DW-1:0];
        end else if (instr_type_i == VCLMULH) begin
            data_vd_o ^= partials[j][2*DW-1:DW];
        end else begin
            data_vd_o ^= 'b0;
        end
    end
end

endmodule
