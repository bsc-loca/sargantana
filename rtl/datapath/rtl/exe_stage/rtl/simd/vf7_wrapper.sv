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

import riscv_pkg::*;
import drac_pkg::*;
import fpnew_pkg::*;

// module vf7_wrapper
// this module wraps VLEN/64 individual smaller vf7_mf modules to
// compute results in traditional SIMD style the vfred and vsqrt
// precise instructions.
module vf7_wrapper (
    input  logic                clk_i,
    input  logic                rstn_i,
    // inputs
    input  logic                valid_i,
    input  drac_pkg::sew_t      sew_i,
    input  logic                operation_i,    // 0: VFREC7, 1: VFRSQRT7
    input  bus_simd_t           src_i,
    // outputs
    output bus_simd_t           res_o,
    output logic                valid_o,
    output fpnew_pkg::status_t  status_o 
);

generate
for (genvar i = 0; i < VLEN/64; i++) begin : GEN_VF7
    bus64_t source_operand;
    bus64_t result;
    fpnew_pkg::status_t status;

    assign source_operand = src_i[i*64 +: 64];

    vf7_mf sqrt7_frec7 (
        .clk_i,
        .rstn_i,
        .valid_i,
        .sew_i,
        .operation_i,   // 0: VFREC7, 1: VFRSQRT7
        .src_i          (source_operand),
        .res_o          (result),
        .valid_o, 
        .status_o       (status)
    );
    
    assign res_o[i*64 +: 64] = result;
    assign status_o.NV |= status.NV; // the output status may ladder the individual status
    assign status_o.DZ |= status.DZ;
    assign status_o.OF |= status.OF;
    assign status_o.UF |= status.UF;
    assign status_o.NX |= status.NX;
end
endgenerate

endmodule

