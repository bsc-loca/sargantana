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

/* vfred_fpadd module (floating-point adder of the vector FP reduction modules)
*
* Replaces the fpnew_top instances of vfredtree and vfredoladder. Those are
* fpnew_top #(SARG_ADDMUL_RV64D, SARG_ADDMUL_ONLY) with the default TagType,
* EnableSIMDMask, TrueSIMDClass and DivSqrtSel, always driven with
* op_i = ADD, op_mod_i = 0, src_fmt_i = dst_fmt_i = FpFormat, operands_i[0] = '0,
* simd_mask_i = '0, vectorial_op_i = 0, tag_i = 0, in_valid_i = 1,
* out_ready_i = 1 and flush_i = 0.
*
* The datapath is fpnew_fma_multi of cvfpu 84066933 (v0.6.6-67-g8406693),
* FP64 super-format, 2 DISTRIBUTED registers (1 input + 1 middle register, no
* output register), with those constants folded:
*  - operand A is the +1.0 of the ADD operation, so the 53x53 mantissa
*    multiplier is an exact shift (no DSPs).
*  - op, op_mod, formats, NaN-boxing, tag, mask and aux are not registered.
*    fpnew loads its input register on every clock edge and only lets a result
*    out once the valid bit has crossed both registers, so whenever an output
*    is visible those registers already hold the constants above.
*  - only the FpFormat slice of every per-format array is generated, and the
*    multi-format slice and both rr_arb_tree levels collapse to
*    "valid ? result : '0" (while not valid fpnew_top outputs the all-zero
*    out-of-range leaf of its arbiters).
* FP32 additions keep running on the FP64-wide datapath with the very same
* rounding and flag logic, so results, NaN-boxing and flags are bit-identical
* to the replaced fpnew_top on every cycle from reset on.
* If the cvfpu submodule is bumped, re-run the fpnew_top vs vfred_fpadd
* lockstep test and port any fpnew_fma_multi change here.
* Latency: 2 cycles, a new addition can start every cycle.
*/
// FP32 instances only read the low half of the operands and the datapath copied
// from fpnew_fma_multi leaves some bits of its signals unused
/* verilator lint_off UNUSEDSIGNAL */
module vfred_fpadd #(
    parameter fpnew_pkg::fp_format_e FpFormat = fpnew_pkg::FP64 // FP32 or FP64
) (
    input  logic                  clk_i,      // Clock signal
    input  logic                  rstn_i,     // Reset signal
    input  logic [63:0]           srca_i,     // First source  (fpnew operands_i[1], operand B)
    input  logic [63:0]           srcb_i,     // Second source (fpnew operands_i[2], addend C)
    input  fpnew_pkg::roundmode_e rnd_mode_i, // Rounding mode
    output logic [63:0]           result_o,   // Sum (FP32 NaN-boxed with ones), '0 while not valid
    output fpnew_pkg::status_t    status_o    // Flags of the sum, '0 while not valid
);

// The expressions below are copied verbatim from fpnew_fma_multi to keep the
// results bit-identical, including their implicit width conversions
/* verilator lint_off WIDTH */

// ----------
// Constants
// ----------
// Super-format of the replaced fpnew (FP32 + FP64)
localparam fpnew_pkg::fp_encoding_t SUPER_FORMAT = fpnew_pkg::super_format(drac_pkg::SARG_ADDMUL_RV64D.FpFmtMask);

localparam int unsigned SUPER_EXP_BITS     = SUPER_FORMAT.exp_bits;
localparam int unsigned SUPER_MAN_BITS     = SUPER_FORMAT.man_bits;
localparam int unsigned PRECISION_BITS     = SUPER_MAN_BITS + 1;          // p, implicit bit included
localparam int unsigned LOWER_SUM_WIDTH    = 2 * PRECISION_BITS + 3;      // searched by the LZC
localparam int unsigned LZC_RESULT_WIDTH   = $clog2(LOWER_SUM_WIDTH);
localparam int unsigned EXP_WIDTH          = fpnew_pkg::maximum(SUPER_EXP_BITS + 2, LZC_RESULT_WIDTH);
localparam int unsigned SHIFT_AMOUNT_WIDTH = $clog2(3 * PRECISION_BITS + 5);
localparam int unsigned ABS_WIDTH          = SUPER_EXP_BITS + SUPER_MAN_BITS;
localparam int unsigned WIDTH              = fpnew_pkg::max_fp_width(drac_pkg::SARG_ADDMUL_RV64D.FpFmtMask);

