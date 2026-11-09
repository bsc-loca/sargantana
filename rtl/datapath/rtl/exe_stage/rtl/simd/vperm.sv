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

// Vector permutations: vslideup, vslidedown, vslide1up/vfslide1up,
// vslide1down/vfslide1down, vrgather.vv/vx/vi, vrgatherei16 and vcompress.
//
// The result is built in read form: every byte of vd either reads one byte of
// vs2 through a single VLEN/8:1 byte crossbar shared by all the instructions,
// or takes a fill value (0, old vd, all ones or rs1). The source element of
// every element is computed for the four SEWs in parallel and the SEW of the
// instruction selects one of them. vcompress obtains its source bytes from a
// log-step compaction network.
//
// As in the rest of simd_unit, the control fields (type, SEW, opvx/opvi, vl,
// vlmax, vta, old vd) come from the instruction at the output of the unit
// (instr_to_out) and the operands (vs1, vs2, rs1, imm and the vlmax of the
// vrgather range checks) from the instruction at its input (instruction_i).
// Permutations always take one cycle, so both are the same instruction when
// this result is used.

module vperm
    import drac_pkg::*;
    import riscv_pkg::*;
(
    // Instruction at the output of the unit (instr_to_out)
    input instr_type_t              instr_type_i,       // Instruction type
    input sew_t                     sew_i,              // Element width
    input logic                     is_opvx_i,          // Scalar operand is rs1
    input logic                     is_opvi_i,          // Scalar operand is imm
    input logic                     vta_i,              // Tail agnostic (vcompress)
    input logic [VMAXELEM_LOG:0]    vl_i,               // Vector length
    input logic [VMAXELEM_LOG:0]    vlmax_i,            // VLMAX (vslidedown)
    input bus_simd_t                data_old_vd_i,      // Old vd (vslideup, vcompress)
    // Instruction at the input of the unit (instruction_i)
    input logic [4:0]               imm_i,              // imm[4:0] (.vi forms)
    input bus64_t                   data_rs1_i,         // rs1 (.vx forms, vslide1)
    input logic [31:0]              rs1_replicated_i,   // rs1_replicated[31:0] (vslide1 with SEW_32)
    input logic [VMAXELEM_LOG:0]    vlmax_gather_i,     // VLMAX of the vrgather range checks
    input bus_simd_t                data_vs1_i,         // vs1 (indices, vcompress mask)
    input bus_simd_t                data_vs2_i,         // vs2 (source elements)
    output bus_simd_t               data_vd_o           // Result
);

localparam int VBYTES     = VLEN/8;                 // Bytes of a vector register
localparam int VBYTES_LOG = $clog2(VBYTES);         // Bits of a byte index

typedef logic [VBYTES_LOG-1:0] byte_idx_t;

// Value of a result byte that does not read vs2
typedef enum logic [1:0] {
    FILL_ZERO,                                      // 0
    FILL_OLD,                                       // Old vd
    FILL_ONES,                                      // All ones (tail agnostic)
    FILL_RS1                                        // rs1 (vslide1up/vslide1down)
} fill_t;

logic is_slideup, is_slidedown, is_slide1up, is_slide1down;
logic is_gather_vv, is_gather_vx, is_gather_ei16, is_compress;

assign is_slideup     = (instr_type_i == VSLIDEUP);
assign is_slidedown   = (instr_type_i == VSLIDEDOWN);
assign is_slide1up    = (instr_type_i == VSLIDE1UP) || (instr_type_i == VFSLIDE1UP);
assign is_slide1down  = (instr_type_i == VSLIDE1DOWN) || (instr_type_i == VFSLIDE1DOWN);
assign is_gather_vv   = (instr_type_i == VRGATHER) && !is_opvx_i && !is_opvi_i;
assign is_gather_vx   = (instr_type_i == VRGATHER) && (is_opvx_i || is_opvi_i);
assign is_gather_ei16 = (instr_type_i == VRGATHEREI16);
assign is_compress    = (instr_type_i == VCOMPRESS);

// Offset of vslideup/vslidedown (imm before rs1) and index of vrgather.vx/vi
// (rs1 before imm), on 64 bits: the range checks below use all of them
bus64_t slide_amount;
bus64_t gather_index;

assign slide_amount = is_opvi_i ? 64'(imm_i) : (is_opvx_i ? data_rs1_i : '0);
assign gather_index = is_opvx_i ? data_rs1_i : (is_opvi_i ? 64'(imm_i) : '0);

//////////////////////////////////////////////////////////////////////////////
// Slides and gathers: source element of every element, for each SEW
//////////////////////////////////////////////////////////////////////////////

// Per SEW (index = sew_t) and byte of vd: source byte in vs2, whether the byte
// reads it and its value otherwise
byte_idx_t sew_src  [4][VBYTES];
logic      sew_take [4][VBYTES];
fill_t     sew_fill [4][VBYTES];

