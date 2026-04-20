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

module conv_zfa
import drac_pkg::*;
import fpnew_pkg::*;
#(
  parameter type                     TagType     = logic
) (
    input logic         clk_i,
    input logic         rstn_i,
    input logic [63:0]  operand_i,
    input               fpnew_pkg::fp_format_e fmt_i,
    input               valid_i,
    input               reg_t tag_i,
    output logic [63:0] result_o,
    output fpnew_pkg::status_t status_o,
    output TagType      tag_o,
    output logic        out_valid_o
    );

    logic [63:0]        result_d;
    fpnew_pkg::status_t status_d;
    TagType             tag_d;
    logic               out_valid_d;

    logic [4:0] operand_b;
    assign operand_b = operand_i[4:0];

    logic [63:0] fli_result_fp32;
    logic [63:0] fli_result_fp64;

    localparam EXP_BITS_FP32 = 8;
    localparam MAN_BITS_FP32 = 23;
    localparam EXP_BITS_FP64 = 11;
    localparam MAN_BITS_FP64 = 52;

    always_comb begin : fli_fp32
        case (operand_b)
            0:  fli_result_fp32 = {1'b1, {1'b0, {(EXP_BITS_FP32-1){1'b1}}}, {MAN_BITS_FP32{1'b0}}};
            1:  fli_result_fp32 = {1'b0, {{(EXP_BITS_FP32-1){1'b0}}, 1'b1}, {MAN_BITS_FP32{1'b0}}};
            2:  fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-6{1'b1}}, 5'b01111}, {MAN_BITS_FP32{1'b0}}};
            3:  fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-5{1'b1}}, 4'b0000}, {MAN_BITS_FP32{1'b0}}};
            4:  fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-5{1'b1}}, 4'b0111}, {MAN_BITS_FP32{1'b0}}};
            5:  fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-4{1'b1}}, 3'b000}, {MAN_BITS_FP32{1'b0}}};
            6:  fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-4{1'b1}}, 3'b011}, {MAN_BITS_FP32{1'b0}}};
            7:  fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-3{1'b1}}, 2'b00}, {MAN_BITS_FP32{1'b0}}};
            8:  fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-3{1'b1}}, 2'b01}, {MAN_BITS_FP32{1'b0}}};
            9:  fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-3{1'b1}}, 2'b01}, {2'b01, {MAN_BITS_FP32-2{1'b0}}}};
            10: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-3{1'b1}}, 2'b01}, {1'b1, {MAN_BITS_FP32-1{1'b0}}}};
            11: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-3{1'b1}}, 2'b01}, {2'b11, {MAN_BITS_FP32-2{1'b0}}}};
            12: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-2{1'b1}}, 1'b0}, {MAN_BITS_FP32{1'b0}}};
            13: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-2{1'b1}}, 1'b0}, {2'b01, {MAN_BITS_FP32-2{1'b0}}}};
            14: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-2{1'b1}}, 1'b0}, {1'b1, {MAN_BITS_FP32-1{1'b0}}}};
            15: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-2{1'b1}}, 1'b0}, {2'b11, {MAN_BITS_FP32-2{1'b0}}}};
            16: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-1{1'b1}}}, {MAN_BITS_FP32{1'b0}}};
            17: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-1{1'b1}}}, {2'b01, {MAN_BITS_FP32-2{1'b0}}}};
            18: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-1{1'b1}}}, {1'b1, {MAN_BITS_FP32-1{1'b0}}}};
            19: fli_result_fp32 = {1'b0, {1'b0, {EXP_BITS_FP32-1{1'b1}}}, {2'b11, {MAN_BITS_FP32-2{1'b0}}}};
            20: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-1{1'b0}}}, {MAN_BITS_FP32{1'b0}}};
            21: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-1{1'b0}}}, {2'b01, {MAN_BITS_FP32-2{1'b0}}}};
            22: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-1{1'b0}}}, {1'b1, {MAN_BITS_FP32-1{1'b0}}}};
            23: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-2{1'b0}}, 1'b1}, {MAN_BITS_FP32{1'b0}}};
            24: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-3{1'b0}}, 2'b10}, {MAN_BITS_FP32{1'b0}}};
            25: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-3{1'b0}}, 2'b11}, {MAN_BITS_FP32{1'b0}}};
            26: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-4{1'b0}}, 3'b110}, {MAN_BITS_FP32{1'b0}}};
            27: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-4{1'b0}}, 3'b111}, {MAN_BITS_FP32{1'b0}}};
            28: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-5{1'b0}}, 4'b1110}, {MAN_BITS_FP32{1'b0}}};
            29: fli_result_fp32 = {1'b0, {1'b1, {EXP_BITS_FP32-5{1'b0}}, 4'b1111}, {MAN_BITS_FP32{1'b0}}};
            30: fli_result_fp32 = {1'b0, {EXP_BITS_FP32{1'b1}}, {MAN_BITS_FP32{1'b0}}};
            31: fli_result_fp32 = {1'b0, {EXP_BITS_FP32{1'b1}}, {1'b1, {MAN_BITS_FP32-1{1'b0}}}};
            default: fli_result_fp32 = '0;
        endcase
    end

    always_comb begin : fli_fp64
        case (operand_b)
            0:  fli_result_fp64 = {1'b1, {1'b0, {(EXP_BITS_FP64-1){1'b1}}}, {MAN_BITS_FP64{1'b0}}};
            1:  fli_result_fp64 = {1'b0, {{(EXP_BITS_FP64-1){1'b0}}, 1'b1}, {MAN_BITS_FP64{1'b0}}};
            2:  fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-6{1'b1}}, 5'b01111}, {MAN_BITS_FP64{1'b0}}};
            3:  fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-5{1'b1}}, 4'b0000}, {MAN_BITS_FP64{1'b0}}};
            4:  fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-5{1'b1}}, 4'b0111}, {MAN_BITS_FP64{1'b0}}};
            5:  fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-4{1'b1}}, 3'b000}, {MAN_BITS_FP64{1'b0}}};
            6:  fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-4{1'b1}}, 3'b011}, {MAN_BITS_FP64{1'b0}}};
            7:  fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-3{1'b1}}, 2'b00}, {MAN_BITS_FP64{1'b0}}};
            8:  fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-3{1'b1}}, 2'b01}, {MAN_BITS_FP64{1'b0}}};
            9:  fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-3{1'b1}}, 2'b01}, {2'b01, {MAN_BITS_FP64-2{1'b0}}}};
            10: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-3{1'b1}}, 2'b01}, {1'b1, {MAN_BITS_FP64-1{1'b0}}}};
            11: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-3{1'b1}}, 2'b01}, {2'b11, {MAN_BITS_FP64-2{1'b0}}}};
            12: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-2{1'b1}}, 1'b0}, {MAN_BITS_FP64{1'b0}}};
            13: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-2{1'b1}}, 1'b0}, {2'b01, {MAN_BITS_FP64-2{1'b0}}}};
            14: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-2{1'b1}}, 1'b0}, {1'b1, {MAN_BITS_FP64-1{1'b0}}}};
            15: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-2{1'b1}}, 1'b0}, {2'b11, {MAN_BITS_FP64-2{1'b0}}}};
            16: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-1{1'b1}}}, {MAN_BITS_FP64{1'b0}}};
            17: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-1{1'b1}}}, {2'b01, {MAN_BITS_FP64-2{1'b0}}}};
            18: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-1{1'b1}}}, {1'b1, {MAN_BITS_FP64-1{1'b0}}}};
            19: fli_result_fp64 = {1'b0, {1'b0, {EXP_BITS_FP64-1{1'b1}}}, {2'b11, {MAN_BITS_FP64-2{1'b0}}}};
            20: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-1{1'b0}}}, {MAN_BITS_FP64{1'b0}}};
            21: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-1{1'b0}}}, {2'b01, {MAN_BITS_FP64-2{1'b0}}}};
            22: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-1{1'b0}}}, {1'b1, {MAN_BITS_FP64-1{1'b0}}}};
            23: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-2{1'b0}}, 1'b1}, {MAN_BITS_FP64{1'b0}}};
            24: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-3{1'b0}}, 2'b10}, {MAN_BITS_FP64{1'b0}}};
            25: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-3{1'b0}}, 2'b11}, {MAN_BITS_FP64{1'b0}}};
            26: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-4{1'b0}}, 3'b110}, {MAN_BITS_FP64{1'b0}}};
            27: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-4{1'b0}}, 3'b111}, {MAN_BITS_FP64{1'b0}}};
            28: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-5{1'b0}}, 4'b1110}, {MAN_BITS_FP64{1'b0}}};
            29: fli_result_fp64 = {1'b0, {1'b1, {EXP_BITS_FP64-5{1'b0}}, 4'b1111}, {MAN_BITS_FP64{1'b0}}};
            30: fli_result_fp64 = {1'b0, {EXP_BITS_FP64{1'b1}}, {MAN_BITS_FP64{1'b0}}};
            31: fli_result_fp64 = {1'b0, {EXP_BITS_FP64{1'b1}}, {1'b1, {MAN_BITS_FP64-1{1'b0}}}};
            default: fli_result_fp64 = '0;
        endcase
    end

    always_comb begin : result_selection
        case (fmt_i)
            FP32: result_d = fli_result_fp32;
            FP64: result_d = fli_result_fp64;
            default: result_d = '0;
        endcase
    end

    assign status_d    = '0;
    assign tag_d       = tag_i;
    assign out_valid_d = valid_i;

    always_ff @(posedge clk_i or negedge rstn_i) begin
       if (!rstn_i) begin
          result_o    <= '0;
          status_o    <= '0;
          tag_o       <= '0;
          out_valid_o <= 1'b0;
       end else begin
          result_o    <= result_d;
          status_o    <= status_d;
          tag_o       <= tag_d;
          out_valid_o <= out_valid_d;
       end
    end

endmodule
