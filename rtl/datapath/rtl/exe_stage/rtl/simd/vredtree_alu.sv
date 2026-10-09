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

// SEW-segmented combine of two vectors of partial reductions (see vredtree).
// Every SEW-wide lane holds a partial result, and its mask bit is replicated
// in each of its bytes. Lane by lane: two active lanes are combined with
// op_i, a single active lane is passed through and two inactive lanes give 0
// with the mask cleared. Lanes wider than the vector are cut at its top.
// Bytes from NB_FULL upwards only implement the addition: the caller keeps
// them inactive for any other operation.
//
// op_i[2] = 0: op_i[1:0] = 00 add, 01 and, 10 or, 11 xor
// op_i[2] = 1: op_i[1] = 0 max, 1 min (a < b ? a : b); op_i[0] = 1 unsigned
module vredtree_alu
    import drac_pkg::*;
#(
    parameter int NB      = 16,                 // Width in bytes
    parameter int NB_FULL = 16                  // Low bytes that implement every operation
) (
    input  sew_t            sew_i,              // Lane width
    input  logic [2:0]      op_i,               // Operation
    input  logic [NB*8-1:0] a_i,                // First operand
    input  logic [NB*8-1:0] b_i,                // Second operand
    input  logic [NB-1:0]   ma_i,               // First operand active, one bit per byte
    input  logic [NB-1:0]   mb_i,               // Second operand active, one bit per byte
    output logic [NB*8-1:0] res_o,              // Result
    output logic [NB-1:0]   mask_o              // Result active, one bit per byte
);

// Lanes never cross a 64-bit boundary, so the carry chains are cut there
localparam int GB      = (NB < 8) ? NB : 8;     // Bytes per carry chain
localparam int NG      = NB / GB;               // Carry chains of the sum
localparam int NG_FULL = NB_FULL / GB;          // Carry chains of the difference

// Byte y is the first byte of a lane
function automatic logic lane_start(input sew_t sew, input int y);
    case (sew)
        SEW_8:   lane_start = 1'b1;
        SEW_16:  lane_start = ((y % 2) == 0);
        SEW_32:  lane_start = ((y % 4) == 0);
        default: lane_start = ((y % 8) == 0);
    endcase
endfunction

// Byte y is the last byte of a lane or of a carry chain
function automatic logic lane_last(input sew_t sew, input int y);
    lane_last = (((y + 1) % GB) == 0) || lane_start(sew, y + 1);
endfunction

// Last byte of the lane of byte y for lanes of bpl bytes, within the low NB_FULL bytes
function automatic int lane_end(input int bpl, input int y);
    lane_end = ((y | (bpl - 1)) < NB_FULL) ? (y | (bpl - 1)) : (NB_FULL - 1);
endfunction

// Bit of the combination of two active lanes for add, and, or, xor
function automatic logic bit_op(input logic [1:0] op, input logic a, input logic b, input logic s);
    case (op)
        2'b01:   bit_op = a & b;
        2'b10:   bit_op = a | b;
        2'b11:   bit_op = a ^ b;
        default: bit_op = s;
    endcase
endfunction

logic [NB*9-1:0]      add_a, add_b, add_s;      // a + b, bytes split by spacer bits
logic [NB_FULL*9-1:0] sub_a, sub_b, sub_s;      // a - b, bytes split by spacer bits
/* verilator lint_off UNUSEDSIGNAL */
logic [GB*9:0]        sub_t;                    // One chain of a - b, carry-in as an extra low bit
/* verilator lint_on UNUSEDSIGNAL */
logic [NB_FULL-1:0]   lt_u, lt_s;               // a < b, valid at the last byte of a lane
logic [NB-1:0]        lt, minmax, pick_b;
logic [NB-1:0]        sel_a, sel_b, sel_op;

always_comb begin
    // Byte y sits at [y*9 +: 8] and bit y*9+8 is a spacer above it. Inside a
    // lane the spacer is (1,0), which propagates the carry. At the end of a
    // lane it is (0,0) for the sum (carry 0 into the next lane) and (1,1) for
    // the difference (carry 1 into the next lane); either way the spacer bit
    // of the result is the carry out of the lane.
    for (int y = 0; y < NB; y++) begin
        add_a[y*9 +: 8] = a_i[y*8 +: 8];
        add_b[y*9 +: 8] = b_i[y*8 +: 8];
        add_a[y*9 + 8]  = !lane_last(sew_i, y);
        add_b[y*9 + 8]  = 1'b0;
    end
    for (int y = 0; y < NB_FULL; y++) begin
        sub_a[y*9 +: 8] = a_i[y*8 +: 8];
        sub_b[y*9 +: 8] = ~b_i[y*8 +: 8];
        sub_a[y*9 + 8]  = 1'b1;
        sub_b[y*9 + 8]  = lane_last(sew_i, y);
    end
    for (int g = 0; g < NG; g++) begin
        add_s[g*GB*9 +: GB*9] = add_a[g*GB*9 +: GB*9] + add_b[g*GB*9 +: GB*9];
    end
    // a + ~b + 1: the carry-in enters as a low bit set in both operands
    for (int g = 0; g < NG_FULL; g++) begin
        sub_t                 = {sub_a[g*GB*9 +: GB*9], 1'b1} + {sub_b[g*GB*9 +: GB*9], 1'b1};
        sub_s[g*GB*9 +: GB*9] = sub_t[GB*9:1];
    end

    // a < b: no carry out of a + ~b + 1, signed when the signs are equal
    for (int y = 0; y < NB_FULL; y++) begin
        lt_u[y] = !sub_s[y*9 + 8];
        lt_s[y] = (a_i[y*8 + 7] != b_i[y*8 + 7]) ? a_i[y*8 + 7] : lt_u[y];
    end

    for (int y = 0; y < NB; y++) begin
        lt[y]     = 1'b0;
        minmax[y] = 1'b0;
        if (y < NB_FULL) begin
            case (sew_i)
                SEW_8:   lt[y] = op_i[0] ? lt_u[lane_end(1, y)] : lt_s[lane_end(1, y)];
                SEW_16:  lt[y] = op_i[0] ? lt_u[lane_end(2, y)] : lt_s[lane_end(2, y)];
                SEW_32:  lt[y] = op_i[0] ? lt_u[lane_end(4, y)] : lt_s[lane_end(4, y)];
                default: lt[y] = op_i[0] ? lt_u[lane_end(8, y)] : lt_s[lane_end(8, y)];
            endcase
            minmax[y] = op_i[2];
        end
        // max: a < b ? b : a, min: a < b ? a : b
        pick_b[y] = op_i[1] ? !lt[y] : lt[y];
        sel_op[y] = ma_i[y] &  mb_i[y] & !minmax[y];
        sel_a[y]  = ma_i[y] & (!mb_i[y] | (minmax[y] & !pick_b[y]));
        sel_b[y]  = mb_i[y] & (!ma_i[y] | (minmax[y] &  pick_b[y]));
        mask_o[y] = ma_i[y] | mb_i[y];
        for (int r = 0; r < 8; r++) begin
            res_o[y*8 + r] = sel_op[y] ? bit_op((y < NB_FULL) ? op_i[1:0] : 2'b00, a_i[y*8 + r], b_i[y*8 + r], add_s[y*9 + r]) :
                                         ((sel_a[y] & a_i[y*8 + r]) | (sel_b[y] & b_i[y*8 + r]));
        end
    end
end

endmodule
