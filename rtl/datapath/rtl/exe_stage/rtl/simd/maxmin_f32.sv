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

// maxmin_f32.sv
// SystemVerilog unit for FP32 MAXMIN operation
// written by Serik Parcet Gomez (serik.perez@bsc.es)

import drac_pkg::*; // import DP2 utils

module maxmin_f32 (
    input  logic        maxmin_i,   // '1' if MAX and '0' if min arbitrarily
    input  logic [31:0] srca_i,     // source operand A 
    input  logic [31:0] srcb_i,     // source operand B
    output logic [31:0] ret_o,      // result
    output logic        is_nan_o,
    output logic        invalid_o,  // return invalid if one or the other is SNAN (following the RISC-V spec)
    output logic        lt_o,
    output logic        eq_o,
    output logic        gt_o,
    output logic        le_o,
    output logic        ge_o
);

comp_f32 fp32_comparator (
    .srca_i   ( srca_i    ),
    .srcb_i   ( srcb_i    ),
    .lt_o     ( lt_o      ),
    .eq_o     ( eq_o      ),
    .gt_o     ( gt_o      ),
    .is_nan_o ( is_nan_o  ),
    .invalid  ( invalid_o ),
    .le_o     ( le_o      ),
    .ge_o     ( ge_o      )
);

// Combinational output logic
always_comb begin
    // if both operands are NAN always return a canonical QNAN
    if ( is_nan_f32(srca_i) && is_nan_f32(srcb_i) ) begin
        ret_o = FP32_QNAN;
    // if only one operand is NAN always return the other operand
    end else if (is_nan_f32(srca_i)) begin
        ret_o = srcb_i;        
    end else if (is_nan_f32(srcb_i)) begin
        ret_o = srca_i;
    // else return the maximum/minimum operation
    end else begin
        case (maxmin_i)
            1'b0: begin // MIN operation 
                if (lt_o) begin
                    ret_o = srca_i;
                end else begin
                    ret_o = srcb_i;
                end
            end
            1'b1: begin // MAX operation
                if (lt_o) begin
                    ret_o = srcb_i;
                end else begin
                    ret_o = srca_i;
                end
            end
        endcase
    end
end // always_comb

endmodule

