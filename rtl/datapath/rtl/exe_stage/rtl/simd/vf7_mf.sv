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

// Module vf7_mf (SIMD FP estimated square-root and reciprocal)
// this module was directly implemented for Yuda Wang's DP2 version of the 
// floating-point SIMD. However, as these features can be open-sourced and
// are lacking on the vectorial CVFPU implementation, this will be
// instanciated on the vfpu_drac_wrapper vectorial module.
//
// The module features a rather direct implementation using the lookup-table 
// given in the Ratified Risc-V Non-supervisor Spec.

import fpnew_pkg::*;
import drac_pkg::*;

module vf7_mf
(
    input  logic                clk_i,
    input  logic                rstn_i,
    // inputs
    input  logic                valid_i,
    input  drac_pkg::sew_t      sew_i,
    input  logic                operation_i,    // 0: VFREC7, 1: VFRSQRT7
    input  bus64_t              src_i,          // Expanded to 64 bits
    // outputs
    output bus64_t              res_o,          // Expanded to 64 bits
    output logic                valid_o,
    output fpnew_pkg::status_t  status_o 
);

// ============================================================================
// Constants
// ============================================================================

localparam NV_FLAG = 0;
localparam DZ_FLAG = 1;
localparam OF_FLAG = 2;
localparam UF_FLAG = 3;
localparam NX_FLAG = 4;

// FP32 Constants
localparam FP32_EXP_BITS = 8;
localparam FP32_MAN_BITS = 23;
localparam FP32_BIAS = 127;
localparam FP32_MAX_EXP = 8'hFF;

// FP64 Constants
localparam FP64_EXP_BITS = 11;
localparam FP64_MAN_BITS = 52;
localparam FP64_BIAS = 1023;
localparam FP64_MAX_EXP = 11'h7FF;

// ============================================================================
// Lookup Tables (Same for both FP32 and FP64)
// ============================================================================

localparam [895:0] LUT_VFREC7_TABLE = {
    7'h7F,7'h7F,7'h7E,7'h7D,7'h7C,7'h7B,7'h7A,7'h79,7'h78,7'h77,7'h76,7'h75,7'h74,7'h73,7'h72,7'h71,
    7'h70,7'h6F,7'h6E,7'h6D,7'h6C,7'h6B,7'h6A,7'h69,7'h68,7'h67,7'h66,7'h65,7'h64,7'h63,7'h62,7'h61,
    7'h60,7'h5F,7'h5E,7'h5D,7'h5C,7'h5B,7'h5A,7'h59,7'h58,7'h57,7'h56,7'h55,7'h54,7'h53,7'h52,7'h51,
    7'h50,7'h4F,7'h4E,7'h4D,7'h4C,7'h4B,7'h4A,7'h49,7'h48,7'h47,7'h46,7'h45,7'h44,7'h43,7'h42,7'h41,
    7'h40,7'h3F,7'h3E,7'h3D,7'h3C,7'h3B,7'h3A,7'h39,7'h38,7'h37,7'h36,7'h35,7'h34,7'h33,7'h32,7'h31,
    7'h30,7'h2F,7'h2E,7'h2D,7'h2C,7'h2B,7'h2A,7'h29,7'h28,7'h27,7'h26,7'h25,7'h24,7'h23,7'h22,7'h21,
    7'h20,7'h1F,7'h1E,7'h1D,7'h1C,7'h1B,7'h1A,7'h19,7'h18,7'h17,7'h16,7'h15,7'h14,7'h13,7'h12,7'h11,
    7'h10,7'h0F,7'h0E,7'h0D,7'h0C,7'h0B,7'h0A,7'h09,7'h08,7'h07,7'h06,7'h05,7'h04,7'h03,7'h02,7'h01
};

