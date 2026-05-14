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

module zfa_post_process
import drac_pkg::*;
import fpnew_pkg::*;
#(
  parameter type TagType = logic
) (
    input  rr_exe_fpu_instr_t  instruction_i,
    input  logic [63:0]        result_i,
    input  fpnew_pkg::status_t status_i,
    input  TagType             tag_i,
    input  logic               out_valid_i,
    output logic [63:0]        result_o,
    output fpnew_pkg::status_t status_o,
    output TagType             tag_o,
    output logic               out_valid_o
);

    logic [31:0] fp32_post_in2fp;
    logic [63:0] fp64_post_in2fp;

    logic [31:0] abs_result_i_32;
    logic [63:0] abs_result_i_64;

    assign abs_result_i_32 = result_i[31] ? (~result_i[31:0] + 1'b1) : result_i[31:0];
    assign abs_result_i_64 = result_i[63] ? (~result_i[63:0] + 1'b1) : result_i[63:0];

    // Pass through by default
    fpnew_int2fp # (
        .AbsWidth(32),
        .FP_WIDTH(32),
        .fmt(FP32)
    )
    fp32_rounding (
        .abs_value_i(abs_result_i_32),
        .is_nan(is_nan_f32(result_i)),
        .sign_i(result_i[31]),
        .post_in2fp(fp32_post_in2fp)
    );

    fpnew_int2fp #(
        .AbsWidth(64),
        .FP_WIDTH(64),
        .fmt(FP64)
    )
    fp64_rounding (
        .abs_value_i(abs_result_i_64),
        .is_nan(is_nan_f64(result_i)),
        .sign_i(result_i[63]),
        .post_in2fp(fp64_post_in2fp)
    );


    always_comb begin
        status_o    = status_i;
        tag_o       = tag_i;
        out_valid_o = out_valid_i;
        result_o    = result_i;

        // FMINM/FMAXM - return canonical NaN if EITHER operand is NaN
        if (instruction_i.instr.instr_type == FMINM_MAXM) begin
            if (instruction_i.instr.fmt == FP32) begin
                if (is_nan_f32(instruction_i.data_rs1[31:0]) || is_nan_f32(instruction_i.data_rs2[31:0])) begin
                    result_o = 64'hFFFFFFFF_7FC00000;
                end
            end else begin // FP64
                if (is_nan_f64(instruction_i.data_rs1) || is_nan_f64(instruction_i.data_rs2)) begin
                    result_o = 64'h7FF8000000000000;
                end
            end

        // FLEQ/FLTQ
        end else if (instruction_i.instr.instr_type == FLEQ_FLTQ) begin
            if (instruction_i.instr.fmt == FP32) begin
                if (is_nan_f32(instruction_i.data_rs1) || is_nan_f32(instruction_i.data_rs2)) begin
                    status_o.NV = 1'b0;
                end
            end else begin // FP64
                if (is_nan_f64(instruction_i.data_rs1) || is_nan_f64(instruction_i.data_rs2)) begin
                    status_o.NV = 1'b0;
                end
            end

        // FROUND/FROUNDNX
        end else if ((instruction_i.instr.instr_type == FROUND) || (instruction_i.instr.instr_type == FROUNDNX)) begin
            if (instruction_i.instr.fmt == FP32) begin
                if (is_inf_f32(instruction_i.data_rs1[31:0])) begin
                    result_o = {{32{1'b1}}, instruction_i.data_rs1[31:0]};
                    status_o.NX = 1'b0;
                    status_o.NV = 1'b0;
                end else if (is_nan_f32(instruction_i.data_rs1[31:0])) begin
                    result_o = { {32{1'b1}}, FP32_QNAN};
                    if (is_snan_f32(instruction_i.data_rs1[31:0])) begin
                        status_o.NV = 1'b1;
                    end else begin
                        status_o.NV = 1'b0;
                    end
                end else if (status_i.NV == 1'b1) begin // must be overflow or underflow as NaNs have already been dealt with
                    result_o = instruction_i.data_rs1;
                    status_o.NV = 1'b0; // OF/UF doesn't rise NV
                end else begin
                    if (instruction_i.data_rs1[31] == 1'b1) begin
                        result_o = {{33{1'b1}}, fp32_post_in2fp[30:0]};
                        status_o.NX = ~({1'b1, fp32_post_in2fp[30:0]} == instruction_i.data_rs1[31:0]) && (instruction_i.instr.instr_type == FROUNDNX);
                    end else begin
                        result_o = {{32{1'b1}}, fp32_post_in2fp};
                        status_o.NX = (fp32_post_in2fp != instruction_i.data_rs1[31:0]) && (instruction_i.instr.instr_type == FROUNDNX);
                    end
                end
            end else begin // FP64
                if (is_inf_f64(instruction_i.data_rs1[63:0])) begin
                    result_o = instruction_i.data_rs1[63:0];
                    status_o.NX = 1'b0;
                    status_o.NV = 1'b0;
                end else if (is_nan_f64(instruction_i.data_rs1[63:0])) begin
                    result_o = { FP64_QNAN};
                    if (is_snan_f64(instruction_i.data_rs1[63:0])) begin
                        status_o.NV = 1'b1;
                    end else begin
                        status_o.NV = 1'b0;
                    end
                end else if (status_i.NV == 1'b1) begin // must be overflow or underflow as NaNs have already been dealt with
                    result_o = instruction_i.data_rs1;
                    status_o.NV = 1'b0; // OF/UF doesn't rise NV
                end else begin
                    if (instruction_i.data_rs1[63] == 1'b1) begin
                        result_o = {1'b1, fp64_post_in2fp[62:0]};
                        status_o.NX = ~({1'b1, fp64_post_in2fp[62:0]} == instruction_i.data_rs1[63:0]) && (instruction_i.instr.instr_type == FROUNDNX);
                    end else begin
                        result_o = fp64_post_in2fp;
                        status_o.NX = (fp64_post_in2fp != instruction_i.data_rs1[63:0]) && (instruction_i.instr.instr_type == FROUNDNX);
                    end
                end
            end
        end
       end
endmodule