// Format of the additions of this instance
localparam int unsigned FP_WIDTH = fpnew_pkg::fp_width(FpFormat);
localparam int unsigned EXP_BITS = fpnew_pkg::exp_bits(FpFormat);
localparam int unsigned MAN_BITS = fpnew_pkg::man_bits(FpFormat);

localparam logic [EXP_BITS-1:0] QNAN_EXPONENT = '1;
localparam logic [MAN_BITS-1:0] QNAN_MANTISSA = 2**(MAN_BITS-1);
localparam logic [MAN_BITS-1:0] ZERO_MANTISSA = '0;

// This module mirrors fpnew_top #(SARG_ADDMUL_RV64D, SARG_ADDMUL_ONLY), it must
// be updated together with that configuration
if ((drac_pkg::SARG_ADDMUL_RV64D.Width != 64) ||
    (drac_pkg::SARG_ADDMUL_RV64D.FpFmtMask != 5'b11000) ||
    (drac_pkg::SARG_ADDMUL_RV64D.EnableVectors != 1'b0) ||
    (drac_pkg::SARG_ADDMUL_RV64D.EnableNanBox != 1'b0) ||
    (drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::ADDMUL][fpnew_pkg::FP32]  != fpnew_pkg::MERGED) ||
    (drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::ADDMUL][fpnew_pkg::FP64]  != fpnew_pkg::MERGED) ||
    (drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::DIVSQRT][fpnew_pkg::FP32] != fpnew_pkg::DISABLED) ||
    (drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::DIVSQRT][fpnew_pkg::FP64] != fpnew_pkg::DISABLED) ||
    (drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::NONCOMP][fpnew_pkg::FP32] != fpnew_pkg::DISABLED) ||
    (drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::NONCOMP][fpnew_pkg::FP64] != fpnew_pkg::DISABLED) ||
    (drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::CONV][fpnew_pkg::FP32]    != fpnew_pkg::DISABLED) ||
    (drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::CONV][fpnew_pkg::FP64]    != fpnew_pkg::DISABLED) ||
    (drac_pkg::SARG_ADDMUL_ONLY.PipeConfig != fpnew_pkg::DISTRIBUTED) ||
    (fpnew_pkg::get_num_regs_multi(drac_pkg::SARG_ADDMUL_ONLY.PipeRegs[fpnew_pkg::ADDMUL],
                                   drac_pkg::SARG_ADDMUL_ONLY.UnitTypes[fpnew_pkg::ADDMUL],
                                   drac_pkg::SARG_ADDMUL_RV64D.FpFmtMask) != 2)) begin : g_cfg_check
    $error("vfred_fpadd mirrors fpnew_top #(SARG_ADDMUL_RV64D, SARG_ADDMUL_ONLY), update it with that configuration");
end

if ((FpFormat != fpnew_pkg::FP32) && (FpFormat != fpnew_pkg::FP64)) begin : g_fmt_check
    $error("vfred_fpadd: FpFormat must be FP32 or FP64");
end

typedef struct packed {
    logic                      sign;
    logic [SUPER_EXP_BITS-1:0] exponent;
    logic [SUPER_MAN_BITS-1:0] mantissa;
} fp_t;

// ---------------
// Input register
// ---------------
// Loaded on every edge like the fpnew input register (in_valid_i = 1, never
// stalled). The constant fields of that register are not kept, see header.
logic [FP_WIDTH-1:0]   srca_q;          // operands_q[1]
logic [FP_WIDTH-1:0]   srcb_q;          // operands_q[2]
fpnew_pkg::roundmode_e inp_rnd_mode_q;
logic                  inp_valid_q;

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        srca_q         <= '0;
        srcb_q         <= '0;
        inp_rnd_mode_q <= fpnew_pkg::RNE;
        inp_valid_q    <= 1'b0;
    end else begin
        srca_q         <= srca_i[FP_WIDTH-1:0];
        srcb_q         <= srcb_i[FP_WIDTH-1:0];
        inp_rnd_mode_q <= rnd_mode_i;
        inp_valid_q    <= 1'b1;
    end
end

