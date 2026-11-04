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

import drac_pkg::*;
import riscv_pkg::*;

module vredtree (
    input  logic clk_i,                         // Clock signal
    input  logic rstn_i,                        // Reset signal
    input  instr_type_t instr_type_i,           // Instruction type
    input  sew_t sew_i,                         // SEW: 00 for 8 bits, 01 for 16 bits, 10 for 32 bits, 11 for 64 bits
    input  logic [VMAXELEM_LOG:0] vl_i,         // Current vector lenght in elements
    /* verilator lint_off UNUSEDSIGNAL */
    input  bus_simd_t data_vs1_i,               // 128-bit from vs1, only vs1[63:0] is used
    input  bus_simd_t data_vs2_i,               // 128-bit source operand
    input  bus_simd_t data_old_vd,              // Backup of previous vector destination value, [7:0] is always overwritten
    input  bus_mask_t data_vm_i,                // Vector mask of VLEN/8 size
    input  instr_type_t instr_to_out_i,         // Instruction to output
    input  sew_t sew_to_out_i,                  // SEW indication for output
    output bus_simd_t red_data_vd_o             // 128-bit result (only cares last element)
);

// Integer reduction tree
//
// Stage s of the tree holds, for every block of 2^s consecutive elements of
// vs2, the reduction of its active elements (data_vm_i and index < vl_i;
// elements past VLEN/SEW are never active) and a mask bit telling whether
// the block has any. A block without active elements is 0. All operations
// are associative and commutative, so a block only depends on which elements
// it covers, not on the order they are combined in. The reduction of
// SEW-wide elements is complete at stage log2(VLEN/SEW), and the output only
// reads the low bits of stages STAGE_SEW8-3 .. STAGE_SEW8. The tree has two
// parts:
//
// - Lane stages 1 .. LANE_STAGES (= STAGE_SEW8-3): element c*NUM_WORDS+w is
//   placed in lane c of the 128-bit double word w, so each double word holds
//   one element of every chunk of NUM_WORDS consecutive elements. Stage s
//   combines double words w and w+NUM_WORDS/2^s lane by lane, and after the
//   last one lane c holds chunk c, which is block c of stage STAGE_SEW8-3 in
//   its original position. Widening reductions are extended to 2*SEW when
//   placed; single-width ones only use the low 64 bits (the high lanes stay
//   inactive), so the high half of each double word only needs an adder.
// - Stages STAGE_SEW8-2 .. STAGE_SEW8 combine blocks 2j and 2j+1 into block
//   j on the 64, 32 and 16 low bits that the output reads.
//
// All stages use the same SEW-segmented ALU (vredtree_alu).

localparam int STAGE_SEW8  = $clog2(VLEN / 8);      // Last stage, result of SEW=8 reductions
localparam int NUM_WORDS   = VLEN / 64;             // 64-bit words in a vector register
localparam int NUM_DW      = NUM_WORDS / 2;         // 128-bit double words after stage 1
localparam int LANE_STAGES = $clog2(NUM_WORDS);     // Lane stages, the last one is STAGE_SEW8-3

// Reduction operation, op[2:0] is the vredtree_alu operation
typedef enum logic [3:0] {
    RED_NONE = 4'b0000,     // Not an integer reduction
    RED_SUM  = 4'b1000,     // VREDSUM, VWREDSUM, VWREDSUMU
    RED_AND  = 4'b1001,
    RED_OR   = 4'b1010,
    RED_XOR  = 4'b1011,
    RED_MAX  = 4'b1100,
    RED_MAXU = 4'b1101,
    RED_MIN  = 4'b1110,
    RED_MINU = 4'b1111
} red_op_t;

function sew_t increase_sew_size(sew_t sew);
    case (sew)
        SEW_8: return SEW_16;
        SEW_16: return SEW_32;
        SEW_32: return SEW_64;
        default: return SEW_16;
    endcase
endfunction

function logic is_vw(input instr_type_t instr);
    is_vw = (instr inside {VWREDSUM, VWREDSUMU}) ? 1'b1 : 1'b0;
