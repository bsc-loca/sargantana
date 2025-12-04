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
import fpnew_pkg::*;

/* vfred tree module (SIMD vector floating-point reduction tree)
*
*/
module vfredtree #(
parameter DELAY_SUM_FP32 = 3,
parameter DELAY_SUM_FP64 = 4
) (
input  logic                    clk_i,           // Clock signal
input  logic                    rstn_i,          // Reset signal
input  instr_type_t             instr_type_i,    // Instruction type
input  op_frm_fp_t              frm_i,           // Input instruction rounding mode
input  sew_t                    sew_i,           // SEW: 00 for 8 bits, 01 for 16 bits, 10 for 32 bits, 11 for 64 bits
input  logic [VMAXELEM_LOG:0]   vl_i,            // Current vector lenght in elements
input  bus_simd_t               data_vs1_i,      // 128-bit from vs1
input  bus_simd_t               data_vs2_i,      // 128-bit source operand
input  bus_simd_t               data_old_vd,     // Backup of previous vector destination value
input  bus_mask_t               data_vm_i,       // Vector mask of VLEN/8 size
input  instr_type_t             instr_to_out_i,  // Instruction to output
input  logic [VMAXELEM_LOG:0]   vl_to_out_i,     // Vector Lenght to output
input  sew_t                    sew_to_out_i,    // SEW indication for output
output bus_simd_t               red_data_vd_o,   // 128-bit result (only cares last element)
output fpnew_pkg::status_t      status_o         // floating point resultant flags of the outgoing instruction
);

typedef logic [3:0]W4_logic;
typedef logic [2:0]W3_logic;
typedef logic [1:0]W2_logic;

typedef struct packed {
    fpnew_pkg::status_t status;         // floating point flags to be reducted and propagated to output
    sew_t               sew;            // sew of the instruction
    instr_type_t        instr_type;     // instruction type
    bus_simd_t          data_vs1;       // data of the scalar vs1 input
    op_frm_fp_t         frm;            // floating point desired rounding mode propagation
    logic               all_inactive;   // all the elements are inactive (propagate vs1 without canonicalizing)
} metadata_t;

/////////////////////    SUPPORT FUNCTION DEFINITIONS    /////////////////////

// Function to translate raw flags comming from DP2 into fpnew_pkg::status_t

function automatic integer floor_log2(input integer value);
    if (value == 0) return integer'(-1);
    return integer'(int'($clog2(value+1)) - 1);
endfunction

function automatic int first_node_index(int level, int sew);
    int sum;
    sum = 0;
    for (int k = 0; k < level; k++) begin
        sum = sum + ((int'(VLEN) / int'(sew)) >> (k+1));
    end
    return sum;
endfunction


//////////////////////////////////////////////////////////////////////////////

// static instantiation of floating point 32 and 64 adders

/* In this parametric generation pattern there will always
* be 2*((VLEN/BASE)-1)+1 connections in the tree and
* VLEN/BASE-1 adders.
* The connections can be expressed as an array of busses
* indexed following the binary tree pattern.
*
* An example diagram of VLEN/32 = 8
*  _______________________________________
* |____|____|____|____|____|____|____|____|
*   0\   /1   2\   /3   4\   /6   6\   /7
*     ____     ____      ____      ____
*    |  0 |   |  1 |    | 2  |    | 3  |
*       8\      /9       10\       /11
*         \    /            \     /
*          ____               ____
*         | 4  |             | 5  |
*           12\               /13
*              \             /
*               \           /
*                \         /
*                 \       /
*                  \ ____/
*                   | 6  |
*                     |
*                     v
*
* The result will always be avaliable 3*LOG(VLEN) cycles
* and the design is actually pipelined to 1 cycle.
*
* The flags will be propagated to the output. The NaN treatment
* has been chosen to be "non-canonicalizing" for any of the cases
* and thus always propagating the NaN for SUM, MAX and MIN reductions.
*
*/

localparam NUM_WIDE_SIGNALS = (VLEN/32) + ((VLEN/32)/2);

genvar i;

bus32_t fp32signals [2*((VLEN/32)-1):0];
bus64_t fp64signals [2*((VLEN/64)-1):0];
logic   fp32valids [2*((VLEN/32)-1):0];
logic   fp64valids [2*((VLEN/64)-1):0];
bus32_t fp32_res;
bus64_t fp64_res;

fpnew_pkg::status_t fp32statusvec  [(VLEN/32)-1:0];
fpnew_pkg::status_t fp64statusvec  [(VLEN/64)-1:0];

// widening signals
bus64_t fp64widesignals [NUM_WIDE_SIGNALS-1:0];
metadata_t fp64widemetadata[DELAY_SUM_FP64-1:0];
logic fp64widevalids[NUM_WIDE_SIGNALS-1:0];
status_t fp64widestatus[((VLEN/32)/2)-1:0];

// Vector Mask Managment for LMUL<1 cases
bus_mask_t data_vm;
always_comb begin
    for (int j = 0; j < $size(data_vm); j++) begin
        if (j < vl_i) begin
            data_vm[j] = data_vm_i[j];
        end else begin
            data_vm[j] = 1'b0;
        end
    end
end

// nullify all the source operands which are unmasked
generate
    for (genvar j = 0; j < (VLEN/32); j++) begin : FP32_GEN_SIGNALS
        assign fp32signals[j] = data_vm[j] ? data_vs2_i[(32*j) +: 32] :
                                (frm_i == FRM_RDN) ? 32'h8000_0000 : 32'h0000_0000;
        assign fp32valids[j] = data_vm[j];
        assign fp64widesignals[j] = data_vm[j] ? fp32_to_fp64_func(data_vs2_i[(32*j) +: 32]) :
                                    (frm_i == FRM_RDN) ? 64'h8000_0000_0000_0000 : 64'h0000_0000_0000_0000;
        assign fp64widevalids[j] = data_vm[j];
    end
    for (genvar j = 0; j < (VLEN/64); j++) begin : FP64_GEN_SIGNALS
        bus64_t fp64op;
        assign fp64signals[j] = data_vm[j] ? data_vs2_i[(64*j) +: 64] :
                                (frm_i == FRM_RDN) ? 64'h8000_0000_0000_0000 : 64'h0000_0000_0000_0000;
        assign fp64valids[j] = (fp64widemetadata[DELAY_SUM_FP64-1].instr_type == VFWREDUSUM) ? fp64widevalids[j] : data_vm[j];
    end