// -----------------
// Input processing
// -----------------
fpnew_pkg::fp_info_t [1:0] info_q; // [0]: srca, [1]: srcb

// NaN-boxing is disabled in SARG_ADDMUL_RV64D, fpnew_top forces is_boxed to '1
fpnew_classifier #(
    .FpFormat    ( FpFormat ),
    .NumOperands ( 2        )
) i_fpnew_classifier (
    .operands_i ( {srcb_q, srca_q} ),
    .is_boxed_i ( 2'b11            ),
    .info_o     ( info_q           )
);

fp_t                 operand_a, operand_b, operand_c;
fpnew_pkg::fp_info_t info_a,    info_b,    info_c;

always_comb begin : op_select
    // ADD: operand A is set to +1.0, op_mod_i = 0 keeps the sign of operand C
    operand_a = '{sign: 1'b0, exponent: SUPER_EXP_BITS'(fpnew_pkg::bias(FpFormat)), mantissa: '0};
    info_a    = '{is_normal: 1'b1, is_boxed: 1'b1, default: 1'b0}; // normal, boxed value

    // Operands moved into the super-format (mantissa left aligned)
    operand_b.sign     = srca_q[FP_WIDTH-1];
    operand_b.exponent = SUPER_EXP_BITS'(srca_q[MAN_BITS+:EXP_BITS]);
    operand_b.mantissa = SUPER_MAN_BITS'(srca_q[MAN_BITS-1:0]) << (SUPER_MAN_BITS - MAN_BITS);
    info_b             = info_q[0];

    operand_c.sign     = srcb_q[FP_WIDTH-1];
    operand_c.exponent = SUPER_EXP_BITS'(srcb_q[MAN_BITS+:EXP_BITS]);
    operand_c.mantissa = SUPER_MAN_BITS'(srcb_q[MAN_BITS-1:0]) << (SUPER_MAN_BITS - MAN_BITS);
    info_c             = info_q[1];
end

// ---------------------
// Input classification
// ---------------------
logic any_operand_inf;
logic any_operand_nan;
logic signalling_nan;
logic effective_subtraction;
logic tentative_sign;

assign any_operand_inf = (| {info_a.is_inf,        info_b.is_inf,        info_c.is_inf});
assign any_operand_nan = (| {info_a.is_nan,        info_b.is_nan,        info_c.is_nan});
assign signalling_nan  = (| {info_a.is_signalling, info_b.is_signalling, info_c.is_signalling});
// Effective subtraction in FMA occurs when product and addend signs differ
assign effective_subtraction = operand_a.sign ^ operand_b.sign ^ operand_c.sign;
// The tentative sign of the FMA shall be the sign of the product
assign tentative_sign = operand_a.sign ^ operand_b.sign;

// ----------------------
// Special case handling
// ----------------------
logic [WIDTH-1:0]   special_result;
fpnew_pkg::status_t special_status;
logic               result_is_special;

always_comb begin : special_results
    logic [FP_WIDTH-1:0] special_res;

    // Default assignment
    special_res       = {1'b0, QNAN_EXPONENT, QNAN_MANTISSA}; // qNaN
    special_status    = '0;
    result_is_special = 1'b0;

    // (inf * 0) + c or (0 * inf) + c INVALID (never for ADD, A is +1.0)
    if ((info_a.is_inf && info_b.is_zero) || (info_a.is_zero && info_b.is_inf)) begin
        result_is_special = 1'b1;
        special_status.NV = 1'b1;
    // NaN Inputs cause canonical quiet NaN at the output and maybe invalid OP
    end else if (any_operand_nan) begin
        result_is_special = 1'b1;
        special_status.NV = signalling_nan;
    // Special cases involving infinity
    end else if (any_operand_inf) begin
        result_is_special = 1'b1;
        // Effective addition of opposite infinities (+-inf - +-inf) is invalid!
        if ((info_a.is_inf || info_b.is_inf) && info_c.is_inf && effective_subtraction)
            special_status.NV = 1'b1;
        // Result is infinity with the sign of the product
        else if (info_a.is_inf || info_b.is_inf) begin
            special_res = {operand_a.sign ^ operand_b.sign, QNAN_EXPONENT, ZERO_MANTISSA};
        // Result is infinity with the sign of the addend
        end else if (info_c.is_inf) begin
            special_res = {operand_c.sign, QNAN_EXPONENT, ZERO_MANTISSA};
        end
    end
    // Initialize special result with ones (NaN-box)
    special_result               = '1;
    special_result[FP_WIDTH-1:0] = special_res;
end

// ---------------------------
// Initial exponent data path
// ---------------------------
logic signed [EXP_WIDTH-1:0] exponent_a, exponent_b, exponent_c;
logic signed [EXP_WIDTH-1:0] exponent_addend, exponent_product, exponent_difference;
logic signed [EXP_WIDTH-1:0] tentative_exponent;

assign exponent_a = signed'({1'b0, operand_a.exponent});
assign exponent_b = signed'({1'b0, operand_b.exponent});
assign exponent_c = signed'({1'b0, operand_c.exponent});