endfunction

function red_op_t red_op(input instr_type_t instr);
    case (instr)
        VREDSUM, VWREDSUM, VWREDSUMU: red_op = RED_SUM;
        VREDAND:  red_op = RED_AND;
        VREDOR:   red_op = RED_OR;
        VREDXOR:  red_op = RED_XOR;
        VREDMAX:  red_op = RED_MAX;
        VREDMAXU: red_op = RED_MAXU;
        VREDMIN:  red_op = RED_MIN;
        VREDMINU: red_op = RED_MINU;
        default:  red_op = RED_NONE;
    endcase
endfunction

// Fields that travel with the instruction through every stage
typedef struct packed {
    sew_t        sew;           // SEW of the tree elements (result SEW for widening)
    red_op_t     op;            // Reduction operation
    logic [63:0] data_vs1;      // vs1[0], only the low SEW bits are used
} ctrl_t;

// Operands registered in stage 0
typedef struct packed {
    logic        vw;            // Widening reduction
    logic        vw_signed;     // VWREDSUM: sign-extend the source elements
    bus_mask_t   mask;          // Active elements
    bus_simd_t   data;          // vs2
} stage0_t;

ctrl_t        ctrl_d [STAGE_SEW8:0];
ctrl_t        ctrl_q [STAGE_SEW8:0];
stage0_t      stage0_d;
stage0_t      stage0_q;
logic [127:0] lane_data_d [LANE_STAGES:1][NUM_DW-1:0];   // Lane stages
logic [127:0] lane_data_q [LANE_STAGES:1][NUM_DW-1:0];
logic [15:0]  lane_mask_d [LANE_STAGES:1][NUM_DW-1:0];   // One bit per byte
logic [15:0]  lane_mask_q [LANE_STAGES:1][NUM_DW-1:0];
logic [63:0]  tail_data_d [2:0];                         // Stage STAGE_SEW8-2+t, 64, 32 and 16 bits
logic [63:0]  tail_data_q [2:0];
logic [7:0]   tail_mask_d [2:0];                         // One bit per byte
logic [7:0]   tail_mask_q [2:0];

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        for (int i = 0; i <= STAGE_SEW8; i++) begin
            ctrl_q[i] <= '0;
        end
        stage0_q <= '0;
        for (int s = 1; s <= LANE_STAGES; s++) begin
            for (int w = 0; w < NUM_DW; w++) begin
                lane_data_q[s][w] <= '0;
                lane_mask_q[s][w] <= '0;
            end
        end
        for (int t = 0; t < 3; t++) begin
            tail_data_q[t] <= '0;
            tail_mask_q[t] <= '0;
        end
    end else begin
        for (int i = 0; i <= STAGE_SEW8; i++) begin
            ctrl_q[i] <= ctrl_d[i];
        end
        stage0_q <= stage0_d;
        for (int s = 1; s <= LANE_STAGES; s++) begin
            for (int w = 0; w < NUM_DW; w++) begin
                lane_data_q[s][w] <= lane_data_d[s][w];
                lane_mask_q[s][w] <= lane_mask_d[s][w];
            end
        end
        for (int t = 0; t < 3; t++) begin
            tail_data_q[t] <= tail_data_d[t];
            tail_mask_q[t] <= tail_mask_d[t];
        end
    end
end

// Stage 0
always_comb begin
    ctrl_d[0].sew      = (is_vw(instr_type_i)) ? increase_sew_size(sew_i) : sew_i;
    ctrl_d[0].op       = red_op(instr_type_i);
    ctrl_d[0].data_vs1 = data_vs1_i[63:0];
    for (int i = 1; i <= STAGE_SEW8; i++) begin
        ctrl_d[i] = ctrl_q[i-1];
    end
    stage0_d.vw        = is_vw(instr_type_i);
    stage0_d.vw_signed = (instr_type_i == VWREDSUM);
    stage0_d.data      = data_vs2_i;
    // Vector Mask Managment for LMUL<1 cases
    for (int i = 0; i < (VLEN/8); i++) begin
        if (i < vl_i) begin
            stage0_d.mask[i] = data_vm_i[i];
        end else begin
            stage0_d.mask[i] = 1'b0;
        end
    end
