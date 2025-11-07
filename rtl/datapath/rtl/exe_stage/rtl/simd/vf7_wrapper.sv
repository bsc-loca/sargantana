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
    input  logic                    clk_i,
    input  logic                    rstn_i,
    // inputs
    input  logic                    valid_i,
    input  drac_pkg::sew_t          sew_i,
    input  logic                    operation_i,    // 0: VFREC7, 1: VFRSQRT7
    input  bus_simd_t               src_i,
    input  fpnew_pkg::roundmode_e   frm_i,          // rounding mode, to be considered in VFREC7 operation
    // outputs
    output bus_simd_t               res_o,
    output logic                    valid_o,
    output fpnew_pkg::status_t      status_o 
);

fpnew_pkg::status_t statusvec [(VLEN/32)-1:0];
logic               validvec  [(VLEN/32)-1:0];
bus64_t             resultvec [(VLEN/32)-1:0];

generate
for (genvar i = 0; (i < (VLEN/32)); i++) begin : GEN_VF7
    bus64_t source_operand;
    bus64_t result;

    always_comb begin
        source_operand = '0;
        result = '0;
        if (sew_i == SEW_64) begin
            if (i < (VLEN/64)) begin
                source_operand = src_i[i*64 +: 64];
                // continous assignment here allowed
            end 
        end else begin
            source_operand = src_i[i*32 +: 32];
        end
    end

    vf7_mf sqrt7_frec7 (
        .clk_i,
        .rstn_i,
        .valid_i,
        .sew_i,
        .operation_i,   // 0: VFREC7, 1: VFRSQRT7
        .src_i          (source_operand),
        .frm_i,
        .res_o          (resultvec[i]),
        .valid_o        (validvec[i]), 
        .status_o       (statusvec[i])
    );
end
endgenerate

fpnew_pkg::status_t accstatus [1:0];
logic               accvalid  [1:0];

// Questa complaining if the ladder is not well separated from the generate block
always_comb begin
    status_o = '0;
    valid_o = 1'b0;

    accstatus[0] = '0;
    accvalid [0] = '0;
    accstatus[1] = '0;
    accvalid [1] = '0;

    for (int i = 0; i < (VLEN/64); i++) begin
        accstatus[0].NV |= statusvec[i].NV;
        accstatus[0].DZ |= statusvec[i].DZ;
        accstatus[0].OF |= statusvec[i].OF;
        accstatus[0].UF |= statusvec[i].UF;
        accstatus[0].NX |= statusvec[i].NX;
        accvalid [0]    |= validvec[i];
    end
    for (int i = (VLEN/64); i < (VLEN/32); i++) begin
        accstatus[1].NV |= statusvec[i].NV;
        accstatus[1].DZ |= statusvec[i].DZ;
        accstatus[1].OF |= statusvec[i].OF;
        accstatus[1].UF |= statusvec[i].UF;
        accstatus[1].NX |= statusvec[i].NX;
        accvalid [1]    |= validvec[i];
    end

    status_o.NV = (sew_i == SEW_64) ? accstatus[0].NV : accstatus[0].NV | accstatus[1].NV;
    status_o.DZ = (sew_i == SEW_64) ? accstatus[0].DZ : accstatus[0].DZ | accstatus[1].DZ;
    status_o.OF = (sew_i == SEW_64) ? accstatus[0].OF : accstatus[0].OF | accstatus[1].OF;
    status_o.UF = (sew_i == SEW_64) ? accstatus[0].UF : accstatus[0].UF | accstatus[1].UF;
    status_o.NX = (sew_i == SEW_64) ? accstatus[0].NX : accstatus[0].NX | accstatus[1].NX;
    valid_o     = (sew_i == SEW_64) ? accvalid[0] : accvalid[0] | accvalid[1];

    if (sew_i == SEW_64) begin
        for (int i = 0; i < (VLEN/64); i++) begin
            res_o[i*64 +: 64] = resultvec[i];
        end
    end else begin // SEW_32
        for (int i = 0; i < (VLEN/32); i++) begin
            res_o[i*32 +: 32] = resultvec[i][31:0];
        end
    end
end

endmodule