// Source and destination formats are both FpFormat (rebias kept as in fpnew)
assign exponent_addend = info_c.is_zero ? 1 // in case the addend is zero, set minimum exp
                         : signed'(exponent_c + $signed({1'b0, ~info_c.is_normal}) // 0 as subnorm
                                   - signed'(fpnew_pkg::bias(FpFormat))
                                   + signed'(fpnew_pkg::bias(FpFormat)));
assign exponent_product = (info_a.is_zero || info_b.is_zero) // in case the product is zero, set minimum exp.
                          ? 2 - signed'(fpnew_pkg::bias(FpFormat))
                          : signed'(exponent_a + info_a.is_subnormal
                                    + exponent_b + info_b.is_subnormal
                                    - 2*signed'(fpnew_pkg::bias(FpFormat))
                                    + signed'(fpnew_pkg::bias(FpFormat)));
assign exponent_difference = exponent_addend - exponent_product;

logic [SHIFT_AMOUNT_WIDTH-1:0] addend_shamt;

always_comb begin : addend_shift_amount
    // Product-anchored case, saturated shift (addend is only in the sticky bit)
    if (exponent_difference <= signed'(-2 * PRECISION_BITS - 1))
        addend_shamt = 3 * PRECISION_BITS + 4;
    // Addend and product will have mutual bits to add
    else if (exponent_difference <= signed'(PRECISION_BITS + 2))
        addend_shamt = unsigned'(signed'(PRECISION_BITS) + 3 - exponent_difference);
    // Addend-anchored case, saturated shift (product is only in the sticky bit)
    else
        addend_shamt = 0;
end

logic        [$clog2(SUPER_MAN_BITS)-1:0] addend_lzc_count;
logic        [$clog2(SUPER_MAN_BITS)  :0] addend_lzc_count_sgn;
logic        [SHIFT_AMOUNT_WIDTH    -1:0] addend_normalize_shamt;

lzc #(
    .WIDTH ( SUPER_MAN_BITS ),
    .MODE  ( 1              ) // MODE = 1 counts leading zeroes
) i_addend_lzc (
    .in_i    ( operand_c.mantissa ),
    .cnt_o   ( addend_lzc_count   ),
    /* verilator lint_off PINCONNECTEMPTY */
    .empty_o (                    )
    /* verilator lint_on PINCONNECTEMPTY */
);

assign addend_lzc_count_sgn = signed'({1'b0, addend_lzc_count});

always_comb begin
    // normal or zero addend
    if (info_c.is_normal || info_c.is_zero) begin
        addend_normalize_shamt = 0;
    // subnormal and will still be subnormal in destination format
    end else if (exponent_addend <= 1) begin
        addend_normalize_shamt = 0;
    // subnormal and will likely be normal in destination format in addend-anchored case
    end else if (addend_lzc_count_sgn + 1 < exponent_addend) begin
        addend_normalize_shamt = addend_lzc_count + 1;
    // subnormal and will still be subnormal in destination format
    end else begin
        addend_normalize_shamt = exponent_addend - 1;
    end
end

// The tentative exponent will be the larger of the product or addend exponent
assign tentative_exponent = (exponent_difference > 0) ? exponent_addend - addend_normalize_shamt : exponent_product;

// ------------------
// Product data path
// ------------------
logic [PRECISION_BITS-1:0]   mantissa_b, mantissa_c;
logic [2*PRECISION_BITS-1:0] product;             // the p*p product is 2p bits wide
logic [3*PRECISION_BITS+3:0] product_shifted;     // addends are 3p+4 bit wide (including G/R)

