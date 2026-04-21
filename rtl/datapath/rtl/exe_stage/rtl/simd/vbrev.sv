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

module vbrev
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input sew_t                 sew_i,          // Element width
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);

always_comb begin
    case (sew_i)
        SEW_8: begin
            for (int i = 0; i < 8; ++i) begin
                for (int j = 0; j < 8; ++j) begin
                    data_vd_o[(i*8)+j] = data_vs2_i[(i*8)+7-j];
                end
            end
        end
        SEW_16: begin
            for (int i = 0; i < 4; ++i) begin
                for (int j = 0; j < 16; ++j) begin
                    data_vd_o[(i*16)+j] = data_vs2_i[(i*16)+15-j];
                end
            end
        end
        SEW_32: begin
            for (int i = 0; i < 2; ++i) begin
                for (int j = 0; j < 32; ++j) begin
                    data_vd_o[(i*32)+j] = data_vs2_i[(i*32)+31-j];
                end
            end
        end
        SEW_64: begin
            for (int j = 0; j < 64; ++j) begin
                data_vd_o[j] = data_vs2_i[63-j];
            end
        end
    endcase
end

endmodule