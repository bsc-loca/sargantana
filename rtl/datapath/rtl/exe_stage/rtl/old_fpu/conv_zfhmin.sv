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

module conv_zfhmin
import drac_pkg::*;
import fpnew_pkg::*;
#(
  parameter type                     TagType     = logic
) (
    input logic [63:0]  operand_i,
    input               fpnew_pkg::fp_format_e src_fmt_i,
    input               fpnew_pkg::fp_format_e dst_fmt_i,
    input               fpnew_pkg::roundmode_e rnd_mode_i,
    input               is_move_i,
    input               valid_i,
    input               reg_t tag_i,
    output logic [63:0] result_o,
    output fpnew_pkg::status_t status_o,
    output TagType tag_o,
    output logic             out_valid_o
    );

   logic [15:0] fp16fp32_i;
   logic [31:0] fp16fp32_o;
   logic        fp16fp32_nv;
   fpnew_pkg::status_t fp16fp32_status;

   logic [31:0] fp32fp16_i;
   logic [15:0] fp32fp16_o;
   fpnew_pkg::status_t fp32fp16_status;

   logic [15:0] fp16fp64_i;
   logic [63:0] fp16fp64_o;
   logic        fp16fp64_nv;
   fpnew_pkg::status_t fp16fp64_status;

   logic [63:0] fp64fp16_i;
   logic [15:0] fp64fp16_o;
   fpnew_pkg::status_t fp64fp16_status;

   // Results

   logic [63:0] result_conv;
   logic [63:0] result_move;
   fpnew_pkg::status_t status_conv;
   fpnew_pkg::status_t status_move;

   assign result_move = {{48{(dst_fmt_i == fpnew_pkg::FP64) ? operand_i[15] : 1'b1}}, operand_i[15:0]};
   assign status_move = '0;

   assign fp16fp32_i = operand_i[15:0];
   assign fp32fp16_i = operand_i[31:0];

   fp32_to_fp16 fp32_to_fp16_inst (
                                   .f32(fp32fp16_i),
                                   .frm(rnd_mode_i),
                                   .f16(fp32fp16_o),
                                   .status_o(fp32fp16_status)
                                   );

   assign fp16fp64_i = operand_i[15:0];
   assign fp64fp16_i = operand_i[63:0];

   fp64_to_fp16 fp64_to_fp16_inst (
                                   .f64(fp64fp16_i),
                                   .frm(rnd_mode_i),
                                   .f16(fp64fp16_o),
                                   .status_o(fp64fp16_status)
                                   );

   fp16_to_fp32 fp16_to_fp32_inst (
                                   .fp16_i(fp16fp32_i),
                                   .fp32_o(fp16fp32_o)
                                   );

   fp16_to_fp64 fp16_to_fp64_inst (
                                   .fp16_i(fp16fp64_i),
                                   .fp64_o(fp16fp64_o)
                                   );

   always_comb begin : s_fp16_to_fp32
      fp16fp32_status = '0;
      fp16fp32_status.NV = fp16fp32_nv;
   end

   always_comb begin: s_fp16_to_fp64
      fp16fp64_status = '0;
      fp16fp64_status.NV = fp16fp64_nv;
   end

   always_comb begin : resultSelection
      if ((dst_fmt_i == fpnew_pkg::FP16) && (src_fmt_i == fpnew_pkg::FP64)) begin : fcvt_h_d
         result_conv = {{48{1'b1}}, fp64fp16_o};
         status_conv = fp64fp16_status;
      end else if ((dst_fmt_i == fpnew_pkg::FP64) && (src_fmt_i == fpnew_pkg::FP16)) begin : fcvt_d_h
         result_conv = fp16fp64_o;
         status_conv = fp16fp64_status;
      end else if ((dst_fmt_i == fpnew_pkg::FP32) && (src_fmt_i == fpnew_pkg::FP16)) begin : fcvt_s_h
         result_conv = {{32{1'b1}}, fp16fp32_o};
         status_conv = fp16fp32_status;
      end else begin : fcvt_h_s
         result_conv = {{48{1'b1}}, fp32fp16_o};
         status_conv = fp32fp16_status;
      end
   end

   assign result_o = (is_move_i == 1'b1) ? result_move : result_conv;
   assign status_o = (is_move_i == 1'b1) ? status_move : status_conv;

   assign tag_o = tag_i;

endmodule;
