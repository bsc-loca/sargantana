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

// vfredo module (SIMD vector floating-point ordered reduction module)
module vfredoladder #(
    parameter DELAY_SUM_FP32 = 3,
    parameter DELAY_SUM_FP64 = 4
) (
    input  logic                    clk_i,           // Clock signal
    input  logic                    rstn_i,          // Reset signal
    input  instr_type_t             instr_type_i,    // Instruction type
    input  riscv_pkg::op_frm_fp_t   frm_i,           // Input instruction rounding mode
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
    output fpnew_pkg::status_t      status_o         // fp status flags as OR ladder of the sequentialized adders 
);

typedef struct packed {
    sew_t                   sew;
    bus_simd_t              data_vs1;
    bus_simd_t              data_vs2;
    fpnew_pkg::status_t     status;
    instr_type_t            instr_type;
    riscv_pkg::op_frm_fp_t  frm;
    bus_mask_t              data_vm;
} metadata_t;

// fp32 signals
bus32_t             fp32signals   [(2*(VLEN/32)) -1:0];
bus32_t             fp32_res;
metadata_t          fp32_metadata [(VLEN/32)-1:0][DELAY_SUM_FP32 -1:0];
fpnew_pkg::status_t fp32statusvec [(VLEN/32)-1:0];

// fp64 signals
bus64_t     fp64signals           [(2*(VLEN/64)) -1:0];
bus64_t     fp64_res;
metadata_t  fp64_metadata         [(VLEN/64)-1:0][DELAY_SUM_FP64 -1:0];
fpnew_pkg::status_t fp64statusvec [(VLEN/64)-1:0];


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

generate
    for (genvar j = 0; j < (VLEN/32); j++) begin : FP32_GEN_SIGNALS
        assign fp32signals[j] = data_vm[j] ? data_vs2_i[(32*j) +: 32] : 32'h0000_0000;
    end
    for (genvar j = 0; j < (VLEN/64); j++) begin : FP64_GEN_SIGNALS
        assign fp64signals[j] = data_vm[j] ? data_vs2_i[(64*j) +: 64] : 64'h0000_0000_0000_0000;
    end
endgenerate

typedef logic [3:0]W4_logic;
typedef logic [2:0]W3_logic;
typedef logic [1:0]W2_logic;

// ------------------------ FP32 ------------------------

bus32_t fp32_srca_first;
bus32_t fp32_srcb_first;

assign fp32_srcb_first = data_vm[0] ? data_vs2_i[31:0] : 32'h0000_0000;
assign fp32_srca_first = data_vs1_i[31:0];