assign mantissa_b = {info_b.is_normal, operand_b.mantissa};
assign mantissa_c = {info_c.is_normal, operand_c.mantissa};

// mantissa_a = {info_a.is_normal, operand_a.mantissa} = 2**(p-1) (+1.0), so the
// p*p product of fpnew is mantissa_b shifted left by p-1 (exact, < 2**(2p-1))
assign product = {1'b0, mantissa_b, {(PRECISION_BITS-1){1'b0}}};

// | 000...000 | product | RS |
assign product_shifted = product << 2; // constant shift

// -----------------
// Addend data path
// -----------------
logic [3*PRECISION_BITS+3:0] addend_after_shift;  // upper 3p+4 bits are needed to go on
logic [PRECISION_BITS-1:0]   addend_sticky_bits;  // up to p bit of shifted addend are sticky
logic                        sticky_before_add;   // they are compressed into a single sticky bit
logic [3*PRECISION_BITS+3:0] addend_shifted;      // addends are 3p+4 bit wide (including G/R)
logic                        inject_carry_in;     // inject carry for subtractions if needed

assign {addend_after_shift, addend_sticky_bits} =
    (mantissa_c << (3 * PRECISION_BITS + 4)) >> addend_shamt;

assign sticky_before_add = (| addend_sticky_bits);

// In case of a subtraction, the addend is inverted
assign addend_shifted  = (effective_subtraction) ? ~addend_after_shift : addend_after_shift;
assign inject_carry_in = effective_subtraction & ~sticky_before_add;

// ------
// Adder
// ------
logic [3*PRECISION_BITS+4:0] sum_pos, sum_neg; // added one bit for the carry
logic                        sum_carry;        // observe carry bit from positive sum for sign fixing
logic [3*PRECISION_BITS+3:0] sum;              // discard carry as sum won't overflow
logic                        final_sign;

assign sum_pos   = product_shifted + addend_shifted + inject_carry_in;
assign sum_carry = sum_pos[3*PRECISION_BITS+4];

// Parallel adder for negative sum (only used for effective subtractions)
assign sum_neg = addend_after_shift - product_shifted;

// Complement negative sum (can only happen in subtraction -> overflows for positive results)
assign sum = (effective_subtraction && ~sum_carry) ? sum_neg : sum_pos;

// In case of a mispredicted subtraction result, do a sign flip
assign final_sign = (effective_subtraction && (sum_carry == tentative_sign))
                    ? 1'b1
                    : (effective_subtraction ? 1'b0 : tentative_sign);

// ----------------
// Middle register
// ----------------
// Loaded only when the input register holds a valid item, as in fpnew
logic                          effective_subtraction_q;
logic signed [EXP_WIDTH-1:0]   exponent_product_q;
logic signed [EXP_WIDTH-1:0]   exponent_difference_q;
logic signed [EXP_WIDTH-1:0]   tentative_exponent_q;
logic [SHIFT_AMOUNT_WIDTH-1:0] addend_shamt_q;
logic                          sticky_before_add_q;
logic [3*PRECISION_BITS+3:0]   sum_q;
logic                          final_sign_q;
fpnew_pkg::roundmode_e         rnd_mode_q;
logic                          result_is_special_q;
fp_t                           special_result_q;
fpnew_pkg::status_t            special_status_q;
logic                          mid_valid_q;

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        effective_subtraction_q <= '0;
        exponent_product_q      <= '0;
        exponent_difference_q   <= '0;
        tentative_exponent_q    <= '0;
        addend_shamt_q          <= '0;
        sticky_before_add_q     <= '0;
        sum_q                   <= '0;
        final_sign_q            <= '0;
        rnd_mode_q              <= fpnew_pkg::RNE;
        result_is_special_q     <= '0;
        special_result_q        <= '0;
        special_status_q        <= '0;
        mid_valid_q             <= 1'b0;
    end else begin
        mid_valid_q <= inp_valid_q;
        if (inp_valid_q) begin
            effective_subtraction_q <= effective_subtraction;
            exponent_product_q      <= exponent_product;
            exponent_difference_q   <= exponent_difference;
            tentative_exponent_q    <= tentative_exponent;
            addend_shamt_q          <= addend_shamt + addend_normalize_shamt;
            sticky_before_add_q     <= sticky_before_add;
            sum_q                   <= sum;
            final_sign_q            <= final_sign;
            rnd_mode_q              <= inp_rnd_mode_q;
            result_is_special_q     <= result_is_special;
            special_result_q        <= special_result;
            special_status_q        <= special_status;
        end
    end
end

// --------------
// Normalization
// --------------
logic        [LOWER_SUM_WIDTH-1:0]  sum_lower;              // lower 2p+3 bits of sum are searched
logic        [LZC_RESULT_WIDTH-1:0] leading_zero_count;     // the number of leading zeroes
logic signed [LZC_RESULT_WIDTH:0]   leading_zero_count_sgn; // signed leading-zero count
logic                               lzc_zeroes;             // in case only zeroes found

logic        [SHIFT_AMOUNT_WIDTH-1:0] norm_shamt; // Normalization shift amount
logic signed [EXP_WIDTH-1:0]          normalized_exponent;

logic [3*PRECISION_BITS+4:0] sum_shifted;       // result after first normalization shift
logic [PRECISION_BITS:0]     final_mantissa;    // final mantissa before rounding with round bit
logic [2*PRECISION_BITS+2:0] sum_sticky_bits;   // remaining 2p+3 sticky bits after normalization
logic                        sticky_after_norm; // sticky bit after normalization

logic signed [EXP_WIDTH-1:0] final_exponent;

assign sum_lower = sum_q[LOWER_SUM_WIDTH-1:0];

lzc #(
    .WIDTH ( LOWER_SUM_WIDTH ),
    .MODE  ( 1               ) // MODE = 1 counts leading zeroes
) i_lzc (
    .in_i    ( sum_lower          ),
    .cnt_o   ( leading_zero_count ),
    .empty_o ( lzc_zeroes         )
);

