/*
 * Copyright 2026 BSC*
 * *Barcelona Supercomputing Center (BSC)
 *
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Licensed under the Solderpad Hardware License v 2.1 (the "License"); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 *
 * https://solderpad.org/licenses/SHL-2.1/
 *
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

module fp_cvt
    import drac_pkg::*;
    import fpnew_pkg::*;
    import riscv_pkg::*;
#(
                parameter fpnew_pkg::fp_format_e SRC_FMT = FP32,
                parameter fpnew_pkg::fp_format_e DST_FMT = FP64
)(
   input logic [fp_width(SRC_FMT)-1:0]  operand_i,
   input                                fpnew_pkg::roundmode_e frm,
   output logic [fp_width(DST_FMT)-1:0] result_o,
   output fpnew_pkg::status_t status_o
);

    localparam                     SRC_WIDTH = fp_width(SRC_FMT);
    localparam                     DST_WIDTH = fp_width(DST_FMT);

    localparam                     SRC_MAN_WIDTH = man_bits(SRC_FMT);
    localparam                     DST_MAN_WIDTH = man_bits(DST_FMT);

    localparam                     SRC_EXP_WIDTH = exp_bits(SRC_FMT);
    localparam                     DST_EXP_WIDTH = exp_bits(DST_FMT);

    localparam int unsigned SRC_BIAS = (1 << (SRC_EXP_WIDTH - 1)) - 1;
    localparam int unsigned DST_BIAS = (1 << (DST_EXP_WIDTH - 1)) - 1;

    // Functions at compile time to check NaNs
    function automatic logic is_snan(logic [SRC_WIDTH-1:0] op);
        if (SRC_FMT == FP16)      return is_snan_f16(op);
        else if (SRC_FMT == FP32) return is_snan_f32(op);
        else                      return is_snan_f64(op);
    endfunction

    function automatic logic is_qnan(logic [SRC_WIDTH-1:0] op);
        if (SRC_FMT == FP16)      return is_qnan_f16(op);
        else if (SRC_FMT == FP32) return is_qnan_f32(op);
        else                      return is_qnan_f64(op);
    endfunction

    function automatic logic [DST_WIDTH-1:0] qnan();
        if (DST_FMT == FP16)      return FP16_QNAN;
        else if (DST_FMT == FP32) return FP32_QNAN;
        else                      return FP64_QNAN;
    endfunction

    function automatic logic is_inf(logic [SRC_WIDTH-1:0] op);
        if (SRC_FMT == FP16)      return is_inf_f16(op);
        else if (SRC_FMT == FP32) return is_inf_f32(op);
        else                      return is_inf_f64(op);
    endfunction

    function automatic logic is_nan(logic [SRC_WIDTH-1:0] op);
        return is_qnan(op) || is_snan(op);
    endfunction

    function automatic logic is_sub(logic [SRC_WIDTH-1:0] op);
        if (SRC_FMT == FP16)      return is_subnorm_f16(op);
        else if (SRC_FMT == FP32) return is_subnorm_f32(op);
        else                      return is_subnorm_f64(op);
    endfunction

    generate
        logic                                   sign;
        logic [SRC_EXP_WIDTH-1:0]               exp_src;
        logic [SRC_MAN_WIDTH-1:0]               frac_src;

        logic [DST_EXP_WIDTH-1:0]               exp_dst;
        logic [DST_MAN_WIDTH-1:0]               frac_dst;

        if (SRC_WIDTH < DST_WIDTH) begin : gen_widening

            logic [DST_MAN_WIDTH+SRC_MAN_WIDTH-1:0] frac_src_shifted_ext;
            logic [SRC_MAN_WIDTH:0]                 frac_src_shifted;

            logic                                   nv_flag;

            logic [DST_WIDTH-1:0]                   converted_val;

            logic [$clog2(SRC_MAN_WIDTH)-1:0]       shift_amount;
            logic                                   empty_lzc_denormals;

            lzc #(
                .WIDTH (SRC_MAN_WIDTH),
                .MODE  (1)
            ) i_lzc (
                .in_i    (frac_src),
                .cnt_o   (shift_amount),
                .empty_o (empty_lzc_denormals)
            );

            always_comb begin
                result_o = '0;
                status_o = '0;

                converted_val = '0;

                frac_dst = '0;
                exp_dst = '0;

                nv_flag = 1'b0;

                sign = 1'b0;
                exp_src = '0;
                frac_src = '0;

                frac_src_shifted_ext = '0;
                frac_src_shifted = '0;

                sign = operand_i[SRC_WIDTH-1];
                exp_src = operand_i[SRC_WIDTH-2 -: SRC_EXP_WIDTH];
                frac_src = operand_i[SRC_WIDTH-2-SRC_EXP_WIDTH -: SRC_MAN_WIDTH];

                nv_flag = is_snan(operand_i);

                if (exp_src == '0) begin
                    if (frac_src == '0) begin
                        exp_dst = '0;
                        frac_dst = '0;
                    end else begin
                        exp_dst = ((bias(DST_FMT) - bias(SRC_FMT)) - shift_amount);

                        frac_src_shifted_ext = {{DST_MAN_WIDTH-SRC_MAN_WIDTH {1'b0}}, frac_src } << (shift_amount + 1);
                        frac_src_shifted = frac_src_shifted_ext[SRC_MAN_WIDTH-1:0];

                        frac_dst = {frac_src_shifted, {DST_MAN_WIDTH-SRC_MAN_WIDTH {1'b0} }};
                    end
                end else begin
                    exp_dst = (exp_src - bias(SRC_FMT)) + bias(DST_FMT);
                    frac_dst = {frac_src, {DST_MAN_WIDTH-SRC_MAN_WIDTH {1'b0}}};
                end

                if (is_nan(operand_i)) begin
                    converted_val = qnan();
                end else if (is_inf(operand_i)) begin
                    converted_val = {sign, {DST_EXP_WIDTH {1'b1} }, {DST_MAN_WIDTH {1'b0} }};
                end else begin
                    converted_val = {sign, exp_dst, frac_dst};
                end

                result_o = converted_val;
                status_o.NV = nv_flag;
            end

        end else if (SRC_WIDTH > DST_WIDTH) begin : gen_narrowing

            logic guard;
            logic round;
            logic sticky;

            logic round_up;

            logic is_tiny;
            logic overflow;
            logic underflow;

            logic nv;
            logic inexact;

            logic [DST_MAN_WIDTH:0] frac_dst_ext;
            logic [DST_MAN_WIDTH-1:0] final_frac_dst;
            logic [DST_EXP_WIDTH-1:0] final_exp_dst;
            logic [DST_EXP_WIDTH:0] exp_dst_biased_ext;

            localparam int signed MIN_NORM_EXP = 1 - signed'(DST_BIAS);

            logic signed [SRC_EXP_WIDTH:0] exp_unbiased_ext;
            logic signed [SRC_EXP_WIDTH-1:0] exp_unbiased;

            logic [SRC_MAN_WIDTH:0] significand;
            logic [SRC_MAN_WIDTH:0] shifted_sig;
            localparam int unsigned MAX_SHIFT = (1 << (SRC_EXP_WIDTH-1)) - (1 << (DST_EXP_WIDTH-1));
            logic [$clog2(MAX_SHIFT + 1)-1:0] shift_amt;
            logic sticky_shifted_out;
            logic [$clog2(SRC_MAN_WIDTH+2)-1:0] rshift_amt;
            logic [SRC_MAN_WIDTH:0] sticky_mask;


            always_comb begin
                result_o = '0;
                status_o = '0;

                nv = 1'b0;
                inexact = 1'b0;
                overflow = 1'b0;
                underflow = 1'b0;
                is_tiny = 1'b0;

                guard = 1'b0;
                round = 1'b0;
                sticky = 1'b0;

                sign = operand_i[SRC_WIDTH-1];
                exp_src = operand_i[SRC_WIDTH-2 -: SRC_EXP_WIDTH];
                frac_src = operand_i[SRC_WIDTH-2-SRC_EXP_WIDTH -: SRC_MAN_WIDTH];

                if (is_nan(operand_i)) begin // NaN
                    exp_dst = '1;
                    frac_dst = {1'b1, {(DST_MAN_WIDTH-1) {1'b0} }};
                    nv = is_snan(operand_i);
                    sign = 1'b0;
                end else if (is_inf(operand_i)) begin // inf
                    exp_dst = '1;
                    frac_dst = '0;
                end else if (operand_i == '0 || (operand_i == {1'b1, {(SRC_WIDTH-1) {1'b0}}})) begin // zero
                    exp_dst = '0;
                    frac_dst = '0;
                end else if (is_sub(operand_i)) begin // subnormal
                    exp_dst = '0;
                    frac_dst = '0;
                    sticky = 1'b1;
                    is_tiny = 1'b1;
                end else begin // regular path
                    exp_unbiased_ext = $signed({1'b0, exp_src}) - signed'(bias(SRC_FMT));
                    exp_unbiased = exp_unbiased_ext[SRC_EXP_WIDTH-1:0];

                    if (exp_unbiased > signed'(DST_BIAS)) begin
                        exp_dst = {(DST_EXP_WIDTH){1'b1}} - 1'b1;
                        frac_dst = '1;
                        guard = 1'b1;
                        round = 1'b0;
                        sticky = 1'b0;
                        overflow = 1'b1;
                    end else if (exp_unbiased >= MIN_NORM_EXP) begin
                        exp_dst_biased_ext = $signed(exp_unbiased) + signed'(DST_BIAS);
                        exp_dst = exp_dst_biased_ext[DST_EXP_WIDTH-1:0];

                        frac_dst = frac_src[SRC_MAN_WIDTH-1 -: DST_MAN_WIDTH];

                        guard = frac_src[SRC_MAN_WIDTH-DST_MAN_WIDTH-1];
                        round = frac_src[SRC_MAN_WIDTH-DST_MAN_WIDTH-2];
                        sticky = |frac_src[SRC_MAN_WIDTH-DST_MAN_WIDTH-3:0];

                    end else begin
                        is_tiny = 1'b1;
                        exp_dst = '0;

                        shift_amt = (MIN_NORM_EXP - $signed(exp_unbiased));

                        significand = {1'b1, frac_src};
                        shifted_sig = significand >> shift_amt;

                        if (shift_amt < (SRC_MAN_WIDTH + 1)) begin
                            rshift_amt = (SRC_MAN_WIDTH + 1) - shift_amt;
                            sticky_mask = {(SRC_MAN_WIDTH+1){1'b1}} >> rshift_amt;
                            sticky_shifted_out = |(significand & sticky_mask);
                        end else begin
                            sticky_shifted_out = |significand;
                        end

                        frac_dst = shifted_sig[SRC_MAN_WIDTH-1 -: DST_MAN_WIDTH];
                        guard = shifted_sig[SRC_MAN_WIDTH-DST_MAN_WIDTH-1];
                        round = shifted_sig[SRC_MAN_WIDTH-DST_MAN_WIDTH-2];
                        sticky = (|shifted_sig[SRC_MAN_WIDTH-DST_MAN_WIDTH-3 : 0]) | sticky_shifted_out;
                    end
                end

                inexact = (guard || round || sticky);

                underflow = is_tiny && inexact && (operand_i != '0);

                case (frm)
                    riscv_pkg::FRM_RNE: round_up = guard && (round || sticky || frac_dst[0]);
                    riscv_pkg::FRM_RTZ: round_up = 1'b0;
                    riscv_pkg::FRM_RDN: round_up = sign && (guard || round || sticky);
                    riscv_pkg::FRM_RUP: round_up = !sign && (guard || round || sticky);
                    riscv_pkg::FRM_RMM: round_up = guard;
                    default: round_up = 1'b0;
                endcase

                if (!is_nan(operand_i) && !is_inf(operand_i) && (operand_i != '0)) begin
                    frac_dst_ext = {1'b0, frac_dst} + round_up;
                    final_exp_dst = exp_dst;

                    if (frac_dst_ext[DST_MAN_WIDTH]) begin
                        final_frac_dst = '0;
                        exp_dst_biased_ext = {1'b0, exp_dst} + 1'b1;

                        if (exp_dst_biased_ext[DST_EXP_WIDTH-1:0] == '1) begin
                            final_exp_dst = '1;
                            overflow = 1'b1;
                        end else begin
                            final_exp_dst = exp_dst_biased_ext[DST_EXP_WIDTH-1:0];
                        end
                    end else begin
                        final_frac_dst = frac_dst_ext[DST_MAN_WIDTH-1:0];
                    end
                end else begin
                    final_exp_dst = exp_dst;
                    final_frac_dst = frac_dst;
                end

                result_o = {sign, final_exp_dst, final_frac_dst};

                status_o = '0;
                status_o.OF = overflow;
                status_o.UF = underflow;
                status_o.NX = inexact || overflow || underflow;
                status_o.NV = nv;
            end

        end else begin : gen_passthrough

            always_comb begin
                result_o = operand_i;
                status_o = '0;
            end

        end
    endgenerate

endmodule;