endgenerate

// --------------------------------------------------------------------------------------


// reduction tree for 32 bit elements
generate
for (i = 0; i < ((VLEN/32)-1); i++) begin : fp32_adders
    localparam FP32_NODE_LEVEL = floor_log2(VLEN/32/2)-floor_log2((VLEN/32)-1-i);

    bus32_t fp32srca, fp32srcb;
    bus32_t fp32maxmin, fp32maxmin_masked;
    bus64_t fp32resdp2;
    logic fp32ismaxinstr_end, fp32ismininstr_end;
    fpnew_pkg::status_t fpnewstatus;

    bus32_t fp32srca_end     [DELAY_SUM_FP32-1:0];
    bus32_t fp32srcb_end     [DELAY_SUM_FP32-1:0];
    logic   fp32aisvalid_end [DELAY_SUM_FP32-1:0];
    logic   fp32bisvalid_end [DELAY_SUM_FP32-1:0];

    // commented on fp64 section
    for (genvar k = 0; k < DELAY_SUM_FP32; k++) begin
        always_ff @(posedge clk_i, negedge rstn_i) begin : sourcesregistersbuffer
            if (~rstn_i) begin
                fp32srca_end[k] <= 32'h0;
                fp32srcb_end[k] <= 32'h0;
                fp32aisvalid_end[k] <= 1'b0;
                fp32bisvalid_end[k] <= 1'b0;
            end else begin
                if (k == 0) begin
                    fp32srca_end[k]     <= fp32srca;
                    fp32srcb_end[k]     <= fp32srcb;
                    fp32aisvalid_end[k] <= fp32valids[2*i];
                    fp32bisvalid_end[k] <= fp32valids[2*i+1];
                end else begin
                    fp32srca_end[k] <= fp32srca_end[k-1];
                    fp32srcb_end[k] <= fp32srcb_end[k-1];
                    fp32aisvalid_end[k] <= fp32aisvalid_end[k-1];
                    fp32bisvalid_end[k] <= fp32bisvalid_end[k-1];
                end
            end
        end
    end

    always_comb begin
        fp32srca = fp32signals[2*i];
        fp32srcb = fp32signals[2*i+1];

        fp32ismaxinstr_end = fp32_metadata_q[FP32_NODE_LEVEL*DELAY_SUM_FP32+(DELAY_SUM_FP32-1)].instr_type == VFREDMAX;
        fp32ismininstr_end = fp32_metadata_q[FP32_NODE_LEVEL*DELAY_SUM_FP32+(DELAY_SUM_FP32-1)].instr_type == VFREDMIN;
        
        // the MAXMIN must first be masked and canonicalized if needed
        fp32maxmin_masked = (~fp32aisvalid_end[DELAY_SUM_FP32-1] && ~fp32bisvalid_end[DELAY_SUM_FP32-1]) ? 32'h0000_0000 :
                            ~fp32aisvalid_end[DELAY_SUM_FP32-1] ? is_nan_f32(fp32srcb_end[DELAY_SUM_FP32-1]) ? FP32_QNAN : fp32srcb_end[DELAY_SUM_FP32-1] :
                            ~fp32bisvalid_end[DELAY_SUM_FP32-1] ? is_nan_f32(fp32srca_end[DELAY_SUM_FP32-1]) ? FP32_QNAN : fp32srca_end[DELAY_SUM_FP32-1] :
                            fp32maxmin;

        // for maxmin instructions the invalid check should also be done by the fpnew
        // however the UF/OF flags should still be cleaned in such case
        if (fp32ismaxinstr_end || fp32ismininstr_end) begin
            fp32statusvec[i] = '0;
            fp32statusvec[i].NV = fpnewstatus.NV;
        end else begin
            fp32statusvec[i] = fpnewstatus;
        end

        // multiplex the correct result depending on the instruction type
        // the chosen NaN treatment will be not to canonicalize nor raise invalid flag even for SUM reductions
        fp32signals[(VLEN/32)+i] = (fp32ismaxinstr_end || fp32ismininstr_end) ? fp32maxmin_masked :
                                 fp32resdp2[31:0];
        fp32valids[(VLEN/32)+i] = fp32aisvalid_end[DELAY_SUM_FP32-1] || fp32bisvalid_end[DELAY_SUM_FP32-1];
    end // always_comb

    maxmin_f32 fp32comparator (
        .maxmin_i   (fp32ismaxinstr_end), // if it's max operate max, else operate min
        .srca_i     (fp32srca_end[DELAY_SUM_FP32-1]),
        .srcb_i     (fp32srcb_end[DELAY_SUM_FP32-1]),
        .ret_o      (fp32maxmin),
        .is_nan_o   (),
        .invalid_o  (),
        .lt_o       (),
        .eq_o       (),
        .gt_o       (),
        .le_o       (),
        .ge_o       ()
    );

    logic [2:0][63:0] fp32_fpnew_operands;
    always_comb begin
        fp32_fpnew_operands[1] = {32'h0000_0000, fp32srca};
        fp32_fpnew_operands[2] = {32'h0000_0000, fp32srcb};
        fp32_fpnew_operands[0] = 64'h0000_0000_0000_0000;
    end
    
    fpnew_top #(
       .Features       ( SARG_ADDMUL_RV64D ),
       .Implementation ( SARG_ADDMUL_ONLY  )
    ) f32_fpnew (
           .clk_i          ( clk_i ),
           .rst_ni         ( rstn_i ),
           .flush_i        ( '0 ),
           // Input
           .operands_i     ( fp32_fpnew_operands ),
           .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(fp32_metadata_d[FP32_NODE_LEVEL*DELAY_SUM_FP32].frm)) ),
           .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
           .op_mod_i       ( 1'b0 ),
           .src_fmt_i      ( fpnew_pkg::fp_format_e'(FP32) ),
           .dst_fmt_i      ( fpnew_pkg::fp_format_e'(FP32) ),
           .int_fmt_i      ( fpnew_pkg::int_format_e'(INT32) ),
           .simd_mask_i    ( '0 ),
           .vectorial_op_i ( '0 ),
           .tag_i          ( '0 ),
           .in_valid_i     ( 1'b1 ),
           .out_ready_i    ( 1'b1 ),
           // Outputs
           .in_ready_o     (  ),
           .result_o       ( fp32resdp2 ),
           .status_o       ( fpnewstatus ),
           .tag_o          (  ),
           .out_valid_o    (  ),
           .busy_o         (  )
        );
end
endgenerate

// the result of the reduction must be added with the last element of the 2nd operand
bus32_t lastfp32srca, lastfp32srcb;
bus32_t lastfp32maxmin, lastfp32maxmin_masked;
bus64_t lastfp32resdp2;
logic lastfp32ismaxinstr_end, lastfp32ismininstr_end;
fpnew_pkg::status_t lastfp32fpnewstatus;

// commented on fp64 section
bus32_t lastfp32srca_end [DELAY_SUM_FP32-1:0];
bus32_t lastfp32srcb_end [DELAY_SUM_FP32-1:0];
logic lastfp32isvalid_end [DELAY_SUM_FP32-1:0];
generate
for (genvar k = 0; k < DELAY_SUM_FP32; k++) begin : fp32_buffers
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        lastfp32srca_end[k] <= 32'h0;
        lastfp32srcb_end[k] <= 32'h0;
        lastfp32isvalid_end[k] <= 1'b0;
    end else begin
        if (k == 0) begin
            lastfp32srca_end[k] <= lastfp32srca;
            lastfp32srcb_end[k] <= lastfp32srcb;
            lastfp32isvalid_end[k] <= fp32valids[2*((VLEN/32)-1)];
        end else begin
            lastfp32srca_end[k] <= lastfp32srca_end[k-1];
            lastfp32srcb_end[k] <= lastfp32srcb_end[k-1];
            lastfp32isvalid_end[k] <= lastfp32isvalid_end[k-1];
        end
    end
end
end
endgenerate

always_comb begin
    lastfp32srca = fp32signals[2*((VLEN/32)-1)];
    lastfp32srcb = fp32_metadata_q[($clog2(VLEN/32))*DELAY_SUM_FP32-1].data_vs1[31:0]; // scalar input propagated down the pipeline

    lastfp32ismaxinstr_end = fp32_metadata_q[($clog2(VLEN/32))*DELAY_SUM_FP32+(DELAY_SUM_FP32-1)].instr_type == VFREDMAX;
    lastfp32ismininstr_end = fp32_metadata_q[($clog2(VLEN/32))*DELAY_SUM_FP32+(DELAY_SUM_FP32-1)].instr_type == VFREDMIN;

    lastfp32maxmin_masked = ~lastfp32isvalid_end[DELAY_SUM_FP32-1] ? 
                            is_nan_f32(lastfp32srcb_end[DELAY_SUM_FP32-1]) ? FP32_QNAN : lastfp32srcb_end[DELAY_SUM_FP32-1] :
                            lastfp32maxmin;

    if (lastfp32ismaxinstr_end || lastfp32ismininstr_end) begin
        fp32statusvec[(VLEN/32)-1] = '0; 
        fp32statusvec[(VLEN/32)-1].NV = lastfp32fpnewstatus.NV; 
    end else begin
        fp32statusvec[(VLEN/32)-1] = lastfp32fpnewstatus;
    end

    // multiplex the correct result depending on the instruction type
    fp32_res = (fp32_metadata_q[($clog2(VLEN/32))*DELAY_SUM_FP32+(DELAY_SUM_FP32-1)].all_inactive == 1'b0) ? lastfp32srcb_end[DELAY_SUM_FP32-1] :
               (lastfp32ismaxinstr_end || lastfp32ismininstr_end) ? lastfp32maxmin_masked :
               lastfp32resdp2[31:0];
end

maxmin_f32 lastfp32comparator (
    .maxmin_i   (lastfp32ismaxinstr_end),
    .srca_i     (lastfp32srca_end[DELAY_SUM_FP32-1]),
    .srcb_i     (lastfp32srcb_end[DELAY_SUM_FP32-1]),
    .ret_o      (lastfp32maxmin),
    .is_nan_o   (),
    .invalid_o  (),
    .lt_o       (),
    .eq_o       (),
    .gt_o       (),
    .le_o       (),
    .ge_o       ()
);

logic [2:0][63:0] lastfp32_fpnew_operands;
always_comb begin
    lastfp32_fpnew_operands[1] = {32'h0000_0000, lastfp32srca};
    lastfp32_fpnew_operands[2] = {32'h0000_0000, lastfp32srcb};
    lastfp32_fpnew_operands[0] = 64'h0000_0000_0000_0000;
end

fpnew_top #(
.Features       ( SARG_ADDMUL_RV64D ),
.Implementation ( SARG_ADDMUL_ONLY  )
) f32_fpnew_last (
    .clk_i          ( clk_i ),
    .rst_ni         ( rstn_i ),
    .flush_i        ( '0 ),
    // Input
    .operands_i     ( lastfp32_fpnew_operands ),
    .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(fp32_metadata_d[($clog2(VLEN/32))*DELAY_SUM_FP32].frm)) ),
    .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
    .op_mod_i       ( 1'b0 ),
    .src_fmt_i      ( fpnew_pkg::fp_format_e'(FP32) ),
    .dst_fmt_i      ( fpnew_pkg::fp_format_e'(FP32) ),
    .int_fmt_i      ( fpnew_pkg::int_format_e'(INT32) ),
    .simd_mask_i    ( '0 ),
    .vectorial_op_i ( '0 ),
    .tag_i          ( '0 ),
    .in_valid_i     ( 1'b1 ),
    .out_ready_i    ( 1'b1 ),
    // Outputs
    .in_ready_o     (  ),
    .result_o       ( lastfp32resdp2 ),
    .status_o       ( lastfp32fpnewstatus ),
    .tag_o          (  ),
    .out_valid_o    (  ),
    .busy_o         (  )
);

// --------------------------------------------------------------------------------------
// for the vector widening reductions for FP64, we must also ensure that
// the elements exceeding the maxvlen FP64 also are reducted, for this
// purpose and asuming the simd control avoid structural hazards a 1st
// level before the default will also be included


// we need a separate metadata buffer for this stage to be recovered later on 
// in the first metadata input fp64_metadata_d and fp64_metadata_q
for (i = 0; i < DELAY_SUM_FP64; i++) begin : fp64_wide_metadata
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            fp64widemetadata[i] <= '0;
        end else begin
            if (i == 0) begin
                fp64widemetadata[i].instr_type   <= instr_type_i;
                fp64widemetadata[i].sew          <= SEW_64;
                fp64widemetadata[i].data_vs1     <= data_vs1_i;
                fp64widemetadata[i].frm          <= frm_i;
                fp64widemetadata[i].status       <= '0;
                fp64widemetadata[i].all_inactive <= |data_vm;
            end else begin
                fp64widemetadata[i] <= fp64widemetadata[i-1];
            end
        end
    end
end

generate
for (i = 0; i < ((VLEN/32)/2); i++) begin : fp64_wide_adders
    bus64_t fp64widesrca, fp64widesrcb;
    bus64_t fp64widesrca_end[DELAY_SUM_FP64-1:0], fp64widesrcb_end[DELAY_SUM_FP64-1:0]; // register chain
    logic fp64wideaisvalid_end[DELAY_SUM_FP64-1:0], fp64widebisvalid_end[DELAY_SUM_FP64-1:0];
    status_t fpnewstatus;
    bus64_t fp64wideresdp2; 

    for (genvar j = 0; j < DELAY_SUM_FP64; j++) begin
        always_ff @(posedge clk_i, negedge rstn_i) begin
            if (~rstn_i) begin
                fp64widesrca_end[j] <= 64'h0;
                fp64widesrcb_end[j] <= 64'h0;
                fp64wideaisvalid_end[j] <= 1'b0;
                fp64widebisvalid_end[j] <= 1'b0;
            end else begin
                if (j == 0) begin
                    fp64widesrca_end[j] <= fp64widesrca; 
                    fp64widesrcb_end[j] <= fp64widesrcb;
                    fp64wideaisvalid_end[j] <= fp32valids[2*j];
                    fp64widebisvalid_end[j] <= fp32valids[2*j+1];
                end else begin
                    fp64widesrca_end[j] <= fp64widesrca_end[j-1];
                    fp64widesrcb_end[j] <= fp64widesrcb_end[j-1];
                    fp64wideaisvalid_end[j] <= fp64wideaisvalid_end[j-1];
                    fp64widebisvalid_end[j] <= fp64widebisvalid_end[j-1];
                end
            end
        end
    end
    
    assign fp64widevalids[(VLEN/32)+i] = fp64wideaisvalid_end[DELAY_SUM_FP64-1] || fp64widebisvalid_end[DELAY_SUM_FP64-1];

    always_comb begin
        fp64widesrca = fp64widesignals[2*i];
        fp64widesrcb = fp64widesignals[2*i+1];
        fp64widestatus[i] = fpnewstatus; // in widening case, always will be computed by fpnew, only sums done
        fp64widesignals[(VLEN/32)+i] = fp64wideresdp2;
    end

    logic [2:0][63:0] fp64wide_fpnew_operands;
    always_comb begin
        fp64wide_fpnew_operands[1] = fp64widesrca;
        fp64wide_fpnew_operands[2] = fp64widesrcb;
        fp64wide_fpnew_operands[0] = 64'h0000_0000_0000_0000;
    end

    fpnew_top #(
       .Features       ( SARG_ADDMUL_RV64D ),
       .Implementation ( SARG_ADDMUL_ONLY  )
    ) fp64_fpnew (
       .clk_i          ( clk_i ),
       .rst_ni         ( rstn_i ),
       .flush_i        ( '0 ),
       // Input
       .operands_i     ( fp64wide_fpnew_operands ),
       .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(frm_i)) ),
       .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
       .op_mod_i       ( 1'b0 ),
       .src_fmt_i      ( fpnew_pkg::fp_format_e'(FP64) ),
       .dst_fmt_i      ( fpnew_pkg::fp_format_e'(FP64) ),
       .int_fmt_i      ( fpnew_pkg::int_format_e'(INT64) ),
       .simd_mask_i    ( '0 ),
       .vectorial_op_i ( '0 ),
       .tag_i          ( '0 ),
       .in_valid_i     ( 1'b1 ),
       .out_ready_i    ( 1'b1 ),
       // Outputs
       .in_ready_o     (  ),
       .result_o       ( fp64wideresdp2 ),
       .status_o       ( fpnewstatus ),
       .tag_o          (  ),
       .out_valid_o    (  ),
       .busy_o         (  )
    );
end
endgenerate

// --------------------------------------------------------------------------------------

// reduction tree for 64 bit elements
generate
for (i = 0; i < ((VLEN/64)-1); i++) begin : fp64_adders
    localparam FP64_NODE_LEVEL = floor_log2(VLEN/64/2)-floor_log2((VLEN/64)-1-i);

    bus64_t fp64srca, fp64srcb;
    bus64_t fp64maxmin, fp64maxmin_masked;
    bus64_t fp64resdp2;
    logic fp64ismaxinstr_end, fp64ismininstr_end;
    fpnew_pkg::status_t fpnewstatus;

    // As the sources will have to be available once the result has been
    // received from the FP substraction to decide which of them is min
    // and max. Buffers have been added to propagate this info for each of
    // the adders in the tree.

    /*                            fp64srca & fp64srcb
     * metadata      A     B               |
     *    |          |     |             __v__   \
     *    |          | dp2 |            |_____|   |
     *    |           \   /              __v__    |
     *  __v__         _v_v_             |_____|    \ DELAY_SUM_FP64
     * |_____|       |_____|             __v__     /
     *    |             |               |_____|   |
     *    |             |                __v__    |
     *    |             v               |_____|  /
     *    v           dp2res               |
     *                                     v
     *                        fp64srca_end & fp64srcb_end
     */

    bus64_t fp64srca_end     [DELAY_SUM_FP64-1:0];
    bus64_t fp64srcb_end     [DELAY_SUM_FP64-1:0];
    logic   fp64aisvalid_end [DELAY_SUM_FP64-1:0];
    logic   fp64bisvalid_end [DELAY_SUM_FP64-1:0];
    for (genvar k = 0; k < DELAY_SUM_FP64; k++) begin
        always_ff @(posedge clk_i, negedge rstn_i) begin : sourcesregistersbuffer
            if (~rstn_i) begin
                fp64srca_end[k] <= 64'h0;
                fp64srcb_end[k] <= 64'h0;
                fp64aisvalid_end[k] <= 1'b0;
                fp64bisvalid_end[k] <= 1'b0;
            end else begin
                if (k == 0) begin
                    fp64srca_end[k] <= fp64srca;
                    fp64srcb_end[k] <= fp64srcb;
                    fp64aisvalid_end[k] <= fp64valids[2*i];
                    fp64bisvalid_end[k] <= fp64valids[2*i+1];
                end else begin
                    fp64srca_end[k] <= fp64srca_end[k-1];
                    fp64srcb_end[k] <= fp64srcb_end[k-1];
                    fp64aisvalid_end[k] <= fp64aisvalid_end[k-1];
                    fp64bisvalid_end[k] <= fp64bisvalid_end[k-1];
                end
            end
        end
    end

    always_comb begin
        if ((FP64_NODE_LEVEL==0) && (fp64widemetadata[DELAY_SUM_FP64-1].instr_type == VFWREDUSUM)) begin
            fp64srca = fp64widesignals[(VLEN/32)+(2*i)];
            fp64srcb = fp64widesignals[((VLEN/32)+(2*i))+1];
        end else begin
            fp64srca = fp64signals[(2*i)];
            fp64srcb = fp64signals[(2*i)+1];
        end

        // the last comparison signals can be done using the propagated instr_type's
        fp64ismaxinstr_end     = fp64_metadata_q[FP64_NODE_LEVEL*DELAY_SUM_FP64+(DELAY_SUM_FP64-1)].instr_type == VFREDMAX;
        fp64ismininstr_end     = fp64_metadata_q[FP64_NODE_LEVEL*DELAY_SUM_FP64+(DELAY_SUM_FP64-1)].instr_type == VFREDMIN;

        fp64maxmin_masked      = (~fp64aisvalid_end[DELAY_SUM_FP64-1] && ~fp64bisvalid_end[DELAY_SUM_FP64-1]) ? 64'h0000_0000_0000_0000 :
                                 ~fp64aisvalid_end[DELAY_SUM_FP64-1] ? is_nan_f64(fp64srcb_end[DELAY_SUM_FP64-1]) ? FP64_QNAN : fp64srcb_end[DELAY_SUM_FP64-1] :
                                 ~fp64bisvalid_end[DELAY_SUM_FP64-1] ? is_nan_f64(fp64srca_end[DELAY_SUM_FP64-1]) ? FP64_QNAN : fp64srca_end[DELAY_SUM_FP64-1] :
                                 fp64maxmin;

        if (fp64ismaxinstr_end || fp64ismininstr_end) begin
            fp64statusvec[i] = '0;
            fp64statusvec[i].NV = fpnewstatus.NV;
        end else begin
            fp64statusvec[i] = fpnewstatus;
        end

        // multiplex the correct result depending on the instruction type
        fp64signals[(VLEN/64)+i] = (fp64ismaxinstr_end || fp64ismininstr_end) ? fp64maxmin_masked :
                                 fp64resdp2;
        fp64valids[(VLEN/64)+i] = fp64aisvalid_end[DELAY_SUM_FP64-1] || fp64bisvalid_end[DELAY_SUM_FP64-1];
    end

    maxmin_f64 fp64comparator (
        .maxmin_i   (fp64ismaxinstr_end),
        .srca_i     (fp64srca_end[DELAY_SUM_FP64-1]),
        .srcb_i     (fp64srcb_end[DELAY_SUM_FP64-1]),
        .ret_o      (fp64maxmin),
        .is_nan_o   (),
        .invalid_o  (),
        .lt_o       (),
        .eq_o       (),
        .gt_o       (),
        .le_o       (),
        .ge_o       ()
    );

    logic [2:0][63:0] fp64_fpnew_operands;
    always_comb begin
        fp64_fpnew_operands[1] = fp64srca;
        fp64_fpnew_operands[2] = fp64srcb;
        fp64_fpnew_operands[0] = 64'h0000_0000_0000_0000;
    end

    fpnew_top #(
       .Features       ( SARG_ADDMUL_RV64D ),
       .Implementation ( SARG_ADDMUL_ONLY  )
    ) fp64_fpnew (
       .clk_i          ( clk_i ),
       .rst_ni         ( rstn_i ),
       .flush_i        ( '0 ),
       // Input
       .operands_i     ( fp64_fpnew_operands ),
       .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(fp64_metadata_d[FP64_NODE_LEVEL*DELAY_SUM_FP64].frm)) ),
       .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
       .op_mod_i       ( 1'b0 ),
       .src_fmt_i      ( fpnew_pkg::fp_format_e'(FP64) ),
       .dst_fmt_i      ( fpnew_pkg::fp_format_e'(FP64) ),
       .int_fmt_i      ( fpnew_pkg::int_format_e'(INT64) ),
       .simd_mask_i    ( '0 ),
       .vectorial_op_i ( '0 ),
       .tag_i          ( '0 ),
       .in_valid_i     ( 1'b1 ),
       .out_ready_i    ( 1'b1 ),
       // Outputs
       .in_ready_o     (  ),
       .result_o       ( fp64resdp2 ),
       .status_o       ( fpnewstatus ),
       .tag_o          (  ),
       .out_valid_o    (  ),
       .busy_o         (  )
    );

end
endgenerate

bus64_t lastfp64srca, lastfp64srcb;
bus64_t lastfp64maxmin, lastfp64maxmin_masked;
bus64_t lastfp64resdp2;
logic lastfp64ismaxinstr_end, lastfp64ismininstr_end;
fpnew_pkg::status_t lastfp64fpnewstatus;

bus64_t lastfp64srca_end [DELAY_SUM_FP64-1:0];
bus64_t lastfp64srcb_end [DELAY_SUM_FP64-1:0];
logic lastfp64isvalid_end [DELAY_SUM_FP64-1:0];
generate
for (genvar k = 0; k < DELAY_SUM_FP64; k++) begin : fp64_buffers
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            lastfp64srca_end[k] <= 64'h0;
            lastfp64srcb_end[k] <= 64'h0;
            lastfp64isvalid_end[k] <= 1'b0;
        end else begin
            if (k == 0) begin
                lastfp64srca_end[k] <= lastfp64srca;
                lastfp64srcb_end[k] <= lastfp64srcb;
                lastfp64isvalid_end[k] <= fp64valids[2*(VLEN/64-1)];
            end else begin
                lastfp64srca_end[k] <= lastfp64srca_end[k-1];
                lastfp64srcb_end[k] <= lastfp64srcb_end[k-1];
                lastfp64isvalid_end[k] <= lastfp64isvalid_end[k-1];
            end
        end
    end
end
endgenerate

always_comb begin
    lastfp64srca = fp64signals[2*((VLEN/64)-1)]; // out of the reduction tree of vs2
    // scalar input propagated down the pipeline
    lastfp64srcb = fp64_metadata_q[($clog2(VLEN/64))*DELAY_SUM_FP64-1].data_vs1[63:0];

    // compare with last metadata register of the chain in this case
    lastfp64ismaxinstr_end = fp64_metadata_q[($clog2(VLEN/64))*DELAY_SUM_FP64+(DELAY_SUM_FP64-1)].instr_type == VFREDMAX;
    lastfp64ismininstr_end = fp64_metadata_q[($clog2(VLEN/64))*DELAY_SUM_FP64+(DELAY_SUM_FP64-1)].instr_type == VFREDMIN;

    lastfp64maxmin_masked = ~lastfp64isvalid_end[DELAY_SUM_FP64-1] ? is_nan_f64(lastfp64srcb_end[DELAY_SUM_FP64-1]) ? FP64_QNAN : lastfp64srcb_end[DELAY_SUM_FP64-1] :
                            lastfp64maxmin;

    fp64statusvec[VLEN/64-1] = '0;
    if (lastfp64ismaxinstr_end || lastfp64ismininstr_end) begin
        fp64statusvec[VLEN/64-1].NV = lastfp64fpnewstatus.NV;
    end else begin
        fp64statusvec[VLEN/64-1] = lastfp64fpnewstatus;
    end

    // multiplex the correct result depending on the instruction type
    fp64_res = (fp64_metadata_q[($clog2(VLEN/64))*DELAY_SUM_FP64+(DELAY_SUM_FP64-1)].all_inactive == 1'b0) ? lastfp64srcb_end[DELAY_SUM_FP64-1] :
               (lastfp64ismaxinstr_end || lastfp64ismininstr_end) ? lastfp64maxmin_masked :
               lastfp64resdp2;
end

maxmin_f64 lastfp64comparator (
    .maxmin_i   (lastfp64ismaxinstr_end),
    .srca_i     (lastfp64srca_end[DELAY_SUM_FP64-1]),
    .srcb_i     (lastfp64srcb_end[DELAY_SUM_FP64-1]),
    .ret_o      (lastfp64maxmin),
    .is_nan_o   (),
    .invalid_o  (),
    .lt_o       (),
    .eq_o       (),
    .gt_o       (),
    .le_o       (),
    .ge_o       ()
); 

// the result of the reduction must be added with the last element of the 2nd operand
logic [2:0][63:0] lastfp64_fpnew_operands;
always_comb begin
    lastfp64_fpnew_operands[1] = lastfp64srca;
    lastfp64_fpnew_operands[2] = lastfp64srcb;
    lastfp64_fpnew_operands[0] = 64'h0000_0000_0000_0000;
end

fpnew_top #(
   .Features       ( SARG_ADDMUL_RV64D ),
   .Implementation ( SARG_ADDMUL_ONLY  )
) fp64_fpnew_last (
   .clk_i          ( clk_i ),
   .rst_ni         ( rstn_i ),
   .flush_i        ( '0 ),
   // Input
   .operands_i     ( lastfp64_fpnew_operands ),
   .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(fp64_metadata_d[($clog2(VLEN/64))*DELAY_SUM_FP64].frm)) ),
   .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
   .op_mod_i       ( 1'b0 ),
   .src_fmt_i      ( fpnew_pkg::fp_format_e'(FP64) ),
   .dst_fmt_i      ( fpnew_pkg::fp_format_e'(FP64) ),
   .int_fmt_i      ( fpnew_pkg::int_format_e'(INT64) ),
   .simd_mask_i    ( '0 ),
   .vectorial_op_i ( '0 ),
   .tag_i          ( '0 ),
   .in_valid_i     ( 1'b1 ),
   .out_ready_i    ( 1'b1 ),
   // Outputs
   .in_ready_o     (  ),
   .result_o       ( lastfp64resdp2 ),
   .status_o       ( lastfp64fpnewstatus ),
   .tag_o          (  ),
   .out_valid_o    (  ),
   .busy_o         (  )
);

// --------------------------------------------------------------------------------------

/*
 * metadata                                                                    metadata
 * buffer fp32      fp32 reduction tree           fp64 reduction tree       buffer fp64
 *  _____         _______________________       _______________________         _____
 * |_____|       |_____|_____|_____|_____|     |___________|___________|       |_____|
 *    |              \   /       \   /                   \   /                    |
 *  __v__             | |         | |                     | |                   __v__
 * |_____|           _v_v_       _v_v_                   _v_v_   ________      |_____|
 *    |             |_____|     |_____|                 |_____|  __|_____|        |
 *  __v__                \       /                        |      /              __v__
 * |_____|                \     /                         |     /              |_____|
 *    |                    \   /                          |    /                  |
 *    |                     | |                           |   /                 __v__
 *  __v__                   | |                           |  /                 |_____|
 * |_____|                  | |                           | |                     |
 *    |                    _v_v_   ________              _v_v_                    |
 *  __v__                 |_____|  __|_____|            |_____|                 __v__
 * |_____|                  |         /                    |                   |_____|
 *    |                     |        /                     |                      |
 *  __v__                   |       /                      v                    __v__
 * |_____|                  |      /                                           |_____|
 *    |                     |     /                                               |
 *    |                     |    /                                              __v__
 *  __v__                   |   /                                              |_____|
 * |_____|                  |  /                                                  |
 *    |                     | |                                                 __v__
 *  __v__                  _v_v_                                               |_____|
 * |_____|                |_____|                                               / |
 *    |                      |                                                 /  v
 *  __v__                    |                                                v
 * |_____|                   v                                              inval
 *    | \
 *    v  \
 *        v
 *      inval
 */

metadata_t fp32_metadata_d[($clog2(VLEN/32)+1)*DELAY_SUM_FP32-1:0]; // combinational logic
metadata_t fp32_metadata_q[($clog2(VLEN/32)+1)*DELAY_SUM_FP32-1:0]; // register

always_comb begin
    fp32_metadata_d[0] = '0;
    fp32_metadata_d[0].instr_type   = instr_type_i;
    fp32_metadata_d[0].sew          = sew_i;
    fp32_metadata_d[0].data_vs1     = data_vs1_i; // we'll need this data at the last sum
    fp32_metadata_d[0].frm          = frm_i;
    // this could be done inside the generate block, but for the sake of
    // understandability will be defined appart for this first step
    fp32_metadata_d[0].status       = '0;
    fp32_metadata_d[0].all_inactive = |data_vm;
end

always_ff @(posedge clk_i, negedge rstn_i) begin // first register
    if (~rstn_i) begin
        fp32_metadata_q[0] <= 'h0;
    end else begin
        fp32_metadata_q[0] <= fp32_metadata_d[0];
    end
end

/* Diagram showing propagation of the status flags onto the metadata structures
 *     __    __    __      __    __    __      __    __    __
 *    |  |  |  |  |  |    |  |  |  |  |  |    |  |  |  |  |  |
 * -->|  |->|  |->|  |--->|  |->|  |->|  |--->|  |->|  |->|  |-->
 *    |__|  |__|  |__|  ^ |__|  |__|  |__|  ^ |__|  |__|  |__|  ^
 *                     /                   /                   /
 *    ----------------/   ----------------/   ----------------/
 */

generate
    for (i = 1; i < (($clog2(VLEN/32)+1)*DELAY_SUM_FP32); i++) begin : fp32_metadata
        localparam int stage   = i / DELAY_SUM_FP32 - 1;
        // the status will always be passed from the previous stage
        localparam int base32  = first_node_index(stage, 32);
        localparam int width32 = (VLEN/32) >> (stage+1);

        fpnew_pkg::status_t statusred;
        always_comb begin
            fp32_metadata_d[i] = '0;
            fp32_metadata_d[i].instr_type   = fp32_metadata_q[i-1].instr_type;
            fp32_metadata_d[i].sew          = fp32_metadata_q[i-1].sew;
            fp32_metadata_d[i].data_vs1     = fp32_metadata_q[i-1].data_vs1;
            fp32_metadata_d[i].frm          = fp32_metadata_q[i-1].frm;
            fp32_metadata_d[i].all_inactive = fp32_metadata_q[i-1].all_inactive;

            // we need also to treat the invalid vector propagation
            // on DELAY_SUM_FP32 multiple stages
            if ((i % DELAY_SUM_FP32) == 0) begin // if starting of stage, OR ladder propagation
                statusred = '0;
                for (int j = 0; j < width32; j++) begin
                    statusred.OF |= fp32statusvec[base32+j].OF;
                    statusred.UF |= fp32statusvec[base32+j].UF;
                    statusred.NX |= fp32statusvec[base32+j].NX;
                    statusred.NV |= fp32statusvec[base32+j].NV;
                end
                fp32_metadata_d[i].status.OF = fp32_metadata_q[i-1].status.OF || statusred.OF;
                fp32_metadata_d[i].status.UF = fp32_metadata_q[i-1].status.UF || statusred.UF;
                fp32_metadata_d[i].status.NX = fp32_metadata_q[i-1].status.NX || statusred.NX;
                fp32_metadata_d[i].status.NV = fp32_metadata_q[i-1].status.NV || statusred.NV;
            end else begin // if propagation cycle only maintain the value
                fp32_metadata_d[i].status.OF = fp32_metadata_d[i-1].status.OF;
                fp32_metadata_d[i].status.UF = fp32_metadata_d[i-1].status.UF;
                fp32_metadata_d[i].status.NX = fp32_metadata_d[i-1].status.NX;
                fp32_metadata_d[i].status.NV = fp32_metadata_d[i-1].status.NV;
            end
        end // always_comb

        always_ff @(posedge clk_i, negedge rstn_i) begin
            if (~rstn_i) begin
                fp32_metadata_q[i] <= 'h0;
            end else begin
                fp32_metadata_q[i] <= fp32_metadata_d[i];
            end
        end // always_ff
    end
endgenerate

// --------------------------------------------------------------------------------------

metadata_t fp64_metadata_d[($clog2(VLEN/64)+1)*DELAY_SUM_FP64-1:0]; // combinational logic
metadata_t fp64_metadata_q[($clog2(VLEN/64)+1)*DELAY_SUM_FP64-1:0]; // register

always_comb begin
    fp64_metadata_d[0] = '0;
    if (fp64widemetadata[DELAY_SUM_FP64-1].instr_type == VFWREDUSUM) begin
        fp64_metadata_d[0] = fp64widemetadata[DELAY_SUM_FP64-1];
        // the flags must be propagated
        for (int j = 0; j < ((VLEN/32)/2); j++) begin
            fp64_metadata_d[0].status.UF |= fp64widestatus[j].UF;
            fp64_metadata_d[0].status.NX |= fp64widestatus[j].NX;
            fp64_metadata_d[0].status.OF |= fp64widestatus[j].OF;
            fp64_metadata_d[0].status.NV |= fp64widestatus[j].NV;
        end
    end else begin
        fp64_metadata_d[0].instr_type   = instr_type_i;
        fp64_metadata_d[0].sew          = sew_i;
        fp64_metadata_d[0].data_vs1     = data_vs1_i;
        fp64_metadata_d[0].frm          = frm_i;
        fp64_metadata_d[0].status       = '0;
        fp64_metadata_d[0].all_inactive = |data_vm;
    end
end

always_ff @(posedge clk_i, negedge rstn_i) begin // first register
    if (~rstn_i) begin
        fp64_metadata_q[0] <= 'h0;
    end else begin
        fp64_metadata_q[0] <= fp64_metadata_d[0];
    end
end

generate
    for (i = 1; i < (($clog2(VLEN/64)+1)*DELAY_SUM_FP64); i++) begin : fp64_metadata
        localparam int stage   = i / DELAY_SUM_FP64 - 1;
        localparam int base64  = first_node_index(stage, 64);
        localparam int width64 = (VLEN/64) >> (stage+1);

        fpnew_pkg::status_t statusred;
        always_comb begin
            fp64_metadata_d[i] = '0;
            fp64_metadata_d[i].instr_type   = fp64_metadata_q[i-1].instr_type;
            fp64_metadata_d[i].sew          = fp64_metadata_q[i-1].sew;
            fp64_metadata_d[i].data_vs1     = fp64_metadata_q[i-1].data_vs1;
            fp64_metadata_d[i].frm          = fp64_metadata_q[i-1].frm;
            fp64_metadata_d[i].all_inactive = fp64_metadata_q[i-1].all_inactive;

            // we need also to treat the invalid vector propagation
            // on DELAY_SUM_FP64 multiple stages
            if ((i % DELAY_SUM_FP64) == 0) begin // if starting of stage, OR ladder propagation
                statusred = '0;
                for (int j = 0; j < width64; j++) begin
                    statusred.OF |= fp64statusvec[base64+j].OF;
                    statusred.UF |= fp64statusvec[base64+j].UF;
                    statusred.NX |= fp64statusvec[base64+j].NX;
                    statusred.NV |= fp64statusvec[base64+j].NV;
                end

                fp64_metadata_d[i].status.OF = fp64_metadata_q[i-1].status.OF || statusred.OF;
                fp64_metadata_d[i].status.UF = fp64_metadata_q[i-1].status.UF || statusred.UF;
                fp64_metadata_d[i].status.NX = fp64_metadata_q[i-1].status.NX || statusred.NX;
                fp64_metadata_d[i].status.NV = fp64_metadata_q[i-1].status.NV || statusred.NV;
            end else begin // if propagation cycle only maintain the value
                fp64_metadata_d[i].status.OF = fp64_metadata_q[i-1].status.OF;
                fp64_metadata_d[i].status.UF = fp64_metadata_q[i-1].status.UF;
                fp64_metadata_d[i].status.NX = fp64_metadata_q[i-1].status.NX;
                fp64_metadata_d[i].status.NV = fp64_metadata_q[i-1].status.NV;
            end
        end // always_comb

        always_ff @(posedge clk_i, negedge rstn_i) begin
            if (~rstn_i) begin
                fp64_metadata_q[i] <= 'h0;
            end else begin
                fp64_metadata_q[i] <= fp64_metadata_d[i];
            end
        end // always_ff
    end
endgenerate

// At the end of the metadata chain there must be an OR between the last
// status result and the accomulated ladder
fpnew_pkg::status_t fp32statusfinal;
fpnew_pkg::status_t fp64statusfinal;

always_comb begin
    fp32statusfinal = '0;
    fp64statusfinal = '0;

    fp32statusfinal.OF = fp32_metadata_q[($clog2(VLEN/32)+1)*DELAY_SUM_FP32-1].status.OF || fp32statusvec[VLEN/32-1].OF;
    fp32statusfinal.UF = fp32_metadata_q[($clog2(VLEN/32)+1)*DELAY_SUM_FP32-1].status.UF || fp32statusvec[VLEN/32-1].UF;
    fp32statusfinal.NX = fp32_metadata_q[($clog2(VLEN/32)+1)*DELAY_SUM_FP32-1].status.NX || fp32statusvec[VLEN/32-1].NX;
    fp32statusfinal.NV = fp32_metadata_q[($clog2(VLEN/32)+1)*DELAY_SUM_FP32-1].status.NV || fp32statusvec[VLEN/32-1].NV;

    fp64statusfinal.OF = fp64_metadata_q[($clog2(VLEN/64)+1)*DELAY_SUM_FP64-1].status.OF || fp64statusvec[VLEN/64-1].OF;
    fp64statusfinal.UF = fp64_metadata_q[($clog2(VLEN/64)+1)*DELAY_SUM_FP64-1].status.UF || fp64statusvec[VLEN/64-1].UF;
    fp64statusfinal.NX = fp64_metadata_q[($clog2(VLEN/64)+1)*DELAY_SUM_FP64-1].status.NX || fp64statusvec[VLEN/64-1].NX;
    fp64statusfinal.NV = fp64_metadata_q[($clog2(VLEN/64)+1)*DELAY_SUM_FP64-1].status.NV || fp64statusvec[VLEN/64-1].NV;
end

// multiplex the outputs from both trees via the sew asked by the simd_unit control
assign status_o = ((sew_to_out_i == SEW_64) || (instr_to_out_i == VFWREDUSUM)) ? fp64statusfinal : fp32statusfinal;

assign red_data_vd_o = ((sew_to_out_i==SEW_64) || (instr_to_out_i == VFWREDUSUM)) ?
                        {data_old_vd[VLEN-1:64], fp64_res} :
                        {data_old_vd[VLEN-1:32], fp32_res};

endmodule