end

// Element c*NUM_WORDS+w in lane c of double word w, mask replicated per byte.
// Single-width: 64/SEW lanes in the low half, the high half inactive.
// Widening (SEW is the result width): 128/SEW lanes of extended elements.
logic [127:0] leaf_data [NUM_WORDS-1:0];
logic [15:0]  leaf_mask [NUM_WORDS-1:0];

always_comb begin
    for (int w = 0; w < NUM_WORDS; w++) begin
        leaf_data[w] = '0;
        leaf_mask[w] = '0;
        case (ctrl_q[0].sew)
            SEW_8: begin // never widening
                for (int c = 0; c < 8; c++) begin
                    leaf_data[w][c*8 +: 8] = stage0_q.data[(c*NUM_WORDS + w)*8 +: 8];
                    leaf_mask[w][c]        = stage0_q.mask[c*NUM_WORDS + w];
                end
            end
            SEW_16: begin
                if (stage0_q.vw) begin
                    for (int c = 0; c < 8; c++) begin
                        leaf_data[w][c*16 +: 16] = {{8{stage0_q.vw_signed & stage0_q.data[(c*NUM_WORDS + w)*8 + 7]}},
                                                    stage0_q.data[(c*NUM_WORDS + w)*8 +: 8]};
                        leaf_mask[w][c*2 +: 2]   = {2{stage0_q.mask[c*NUM_WORDS + w]}};
                    end
                end else begin
                    for (int c = 0; c < 4; c++) begin
                        leaf_data[w][c*16 +: 16] = stage0_q.data[(c*NUM_WORDS + w)*16 +: 16];
                        leaf_mask[w][c*2 +: 2]   = {2{stage0_q.mask[c*NUM_WORDS + w]}};
                    end
                end
            end
            SEW_32: begin
                if (stage0_q.vw) begin
                    for (int c = 0; c < 4; c++) begin
                        leaf_data[w][c*32 +: 32] = {{16{stage0_q.vw_signed & stage0_q.data[(c*NUM_WORDS + w)*16 + 15]}},
                                                    stage0_q.data[(c*NUM_WORDS + w)*16 +: 16]};
                        leaf_mask[w][c*4 +: 4]   = {4{stage0_q.mask[c*NUM_WORDS + w]}};
                    end
                end else begin
                    for (int c = 0; c < 2; c++) begin
                        leaf_data[w][c*32 +: 32] = stage0_q.data[(c*NUM_WORDS + w)*32 +: 32];
                        leaf_mask[w][c*4 +: 4]   = {4{stage0_q.mask[c*NUM_WORDS + w]}};
                    end
                end
            end
            default: begin // SEW_64
                if (stage0_q.vw) begin
                    for (int c = 0; c < 2; c++) begin
                        leaf_data[w][c*64 +: 64] = {{32{stage0_q.vw_signed & stage0_q.data[(c*NUM_WORDS + w)*32 + 31]}},
                                                    stage0_q.data[(c*NUM_WORDS + w)*32 +: 32]};
                        leaf_mask[w][c*8 +: 8]   = {8{stage0_q.mask[c*NUM_WORDS + w]}};
                    end
                end else begin
                    leaf_data[w][63:0] = stage0_q.data[w*64 +: 64];
                    leaf_mask[w][7:0]  = {8{stage0_q.mask[w]}};
                end
            end
        endcase
    end
end

