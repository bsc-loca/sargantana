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
import fpnew_pkg::*; 
import riscv_pkg::*;

// Vector FPU wrapper for FPNEW
module vfpu_drac_wrapper #(
    parameter fpu_features_t       Features = SARG_RV64DV,
    parameter fpu_implementation_t Implementation = SARG_SIMD_INIT,
    parameter int unsigned NumLanes = fpnew_pkg::max_num_lanes(Features.Width, Features.FpFmtMask, Features.EnableVectors),
    parameter type         MaskType = logic [NumLanes-1:0],
    // Do not change - Intel Spyglass tells unused
    localparam int unsigned WIDTH        = Features.Width,
    localparam int unsigned NUM_OPERANDS = 3
) (
    input  logic                    clk_i,              // Input clock
    input  logic                    rstn_i,             // Input reset
    input  logic                    flush_i,            // do a pipeline flush of CVFPU and vfp pending queue 
    // inputs
    input  rr_exe_simd_instr_t      instruction_i,      // input instruction
    input  logic                    out_ready_i,
    // outputs
    output rr_exe_simd_instr_t      instruction_o,      // output instruction, already formatted
    output bus_simd_t               data_vd_o,
    output logic                    stall_o,
    output fpnew_pkg::status_t      status_o
);

/* Main floting-point parallel FPNEW unit
 *
 * The FPNEW floating-point unit needs to be passed all the operands and
 * operation type and selector bit depending on the incoming instruction
 * type. This will be done combinationally in the instruction type "case".
 *
 * FP Operations
 *
 * Enumerator    Modifier    Operation
 * ------------------------------------------------------------------------------------
 * FMADD         0           Fused multiply-add ((op[0] * op[1]) + op[2])
 * FMADD         1           Fused multiply-subtract ((op[0] * op[1]) - op[2])
 * FNMSUB        0           Negated fused multiply-subtract (-(op[0] * op[1]) + op[2])
 * FNMSUB        1           Negated fused multiply-add (-(op[0] * op[1]) - op[2])
 * ADD           0           Addition (op[1] + op[2])
 * ADD           1           Subtraction (op[1] - op[2])
 * MUL           0           Multiplication (op[0] * op[1])
 * DIV           0           Division (op[0] / op[1])
 * SQRT          0           Square root
 * SGNJ          0           Sign injection, operation encoded in rounding mode
 *                              RNE: op[0] with sign(op[1])
 *                              RTZ: op[0] with ~sign(op[1])
 *                              RDN: op[0] with sign(op[0]) ^ sign(op[1])
 *                              RUP: op[0] (passthrough)
 * SGNJ          1           As above, but result is sign-extended instead of NaN-Boxed
 * MINMAX        0           Minimum / maximum, operation encoded in rounding mode
 *                              RNE: minimumNumber(op[0], op[1])
 *                              RTZ: maximumNumber(op[0], op[1])
 * CMP           0           Comparison, operation encoded in rounding mode
 *                              RNE: op[0] <= op[1]
 *                              RTZ: op[0] < op[1]
 *                              RDN: op[0] == op[1]
 * CLASSIFY      0           Classification, returns RISC-V classification block
 * F2F           0           FP to FP cast, formats given by src_fmt_i and dst_fmt_i
 * F2I           0           FP to signed integer cast, formats given by src_fmt_i and int_fmt_i
 * F2I           1           FP to unsigned integer cast, formats given by src_fmt_i and int_fmt_i
 * I2F           0           Signed integer to FP cast, formats given by int_fmt_i and dst_fmt_i
 * I2F           1           Unsigned integer to FP cast, formats given by int_fmt_i and dst_fmt_i
 * CPKAB         0           Cast-and-pack op[0] and op[1] to entries 0,1 of vector op[2]
 * CPKAB         1           Cast-and-pack op[0] and op[1] to entries 2,3 of vector op[2]
 * CPKCD         0           Cast-and-pack op[0] and op[1] to entries 4,5 of vector op[2]
 * CPKCD         1           Cast-and-pack op[0] and op[1] to entries 6,7 of vector op[2]
 */

