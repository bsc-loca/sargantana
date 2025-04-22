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

module alu_count_zeros
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

bus64_t data_to_calc;

always_comb begin
    case (instr_type_i)
        CTZ: begin
            for (int i = 0; i < 64; ++i) begin
                data_to_calc[i] = data_rs1_i[63-i];
            end
        end
        CTZW: begin
            for (int i = 0; i < 32; ++i) begin
                data_to_calc[i] = data_rs1_i[31-i];
            end

            data_to_calc[63:32] = '0;
        end
        CLZ: begin
            data_to_calc = data_rs1_i;
        end
        CLZW: begin
            data_to_calc[31:0] = data_rs1_i[31:0];
            data_to_calc[63:32] = '0;
        end
        default: begin
            data_to_calc = data_rs1_i;
        end
    endcase
end

bus64_t res_module;

logic q_high;
logic q_low;

logic[4:0] y_high;
logic[4:0] y_low;

LZC_32_bits LZC_32_bits_high (
    .data_i(data_to_calc[63:32]),
    .q_o(q_high),
    .y_o(y_high)
);

LZC_32_bits LZC_32_bits_low (
    .data_i(data_to_calc[31:0]),
    .q_o(q_low),
    .y_o(y_low)
);

logic invalid;

always_comb begin
    res_module = '0;

    invalid = q_high & q_low;
    res_module[6] = invalid;
    res_module[5] = (invalid == 1'b0) ? q_high : 1'b0;
    res_module[4:0] = (invalid == 1'b0) ? (q_high == 1'b1) ? y_low : y_high : 5'b0;
end



always_comb begin
    case (instr_type_i)
        CTZW, CLZW: begin
            if (res_module == 64) begin
                result_o = 32;
            end else if (res_module[5] == 1'b1) begin
                result_o = res_module;
                result_o[5] = 1'b0;
            end else begin
                result_o = res_module;
            end
        end
        default: begin
            result_o = res_module;
        end
    endcase
end

endmodule
