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

module fp16_to_fp64 (
    input logic [15:0] fp16_i,
    output logic [63:0] fp64_o,
    output logic nv_o
);

    logic        sign;
    logic [4:0]  exp16;
    logic [9:0]  frac16;

    logic [10:0] exp64;
    logic [51:0] frac64;

    logic        nv_flag;
    logic [63:0] converted_val;
    logic [3:0]  shift_amount;

    logic [63:0] fp64_s;

    logic empty_lzc_denormals;

    lzc #(
        .WIDTH(10),
        .MODE(1)
    ) i_lzc (
        .in_i(frac16),
        .cnt_o(shift_amount),
        .empty_o(empty_lzc_denormals)
    );

    always_comb begin
        sign   = fp16_i[15];
        exp16  = fp16_i[14:10];
        frac16 = fp16_i[9:0];

        // Snan
        nv_flag = (exp16 == 5'h1F) && (frac16[9] == 1'b0) && (frac16[8:0] != 0);

        // Denormalized or Zero case
        if (exp16 == 5'h00) begin
            if (frac16 == 10'h000) begin
                exp64  = 11'h000;
                frac64 = 52'h0000000000000;
            end
            else begin
                exp64 = (11'd1008 - shift_amount);

                frac64 = {frac16, {42{1'b0}}} << (shift_amount + 1);
            end
        end

        // Infinity or NaN case
        else if (exp16 == 5'h1F) begin
            exp64  = 11'h7FF;
            frac64 = {frac16, {42{1'b0}}};
        end
        else begin
            // Re-bias
            exp64  = (exp16 - 5'd15) + 11'd1023;
            frac64 = {frac16, {42{1'b0}}};
        end

        if (drac_pkg::is_qnan_f16(fp16_i)) begin
            converted_val = drac_pkg::FP64_QNAN;
        end else if (drac_pkg::is_snan_f16(fp16_i)) begin
            converted_val = drac_pkg::FP64_QNAN;
        end else begin
            converted_val = {sign, exp64, frac64};
        end

        fp64_s = converted_val;
    end

    assign fp64_o = fp64_s;
    assign nv_o = nv_flag;

endmodule