localparam [447:0] LUT_VFRSQRT7_EVEN_TABLE = {
    7'h7F,7'h7D,7'h7B,7'h79,7'h77,7'h75,7'h73,7'h72,7'h70,7'h6E,7'h6D,7'h6B,7'h6A,7'h68,7'h67,7'h65,
    7'h64,7'h62,7'h61,7'h60,7'h5E,7'h5D,7'h5C,7'h5A,7'h59,7'h58,7'h57,7'h56,7'h54,7'h53,7'h52,7'h51,
    7'h50,7'h4F,7'h4E,7'h4D,7'h4C,7'h4B,7'h4A,7'h49,7'h48,7'h47,7'h46,7'h45,7'h44,7'h43,7'h42,7'h41,
    7'h41,7'h40,7'h3F,7'h3E,7'h3D,7'h3C,7'h3C,7'h3B,7'h3A,7'h39,7'h39,7'h38,7'h37,7'h36,7'h36,7'h35
};

localparam [447:0] LUT_VFRSQRT7_ODD_TABLE  = {
    7'h34,7'h32,7'h31,7'h30,7'h2E,7'h2D,7'h2C,7'h2B,7'h2A,7'h28,7'h27,7'h26,7'h25,7'h24,7'h23,7'h22,
    7'h21,7'h20,7'h1F,7'h1E,7'h1D,7'h1C,7'h1B,7'h1A,7'h19,7'h19,7'h18,7'h17,7'h16,7'h15,7'h14,7'h14,
    7'h13,7'h12,7'h11,7'h11,7'h10,7'h0F,7'h0F,7'h0E,7'h0D,7'h0C,7'h0C,7'h0B,7'h0B,7'h0A,7'h09,7'h09,
    7'h08,7'h07,7'h07,7'h06,7'h06,7'h05,7'h05,7'h04,7'h03,7'h03,7'h02,7'h02,7'h01,7'h01,7'h00,7'h00
};

// ============================================================================
// Input Decomposition
// ============================================================================

logic        src_sign;
logic [10:0] src_exp;
logic [51:0] src_mant;
logic        fp64_mode;