assign fp32_res = ((|(fp32_metadata[(VLEN/32)-1][DELAY_SUM_FP32-1].data_vm)) == 1'b0) ? fp32_metadata[(VLEN/32)-1][DELAY_SUM_FP32-1].data_vs1[31:0] :
                  fp32signals[(2*(VLEN/32)) -1];

logic [2:0][63:0] fp32_fpnew_operands_first;
always_comb begin
    fp32_fpnew_operands_first[1] = {32'h0000_0000, fp32_srca_first};
    fp32_fpnew_operands_first[2] = {32'h0000_0000, fp32_srcb_first};
    fp32_fpnew_operands_first[0] = 64'h0000_0000_0000_0000;
end

bus64_t fpnewfirst_result;
assign fp32signals[VLEN/32] = fpnewfirst_result[31:0];

fpnew_top #(
   .Features       ( SARG_ADDMUL_RV64D ),
   .Implementation ( SARG_ADDMUL_ONLY  )
) f32_fpnew_first (
   .clk_i          ( clk_i ),
   .rst_ni         ( rstn_i ),
   .flush_i        ( '0 ),
   // Input
   .operands_i     ( fp32_fpnew_operands_first ),
   .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(frm_i)) ),
   .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
   .op_mod_i       ( '0 ),
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
   .result_o       ( fpnewfirst_result ),
   .status_o       ( fp32statusvec[0] ),
   .tag_o          (  ),
   .out_valid_o    (  ),
   .busy_o         (  )
);

generate
for (genvar i = 1; i < (VLEN/32); i++) begin : FP32_GEN_FPNEW
    bus32_t fp32_srca;
    bus32_t fp32_srcb;
    assign fp32_srca = fp32_metadata[i-1][DELAY_SUM_FP32-1].data_vm[i] ?
                       fp32_metadata[i-1][DELAY_SUM_FP32-1].data_vs2[(32*i) +: 32] :
                       32'h0000_0000;
    assign fp32_srcb = fp32signals[(VLEN/32)-1+i];

    logic [2:0][63:0] fp32_fpnew_operands;
    always_comb begin
        fp32_fpnew_operands[1] = {32'h0000_0000, fp32_srca};
        fp32_fpnew_operands[2] = {32'h0000_0000, fp32_srcb};
        fp32_fpnew_operands[0] = 64'h0000_0000_0000_0000;
    end

    bus64_t fpnew_result;
    assign fp32signals[(VLEN/32)+i] = fpnew_result[31:0];

    fpnew_top #(
       .Features       ( SARG_ADDMUL_RV64D ),
       .Implementation ( SARG_ADDMUL_ONLY  )
    ) fp32_fpnew (
       .clk_i          ( clk_i ),
       .rst_ni         ( rstn_i ),
       .flush_i        ( '0 ),
       // Input
       .operands_i     ( fp32_fpnew_operands ),
       .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(fp32_metadata[i-1][DELAY_SUM_FP32-1].frm)) ),
       .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
       .op_mod_i       ( '0 ),
       .src_fmt_i      ( fpnew_pkg::fp_format_e'(W3_logic'(FP32)) ),
       .dst_fmt_i      ( fpnew_pkg::fp_format_e'(W3_logic'(FP32)) ),
       .int_fmt_i      ( fpnew_pkg::int_format_e'(W2_logic'(INT32))),
       .simd_mask_i    ( '0 ),
       .vectorial_op_i ( '0 ),
       .tag_i          ( '0 ),
       .in_valid_i     ( 1'b1 ),
       .out_ready_i    ( 1'b1 ),
       // Outputs
       .in_ready_o     (  ),
       .result_o       ( fpnew_result ),
       .status_o       ( fp32statusvec[i] ),
       .tag_o          (  ),
       .out_valid_o    (  ),
       .busy_o         (  )
    );
end // for
endgenerate

/*
 *
 * As we'll need to have both the vs1 scalar, as well as any addtitional
 * relevant data for the very same instruction a metadata register chain
 * will be needed, similary to what done in the module vfredtree.
 * In this design, however has opted for a matrix naming.
 *
 *   [0][0] [0][1] [0][2]   [1][0] [1][1] [1][2]
 *     __     __     __       __     __     __            __     __     __
 *    |  |   |  |   |  |     |  |   |  |   |  |      vs1 |  |   |  |   |  |
 * -->|  |-->|  |-->|  |---->|  |-->|  |-->|  |-- ... -->|  |-->|  |-->|  |--> sew
 *    |__|   |__|   |__|     |__|   |__|   |__|          |__|   |__|   |__|
 *   \__________________/
 *      DELAY_SUM_FP32
 */

generate
for (genvar i = 0; i < (VLEN/32); i++) begin : FP32_GEN_METADATA_I
    for (genvar j = 0; j < DELAY_SUM_FP32; j++) begin : FP32_GEN_METADATA_J
        always_ff @(posedge clk_i, negedge rstn_i) begin
            if (~rstn_i) begin
                fp32_metadata[i][j] <= '0;
            end else begin
                if (j == 0) begin
                    if (i == 0) begin // if it's the first element
                        fp32_metadata[0][0].sew <= sew_i;
                        fp32_metadata[0][0].data_vs1 <= data_vs1_i;
                        fp32_metadata[0][0].data_vs2 <= data_vs2_i;
                        fp32_metadata[0][0].instr_type <= instr_type_i; // all flags initially to '0
                        fp32_metadata[0][0].frm <= frm_i;
                        fp32_metadata[0][0].status <= '0;
                        fp32_metadata[0][0].data_vm <= data_vm;
                    end else begin // first element of each stage
                        fp32_metadata[i][j].sew <= fp32_metadata[i-1][DELAY_SUM_FP32-1].sew;
                        fp32_metadata[i][j].data_vs1 <= fp32_metadata[i-1][DELAY_SUM_FP32-1].data_vs1;
                        fp32_metadata[i][j].data_vs2 <= fp32_metadata[i-1][DELAY_SUM_FP32-1].data_vs2;
                        fp32_metadata[i][j].instr_type <= fp32_metadata[i-1][DELAY_SUM_FP32-1].instr_type;
                        fp32_metadata[i][j].frm <= fp32_metadata[i-1][DELAY_SUM_FP32-1].frm;
                        fp32_metadata[i][j].data_vm <= fp32_metadata[i-1][DELAY_SUM_FP32-1].data_vm;

                        fp32_metadata[i][j].status.OF <= fp32_metadata[i-1][DELAY_SUM_FP32-1].status.OF || fp32statusvec[i-1].OF;
                        fp32_metadata[i][j].status.UF <= fp32_metadata[i-1][DELAY_SUM_FP32-1].status.UF || fp32statusvec[i-1].UF;
                        fp32_metadata[i][j].status.NX <= fp32_metadata[i-1][DELAY_SUM_FP32-1].status.NX || fp32statusvec[i-1].NX;
                        fp32_metadata[i][j].status.NV <= fp32_metadata[i-1][DELAY_SUM_FP32-1].status.NV || fp32statusvec[i-1].NV;
                        fp32_metadata[i][j].status.DZ <= 1'b0;
                    end
                end else begin // chaining registers
                    fp32_metadata[i][j] <= fp32_metadata[i][j-1];
                end
            end
        end
    end
end
endgenerate

// ---------------------- WIDENING ----------------------

localparam ADDS_WIDENING = (VLEN/32) - (VLEN/64);

bus64_t fp64widesignals     [ADDS_WIDENING-1:0];
status_t fp64widestatusvec  [ADDS_WIDENING-1:0];
bus64_t fp64wide_srca_first;
bus64_t fp64wide_srcb_first;

bus64_t fp64wide_srcb_unmasked;

fp32_to_fp64 fp32_to_fp64_inst_srcb_unmasked (
    .fp32_i(data_vs2_i[(32*((0)+1)) +: 32]),
    .fp64_o(fp64wide_srcb_unmasked)
);


always_comb begin
fp64wide_srca_first = data_vs1_i[63:0];
fp64wide_srcb_first = data_vm[0] ? fp64wide_srcb_unmasked : 64'h0000_0000_0000_0000;
end

logic [2:0][63:0] fp64wide_fpnew_operands_first;
always_comb begin
    fp64wide_fpnew_operands_first[1] = fp64wide_srca_first;
    fp64wide_fpnew_operands_first[2] = fp64wide_srcb_first;
    fp64wide_fpnew_operands_first[0] = 64'h0000_0000_0000_0000;
end

bus64_t fp64wide_fpnew_result_first;
assign fp64widesignals[0] = fp64wide_fpnew_result_first;

fpnew_top #(
   .Features       ( SARG_ADDMUL_RV64D ),
   .Implementation ( SARG_ADDMUL_ONLY  )
) fp64wide_fpnew_first (
   .clk_i          ( clk_i ),
   .rst_ni         ( rstn_i ),
   .flush_i        ( '0 ),
   // Input
   .operands_i     ( fp64wide_fpnew_operands_first ),
   .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(frm_i)) ),
   .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
   .op_mod_i       ( '0 ),
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
   .result_o       ( fp64wide_fpnew_result_first ),
   .status_o       ( fp64widestatusvec[0] ),
   .tag_o          (  ),
   .out_valid_o    (  ),
   .busy_o         (  )
);

generate
for (genvar i = 1; i < ADDS_WIDENING; i++) begin : FP64WIDE_GEN_FPNEW
    bus64_t fp64wide_srca, fp64wide_srcb;

    bus64_t fp64_wide_srca_unmasked;

    fp32_to_fp64 fp32_to_fp64_inst (
        .fp32_i(fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vs2[(32*(i)) +: 32]),
        .fp64_o(fp64_wide_srca_unmasked)
    );

    assign fp64wide_srca = fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vm[i] ?
                           fp64_wide_srca_unmasked :
                           64'h0000_0000_0000_0000;
    assign fp64wide_srcb = fp64widesignals[i-1];

    logic [2:0][63:0] fp64wide_fpnew_operands;
    always_comb begin
        fp64wide_fpnew_operands[1] = fp64wide_srca;
        fp64wide_fpnew_operands[2] = fp64wide_srcb;
        fp64wide_fpnew_operands[0] = 64'h0000_0000_0000_0000;
    end

    bus64_t fp64wide_fpnew_result;
    assign fp64widesignals[i] = fp64wide_fpnew_result;

    fpnew_top #(
       .Features       ( SARG_ADDMUL_RV64D ),
       .Implementation ( SARG_ADDMUL_ONLY  )
    ) fp64wide_fpnew (
       .clk_i          ( clk_i ),
       .rst_ni         ( rstn_i ),
       .flush_i        ( '0 ),
       // Input
       .operands_i     ( fp64wide_fpnew_operands ),
       .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(fp64_metadata[i-1][DELAY_SUM_FP64-1].frm)) ),
       .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
       .op_mod_i       ( '0 ),
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
       .result_o       ( fp64wide_fpnew_result ),
       .status_o       ( fp64widestatusvec[i] ),
       .tag_o          (  ),
       .out_valid_o    (  ),
       .busy_o         (  )
    );
end // for
endgenerate

metadata_t fp64wide_metadata [ADDS_WIDENING-1:0][DELAY_SUM_FP64-1:0];

generate
for (genvar i = 0; i < ADDS_WIDENING; i++) begin : FP64WIDE_GEN_METADATA_I
    for (genvar j = 0; j < DELAY_SUM_FP64; j++) begin : FP64WIDE_GEN_METADATA_J
        always_ff @(posedge clk_i, negedge rstn_i) begin
            if (~rstn_i) begin
                fp64wide_metadata[i][j] <= '0;
            end else begin
                if (j == 0) begin
                    if (i == 0) begin // if it's the first element
                        fp64wide_metadata[0][0].sew <= (instr_type_i == VFWREDOSUM) ? SEW_64 : sew_i;
                        fp64wide_metadata[0][0].data_vs1 <= data_vs1_i;
                        fp64wide_metadata[0][0].data_vs2 <= data_vs2_i;
                        fp64wide_metadata[0][0].status <= '0;
                        fp64wide_metadata[0][0].frm <= frm_i;
                        fp64wide_metadata[0][0].instr_type <= instr_type_i;
                        fp64wide_metadata[0][0].data_vm <= data_vm;
                    end else begin // first element of each stage
                        fp64wide_metadata[i][j].sew <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].sew;
                        fp64wide_metadata[i][j].data_vs1 <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].data_vs1;
                        fp64wide_metadata[i][j].data_vs2 <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].data_vs2;
                        fp64wide_metadata[i][j].instr_type <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].instr_type;
                        fp64wide_metadata[i][j].frm <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].frm;
                        fp64wide_metadata[i][j].data_vm <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].data_vm;

                        fp64wide_metadata[i][j].status.OF <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].status.OF || fp64widestatusvec[i-1].OF;
                        fp64wide_metadata[i][j].status.UF <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].status.UF || fp64widestatusvec[i-1].UF;
                        fp64wide_metadata[i][j].status.NX <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].status.NX || fp64widestatusvec[i-1].NX;
                        fp64wide_metadata[i][j].status.NV <= fp64wide_metadata[i-1][DELAY_SUM_FP64-1].status.NV || fp64widestatusvec[i-1].NV;
                        fp64wide_metadata[i][j].status.DZ <= 1'b0;
                    end
                end else begin // chaining registers
                    fp64wide_metadata[i][j] <= fp64wide_metadata[i][j-1];
                end
            end
        end
    end