logic                   [2:0][SARG_RV64DV.Width-1:0] vector_operands;
fpnew_pkg::operation_e  vector_operation; // to be setted in decode always_comb
logic                   vector_operation_modifier;
fpnew_pkg::fp_format_e  vector_src_format;
fpnew_pkg::fp_format_e  vector_dst_format;
bus_simd_t              widened_operands [1:0]; // the order will be thhe next {data_vs2, data_vs1}

instr_type_t    instr_type  ;
logic           instr_valid ;
op_frm_fp_t     frm         ;
sew_t           sew         ;
bus_simd_t      data_vs1    ;
bus_simd_t      data_vs2    ;
bus_simd_t      rs1_repl    ;
bus64_t         data_rs1    ; // scalar operand
bus_simd_t      data_old_vd ;
MaskType        data_vm     ;
logic           is_opvf     ; // uses the scalar operand

assign instr_type      = instruction_i.instr.instr_type                                                     ;
assign instr_valid     = instruction_i.instr.valid & drac_pkg::is_vfpnew(instruction_i.instr.instr_type)    ; 
assign frm             = instruction_i.instr.frm                                                            ; 
assign sew             = instruction_i.instr.sew                                                            ;
assign is_opvf         = instruction_i.instr.is_opvf                                                        ;
assign data_rs1        = instruction_i.data_rs1                                                             ;
assign data_old_vd     = instruction_i.data_old_vd                                                          ;
assign data_vm         = {NumLanes{1'b1}}                                                                   ;
assign data_vs1        = is_opvf ? rs1_repl : instruction_i.data_vs1                                        ;
assign data_vs2        = instruction_i.data_vs2                                                             ;

assign rs1_repl = (sew == SEW_64) ? {(VLEN/64){data_rs1}} : {(VLEN/32){data_rs1[31:0]}};

always_comb begin
    vector_operands             = '0;
    vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
    vector_operation_modifier   = '0;
    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);

    for (int i = 0; i < (VLEN/64); i++) begin
        widened_operands[0][i*64 +: 64] = fp32_to_fp64(data_vs1[i*32 +: 32]);
        widened_operands[1][i*64 +: 64] = fp32_to_fp64(data_vs2[i*32 +: 32]);
    end

    case (instr_type)
        // Vector Single-Width Floating-Point Add/Subtract Instructions
        VFADD: begin
            vector_operands[0]          = '0; // ignored in ADD mode 
            vector_operands[1]          = data_vs1;
            vector_operands[2]          = data_vs2;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b0;
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFSUB: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = data_vs2; // VS2 - VS1 or VS2 - f (if vfsub.vf)
            vector_operands[2]          = data_vs1;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b1; // SUB mode
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFRSUB: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = data_vs1; // reverse order (f - VS2)
            vector_operands[2]          = data_vs2;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b1;
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end

        // Vector Widening Floating-Point Add/Subtract Instructions
        VFWADD: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = widened_operands[1]; // data_vs2
            vector_operands[2]          = widened_operands[0]; // data_vs1
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b0;
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end
        VFWSUB: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = widened_operands[1]; // vs2 - vs1, vs2 - f
            vector_operands[2]          = widened_operands[0];
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b1;
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end
        VFWADDW: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = widened_operands[0]; // data_vs2 to be widened
            vector_operands[2]          = data_vs2; // data_vs1 already on widened format
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b0; // ADD operation
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end
        VFWSUBW: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = data_vs2;
            vector_operands[2]          = widened_operands[0]; // narrow_to_wide(vs2) - vs1
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b1;
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end

        // Vector Single-Width Floating-Point Multiply/Divide Instructions
        VFMUL: begin
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_vs2;
            vector_operands[2]          = '0;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::MUL);
            vector_operation_modifier   = 1'b0; // mul operation
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFDIV: begin
            // vd[i] = vs2[i] / vs1[i]
            vector_operands[0]          = data_vs2;
            vector_operands[1]          = data_vs1;
            vector_operands[2]          = '0;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::DIV);
            vector_operation_modifier   = 1'b0; // div operation
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFRDIV: begin // scalar-vector, vd[i] = f[rs1]/vs2[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_vs2;
            vector_operands[2]          = '0;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::DIV);
            vector_operation_modifier   = 1'b0; // div operation
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end

        // Vector Widening Floating-Point Multiply
        VFWMUL: begin
            // vd[i] = vs1[i] * vs2[i]
            vector_operands[0]          = widened_operands[0];
            vector_operands[1]          = widened_operands[1];
            vector_operands[2]          = '0;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::MUL);
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end

        // Vector Single-Width Floating-Point Fused Multiply-Add Instructions
        VFMACC: begin
            // vd[i] = +(vs1[i] * vs2[i]) + vd[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_vs2;
            vector_operands[2]          = data_old_vd;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FMADD);
            vector_operation_modifier   = 1'b0; // (op[0] * op[1]) + op[2]
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFNMACC: begin
            // vd[i] = -(vs1[i] * vs2[i]) - vd[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_vs2;
            vector_operands[2]          = data_old_vd;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FNMSUB);
            vector_operation_modifier   = 1'b1; // -(op[0] * op[1]) + op[2]
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFMSAC: begin
            // vd[i] = +(vs1[i] * vs2[i]) - vd[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_vs2;
            vector_operands[2]          = data_old_vd;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FMADD);
            vector_operation_modifier   = 1'b1; // (op[0] * op[1]) - op[2]
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFNMSAC: begin
            // -(vs1[i] * vs2[i]) + vd[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_vs2;
            vector_operands[2]          = data_old_vd;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FNMSUB);
            vector_operation_modifier   = 1'b0; // -(op[0] * op[1]) + op[2]
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFMADD: begin
            // +(vs1[i] * vd[i]) + vs2[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_old_vd;
            vector_operands[2]          = data_vs2;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FMADD);
            vector_operation_modifier   = 1'b0; // (op[0] * op[1]) + op[2]
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFNMADD: begin
            // -(vs1[i] * vd[i]) - vs2[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_old_vd;
            vector_operands[2]          = data_vs2;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FNMSUB);
            vector_operation_modifier   = 1'b1; // -(op[0] * op[1]) - op[2]
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFMSUB: begin
            // vd[i] = +(vs1[i] * vd[i]) - vs2[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_old_vd;
            vector_operands[2]          = data_vs2;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FMADD);
            vector_operation_modifier   = 1'b1; // (op[0] * op[1]) - op[2]
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFNMSUB: begin
            // vd[i] = -(vs1[i] * vd[i]) + vs2[i]
            vector_operands[0]          = data_vs1;
            vector_operands[1]          = data_old_vd;
            vector_operands[2]          = data_vs2;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FNMSUB);
            vector_operation_modifier   = 1'b0; // -(op[0] * op[1]) + op[2]
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end

        // Vector Widening Floating-Point Fused Multiply-Add Instructions
        VFWMACC: begin
            // vd[i] = +(vs1[i] * vs2[i]) + vd[i]
            vector_operands[0]          = widened_operands[0];
            vector_operands[1]          = widened_operands[1];
            vector_operands[2]          = data_old_vd;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FMADD);
            vector_operation_modifier   = 1'b0; // (op[0] * op[1]) + op[2]
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end
        VFWNMACC: begin
            // vd[i] = -(vs1[i] * vs2[i]) - vd[i]
            vector_operands[0]          = widened_operands[0];
            vector_operands[1]          = widened_operands[1];
            vector_operands[2]          = data_old_vd;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FNMSUB);
            vector_operation_modifier   = 1'b1; // -(op[0] * op[1]) - op[2]
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end
        VFWMSAC: begin
            // vd[i] = +(vs1[i] * vs2[i]) - vd[i]
            vector_operands[0]          = widened_operands[0];
            vector_operands[1]          = widened_operands[1];
            vector_operands[2]          = data_old_vd;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FMADD);
            vector_operation_modifier   = 1'b1; // (op[0] * op[1]) - op[2]
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end
        VFWNMSAC: begin
            // vd[i] = -(vs1[i] * vs2[i]) + vd[i]
            vector_operands[0]          = widened_operands[0];
            vector_operands[1]          = widened_operands[1];
            vector_operands[2]          = data_old_vd;
            // fused multiply-add operation
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::FNMSUB);
            vector_operation_modifier   = 1'b0; // -(op[0] * op[1]) + op[2]
            vector_src_format = fpnew_pkg::fp_format_e'(FP64);
            vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
        end

        // Vector Floating-Point Square-Root Instruction
        VFSQRT: begin
            vector_operands[0]          = data_vs2;
            vector_operands[1]          = '0;
            vector_operands[2]          = '0;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::SQRT);
            vector_operation_modifier   = 1'b0;
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end

        VFCLASS: begin
            vector_operands[0]          = data_vs2;
            vector_operands[1]          = '0;
            vector_operands[2]          = '0;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::CLASSIFY);
            vector_operation_modifier   = 1'b0;
            case (sew)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end

        default: begin
            vector_operands             = '0;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = '0;
        end
    endcase
