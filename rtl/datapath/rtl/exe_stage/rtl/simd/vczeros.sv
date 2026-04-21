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

module vczeros
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input sew_t                 sew_i,          // Element width
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);

/* Implementation: 16 NLC modules as on the scalar implementation (found on 
 * alu_count_zeros.sv) with a custom block of selection for having 8, 16, 32,
 * and 64 bits element size result from a 64 bits input.
 */
logic[15:0] a;
logic[15:0][1:0] z;

/* The order on a and z is inverted to match the order of the bits on the
 * input data.
 *
 * the bits of a are 1 if all the bits of the block of 4 are 0
 *
 * z is the position of the first 1 on the vlock of 4 bits
 */
genvar k;
generate
    for (k = 0; k < 16; ++k) begin
        alu_count_zeros_NLC NLC_inst (
            .data_i(data_vs2_i[4*k +: 4]),
            .z_o(z[15-k]),
            .a_o(a[15-k])
        );
    end
endgenerate


typedef union packed {
    logic[7:0][7:0] sew8;
    logic[3:0][15:0] sew16;
    logic[1:0][31:0] sew32;
    logic[0:0][63:0] sew64;
} result_t;

result_t data_result;

logic[1:0][31:0] result_sew32;

logic[7:0] zeros_sew8;
logic[3:0] zeros_sew16;
logic[1:0] zeros_sew32;

logic[3:0][1:0] selection_sew16;
logic[1:0][2:0] selection_sew32;

genvar j;
generate
    for (j = 0; j < 2; ++j) begin
        alu_count_zeros_BNE BNE_inst (
            .data_i(a[8*(1-j)+:8]),
            .q_o(zeros_sew32[j]),
            .y_o(selection_sew32[j])
        );
    end
endgenerate

//32 bits logic needs to be here because the result is used on 32 and 64 bits.
always_comb begin
    for (int i = 0; i < 2; ++i) begin
        if (zeros_sew32[i] == 1'b1) begin
            result_sew32[i] = 'd32;
        end
        else begin
            result_sew32[i][31:5] = '0;
            result_sew32[i][4:2] = selection_sew32[i];
            result_sew32[i][1:0] = z[(1-i)*8 + selection_sew32[i]];
        end
    end
end

//SEW 8
always_comb begin
    for (int i = 0; i < 8; ++i) begin
        zeros_sew8[i] = a[(7-i)*2] & a[((7-i)*2)+1];
    end

    for (int i = 0; i < 4; ++i) begin
        zeros_sew16[i] = zeros_sew8[(i*2)] & zeros_sew8[(i*2)+1];
    end

    for (int i = 0; i < 4; ++i) begin
        selection_sew16[i] = '0;
    end

    case (sew_i)
        SEW_8: begin
            for (int i = 0; i < 8; ++i) begin
                if (zeros_sew8[i] == 1'b1) begin
                    data_result.sew8[i] = 'd8;
                end
                else begin
                    data_result.sew8[i][7:3] = '0;
                    data_result.sew8[i][2] = a[(7-i)*2];
                    data_result.sew8[i][1:0] = (a[(7-i)*2] == 1'b1) ? z[(7-i)*2+1] : z[(7-i)*2];
                end
            end
        end
        SEW_16: begin
            for (int i = 0; i < 4; ++i) begin
                if (zeros_sew16[i] == 1'b1) begin
                    data_result.sew16[i] = 'd16;
                end
                else begin
                    selection_sew16[i][1] = a[(3-i)*4] & a[((3-i)*4)+1];
                    selection_sew16[i][0] = a[(3-i)*4] & ((~a[(3-i)*4+1]) | a[(3-i)*4+2]);

                    data_result.sew16[i][15:4] = '0;
                    data_result.sew16[i][3:2] = selection_sew16[i];
                    data_result.sew16[i][1:0] = z[(3-i)*4 + selection_sew16[i]];
                end
            end
        end
        SEW_32: begin

            data_result.sew32 = result_sew32;
        end
        SEW_64: begin
            if ((zeros_sew32[1] & zeros_sew32[0]) == 1'b1) begin
                data_result.sew64[0] = 'd64;
            end
            else begin
                data_result.sew64[0][63:6] = '0;
                data_result.sew64[0][5] = zeros_sew32[1];
                data_result.sew64[0][4:0] = (zeros_sew32[1] == 1'b1) ? result_sew32[0][4:0] : result_sew32[1][4:0];
            end
        end
    endcase
end

assign data_vd_o = data_result.sew64;

endmodule