// Lane stages: double word w combines w and w + NUM_WORDS/2^s of the previous stage
for (genvar s = 1; s <= LANE_STAGES; s++) begin : g_lane
    for (genvar w = 0; w < NUM_DW; w++) begin : g_dw
        if (w < (NUM_WORDS >> s)) begin : g_alu
            logic [127:0] a, b;
            logic [15:0]  ma, mb;
            if (s == 1) begin : g_leaf
                assign a  = leaf_data[w];
                assign b  = leaf_data[w + NUM_DW];
                assign ma = leaf_mask[w];
                assign mb = leaf_mask[w + NUM_DW];
            end else begin : g_node
                assign a  = lane_data_q[s-1][w];
                assign b  = lane_data_q[s-1][w + (NUM_WORDS >> s)];
                assign ma = lane_mask_q[s-1][w];
                assign mb = lane_mask_q[s-1][w + (NUM_WORDS >> s)];
            end
            // The high 64 bits are only active for widening sums
            vredtree_alu #(
                .NB      (16),
                .NB_FULL (8)
            ) vredtree_alu_inst (
                .sew_i   (ctrl_q[s-1].sew),
                .op_i    (ctrl_q[s-1].op[2:0]),
                .a_i     (a),
                .b_i     (b),
                .ma_i    (ma),
                .mb_i    (mb),
                .res_o   (lane_data_d[s][w]),
                .mask_o  (lane_mask_d[s][w])
            );
        end else begin : g_unused
            assign lane_data_d[s][w] = '0;
            assign lane_mask_d[s][w] = '0;
        end
    end
end