end

reg_t               fpnew_new_tag, fpnew_out_tag;
bus_simd_t          fpnew_result;
bus_simd_t          finish_vfp_result;
fpnew_pkg::status_t fpnew_status;
rr_exe_simd_instr_t finish_vfp_instr;
fpnew_pkg::status_t finish_vfp_status;
logic               stall_pending_vfp;
logic               enable_vfp_op;
logic               fpnew_out_valid;
logic               advance_head;
logic               pending_queue_valid;
logic               in_ready;

assign enable_vfp_op = instruction_i.instr.valid & drac_pkg::is_vfpnew(instruction_i.instr.instr_type) & !stall_pending_vfp;
assign pending_queue_valid = enable_vfp_op & in_ready;
assign advance_head = finish_vfp_instr.instr.valid & out_ready_i;
assign stall_o = (instruction_i.instr.valid & drac_pkg::is_vfpnew(instruction_i.instr.instr_type) & (!in_ready | stall_pending_vfp));

assign instruction_o = finish_vfp_instr;
assign status_o = finish_vfp_status;
assign data_vd_o = finish_vfp_result;

pending_vfp_ops_queue pending_vfp_ops_queue_inst (
    .clk_i,
    .rstn_i,
    .flush_i,

    .valid_i            (pending_queue_valid),
    .instruction_i,

    .result_valid_i     (fpnew_out_valid),
    .result_tag_i       (fpnew_out_tag),
    .result_fp_status_i (fpnew_status),
    .result_data_i      (fpnew_result),

    .advance_head_i     (advance_head),
    .finish_instr_fp_o  (finish_vfp_instr),
    .finish_fp_status_o (finish_vfp_status),
    .finish_result_o    (finish_vfp_result),
    .tag_o              (fpnew_new_tag),

    .full_o             (stall_pending_vfp)
);

