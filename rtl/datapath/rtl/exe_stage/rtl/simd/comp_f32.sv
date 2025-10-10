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

// comp_f32.sv
// IEEE-754 2008 single-precision combinational comparator

// Sérik Parcet Gómez (spere4@bsc.es)

import drac_pkg::*;

module comp_f32
(
    input  logic [31:0]     srca_i,
    input  logic [31:0]     srcb_i,
    output logic            lt_o,
    output logic            eq_o,
    output logic            gt_o,
    output logic            is_nan_o,
    output logic            invalid,
    output logic            le_o,       // lt || eq
    output logic            ge_o        // gt || eq
);

// separate fields
logic sa, sb;           // signs
logic [7:0] ea, eb;     // exponents
logic [22:0] ma, mb;    // mantissas

assign {sa, ea, ma} = srca_i;
assign {sb, eb, mb} = srcb_i;

assign is_nan_o = is_nan_f32(srca_i)  || is_nan_f32(srcb_i);
assign invalid  = is_snan_f32(srca_i) || is_snan_f32(srcb_i);

always_comb begin
    lt_o = 1'b0;
    eq_o = 1'b0;
    gt_o = 1'b0;

    if (is_zero_f32(srca_i) && is_zero_f32(srcb_i)) begin
        eq_o = 1'b1;
    end else if (srca_i == srcb_i) begin
        // bitwise equality covers +inf==+inf, -inf==-inf,
        // same finite nums, same subnormals
        eq_o = 1'b1;
    end else begin
        if (sa != sb) begin
            lt_o = sa; // if a>0 then b<0 and smaller
            gt_o = sb; // if b>0 then a<0 and smaller
        end else begin
            if (sa == 1'b0) begin // if both positives
                // the comparison can be simpified directly to the
                // concatenation of exp + mantissa
                lt_o = ({ea, ma} < {eb, mb});
                gt_o = ({ea, ma} > {eb, mb});
            end else begin // if both are negative
                lt_o = ({ea, ma} > {eb, mb});
                gt_o = ({ea, ma} < {eb, mb});
            end
        end
    end
end

// convenience outputs
assign le_o = lt_o || eq_o;
assign ge_o = gt_o || eq_o;

endmodule