assign leading_zero_count_sgn = signed'({1'b0, leading_zero_count});

always_comb begin : norm_shift_amount
    // Product-anchored case or cancellations require LZC
    if ((exponent_difference_q <= 0) || (effective_subtraction_q && (exponent_difference_q <= 2))) begin
        // Normal result (biased exponent > 0 and not a zero)
        if ((exponent_product_q - leading_zero_count_sgn + 1 >= 0) && !lzc_zeroes) begin
            norm_shamt          = PRECISION_BITS + 2 + leading_zero_count;
            normalized_exponent = exponent_product_q - leading_zero_count_sgn + 1; // account for shift
        // Subnormal result
        end else begin
            norm_shamt          = unsigned'(signed'(PRECISION_BITS + 2 + exponent_product_q));
            normalized_exponent = 0; // subnormals encoded as 0
        end
    // Addend-anchored case
    end else begin
        norm_shamt          = addend_shamt_q; // Undo the initial shift
        normalized_exponent = tentative_exponent_q;
    end
end

// Do the large normalization shift
assign sum_shifted = sum_q << norm_shamt;

always_comb begin : small_norm
    // Default assignment, discarding carry bit
    {final_mantissa, sum_sticky_bits} = sum_shifted;
    final_exponent                    = normalized_exponent;

    // The normalized sum has overflown, align right and fix exponent
    if (sum_shifted[3*PRECISION_BITS+4]) begin // check the carry bit
        {final_mantissa, sum_sticky_bits} = sum_shifted >> 1;
        final_exponent                    = normalized_exponent + 1;
    // The normalized sum is normal, nothing to do
    end else if (sum_shifted[3*PRECISION_BITS+3]) begin // check the sum MSB
        // do nothing
    // The normalized sum is still denormal, align left - unless the result is not already subnormal
    end else if (normalized_exponent > 1) begin
        {final_mantissa, sum_sticky_bits} = sum_shifted << 1;
        final_exponent                    = normalized_exponent - 1;
    // Otherwise we're denormal
    end else begin
        final_exponent = '0;
    end
end

// Update the sticky bit with the shifted-out bits
assign sticky_after_norm = (| {sum_sticky_bits}) | sticky_before_add_q;

// ----------------------------
// Rounding and classification
// ----------------------------
logic                 pre_round_sign;
logic [ABS_WIDTH-1:0] pre_round_abs;      // absolute value of result before rounding
logic [1:0]           round_sticky_bits;
logic [EXP_BITS-1:0]  pre_round_exponent;
logic [MAN_BITS-1:0]  pre_round_mantissa;