for (genvar gs = 0; gs < 4; gs++) begin : g_sew
    localparam int EB      = 1 << gs;                           // Bytes of an element
    localparam int EBITS   = 8*EB;                              // Bits of an element
    localparam int NE      = VBYTES/EB;                         // Elements of a register
    localparam int NE_LOG  = VBYTES_LOG - gs;                   // Bits of an element index
    localparam int NE_EI16 = (NE < (VLEN/16)) ? NE : (VLEN/16); // Elements with a 16-bit index

    logic [NE_LOG-1:0] slide_off;           // Slide offset, low bits
    logic              slide_in_range;      // Slide offset < NE, on its 64 bits
    logic [NE_LOG-1:0] last_elem;           // (vl - 1) mod NE, rs1 of vslide1down
    logic [NE_LOG-1:0] ei16_src  [NE];      // vrgatherei16 index, low bits
    logic              ei16_take [NE];      // vrgatherei16 index < vlmax, on its 16 bits
    logic [NE_LOG-1:0] elem_src  [NE];      // Source element in vs2
    logic              elem_take [NE];      // Element reads vs2
    fill_t             elem_fill [NE];      // Element value otherwise

    always_comb begin
        slide_off      = slide_amount[NE_LOG-1:0];
        slide_in_range = (slide_amount < 64'(NE));
        last_elem      = NE_LOG'(int'(vl_i) - 1);

        // vrgatherei16 reads VLEN/16 indices, so with SEW_8 only the low half
        // of vd is gathered and the high half is 0
        for (int k = 0; k < NE; k++) begin
            ei16_src[k]  = '0;
            ei16_take[k] = 1'b0;
        end
        for (int k = 0; k < NE_EI16; k++) begin
            ei16_src[k]  = data_vs1_i[k*16 +: NE_LOG];
            ei16_take[k] = (data_vs1_i[k*16 +: 16] < 16'(vlmax_gather_i));
        end

        for (int k = 0; k < NE; k++) begin
            elem_src[k]  = '0;
            elem_take[k] = 1'b0;
            elem_fill[k] = FILL_ZERO;
            if (is_slideup) begin
                // vd[k] = vs2[k - off] for k >= off; old vd below off, or
                // everywhere when off >= NE
                elem_src[k]  = NE_LOG'(k) - slide_off;
                elem_take[k] = slide_in_range && (NE_LOG'(k) >= slide_off);
                elem_fill[k] = FILL_OLD;
            end else if (is_slidedown) begin
                // vd[k] = vs2[k + off] for k < vl, k + off < vlmax and
                // k + off < NE; 0 otherwise, and everywhere when off >= NE
                elem_src[k]  = NE_LOG'(k) + slide_off;
                elem_take[k] = slide_in_range && (k < int'(vl_i)) &&
                               ((k + int'(slide_off)) < int'(vlmax_i)) &&
                               ((k + int'(slide_off)) < NE);
            end else if (is_slide1up) begin
                // vd[0] = rs1, vd[k] = vs2[k - 1] for k < vl (every k when vl
                // is 0, as vl - 1 wraps around); 0 otherwise
                if (k == 0) begin
                    elem_fill[k] = FILL_RS1;
                end else begin
                    elem_src[k]  = NE_LOG'(k - 1);
                    elem_take[k] = (vl_i == '0) || (k < int'(vl_i));
                end
            end else if (is_slide1down) begin
                // vd[(vl - 1) mod NE] = rs1, else vd[k] = vs2[k + 1] for
                // k + 1 < vl; 0 otherwise
                if (NE_LOG'(k) == last_elem) begin
                    elem_fill[k] = FILL_RS1;
                end else if (k < (NE - 1)) begin
                    elem_src[k]  = NE_LOG'(k + 1);
                    elem_take[k] = ((k + 1) < int'(vl_i));
                end
            end else if (is_gather_vv) begin
                // vd[k] = vs2[vs1[k] mod NE] if vs1[k] < vlmax, compared on
                // all SEW bits; 0 otherwise
                elem_src[k]  = data_vs1_i[k*EBITS +: NE_LOG];
                elem_take[k] = (data_vs1_i[k*EBITS +: EBITS] < EBITS'(vlmax_gather_i));
            end else if (is_gather_ei16) begin
                elem_src[k]  = ei16_src[k];
                elem_take[k] = ei16_take[k];
            end else if (is_gather_vx) begin
                // vd[k] = vs2[index] if index < vlmax, compared on all 64 bits;
                // 0 otherwise. vlmax <= NE, so the index is below NE when it
                // is used (with a larger vlmax this reads vs2[index mod NE])
                elem_src[k]  = gather_index[NE_LOG-1:0];
                elem_take[k] = (gather_index < 64'(vlmax_gather_i));
            end
        end
    end

    // Byte b of vd is byte (b mod EB) of element b/EB
    for (genvar b = 0; b < VBYTES; b++) begin : g_byte
        assign sew_src[gs][b]  = (byte_idx_t'(elem_src[b/EB]) << gs) | byte_idx_t'(b % EB);
        assign sew_take[gs][b] = elem_take[b/EB];
        assign sew_fill[gs][b] = elem_fill[b/EB];
    end
end

//////////////////////////////////////////////////////////////////////////////
// vcompress
//////////////////////////////////////////////////////////////////////////////

// Element k of vs2 is selected when vs1[k] and k < vl, and moves down by the
// number of unselected elements below it. Per byte, as all the bytes of an
// element move together: cmp_sel, the byte belongs to a selected element;
// cmp_first_out, the byte is the first one of an unselected element.
logic      cmp_sel       [VBYTES];
logic      cmp_first_out [VBYTES];
// Unselected elements below every byte (prefix count, Sklansky)
byte_idx_t cmp_cnt [VBYTES_LOG+1][VBYTES];
// Compaction network: valid and distance in bytes (from the original position
// to the final one) of the byte at every position after each stage
logic      cmp_v   [VBYTES_LOG+1][VBYTES];
byte_idx_t cmp_d   [VBYTES_LOG+1][VBYTES];

always_comb begin
    for (int b = 0; b < VBYTES; b++) begin
        cmp_sel[b]       = data_vs1_i[b >> sew_i] && ((b >> sew_i) < int'(vl_i));
        cmp_first_out[b] = ((b & ((1 << sew_i) - 1)) == 0) && !cmp_sel[b];
    end

    // cmp_cnt[VBYTES_LOG][b] = number of cmp_first_out below b: inclusive
    // prefix sum of cmp_first_out shifted up one byte
    cmp_cnt[0][0] = '0;
    for (int b = 1; b < VBYTES; b++) begin
        cmp_cnt[0][b] = byte_idx_t'(cmp_first_out[b-1]);
    end
    for (int t = 0; t < VBYTES_LOG; t++) begin
        for (int b = 0; b < VBYTES; b++) begin
            if (((b >> t) % 2) == 1) begin
                cmp_cnt[t+1][b] = cmp_cnt[t][b] + cmp_cnt[t][((b >> (t+1)) << (t+1)) + (1 << t) - 1];
            end else begin
                cmp_cnt[t+1][b] = cmp_cnt[t][b];
            end
        end
    end

    // Stage t moves down by 2^t bytes the valid bytes with bit t of their
    // distance set. With the low bits first two selected elements never meet
    // in the same position, and no byte goes below position 0.
    for (int b = 0; b < VBYTES; b++) begin
        cmp_v[0][b] = cmp_sel[b];
        cmp_d[0][b] = cmp_cnt[VBYTES_LOG][b] << sew_i;
    end
    for (int t = 0; t < VBYTES_LOG; t++) begin
        for (int p = 0; p < VBYTES; p++) begin
            cmp_v[t+1][p] = cmp_v[t][p] && !cmp_d[t][p][t];
            cmp_d[t+1][p] = cmp_d[t][p];
        end
        for (int p = 0; p < (VBYTES - (1 << t)); p++) begin
            if (cmp_v[t][p + (1 << t)] && cmp_d[t][p + (1 << t)][t]) begin
                cmp_v[t+1][p] = 1'b1;
                cmp_d[t+1][p] = cmp_d[t][p + (1 << t)];
            end
        end
    end
end

//////////////////////////////////////////////////////////////////////////////
// Byte crossbar
//////////////////////////////////////////////////////////////////////////////

logic [7:0] vs2_byte [VBYTES];

always_comb begin
    for (int b = 0; b < VBYTES; b++) begin
        vs2_byte[b] = data_vs2_i[b*8 +: 8];
    end
end

logic [7:0] rs1_byte  [VBYTES];         // rs1 byte at the position of b in its element
byte_idx_t  byte_src  [VBYTES];
logic       byte_take [VBYTES];
fill_t      byte_fill [VBYTES];

always_comb begin
    for (int b = 0; b < VBYTES; b++) begin
        case (sew_i)
            SEW_8:   rs1_byte[b] = data_rs1_i[7:0];
            SEW_16:  rs1_byte[b] = data_rs1_i[(b % 2)*8 +: 8];
            SEW_32:  rs1_byte[b] = rs1_replicated_i[(b % 4)*8 +: 8];
            default: rs1_byte[b] = data_rs1_i[(b % 8)*8 +: 8];      // SEW_64
        endcase

        if (is_compress) begin
            // Position b holds the byte that was cmp_d bytes above it
            byte_src[b]  = byte_idx_t'(b) + cmp_d[VBYTES_LOG][b];
            byte_take[b] = cmp_v[VBYTES_LOG][b];
            byte_fill[b] = vta_i ? FILL_ONES : FILL_OLD;
        end else begin
            byte_src[b]  = sew_src[sew_i][b];
            byte_take[b] = sew_take[sew_i][b];
            byte_fill[b] = sew_fill[sew_i][b];
        end

        if (byte_take[b]) begin
            data_vd_o[b*8 +: 8] = vs2_byte[byte_src[b]];
        end else begin
            case (byte_fill[b])
                FILL_OLD:  data_vd_o[b*8 +: 8] = data_old_vd_i[b*8 +: 8];
                FILL_ONES: data_vd_o[b*8 +: 8] = 8'hFF;
                FILL_RS1:  data_vd_o[b*8 +: 8] = rs1_byte[b];
                default:   data_vd_o[b*8 +: 8] = 8'h00;                 // FILL_ZERO
            endcase
        end
    end
end

endmodule
