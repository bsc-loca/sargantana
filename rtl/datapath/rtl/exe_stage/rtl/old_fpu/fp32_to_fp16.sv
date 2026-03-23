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

module fp32_to_fp16 (
    input  logic [31:0] f32,
    input  fpnew_pkg::roundmode_e frm,
    output logic [15:0] f16,
    output fpnew_pkg::status_t status_o
);

    logic sign;
    logic [7:0]  exp32;
    logic [22:0] frac32;
    logic [4:0]  exp16;
    logic [9:0]  frac16;

    logic [4:0]  final_exp16;
    logic [9:0]  final_frac16;

    logic [7:0]  exp_unbiased;
    logic [8:0]  exp_unbiased_ext;
    logic [7:0]  exp16_biased_ext;
    logic [10:0] frac16_ext;
    logic [8:0]  shift_amt;

    logic guard;
    logic round;
    logic sticky;
    logic round_up;

    logic is_zero_f32;
    logic is_subnormal_f32;
    logic is_inf_f32;
    logic is_nan_f32;
    logic is_snan_f32;

    logic inexact;
    logic nv;
    logic overflow;
    logic underflow;
    logic is_tiny;

    logic [23:0] significand;
    logic [23:0] shifted_sig;

    logic [8:0]  rshift_amt;
    logic [9:0]  rshift_amt_ext;
    logic [23:0] sticky_mask;
    logic        sticky_shifted_out;

    localparam logic signed [4:0] EXP_BIAS_16 = 5'sd15;
    localparam logic signed [7:0] EXP_BIAS_32 = 8'sd127;
    localparam signed [7:0] MIN_NORM_EXP_16 = -8'sd14;

    always_comb begin
        sign = f32[31];
        exp32 = f32[30:23];
        frac32 = f32[22:0];

        is_zero_f32 = (exp32 == 8'h00) && (frac32 == 23'h0);
        is_subnormal_f32 = (exp32 == 8'h00) && (frac32 != 23'h0);
        is_inf_f32 = (exp32 == 8'hFF) && (frac32 == 23'h0);
        is_nan_f32 = (exp32 == 8'hFF) && (frac32 != 23'h0);
        is_snan_f32 = is_nan_f32 && !frac32[22];

        exp16 = '0;
        frac16 = '0;
        guard = 1'b0;
        round = 1'b0;
        sticky = 1'b0;
        round_up = 1'b0;
        sticky_shifted_out = 1'b0;
        rshift_amt = '0;
        sticky_mask = '0;

        nv = 1'b0;
        overflow = 1'b0;
        underflow = 1'b0;
        inexact = 1'b0;
        is_tiny = 1'b0;

        if (is_nan_f32) begin
            exp16 = 5'h1F;
            frac16 = 10'h200;
            nv = is_snan_f32;
            sign = 1'b0;

        end else if (is_inf_f32) begin
            exp16 = 5'h1F;
            frac16 = 10'h0;

        end else if (is_zero_f32) begin
            exp16 = 5'h00;
            frac16 = 10'h0;

        end else if (is_subnormal_f32) begin
            exp16 = 5'h00;
            frac16 = 10'h0;
            sticky = 1'b1;
            is_tiny = 1'b1;

        end else begin
            exp_unbiased_ext = 9'($signed({1'b0, exp32}) - EXP_BIAS_32);
            exp_unbiased = exp_unbiased_ext[7:0];

            if ($signed(exp_unbiased) > 15) begin
                exp16 = 5'h1E;
                frac16 = 10'h3FF;
                guard = 1'b1;
                round = 1'b0;
                sticky = 1'b0;
                overflow = 1'b1;

            end else if ($signed(exp_unbiased) >= MIN_NORM_EXP_16) begin
                exp16_biased_ext = $signed(exp_unbiased) + EXP_BIAS_16;
                exp16 = exp16_biased_ext[4:0];

                frac16 = frac32[22:13];
                guard = frac32[12];
                round = frac32[11];
                sticky = |frac32[10:0];

            end else begin
                is_tiny = 1'b1;
                exp16 = 5'h00;

                shift_amt = (MIN_NORM_EXP_16 - $signed(exp_unbiased));

                significand = {1'b1, frac32};
                shifted_sig = significand >> shift_amt;

                if (shift_amt < 24) begin
                    rshift_amt_ext = 9'd24 - shift_amt;
                    rshift_amt = rshift_amt_ext[8:0];
                    sticky_mask = 24'hFFFFFF >> rshift_amt;
                    sticky_shifted_out = |(significand & sticky_mask);
                end else begin
                    sticky_shifted_out = |significand;
                end

                frac16 = shifted_sig[22:13];
                guard = shifted_sig[12];
                round = shifted_sig[11];
                sticky = ((|shifted_sig[10:0]) | sticky_shifted_out);
            end
        end

        inexact = (guard || round || sticky);

        underflow = is_tiny && inexact && !is_zero_f32;

        case (frm)
            riscv_pkg::FRM_RNE: round_up = guard && (round || sticky || frac16[0]);
            riscv_pkg::FRM_RTZ: round_up = 1'b0;
            riscv_pkg::FRM_RDN: round_up = sign && (guard || round || sticky);
            riscv_pkg::FRM_RUP: round_up = !sign && (guard || round || sticky);
            riscv_pkg::FRM_RMM: round_up = (guard || round || sticky);
            default: round_up = 1'b0;
        endcase

        if (!is_nan_f32 && !is_inf_f32 && !is_zero_f32) begin
            frac16_ext = {1'b0, frac16} + round_up;
            final_exp16 = exp16;

            if (frac16_ext[10]) begin
                final_frac16 = 10'h0;
                exp16_biased_ext = {1'b0, exp16} + 1;

                if (exp16_biased_ext == 6'h1F) begin
                    final_exp16 = 5'h1F;
                    overflow = 1'b1;
                end else begin
                    final_exp16 = exp16_biased_ext[4:0];
                end
            end else begin
                final_frac16 = frac16_ext[9:0];
            end
        end

        else begin
            final_exp16 = exp16;
            final_frac16 = frac16;
        end

        f16 = {sign, final_exp16, final_frac16};

        status_o = '0;
        status_o.OF = overflow;
        status_o.UF = underflow;
        status_o.NX = inexact || overflow || underflow;
        status_o.NV = nv;
    end

endmodule
