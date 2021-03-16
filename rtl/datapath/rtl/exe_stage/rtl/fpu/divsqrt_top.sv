// Copyright 2018 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author:  Lei Li <lile@iis.ee.ethz.ch> 
//
// Additional contributions by: Mate Kovac <mate.kovac@fer.hr>
//                              Leon Dragic <leon.dragic@fer.hr>
//
// Change history: 04/02/2020 - Merged top and preprocess module, removed precision control
//                              feature, changed coding style and module name.
//                 10/02/2020 - Removed fpuv_norm_div_sqrt_mvp module. Special case handling,
//                              normalization, classification are implemented in divsqrt_top
//                              module. fpuv_rounding module is used for rounding.
//                 30/06/2020 - Added forwarding of 3 src registers for inactive element select.
//

`include "registers.svh"

module divsqrt_top #(
   parameter fpuv_pkg::fmt_logic_t   FpFmtConfig  = 5'b11000,
   // Do not change
   localparam int unsigned WIDTH       = 64,
   localparam int unsigned NUM_FORMATS = fpuv_pkg::NUM_FP_FORMATS,
   localparam int unsigned DIVSQRT_ITER = drac_pkg::DIVSQRT_ITER
)(
   input  logic                        clk_i,
   input  logic                        rst_ni,
   // Input signals
   input  logic [2:0][WIDTH-1:0]       operands_i, // 2 operands for op, 1 for mask forwarding
   input  logic                        div_start_i,
   input  logic                        sqrt_start_i,
   input  fpuv_pkg::roundmode_e        rnd_mode_i,
   input  fpuv_pkg::fp_format_e        dst_fmt_i,
   input  logic                        kill_i,
   input  logic                        mask_i,
   input  logic [1:0]                  inactive_sel_i,
   // Output signals
   output logic [WIDTH-1:0]            result_o,
   output fpuv_pkg::status_t           status_o,
   output logic                        in_ready_o,
   output logic                        done_o
);

   // ----------
   // Constants
   // ----------
   // The super-format that can hold all formats
   // localparam fpuv_pkg::fp_encoding_t SUPER_FORMAT = fpuv_pkg::super_format(FpFmtConfig);
   localparam int unsigned SUPER_EXP_BITS = fpuv_pkg::exp_bits(fpuv_pkg::FP64);
   localparam int unsigned SUPER_MAN_BITS = fpuv_pkg::man_bits(fpuv_pkg::FP64);

   // Precision bits 'p' include the implicit bit
   localparam int unsigned PRECISION_BITS = SUPER_MAN_BITS + 1;
   // Leading zero counter width, maximum number of zeroes is PRECISION_BITS
   localparam int unsigned LZC_RESULT_WIDTH = $clog2(PRECISION_BITS);
   // Normalization shift amount width, maximum shift is PRECISION_BITS + 1
   localparam int unsigned SHIFT_AMOUNT_WIDTH = $clog2(PRECISION_BITS + 1);

   // ----------------
   // Type definition
   // ----------------
   typedef struct packed {
      logic                      sign;
      logic [SUPER_EXP_BITS-1:0] exponent;
      logic [SUPER_MAN_BITS-1:0] mantissa;
   } fp_t;

   logic start;    // high in the cycle when div_start_i or sqrt_start_i are high
   logic op_start; // high in the cycle when a new operation starts

   assign start    = div_start_i | sqrt_start_i;
   assign op_start = in_ready_o & start; // new operation starts when unit is ready and start is high

   // -----------------
   // Input processing
   // -----------------
   logic        [NUM_FORMATS-1:0][1:0]                     fmt_sign;
   logic signed [NUM_FORMATS-1:0][1:0][SUPER_EXP_BITS-1:0] fmt_exponent;
   logic        [NUM_FORMATS-1:0][1:0][SUPER_MAN_BITS-1:0] fmt_mantissa;

   fpuv_pkg::fp_info_t [NUM_FORMATS-1:0][1:0] info;

   // FP Input initialization
   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : fmt_init_inputs
      // Set up some constants
      localparam int unsigned FP_WIDTH = fpuv_pkg::fp_width(fpuv_pkg::fp_format_e'(fmt));
      localparam int unsigned EXP_BITS = fpuv_pkg::exp_bits(fpuv_pkg::fp_format_e'(fmt));
      localparam int unsigned MAN_BITS = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt));

      if (FpFmtConfig[fmt]) begin : active_format
         logic [1:0][FP_WIDTH-1:0] trimmed_ops;

         // Classify input
         fpuv_classifier #(
            .FpFormat    ( fpuv_pkg::fp_format_e'(fmt) ),
            .NumOperands ( 2                           )
         ) i_fpuv_classifier (
            .operands_i ( trimmed_ops ),
            .is_boxed_i ( '1          ),
            .info_o     ( info[fmt]   )
         );
         for (genvar op = 0; op < 2; op++) begin : gen_operands
            assign trimmed_ops[op]       = operands_i[op][FP_WIDTH-1:0];
            assign fmt_sign[fmt][op]     = operands_i[op][FP_WIDTH-1];
            assign fmt_exponent[fmt][op] = signed'({1'b0, operands_i[op][MAN_BITS+:EXP_BITS]});
            assign fmt_mantissa[fmt][op] = {info[fmt][op].is_normal, operands_i[op][MAN_BITS-1:0]} <<
                                          (SUPER_MAN_BITS - MAN_BITS); // move to left of mantissa
         end
      end else begin : inactive_format
         assign info[fmt]                = '{default: fpuv_pkg::DONT_CARE}; // format disabled
         assign fmt_sign[fmt]            = fpuv_pkg::DONT_CARE;             // format disabled
         assign fmt_exponent[fmt]        = '{default: fpuv_pkg::DONT_CARE}; // format disabled
         assign fmt_mantissa[fmt]        = '{default: fpuv_pkg::DONT_CARE}; // format disabled
      end
   end

   fp_t                 operand_a, operand_b;
   fpuv_pkg::fp_info_t  info_a, info_b;
   fpuv_pkg::fp_info_t  info_a_q, info_b_q;

   // Packing-order-agnostic assignments
   assign operand_a = {fmt_sign[dst_fmt_i][0], fmt_exponent[dst_fmt_i][0], fmt_mantissa[dst_fmt_i][0]};
   assign operand_b = {fmt_sign[dst_fmt_i][1], fmt_exponent[dst_fmt_i][1], fmt_mantissa[dst_fmt_i][1]};
   assign info_a    = op_start ? info[dst_fmt_i][0] : info_a_q;
   // ignore operand_b for sqrt: set to normal, boxed value.
   assign info_b    = op_start ? (sqrt_start_i ? '{is_normal: 1'b1, is_boxed: 1'b1, default: 1'b0} : info[dst_fmt_i][1]) : info_b_q;

   `FF(info_a_q, info_a, '0)
   `FF(info_b_q, info_b, '0)

   // Significands with hidden bit
   logic [PRECISION_BITS-1:0]   mantissa_a, mantissa_b;

   // Add implicit bits to significands
   assign mantissa_a = {info_a.is_normal, operand_a.mantissa};
   assign mantissa_b = {info_b.is_normal, operand_b.mantissa};

   // ---------------------
   // Input classification
   // ---------------------
   logic any_operand_inf;
   logic any_operand_nan;
   logic any_operand_zero;
   logic signalling_nan;

   // Reduction for special case handling
   assign any_operand_inf  = (| {info_a.is_inf,        info_b.is_inf});
   assign any_operand_nan  = (| {info_a.is_nan,        info_b.is_nan});
   assign any_operand_zero = (| {info_a.is_zero,       info_b.is_zero});
   assign signalling_nan   = (| {info_a.is_signalling, info_b.is_signalling});

   // ----------------------
   // Special case handling
   // ----------------------
   logic [WIDTH-1:0]  special_result;
   fpuv_pkg::status_t special_status;
   logic              result_is_special;

   logic [NUM_FORMATS-1:0][WIDTH-1:0]   fmt_special_result;
   fpuv_pkg::status_t [NUM_FORMATS-1:0] fmt_special_status;
   logic [NUM_FORMATS-1:0]              fmt_result_is_special;

   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : gen_special_results
      // Set up some constants
      localparam int unsigned FP_WIDTH = fpuv_pkg::fp_width(fpuv_pkg::fp_format_e'(fmt));
      localparam int unsigned EXP_BITS = fpuv_pkg::exp_bits(fpuv_pkg::fp_format_e'(fmt));
      localparam int unsigned MAN_BITS = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt));

      localparam logic [EXP_BITS-1:0] QNAN_EXPONENT = '1;
      localparam logic [EXP_BITS-1:0] ZERO_EXPONENT = '0;
      localparam logic [MAN_BITS-1:0] QNAN_MANTISSA = 2**(MAN_BITS-1);
      localparam logic [MAN_BITS-1:0] ZERO_MANTISSA = '0;

      if (FpFmtConfig[fmt]) begin : active_format
         always_comb begin : special_results
            logic [FP_WIDTH-1:0] special_res;

            // Default assignment
            special_res                = {1'b0, QNAN_EXPONENT, QNAN_MANTISSA}; // qNaN
            fmt_special_status[fmt]    = '0;
            fmt_result_is_special[fmt] = 1'b0;

            // First check if the result is masked.
            if (mask_i) begin
               fmt_result_is_special[fmt] = 1'b1; // result is special. masking operation.
               if (inactive_sel_i == 2'b01) begin
                  special_res = operands_i[0];
               end else if (inactive_sel_i == 2'b10) begin
                  special_res = operands_i[1];
               end else if (inactive_sel_i == 2'b11) begin
                  special_res = operands_i[2];
               end else begin
                  special_res = '{default: fpuv_pkg::DONT_CARE};
               end
            // IEEE 754-2019 mandates raising the NV exception in these cases:
            // - operation on signaling NaN
            // - division: 0/0, inf/inf
            // - square root if the operand is less than zero
            // Default result shall be qNaN
            end else if (any_operand_nan) begin // NaN Inputs cause canonical quiet NaN at the output and maybe invalid OP
               fmt_result_is_special[fmt] = 1'b1;           // bypass DIV/SQRT, output is the canonical qNaN
               fmt_special_status[fmt].NV = signalling_nan; // raise the invalid operation flag if signalling
            // Special cases involving zero
            end else if (any_operand_zero) begin
               if (info_a.is_zero && info_b.is_zero) begin // 0/0
                  fmt_result_is_special[fmt] = 1'b1; // bypass DIV, output is the canonical qNaN
                  fmt_special_status[fmt].NV = 1'b1; // invalid operation
               end else if (info_b.is_zero) begin // Division by zero case
                  fmt_result_is_special[fmt] = 1'b1; // bypass DIV, output is inf
                  fmt_special_status[fmt].DZ = ~info_a.is_inf; // raise division by zero flag only when the dividend is finite non-zero number
                  // Result is infinitiy, the sign is the XOR of the operand's signs
                  special_res = {operand_a.sign ^ operand_b.sign, QNAN_EXPONENT, ZERO_MANTISSA};
               end else begin // 0/x or sqrt(0) -> result is zero
                  fmt_result_is_special[fmt] = 1'b1; // bypass DIV/SQRT, output is zero
                  special_res = {sqrt_start_i ? operand_a.sign : operand_a.sign ^ operand_b.sign, ZERO_EXPONENT, ZERO_MANTISSA};
               end 
            // Square root of negative operand
            end else if (operand_a.sign && sqrt_start_i) begin
               fmt_result_is_special[fmt] = 1'b1; // bypass SQRT, output is the canonical qNaN
               fmt_special_status[fmt].NV = 1'b1; // invalid operation
            // Special cases involving infinity
            end else if (any_operand_inf) begin
               fmt_result_is_special[fmt] = 1'b1; // bypass DIV/SQRT
               if (info_a.is_inf && info_b.is_inf) // inf/inf
                  fmt_special_status[fmt].NV = 1'b1; // invalid operation
               // Handle case where output will be inf because of inf input
               else if (info_a.is_inf) begin // inf/b or sqrt(+inf)
                  // Result is infinity with the sign of the operand_a ('+') for sqrt or quotient for division
                  special_res = {sqrt_start_i ? operand_a.sign : operand_a.sign ^ operand_b.sign, QNAN_EXPONENT, ZERO_MANTISSA};
               end else begin // Divisor is inf, output will be zero
                  special_res = {operand_a.sign ^ operand_b.sign, ZERO_EXPONENT, ZERO_MANTISSA};
               end
           end
           // Initialize special result with ones (NaN-box)
           fmt_special_result[fmt]               = '1;
           fmt_special_result[fmt][FP_WIDTH-1:0] = special_res;
         end
      end else begin : inactive_format
         assign fmt_special_result[fmt]    = '{default: fpuv_pkg::DONT_CARE}; // format disabled
         assign fmt_special_status[fmt]    = '{default: fpuv_pkg::DONT_CARE}; // format disabled
         assign fmt_result_is_special[fmt] = fpuv_pkg::DONT_CARE;             // format disabled
      end
   end

   // Special result registers
   logic [WIDTH-1:0]  special_result_q;
   fpuv_pkg::status_t special_status_q;
   logic              result_is_special_q;

   // Detect special case from source format
   assign result_is_special = op_start ? fmt_result_is_special[dst_fmt_i] : result_is_special_q;
   assign special_status    = op_start ? fmt_special_status[dst_fmt_i] : special_status_q;
   // Assemble result according to destination format
   assign special_result    = op_start ? fmt_special_result[dst_fmt_i] : special_result_q; // destination format

   // Fill the registers everytime a valid operation arrives (load FF, active low asynch rst)
   `FF(special_result_q,    special_result,    '0)
   `FF(special_status_q,    special_status,    '0)
   `FF(result_is_special_q, result_is_special, '0)

   // Calculate result sign 
   logic result_sign;
   logic result_sign_q;

   assign result_sign = op_start ? (div_start_i ? operand_a.sign ^ operand_b.sign : operand_a.sign) : result_sign_q;
   // Fill the registers everytime a valid operation arrives (load FF, active low asynch rst)
   `FF(result_sign_q, result_sign, '0)

   // Save rounding mode in register
   fpuv_pkg::roundmode_e rnd_mode_q;
   // Fill the register everytime a valid operation arrives (load FF, active low asynch rst, default rnd mode is RNE)
   `FFL(rnd_mode_q, rnd_mode_i, op_start, fpuv_pkg::RNE)

   // Store dst_fmt_i in register
   fpuv_pkg::fp_format_e dst_fmt_q;
   `FFL(dst_fmt_q, dst_fmt_i, op_start, fpuv_pkg::FP64)

   // ----------------------
   // Input normalization
   // ----------------------
   logic [LZC_RESULT_WIDTH-1:0] leading_zero_cnt_a, leading_zero_cnt_b; // the number of leading zeroes in operands
   logic                        lzc_zeroes_a, lzc_zeroes_b;             // in case only zeroes found
   logic [PRECISION_BITS-1:0]   mant_norm_a, mant_norm_b;               // normalized significands
   logic [PRECISION_BITS-1:0]   mant_norm_a_q, mant_norm_b_q;           // registers for normalized significands

   // Leading zero counter instance for operand_a
   fpuv_lzc #(
      .WIDTH ( PRECISION_BITS ),
      .MODE  ( 1               ) // MODE = 1 counts leading zeroes
   ) i_lzc_0 (
      .in_i    ( mantissa_a         ),
      .cnt_o   ( leading_zero_cnt_a ),
      .empty_o ( lzc_zeroes_a       )
   );
   
   // Leading zero counter instance for operand_b
   fpuv_lzc #(
      .WIDTH ( PRECISION_BITS ),
      .MODE  ( 1               ) // MODE = 1 counts leading zeroes
   ) i_lzc_1 (
      .in_i    ( mantissa_b         ),
      .cnt_o   ( leading_zero_cnt_b ),
      .empty_o ( lzc_zeroes_b       )
   );

   // Normalize subnormal significands for new operation
   assign mant_norm_a = op_start ? mantissa_a << leading_zero_cnt_a : mant_norm_a_q;
   assign mant_norm_b = op_start ? mantissa_b << leading_zero_cnt_b : mant_norm_b_q;

   // Store normalized significands (FF, asynchronous active-low reset (implicit clock and reset))
   `FF(mant_norm_a_q, mant_norm_a, '0)
   `FF(mant_norm_b_q, mant_norm_b, '0)

   logic signed [SUPER_EXP_BITS+2-1:0] exponent_a, exponent_b;     // sign extended input exponents
   logic signed [SUPER_EXP_BITS+2-1:0] exp_norm_a, exp_norm_b;     // normalized exponents
   logic signed [SUPER_EXP_BITS+2-1:0] exp_norm_a_q, exp_norm_b_q; // registers for normalized exponents

   // Zero-extend exponents into signed container - implicit width extension
   assign exponent_a = signed'({1'b0, operand_a.exponent});
   assign exponent_b = signed'({1'b0, operand_b.exponent});
   // Calculate normalized exponents for new operation
   assign exp_norm_a = op_start ? signed'(exponent_a - leading_zero_cnt_a + info_a.is_subnormal) : exp_norm_a_q;
   assign exp_norm_b = op_start ? signed'(exponent_b - leading_zero_cnt_b + info_b.is_subnormal) : exp_norm_b_q;
   
   // Store normalized exponents (FF, asynchronous active-low reset (implicit clock and reset))
   `FF(exp_norm_a_q, exp_norm_a, '0)
   `FF(exp_norm_b_q, exp_norm_b, '0)

   // ----------------------
   // Non-restoring div/sqrt
   // ----------------------
   logic                               div_enable;       // high in cycles when a division operation is in progress
   logic                               sqrt_enable;      // high in cycles when a sqrt operation is in progress
   logic        [PRECISION_BITS+4-1:0] pre_round_mant;   // result significand before rounding extended with 4 bits for rounding
   logic signed [SUPER_EXP_BITS+2-1:0] pre_round_exp;    // result exponent before rounding

   divsqrt_nrst #(
      .FpFmtConfig    ( FpFmtConfig ),
      .ITER_CELLS_NUM ( DIVSQRT_ITER )
   ) i_divsqrt_nrst (
      .clk_i,
      .rst_ni,
      .dividend_i          ( mant_norm_a_q       ),
      .dividend_exp_i      ( exp_norm_a_q        ),
      .divisor_i           ( mant_norm_b_q       ),
      .divisor_exp_i       ( exp_norm_b_q        ),
      .div_start_i         ( div_start_i         ),
      .sqrt_start_i        ( sqrt_start_i        ),
      .start_i             ( start               ),
      .dst_fmt_i           ( dst_fmt_q           ),
      .kill_i              ( kill_i              ),
      .result_is_special   ( result_is_special   ),
      .result_is_special_q ( result_is_special_q ),
      .result_mant_o       ( pre_round_mant      ),
      .result_exp_o        ( pre_round_exp       ),
      .div_enable_o        ( div_enable          ),
      .sqrt_enable_o       ( sqrt_enable         ),
      .in_ready_o          ( in_ready_o          ),
      .done_o              ( done_o              )
   );

   // ----------------------
   // Pre-round processing
   // ----------------------

   // Pre-round normalization ("small" left shift)
   logic        [PRECISION_BITS+4-1:0] small_shift_mant; // correct significand in case pre_round_mant is 0.1x...x
   logic signed [SUPER_EXP_BITS+2-1:0] small_shift_exp;  // correct exponent in case pre_round_mant is 0.1x...x
   logic                               mant_msb_zero;

   assign mant_msb_zero    = ~pre_round_mant[PRECISION_BITS+4-1]; // is msb zero? (0.1x...x case)
   assign small_shift_mant = mant_msb_zero ? pre_round_mant << 1 : pre_round_mant; // shift one bit to the left if needed
   assign small_shift_exp  = signed'(pre_round_exp - mant_msb_zero); // corrected exponent

   // Second pre-round shift (right shift)
   logic        [SHIFT_AMOUNT_WIDTH-1:0] right_shamt;        // right shift amount
   logic        [PRECISION_BITS+1-1:0]   final_mantissa;     // significand with guard bit
   logic signed [SUPER_EXP_BITS+2-1:0]   final_exponent;     // final exponent in binary64 exponent range
   logic        [PRECISION_BITS+3-1:0]   sticky_bits;        // bits after shift used for sticky bit calculation
   logic                                 sticky_after_shift; // sticky bit value

   // Calculate shift amount
   always_comb begin
      if (small_shift_exp[SUPER_EXP_BITS+1]) begin // negative exponent, subnormal number
         // if exponent is less or equal than -(PRECISION_BITS+1) (guard bit included) significand is only in the sticky bit
         if (small_shift_exp <= signed'(-1*PRECISION_BITS-1))
            right_shamt = PRECISION_BITS + 1; // set shift amount to maximum value
         else // shift amount is abs(exp) + 1
            right_shamt = unsigned'(~small_shift_exp+1 + 1);
      end else if (small_shift_exp == '0) begin // exponent is zero
         right_shamt = (| small_shift_mant); // for subnormal numbers hidden bit is shifted to the right (1 bit shift)
      end else // shift is not needed
         right_shamt = 0;
   end

   // Right shift
   assign {final_mantissa, sticky_bits} = {small_shift_mant, {(PRECISION_BITS){1'b0}} } >> right_shamt;
   // Calculate final exponent
   // If small_shift_exp is negative result is subnormal and exponent is zero
   assign final_exponent                = small_shift_exp[SUPER_EXP_BITS+1] ? '0 : small_shift_exp; 
   assign sticky_after_shift            = (| sticky_bits);

   // ----------------------
   // Rounding
   // ----------------------
   logic                                     pre_round_sign;    // result sign used for rounding
   logic [SUPER_EXP_BITS+SUPER_MAN_BITS-1:0] pre_round_abs;     // absolute value of result before rounding
   logic [1:0]                               round_sticky_bits; // 2 bits needed for rounding

   logic of_before_round, of_after_round; // overflow flags
   logic uf_before_round, uf_after_round; // underflow flags

   // Format specific
   logic [NUM_FORMATS-1:0][SUPER_EXP_BITS+SUPER_MAN_BITS-1:0] fmt_pre_round_abs; // per format
   logic [NUM_FORMATS-1:0][1:0]                               fmt_round_sticky_bits;
   logic [NUM_FORMATS-1:0]                                    fmt_of_after_round;
   logic [NUM_FORMATS-1:0]                                    fmt_uf_after_round;

   // Rounding outputs
   logic                                     rounded_sign;
   logic [SUPER_EXP_BITS+SUPER_MAN_BITS-1:0] rounded_abs; // absolute value of result after rounding
   logic                                     result_zero; // not used
   logic                                     round_up;    // not used

   // Check overflow/underflow before rounding
   assign of_before_round = final_exponent >= 2**(fpuv_pkg::exp_bits(dst_fmt_q))-1;
   assign uf_before_round = final_exponent == 0;

   // Pre-round absolute value calculation
   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin
      // Set up some constants
      localparam int unsigned EXP_BITS  = fpuv_pkg::exp_bits(fpuv_pkg::fp_format_e'(fmt));
      localparam int unsigned MAN_BITS  = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt));
      localparam int unsigned PREC_BITS = MAN_BITS + 1;
      
      logic [EXP_BITS-1:0] pre_round_exponent;
      logic [MAN_BITS-1:0] pre_round_mantissa;

      if (FpFmtConfig[fmt]) begin : active_format
         
         assign pre_round_exponent = (of_before_round) ? 2**EXP_BITS-2 : final_exponent[EXP_BITS-1:0];
         assign pre_round_mantissa = (of_before_round) ? '1 : final_mantissa[SUPER_MAN_BITS-:MAN_BITS];
         // Assemble result before rounding. In case of overflow, the largest normal value is set.
         assign fmt_pre_round_abs[fmt] = {pre_round_exponent, pre_round_mantissa}; // 0-extend

         // Round bit is after mantissa (1 in case of overflow for rounding)
         assign fmt_round_sticky_bits[fmt][1] = final_mantissa[SUPER_MAN_BITS-MAN_BITS] | of_before_round;

         // remaining bits in mantissa to sticky (1 in case of overflow for rounding)
         if (MAN_BITS < SUPER_MAN_BITS) begin : narrow_sticky
            assign fmt_round_sticky_bits[fmt][0] = (| final_mantissa[SUPER_MAN_BITS-MAN_BITS-1:0]) |
                                                   sticky_after_shift | of_before_round;
         end else begin : normal_sticky
            assign fmt_round_sticky_bits[fmt][0] = sticky_after_shift | of_before_round;
         end
      end else begin : inactive_format
         assign fmt_pre_round_abs[fmt]     = '{default: fpuv_pkg::DONT_CARE};
         assign fmt_round_sticky_bits[fmt] = '{default: fpuv_pkg::DONT_CARE};
      end
   end

   // Assemble result before rounding. In case of overflow, the largest normal value is set.
   assign pre_round_sign     = result_sign_q;
   assign pre_round_abs      = fmt_pre_round_abs[dst_fmt_q];

   // In case of overflow, the round and sticky bits are set for proper rounding
   assign round_sticky_bits  = fmt_round_sticky_bits[dst_fmt_q];

   // Perform the rounding
   fpuv_rounding #(
      .AbsWidth ( SUPER_EXP_BITS + SUPER_MAN_BITS )
   ) i_fpuv_rounding (
      .abs_value_i             ( pre_round_abs           ),
      .sign_i                  ( pre_round_sign          ),
      .round_sticky_bits_i     ( round_sticky_bits       ),
      .rnd_mode_i              ( rnd_mode_q              ),
      .effective_subtraction_i ( '0                      ),
      .abs_rounded_o           ( rounded_abs             ),
      .sign_o                  ( rounded_sign            ),
      .exact_zero_o            ( result_zero             ),
      .round_up_o              ( round_up                )
   );

   // Result packing, format specific
   logic [NUM_FORMATS-1:0][WIDTH-1:0] fmt_result;

   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : gen_sign_inject
      // Set up some constants
      localparam int unsigned FP_WIDTH = fpuv_pkg::fp_width(fpuv_pkg::fp_format_e'(fmt));
      localparam int unsigned EXP_BITS = fpuv_pkg::exp_bits(fpuv_pkg::fp_format_e'(fmt));
      localparam int unsigned MAN_BITS = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt));

      if (FpFmtConfig[fmt]) begin : active_format
         always_comb begin : post_process
            // detect of / uf
            fmt_uf_after_round[fmt] = rounded_abs[EXP_BITS+MAN_BITS-1:MAN_BITS] == '0; // denormal
            fmt_of_after_round[fmt] = rounded_abs[EXP_BITS+MAN_BITS-1:MAN_BITS] == '1; // inf exp.

            // Assemble regular result, nan box short ones.
            fmt_result[fmt]               = '1;
            fmt_result[fmt][FP_WIDTH-1:0] = {rounded_sign, rounded_abs[EXP_BITS+MAN_BITS-1:0]};
         end
      end else begin : inactive_format
         assign fmt_uf_after_round[fmt] = fpuv_pkg::DONT_CARE;
         assign fmt_of_after_round[fmt] = fpuv_pkg::DONT_CARE;
         assign fmt_result[fmt]         = '{default: fpuv_pkg::DONT_CARE};
      end
   end

   // Classification after rounding select by destination format
   assign uf_after_round = fmt_uf_after_round[dst_fmt_q];
   assign of_after_round = fmt_of_after_round[dst_fmt_q];
   
   // -----------------
   // Result selection
   // -----------------
   logic [WIDTH-1:0]    regular_result;
   fpuv_pkg::status_t   regular_status;

   // Assemble regular result
   assign regular_result = fmt_result[dst_fmt_q];
   assign regular_status.NV = 1'b0; // only valid cases are handled in regular path
   assign regular_status.DZ = 1'b0; // division by zero is handled in special case path
   assign regular_status.OF = of_before_round | of_after_round;   // rounding can introduce overflow
   assign regular_status.UF = uf_after_round & regular_status.NX; // only inexact results raise UF
   assign regular_status.NX = (| round_sticky_bits) | of_before_round | of_after_round;

   // Select output depending on special case detection
   assign result_o = result_is_special_q ? special_result_q : regular_result;
   assign status_o = result_is_special_q ? special_status_q : regular_status;

endmodule