// Last three stages: block j combines blocks 2j and 2j+1, keeping the low
// 64, 32 and 16 bits. The input is zero-extended, so when an element is
// wider than the stage its pair (an empty block) reads as inactive and the
// element is passed through.
for (genvar t = 0; t < 3; t++) begin : g_tail
    localparam int NBO = 8 >> t;                // Bytes kept by this stage
    logic [127:0]     tin;
    logic [15:0]      tin_m;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [63:0]      ta, tb;                   // Only the low NBO bytes are used
    logic [7:0]       tma, tmb;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [NBO*8-1:0] tres;
    logic [NBO-1:0]   tmask;

    if (t == 0) begin : g_in_lane
        assign tin   = lane_data_q[LANE_STAGES][0];
        assign tin_m = lane_mask_q[LANE_STAGES][0];
    end else begin : g_in_tail
        assign tin   = {64'b0, tail_data_q[t-1]};
        assign tin_m = {8'b0, tail_mask_q[t-1]};
    end

    always_comb begin
        ta  = '0;
        tb  = '0;
        tma = '0;
        tmb = '0;
        case (ctrl_q[LANE_STAGES+t].sew)
            SEW_8: begin
                for (int j = 0; j < 8; j++) begin
                    ta[j*8 +: 8] = tin[(2*j)*8 +: 8];
                    tb[j*8 +: 8] = tin[(2*j+1)*8 +: 8];
                    tma[j]       = tin_m[2*j];
                    tmb[j]       = tin_m[2*j+1];
                end
            end
            SEW_16: begin
                for (int j = 0; j < 4; j++) begin
                    ta[j*16 +: 16] = tin[(2*j)*16 +: 16];
                    tb[j*16 +: 16] = tin[(2*j+1)*16 +: 16];
                    tma[j*2 +: 2]  = {2{tin_m[(2*j)*2]}};
                    tmb[j*2 +: 2]  = {2{tin_m[(2*j+1)*2]}};
                end
            end
            SEW_32: begin
                for (int j = 0; j < 2; j++) begin
                    ta[j*32 +: 32] = tin[(2*j)*32 +: 32];
                    tb[j*32 +: 32] = tin[(2*j+1)*32 +: 32];
                    tma[j*4 +: 4]  = {4{tin_m[(2*j)*4]}};
                    tmb[j*4 +: 4]  = {4{tin_m[(2*j+1)*4]}};
                end
            end
            default: begin // SEW_64
                ta  = tin[63:0];
                tb  = tin[127:64];
                tma = {8{tin_m[0]}};
                tmb = {8{tin_m[8]}};
            end
        endcase
    end

    vredtree_alu #(
        .NB      (NBO),
        .NB_FULL (NBO)
    ) vredtree_alu_inst (
        .sew_i   (ctrl_q[LANE_STAGES+t].sew),
        .op_i    (ctrl_q[LANE_STAGES+t].op[2:0]),
        .a_i     (ta[NBO*8-1:0]),
        .b_i     (tb[NBO*8-1:0]),
        .ma_i    (tma[NBO-1:0]),
        .mb_i    (tmb[NBO-1:0]),
        .res_o   (tres),
        .mask_o  (tmask)
    );

    assign tail_data_d[t] = 64'(tres);
    assign tail_mask_d[t] = 8'(tmask);
end

sew_t        sew_to_out;
logic [1:0]  out_sel;       // Stage read: STAGE_SEW8 - out_sel
logic        out_m0;        // Block 0 has active elements
red_op_t     out_op;
logic [63:0] out_data;
logic [63:0] out_vs1;
logic [63:0] out_res;
logic        out_zero;      // Not a reduction and block 0 active: the whole result is 0

assign sew_to_out = (is_vw(instr_to_out_i)) ? increase_sew_size(sew_to_out_i) : sew_to_out_i;

// The tree halves the number of elements per stage, starting from SEW=8, so
// the reduction of SEW-wide elements is complete at stage log2(VLEN/SEW). For
// widening reductions sew_to_out is the result SEW and the operands are half
// as wide. This equals simd_exe_stages - 2 (see simd_unit).
always_comb begin
    case (sew_to_out)
        SEW_8:   out_sel = 2'd0;
        SEW_16:  out_sel = (is_vw(instr_to_out_i)) ? 2'd0 : 2'd1;
        SEW_32:  out_sel = (is_vw(instr_to_out_i)) ? 2'd1 : 2'd2;
        SEW_64:  out_sel = (is_vw(instr_to_out_i)) ? 2'd2 : 2'd3;
        default: out_sel = 2'd0;
    endcase
end

always_comb begin
    case (out_sel)
        2'd0: begin
            out_m0   = tail_mask_q[2][0];
            out_data = tail_data_q[2];
            out_op   = ctrl_q[STAGE_SEW8].op;
            out_vs1  = ctrl_q[STAGE_SEW8].data_vs1;
        end
        2'd1: begin
            out_m0   = tail_mask_q[1][0];
            out_data = tail_data_q[1];
            out_op   = ctrl_q[STAGE_SEW8-1].op;
            out_vs1  = ctrl_q[STAGE_SEW8-1].data_vs1;
        end
        2'd2: begin
            out_m0   = tail_mask_q[0][0];
            out_data = tail_data_q[0];
            out_op   = ctrl_q[STAGE_SEW8-2].op;
            out_vs1  = ctrl_q[STAGE_SEW8-2].data_vs1;
        end
        default: begin
            out_m0   = lane_mask_q[LANE_STAGES][0][0];
            out_data = lane_data_q[LANE_STAGES][0][63:0];
            out_op   = ctrl_q[LANE_STAGES].op;
            out_vs1  = ctrl_q[LANE_STAGES].data_vs1;
        end
    endcase
end

// Result element: op(block 0, vs1[0]), or vs1[0] when no element is active
vredtree_alu #(
    .NB      (8),
    .NB_FULL (8)
) vredtree_alu_out (
    .sew_i   (sew_to_out),
    .op_i    (out_op[2:0]),
    .a_i     (out_data),
    .b_i     (out_vs1),
    .ma_i    ({8{out_m0}}),
    .mb_i    (8'hFF),
    .res_o   (out_res),
    /* verilator lint_off PINCONNECTEMPTY */
    .mask_o  ()
    /* verilator lint_on PINCONNECTEMPTY */
);

assign out_zero = out_m0 && (out_op == RED_NONE);

always_comb begin
    red_data_vd_o = '0;
    if (!out_zero) begin
        case (sew_to_out)
            SEW_8:  red_data_vd_o = {data_old_vd[VLEN-1:8],  out_res[7:0]};
            SEW_16: red_data_vd_o = {data_old_vd[VLEN-1:16], out_res[15:0]};
            SEW_32: red_data_vd_o = {data_old_vd[VLEN-1:32], out_res[31:0]};
            SEW_64: red_data_vd_o = {data_old_vd[VLEN-1:64], out_res[63:0]};
        endcase
    end
end

endmodule