logic of_before_round, of_after_round; // overflow
logic uf_after_round;                  // underflow

logic                 rounded_sign;
logic [ABS_WIDTH-1:0] rounded_abs;     // absolute value of result after rounding
logic                 result_zero;

// Classification before round. RISC-V mandates checking underflow AFTER rounding!
assign of_before_round = final_exponent >= 2**(fpnew_pkg::exp_bits(FpFormat))-1; // infinity exponent is all ones

// Assemble result before rounding. In case of overflow, the largest normal value is set.
assign pre_round_exponent = (of_before_round) ? 2**EXP_BITS-2 : final_exponent[EXP_BITS-1:0];
assign pre_round_mantissa = (of_before_round) ? '1 : final_mantissa[SUPER_MAN_BITS-:MAN_BITS];
assign pre_round_sign     = final_sign_q;
assign pre_round_abs      = ABS_WIDTH'({pre_round_exponent, pre_round_mantissa}); // 0-extend

// Round bit is after mantissa (1 in case of overflow for rounding)
assign round_sticky_bits[1] = final_mantissa[SUPER_MAN_BITS-MAN_BITS] | of_before_round;

// remaining bits in mantissa to sticky (1 in case of overflow for rounding)
if (MAN_BITS < SUPER_MAN_BITS) begin : narrow_sticky
    assign round_sticky_bits[0] = (| final_mantissa[SUPER_MAN_BITS-MAN_BITS-1:0]) |
                                  sticky_after_norm | of_before_round;
end else begin : normal_sticky
    assign round_sticky_bits[0] = sticky_after_norm | of_before_round;
end

fpnew_rounding #(
    .AbsWidth ( ABS_WIDTH )
) i_fpnew_rounding (
    .abs_value_i             ( pre_round_abs           ),
    .sign_i                  ( pre_round_sign          ),
    .round_sticky_bits_i     ( round_sticky_bits       ),
    .rnd_mode_i              ( rnd_mode_q              ),
    .effective_subtraction_i ( effective_subtraction_q ),
    .abs_rounded_o           ( rounded_abs             ),
    .sign_o                  ( rounded_sign            ),
    .exact_zero_o            ( result_zero             )
);

// detect of / uf
assign uf_after_round = (rounded_abs[EXP_BITS+MAN_BITS-1:MAN_BITS] == '0) // denormal
    || ((pre_round_abs[EXP_BITS+MAN_BITS-1:MAN_BITS] == '0) && (rounded_abs[EXP_BITS+MAN_BITS-1:MAN_BITS] == 1) &&
        ((round_sticky_bits != 2'b11) || (!sum_sticky_bits[MAN_BITS*2 + 4] && ((rnd_mode_q == fpnew_pkg::RNE) || (rnd_mode_q == fpnew_pkg::RMM)))));
assign of_after_round = rounded_abs[EXP_BITS+MAN_BITS-1:MAN_BITS] == '1; // inf exp.

// -----------------
// Result selection
// -----------------
logic [WIDTH-1:0]   regular_result;
fpnew_pkg::status_t regular_status;

// Assemble regular result, nan box short ones
always_comb begin : post_process
    regular_result               = '1;
    regular_result[FP_WIDTH-1:0] = {rounded_sign, rounded_abs[EXP_BITS+MAN_BITS-1:0]};
end

assign regular_status.NV = 1'b0; // only valid cases are handled in regular path
assign regular_status.DZ = 1'b0; // no divisions
assign regular_status.OF = of_before_round | of_after_round;   // rounding can introduce overflow
assign regular_status.UF = uf_after_round & regular_status.NX; // only inexact results raise UF
assign regular_status.NX = (| round_sticky_bits) | of_before_round | of_after_round;

logic [WIDTH-1:0]   result_d;
fpnew_pkg::status_t status_d;

assign result_d = result_is_special_q ? special_result_q : regular_result;
assign status_d = result_is_special_q ? special_status_q : regular_status;

// fpnew_top output: the slice result while valid (FP32 upper half already
// NaN-boxed with ones), otherwise the all-zero out-of-range arbiter leaf
assign result_o = mid_valid_q ? result_d : '0;
assign status_o = mid_valid_q ? status_d : '0;

/* verilator lint_on WIDTH */

endmodule
/* verilator lint_on UNUSEDSIGNAL */
