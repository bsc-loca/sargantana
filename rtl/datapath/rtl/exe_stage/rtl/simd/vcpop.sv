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


module vcpop
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input sew_t                 sew_i,          // Element width
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);


logic[1:0] data_sum_0[31:0];
logic[2:0] data_sum_1[15:0];
logic[3:0] data_sum_2[7:0];
logic[4:0] data_sum_3[3:0];
logic[5:0] data_sum_4[1:0];

always_comb begin
    for (int i = 0; i < 32; ++i) begin
        data_sum_0[i] = data_vs2_i[2*i] + data_vs2_i[2*i + 1]; // 2 bits added
    end

    for (int i = 0; i < 16; ++i) begin
        data_sum_1[i] = data_sum_0[2*i] + data_sum_0[2*i + 1]; // 4 bits added
    end

    for (int i = 0; i < 8; ++i) begin
        data_sum_2[i] = data_sum_1[2*i] + data_sum_1[2*i + 1]; // 8 bits added
    end

    for (int i = 0; i < 4; ++i) begin
        data_sum_3[i] = data_sum_2[2*i] + data_sum_2[2*i + 1]; // 16 bits added
    end

    for (int i = 0; i < 2; ++i) begin
        data_sum_4[i] = data_sum_3[2*i] + data_sum_3[2*i + 1]; // 32 bits added
    end

    case (sew_i)
        SEW_8: begin
            for (int i = 0; i < 8; ++i) begin
                data_vd_o[8*i +: 8] = data_sum_2[i];
            end
        end
        SEW_16: begin
            for (int i = 0; i < 4; ++i) begin
                data_vd_o[16*i +: 16] = data_sum_3[i];
            end
        end
        SEW_32: begin
            for (int i = 0; i < 2; ++i) begin
                data_vd_o[32*i +: 32] = data_sum_4[i];
            end
        end
        default: begin // SEW_64
            data_vd_o = data_sum_4[0] + data_sum_4[1];
        end
    endcase
end

endmodule