assign fp64_mode = (sew_i == SEW_64);
assign src_sign  = fp64_mode ? src_i[63] : src_i[31];
assign src_exp   = fp64_mode ? src_i[62:52] : {3'b0, src_i[30:23]};
assign src_mant  = fp64_mode ? src_i[51:0] : {29'b0, src_i[22:0]};

// ============================================================================
// Special Case Detection
// ============================================================================

// modified this section to make it sync to drac_pkg FP comparsion functions
logic src_is_zero      ;
logic src_is_inf       ;
logic src_is_nan       ;
logic src_is_snan      ;
logic src_is_subnormal ;

assign src_is_zero      = fp64_mode ? drac_pkg::is_zero_f64    (src_i[63:0]) : drac_pkg::is_zero_f32    (src_i[31:0]);
assign src_is_inf       = fp64_mode ? drac_pkg::is_inf_f64     (src_i[63:0]) : drac_pkg::is_inf_f32     (src_i[31:0]);
assign src_is_nan       = fp64_mode ? drac_pkg::is_nan_f64     (src_i[63:0]) : drac_pkg::is_nan_f32     (src_i[31:0]);
assign src_is_snan      = fp64_mode ? drac_pkg::is_snan_f64    (src_i[63:0]) : drac_pkg::is_snan_f32    (src_i[31:0]);
assign src_is_subnormal = fp64_mode ? drac_pkg::is_subnorm_f64 (src_i[63:0]) : drac_pkg::is_subnorm_f32 (src_i[31:0]);

// ============================================================================
// Normalization Pattern Detection (Same for both FP32 and FP64)
// ============================================================================

logic vfrec7_sig_1xxx   ;
logic vfrec7_sig_01xx   ;
logic vfrec7_direct_inf ;
logic [4:0] lzc_count   ;

assign vfrec7_sig_1xxx   = src_is_subnormal && (fp64_mode ? src_mant[51] : src_mant[22]);
assign vfrec7_sig_01xx   = src_is_subnormal && (fp64_mode ? !src_mant[51] && src_mant[50] : !src_mant[22] && src_mant[21]);
assign vfrec7_direct_inf = src_is_subnormal && (fp64_mode ? !src_mant[51] && !src_mant[50] : !src_mant[22] && !src_mant[21]);
assign lzc_count         = vfrec7_sig_1xxx ? 5'd0 : vfrec7_sig_01xx ? 5'd1 : 5'd0;

// ============================================================================
// Normalization
// ============================================================================


logic [12:0] normalized_exp  ;
logic [51:0] normalized_mant ;

logic [52:0] src_mant_shift_one;
logic [53:0] src_mant_shift_two;

assign src_mant_shift_one = (src_mant << 1);
assign src_mant_shift_two = (src_mant << 2);

assign normalized_exp   = (src_is_subnormal && !operation_i && (vfrec7_sig_1xxx || vfrec7_sig_01xx)) ?
                          (13'd1 - {8'b0, lzc_count}) : 
                          (fp64_mode ? {2'b0, src_exp} : {5'b0, src_exp});
// trunc of shifted values is compulsory, required to match widths for lin  stage
assign normalized_mant  = (src_is_subnormal && !operation_i && vfrec7_sig_1xxx) ? src_mant_shift_one[51:0] :
                          (src_is_subnormal && !operation_i && vfrec7_sig_01xx) ? src_mant_shift_two[51:0] : src_mant;

// ============================================================================
// Table Lookup
// ============================================================================

logic [6:0] rec_lookup_addr   ;
logic [5:0] rsqrt_lookup_addr ;
logic [6:0] table_result      ;

assign rec_lookup_addr   = fp64_mode ? normalized_mant[51:45] : normalized_mant[22:16];
assign rsqrt_lookup_addr = fp64_mode ? normalized_mant[51:46] : normalized_mant[22:17];
assign table_result      = operation_i ? (!normalized_exp[0] ? LUT_VFRSQRT7_ODD_TABLE[(447 - rsqrt_lookup_addr * 7) -: 7] : 
                                                               LUT_VFRSQRT7_EVEN_TABLE[(447 - rsqrt_lookup_addr * 7) -: 7]) :
                                                               LUT_VFREC7_TABLE[(895 - rec_lookup_addr * 7) -: 7];

// ============================================================================
// Result Computation
// ============================================================================

bus64_t      computed_result     ;
logic [4:0]  computed_exceptions ;
logic [12:0] result_exp          ;
logic [51:0] result_mant         ;

always_comb begin
    computed_exceptions = 5'b0;
    
    // Handle special cases
    if (src_is_nan) begin
        if (src_is_snan) begin
            computed_result = fp64_mode ? 
                {src_sign, FP64_MAX_EXP, 1'b1, 51'h0} : 
                {src_sign, FP32_MAX_EXP, 1'b1, 22'h0};
            computed_exceptions[NV_FLAG] = 1'b1;
        end else begin
            computed_result = fp64_mode ? 
                {src_sign, FP64_MAX_EXP, 52'h8000000000000} : 
                {src_sign, FP32_MAX_EXP, 23'h400000};
        end
    end else if (src_is_inf) begin
        if (operation_i == 1'b0) begin // VFREC7
            computed_result = fp64_mode ? 
                {src_sign, 11'h0, 52'h0} : 
                {src_sign, 8'h0, 23'h0};
        end else begin // VFRSQRT7
            if (src_sign) begin
                computed_result = fp64_mode ? 
                    {1'b0, FP64_MAX_EXP, 52'h8000000000000} : 
                    {1'b0, FP32_MAX_EXP, 23'h400000};
                computed_exceptions[NV_FLAG] = 1'b1;
            end else begin
                computed_result = fp64_mode ? 
                    {1'b0, 11'h0, 52'h0} : 
                    {1'b0, 8'h0, 23'h0};
            end
        end
    end else if (src_is_zero) begin
        computed_result = fp64_mode ? 
            {src_sign, FP64_MAX_EXP, 52'h0} : 
            {src_sign, FP32_MAX_EXP, 23'h0};
        computed_exceptions[DZ_FLAG] = 1'b1;
    end else if (src_sign && operation_i) begin
        computed_result = fp64_mode ? 
            {1'b0, FP64_MAX_EXP, 52'h8000000000000} : 
            {1'b0, FP32_MAX_EXP, 23'h400000};
        computed_exceptions[NV_FLAG] = 1'b1;
    end else if (src_is_subnormal) begin
        if (operation_i == 1'b0) begin // VFREC7
            if (vfrec7_direct_inf) begin
                computed_result = fp64_mode ? 
                    {src_sign, FP64_MAX_EXP, 52'h0} : 
                    {src_sign, FP32_MAX_EXP, 23'h0};
                computed_exceptions[DZ_FLAG] = 1'b1;
            end else begin
                result_exp = fp64_mode ? 13'(13'd2045 - normalized_exp) : 13'(13'd253 - normalized_exp);
                result_mant = fp64_mode ? {table_result, 45'b0} : {table_result, 16'b0};
                
                if (result_exp >= (fp64_mode ? 13'd2047 : 13'd255)) begin
                    computed_result = fp64_mode ? 
                        {src_sign, FP64_MAX_EXP, 52'h0} : 
                        {src_sign, FP32_MAX_EXP, 23'h0};
                    computed_exceptions[OF_FLAG] = 1'b1;
                end else if ((result_exp == 13'd0) || result_exp[12]) begin
                    computed_result = fp64_mode ? 
                        {src_sign, 11'h0, 52'h0} : 
                        {src_sign, 8'h0, 23'h0};
                    computed_exceptions[UF_FLAG] = 1'b1;
                end else begin
                    computed_result = fp64_mode ? 
                        {src_sign, result_exp[10:0], result_mant[51:0]} : 
                        {src_sign, result_exp[7:0], result_mant[22:0]};
                    computed_exceptions[NX_FLAG] = 1'b1;
                end
            end
        end else begin // VFRSQRT7
            computed_result = fp64_mode ? 
                {1'b0, FP64_MAX_EXP, 52'h0} : 
                {1'b0, FP32_MAX_EXP, 23'h0};
            computed_exceptions[DZ_FLAG] = 1'b1;
        end
    end else begin
        // Normal computation
        if (operation_i) begin
            if(!normalized_exp[0]) begin
                result_exp = fp64_mode ? 13'(13'd3069 - normalized_exp) >> 1 : 13'(13'd380 - normalized_exp) >> 1;
            end else begin
                result_exp = fp64_mode ? 13'(13'd3068 - normalized_exp) >> 1 : 13'(13'd379 - normalized_exp) >> 1;
            end
        end else begin
            result_exp = fp64_mode ? 13'(13'd2045 - normalized_exp) : 13'(13'd253 - normalized_exp);
        end
        
        result_mant = fp64_mode ? {table_result, 45'b0} : {table_result, 16'b0};
        
        if (result_exp >= (fp64_mode ? 13'd2047 : 13'd255)) begin
            computed_result = fp64_mode ? 
                {src_sign, FP64_MAX_EXP, 52'h0} : 
                {src_sign, FP32_MAX_EXP, 23'h0};
            computed_exceptions[OF_FLAG] = 1'b1;
        end else if ((result_exp == 13'd0) || result_exp[12]) begin
            computed_result = fp64_mode ? 
                {src_sign, 11'h0, 52'h0} : 
                {src_sign, 8'h0, 23'h0};
            computed_exceptions[UF_FLAG] = 1'b1;
        end else begin
            computed_result = fp64_mode ? 
                {src_sign, result_exp[10:0], result_mant[51:0]} : 
                {src_sign, result_exp[7:0], result_mant[22:0]};
            computed_exceptions[NX_FLAG] = 1'b1;
        end
    end
end

// directly compute by default the result combinationally
assign res_o = computed_result;
assign valid_o = valid_i;
always_comb begin // "translate" exception flags to fpnew_pkg::status_t
    status_o = '0; // default
    status_o.NV = computed_exceptions[NV_FLAG];
    status_o.DZ = computed_exceptions[DZ_FLAG];
    status_o.OF = computed_exceptions[OF_FLAG];
    status_o.UF = computed_exceptions[UF_FLAG];
    status_o.NX = computed_exceptions[NX_FLAG];
end

endmodule