end
endgenerate


// ------------------------ FP64 ------------------------

bus64_t fp64_srca_first;
bus64_t fp64_srcb_first;

bus64_t fp64_srcb_vfwredosum;

bus_mask_t vm_debug;
bus_simd_t vs2_debug;

assign vm_debug = fp64wide_metadata[ADDS_WIDENING-1][DELAY_SUM_FP64-1].data_vm[(VLEN/32)-1];
assign vs2_debug = fp64wide_metadata[ADDS_WIDENING-1][DELAY_SUM_FP64-1].data_vs2[(VLEN-1) -: 32];

fp32_to_fp64 fp32_to_fp64_inst (
    .fp32_i((fp64wide_metadata[ADDS_WIDENING-1][DELAY_SUM_FP64-1].data_vm[(ADDS_WIDENING)] == 1'b1) ?
            fp64wide_metadata[ADDS_WIDENING-1][DELAY_SUM_FP64-1].data_vs2[(32*(ADDS_WIDENING)) +: 32] :
            32'h00000000),
    .fp64_o(fp64_srcb_vfwredosum)
);

always_comb begin
fp64_srca_first = (fp64wide_metadata[ADDS_WIDENING-1][DELAY_SUM_FP64-1].instr_type == VFWREDOSUM) ? 
                  fp64widesignals[ADDS_WIDENING-1] :
                  (data_vs1_i[63:0]);
fp64_srcb_first = (fp64wide_metadata[ADDS_WIDENING-1][DELAY_SUM_FP64-1].instr_type == VFWREDOSUM) ?
                  fp64_srcb_vfwredosum :
                  (data_vm[0] ? fp64signals[0] : 64'h0000_0000_0000_0000);

fp64_res        = ((|fp64_metadata[(VLEN/64)-1][DELAY_SUM_FP64-1].data_vm) == 1'b0) ? fp64_metadata[(VLEN/64)-1][DELAY_SUM_FP64-1].data_vs1[63:0] :
                  fp64signals[2*(VLEN/64) -1];
end

logic [2:0][63:0] fp64_fpnew_operands_first;
always_comb begin
    fp64_fpnew_operands_first[1] = fp64_srca_first;
    fp64_fpnew_operands_first[2] = fp64_srcb_first;
    fp64_fpnew_operands_first[0] = 64'h0000_0000_0000_0000;
end

bus64_t fp64_fpnew_result_first;
assign fp64signals[VLEN/64] = fp64_fpnew_result_first;

fpnew_top #(
   .Features       ( SARG_ADDMUL_RV64D ),
   .Implementation ( SARG_ADDMUL_ONLY  )
) fp64_fpnew_first (
   .clk_i          ( clk_i ),
   .rst_ni         ( rstn_i ),
   .flush_i        ( '0 ),
   // Input
   .operands_i     ( fp64_fpnew_operands_first ),
   .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(frm_i)) ),
   .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
   .op_mod_i       ( '0 ),
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
   .result_o       ( fp64_fpnew_result_first ),
   .status_o       ( fp64statusvec[0] ),
   .tag_o          (  ),
   .out_valid_o    (  ),
   .busy_o         (  )
);

generate
for (genvar i = 1; i < (VLEN/64); i++) begin : FP64_GEN_FPNEW
    bus64_t fp64_srca;
    bus64_t fp64_srcb;

    bus64_t fp64_srca_unmasked;

    fp32_to_fp64 fp32_to_fp64_inst (
        .fp32_i(fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vs2[(32*(ADDS_WIDENING+i)) +: 32]),
        .fp64_o(fp64_srca_unmasked)
    );

    assign fp64_srca = (fp64_metadata[i-1][DELAY_SUM_FP64-1].instr_type == VFWREDOSUM) ? fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vm[VLEN/64+i-1] ?
                       fp64_srca_unmasked : 64'h0000_0000_0000_0000 :
                       fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vm[i] ?
                       fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vs2[(64*i) +: 64] : 64'h0000_0000_0000_0000;
    assign fp64_srcb = fp64signals[(VLEN/64)-1+i];

    logic [2:0][63:0] fp64_fpnew_operands;
    always_comb begin
        fp64_fpnew_operands[1] = fp64_srca;
        fp64_fpnew_operands[2] = fp64_srcb;
        fp64_fpnew_operands[0] = 64'h0000_0000_0000_0000;
    end

    bus64_t fp64_fpnew_result;
    assign fp64signals[(VLEN/64)+i] = fp64_fpnew_result;

    fpnew_top #(
       .Features       ( SARG_ADDMUL_RV64D ),
       .Implementation ( SARG_ADDMUL_ONLY  )
    ) fp64_fpnew (
       .clk_i          ( clk_i ),
       .rst_ni         ( rstn_i ),
       .flush_i        ( '0 ),
       // Input
       .operands_i     ( fp64_fpnew_operands ),
       .rnd_mode_i     ( fpnew_pkg::roundmode_e'(riscv_pkg::op_frm_fp_t'(fp64_metadata[i-1][DELAY_SUM_FP64-1].frm)) ),
       .op_i           ( fpnew_pkg::operation_e'(W4_logic'(fpnew_pkg::ADD)) ),
       .op_mod_i       ( '0 ),
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
       .result_o       ( fp64_fpnew_result ),
       .status_o       ( fp64statusvec[i] ),
       .tag_o          (  ),
       .out_valid_o    (  ),
       .busy_o         (  )
    );
end // for
endgenerate

generate
for (genvar i = 0; i < (VLEN/64); i++) begin : FP64_GEN_METADATA_I
    for (genvar j = 0; j < DELAY_SUM_FP64; j++) begin : FP64_GEN_METADATA_J
        always_ff @(posedge clk_i, negedge rstn_i) begin
            if (~rstn_i) begin
                fp64_metadata[i][j] <= '0;
            end else begin
                if (j == 0) begin
                    if (i == 0) begin // if it's the first element
                        if (fp64wide_metadata[ADDS_WIDENING-1][DELAY_SUM_FP64-1].instr_type == VFWREDOSUM) begin
                            fp64_metadata[0][0] <= fp64wide_metadata[ADDS_WIDENING-1][DELAY_SUM_FP64-1];
                        end else begin
                            fp64_metadata[0][0].sew <= sew_i;
                            fp64_metadata[0][0].data_vs1 <= data_vs1_i;
                            fp64_metadata[0][0].data_vs2 <= data_vs2_i;
                            fp64_metadata[0][0].status <= '0;
                            fp64_metadata[0][0].frm <= frm_i;
                            fp64_metadata[0][0].instr_type <= instr_type_i;
                            fp64_metadata[0][0].data_vm <= data_vm;
                        end
                    end else begin // first element of each stage
                        fp64_metadata[i][j].sew <= fp64_metadata[i-1][DELAY_SUM_FP64-1].sew;
                        fp64_metadata[i][j].data_vs1 <= fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vs1;
                        fp64_metadata[i][j].data_vs2 <= fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vs2;
                        fp64_metadata[i][j].instr_type <= fp64_metadata[i-1][DELAY_SUM_FP64-1].instr_type;
                        fp64_metadata[i][j].frm <= fp64_metadata[i-1][DELAY_SUM_FP64-1].frm;
                        fp64_metadata[i][j].data_vm <= fp64_metadata[i-1][DELAY_SUM_FP64-1].data_vm;

                        fp64_metadata[i][j].status.OF <= fp64_metadata[i-1][DELAY_SUM_FP64-1].status.OF || fp64statusvec[i-1].OF;
                        fp64_metadata[i][j].status.UF <= fp64_metadata[i-1][DELAY_SUM_FP64-1].status.UF || fp64statusvec[i-1].UF;
                        fp64_metadata[i][j].status.NX <= fp64_metadata[i-1][DELAY_SUM_FP64-1].status.NX || fp64statusvec[i-1].NX;
                        fp64_metadata[i][j].status.NV <= fp64_metadata[i-1][DELAY_SUM_FP64-1].status.NV || fp64statusvec[i-1].NV;
                        fp64_metadata[i][j].status.DZ <= 1'b0;
                    end
                end else begin // chaining registers
                    fp64_metadata[i][j] <= fp64_metadata[i][j-1];
                end
            end
        end
    end
end
endgenerate

// ------------------------------------------------------

fpnew_pkg::status_t fp32statusfinal;
fpnew_pkg::status_t fp64statusfinal;

always_comb begin
    fp32statusfinal = '0;
    fp64statusfinal = '0;

    fp32statusfinal.OF = fp32_metadata[(VLEN/32)-1][DELAY_SUM_FP32-1].status.OF || fp32statusvec[VLEN/32-1].OF;
    fp32statusfinal.UF = fp32_metadata[(VLEN/32)-1][DELAY_SUM_FP32-1].status.UF || fp32statusvec[VLEN/32-1].UF;
    fp32statusfinal.NX = fp32_metadata[(VLEN/32)-1][DELAY_SUM_FP32-1].status.NX || fp32statusvec[VLEN/32-1].NX;
    fp32statusfinal.NV = fp32_metadata[(VLEN/32)-1][DELAY_SUM_FP32-1].status.NV || fp32statusvec[VLEN/32-1].NV;

    fp64statusfinal.OF = fp64_metadata[(VLEN/64)-1][DELAY_SUM_FP64-1].status.OF || fp64statusvec[VLEN/64-1].OF;
    fp64statusfinal.UF = fp64_metadata[(VLEN/64)-1][DELAY_SUM_FP64-1].status.UF || fp64statusvec[VLEN/64-1].UF;
    fp64statusfinal.NX = fp64_metadata[(VLEN/64)-1][DELAY_SUM_FP64-1].status.NX || fp64statusvec[VLEN/64-1].NX;
    fp64statusfinal.NV = fp64_metadata[(VLEN/64)-1][DELAY_SUM_FP64-1].status.NV || fp64statusvec[VLEN/64-1].NV;
end


assign status_o = ((sew_to_out_i==SEW_64) || (instr_to_out_i==VFWREDOSUM)) ? fp64statusfinal : fp32statusfinal;

assign red_data_vd_o = ((sew_to_out_i==SEW_64) || (instr_to_out_i==VFWREDOSUM)) ? 
                        {data_old_vd[VLEN-1:64], fp64_res} : 
                        {data_old_vd[VLEN-1:32], fp32_res};

endmodule