// instanciation of main FPNEW module
fpnew_top #(
    .Features       (SARG_RV64DV),
    .Implementation (SARG_SIMD_INIT),
    .TagType        (logic[4:0]),
    .TrueSIMDClass  (1'b1)
) vector_fpnew (
    .clk_i          (clk_i),
    .rst_ni         (rstn_i),
    .flush_i        (flush_i),
    // inputs
    .operands_i     (vector_operands),
    .rnd_mode_i     (fpnew_pkg::roundmode_e'(frm)),
    .op_i           (vector_operation),
    .op_mod_i       (vector_operation_modifier),
    .src_fmt_i      (vector_src_format),
    .dst_fmt_i      (vector_dst_format),
    .int_fmt_i      (fpnew_pkg::int_format_e'(INT32)),  // no INT use
    .vectorial_op_i (1'b1),                             // only vector mode enabled
    .tag_i          (fpnew_new_tag),
    .simd_mask_i    (data_vm),                        // MaskType logic [NumLanes-1:0]
    // ouputs
    .result_o       (fpnew_result),
    .status_o       (fpnew_status),
    .tag_o          (fpnew_out_tag),
    .busy_o         (/* unused */),
    // handshake signals
    .in_valid_i     (instr_valid),
    .in_ready_o     (in_ready),
    .out_ready_i    (1'b1), // always held in "pending queue"
    .out_valid_o    (fpnew_out_valid)
);

endmodule
