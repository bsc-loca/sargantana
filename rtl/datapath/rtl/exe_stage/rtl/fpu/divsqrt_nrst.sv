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
//
// Change history: 04/02/2020 - Removed precision control feature, changed coding style and module name.
//                              Added correction step for division operation when final remainder is negative.
//                              Corrected sticky bit calculation.
//                 09/03/2020 - Added correction step for square root operation.
//

`include "registers.svh"

module divsqrt_nrst #(
   parameter fpuv_pkg::fmt_logic_t FpFmtConfig  = '1,
   parameter int unsigned          ITER_CELLS_NUM = 3,
   // Do not change
   // localparam fpuv_pkg::fp_encoding_t SUPER_FORMAT = fpuv_pkg::super_format(FpFmtConfig),
   // localparam int unsigned SUPER_MAN_BITS = SUPER_FORMAT.man_bits,
   localparam int unsigned SUPER_MAN_BITS = fpuv_pkg::man_bits(fpuv_pkg::FP64),
   // localparam int unsigned SUPER_EXP_BITS = SUPER_FORMAT.exp_bits,
   localparam int unsigned SUPER_EXP_BITS = fpuv_pkg::exp_bits(fpuv_pkg::FP64),
   localparam int unsigned PRECISION_BITS = SUPER_MAN_BITS + 1,
   localparam int unsigned NUM_FORMATS = fpuv_pkg::NUM_FP_FORMATS
)(
   input  logic                        clk_i,
   input  logic                        rst_ni,
   // Input signals
   input  logic [PRECISION_BITS-1:0]   dividend_i,
   input  logic [SUPER_EXP_BITS+2-1:0] dividend_exp_i,
   input  logic [PRECISION_BITS-1:0]   divisor_i,
   input  logic [SUPER_EXP_BITS+2-1:0] divisor_exp_i,
   input  logic                        div_start_i,
   input  logic                        sqrt_start_i,
   input  logic                        start_i,
   input  fpuv_pkg::fp_format_e        dst_fmt_i,
   input  logic                        kill_i,
   input  logic                        result_is_special,
   input  logic                        result_is_special_q,
   // Output signals
   output logic [PRECISION_BITS+4-1:0] result_mant_o,
   output logic [SUPER_EXP_BITS+2-1:0] result_exp_o,
   output logic                        div_enable_o,
   output logic                        sqrt_enable_o,
   output logic                        in_ready_o,
   output logic                        done_o

);
   // ----------
   // Constants
   // ----------
   localparam int unsigned FP32_MANT_BITS    = fpuv_pkg::man_bits(fpuv_pkg::FP32);
   localparam int unsigned FP16_MANT_BITS    = fpuv_pkg::man_bits(fpuv_pkg::FP16);
   localparam int unsigned FP16ALT_MANT_BITS = fpuv_pkg::man_bits(fpuv_pkg::FP16ALT);
   localparam int unsigned PREC_EXT_BITS     = PRECISION_BITS + 1 + 4; // p + sign bit + 4 bits for rounding

   logic [PREC_EXT_BITS-1:0]   part_remainder, part_remainder_next; // p + sign bit + 4 bits for rounding
   logic [PREC_EXT_BITS-1-1:0] quotient, quotient_next;             // p + 4 bits for rounding

   logic [PRECISION_BITS+1-1:0] dividend_sgn;     // sign extended dividend/radicand
   logic [PRECISION_BITS+1-1:0] divisor_sgn;      // sign extended divisor
   logic [PREC_EXT_BITS-1:0]    dividend_sgn_ext; // extended dividend for first iteration
   logic [PREC_EXT_BITS-1:0]    divisor_sgn_comp; // 1's complement of divisor extended with rounding bits

   // Sign extensions: both numbers are always positive
   assign dividend_sgn = {1'b0, dividend_i};
   assign divisor_sgn  = {1'b0, divisor_i};

   // Divisor 1's complement calculation, format specific
   logic [NUM_FORMATS-1:0][PREC_EXT_BITS-1:0] fmt_divisor_comp; // precision bits + sign bit + rounding bits
   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : divisor_complement
      // Precision bits for every format
      localparam int unsigned FMT_PREC_BITS = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt)) + 1; // mantissa bits + implicit bit
      // Generate for enabled formats
      if (FpFmtConfig[fmt]) begin : active_format
         // Complement FMT_PREC_BITS + sign bit
         // Add bits for rounding, guard bit is set to '1' (later used for 2's complement calculation)
         // For narrower formats divisor complement is stored in upper FMT_PREC_BITS+1, lower bits are set to '0'
         assign fmt_divisor_comp[fmt] = { ~divisor_sgn[PRECISION_BITS+1-1:PRECISION_BITS-FMT_PREC_BITS], 4'b1000, {(PRECISION_BITS-FMT_PREC_BITS){1'b0}} };
      end else begin : inactive_format
         assign fmt_divisor_comp[fmt] = '{default: fpuv_pkg::DONT_CARE}; // format disabled
      end
   end
   assign divisor_sgn_comp = fmt_divisor_comp[dst_fmt_i]; // assign divisor 1's complement for destination format

   // Dividend preparation for first iteration, format specific
   logic [NUM_FORMATS-1:0][PREC_EXT_BITS-1:0] fmt_dividend_ext; // precision bits + sign bit + rounding bits
   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : dividend_prep
      // Precision bits for every format
      localparam int unsigned FMT_PREC_BITS = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt)) + 1; // mantissa bits + implicit bit
      // Generate for enabled formats
      if (FpFmtConfig[fmt]) begin : active_format
         // Add bits for rounding, guard bit is '1' (later used for 2's complement calculation)
         // For narrower formats dividend is stored in upper FMT_PREC_BITS+1, lower bits are set to '0'
         assign fmt_dividend_ext[fmt] = { dividend_sgn[PRECISION_BITS+1-1:PRECISION_BITS-FMT_PREC_BITS], 4'b1000, {(PRECISION_BITS-FMT_PREC_BITS){1'b0}} };
      end else begin : inactive_format
         assign fmt_dividend_ext[fmt] = '{default: fpuv_pkg::DONT_CARE}; // format disabled
      end
   end
   assign dividend_sgn_ext = fmt_dividend_ext[dst_fmt_i]; // assign extended dividend for destination format

   logic [5:0] iter_number, iter_cnt; // todo: replace '5' with parameter 

   // Determine number of cycles needed for result calculation
   // Number of cycles = p / m
   // p - precision bits + bits for rounding
   // m - number of iteration cells 
   generate 
      case (ITER_CELLS_NUM)
         1: begin : iter_num_one // generate for one iteration cell
            always_comb begin 
               unique case (dst_fmt_i)
                  fpuv_pkg::FP32:    iter_number = 6'h1a; // 28 = 23 bits + implicit bit + 3 bits for rounding
                  fpuv_pkg::FP64:    iter_number = 6'h38; // 57 = 52 bits + implicit bit + 4 bits for rounding
                  fpuv_pkg::FP16:    iter_number = 6'h0e; // 15 = 10 bits + implicit bit + 4 bits for rounding
                  fpuv_pkg::FP8:     iter_number = 6'h0e; // FP8 is mapped to FP16
                  fpuv_pkg::FP16ALT: iter_number = 6'h0b; // 12 = 7 bits + implicit bit + 4 bits for rounding
                  default:           iter_number = 6'h38; // default is FP64
               endcase
            end
         end
         2: begin : iter_num_two // generate for two iteration cells
            always_comb begin
               unique case (dst_fmt_i)
                  fpuv_pkg::FP32:    iter_number = 6'h0d; // 14 = (23 bits + implicit bit + 4 bits for rounding) / 2
                  fpuv_pkg::FP64:    iter_number = 6'h1b; // 28 = (52 bits + implicit bit + 3 bits for rounding) / 2
                  fpuv_pkg::FP16:    iter_number = 6'h06; // 7  = (10 bits + implicit bit + 3 bits for rounding) / 2
                  fpuv_pkg::FP8:     iter_number = 6'h06; // FP8 is mapped to FP16
                  fpuv_pkg::FP16ALT: iter_number = 6'h05; // 6  = (7 bits + implicit bit + 4 bits for rounding) / 2
                  default:           iter_number = 6'h1b; // default is FP64
               endcase
            end
         end
         3: begin : iter_num_three // generate for three iteration cells
            always_comb begin
               unique case (dst_fmt_i)
                  fpuv_pkg::FP32:    iter_number = 6'h08; // 9  = (23 bits + implicit bit + 3 bits for rounding) / 3
                  fpuv_pkg::FP64:    iter_number = 6'h12; // 19 = (52 bits + implicit bit + 4 bits for rounding) / 3
                  fpuv_pkg::FP16:    iter_number = 6'h04; // 5  = (10 bits + implicit bit + 4 bits for rounding) / 3
                  fpuv_pkg::FP8:     iter_number = 6'h04; // FP8 is mapped to FP16
                  fpuv_pkg::FP16ALT: iter_number = 6'h03; // 4  = (7 bits + implicit bit + 4 bits for rounding) / 3
                  default:           iter_number = 6'h12; // default is FP64
               endcase
            end
         end
         4: begin : iter_num_four // generate for four iteration cells
            always_comb begin
               unique case (dst_fmt_i)
                  fpuv_pkg::FP32:    iter_number = 6'h06; // 7  = (23 bits + implicit bit + 4 bits for rounding) / 4
                  fpuv_pkg::FP64:    iter_number = 6'h0d; // 14 = (52 bits + implicit bit + 3 bits for rounding) / 4
                  fpuv_pkg::FP16:    iter_number = 6'h03; // 4  = (10 bits + implicit bit + 4 bits for rounding) / 4
                  fpuv_pkg::FP8:     iter_number = 6'h03; // FP8 is mapped to FP16
                  fpuv_pkg::FP16ALT: iter_number = 6'h02; // 3  = (7 bits + implicit bit + 4 bits for rounding) / 4
                  default:           iter_number = 6'h0d; // default is FP64
               endcase
            end
         end
      endcase
   endgenerate

   // ---------------
   // Control logic
   // ---------------
   logic div_start_q, sqrt_start_q, start_q; // delayed start signals
   assign start_q = div_start_q | sqrt_start_q;

   // Generate div_start_q signal
   always_ff @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni)
         div_start_q <= 1'b0;
      else if (div_start_i && in_ready_o)
         div_start_q <= 1'b1;
      else
         div_start_q <= 1'b0;
   end

   // Generate div_enable_o signal
   always_ff @(posedge clk_i, negedge rst_ni) begin  
      if (~rst_ni)
         div_enable_o <= 1'b0;
      // Synchronous reset with Flush
      else if (kill_i)
         div_enable_o <= 1'b0;
      else if (div_start_i && in_ready_o)
         div_enable_o <= 1'b1;
      else if (done_o)
         div_enable_o <= 1'b0;
      else
         div_enable_o <= div_enable_o;
   end

   // Generate sqrt_start_q signal
   always_ff @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni)
         sqrt_start_q <= 1'b0;
      else if (sqrt_start_i && in_ready_o)
         sqrt_start_q <= 1'b1;
      else
         sqrt_start_q <= 1'b0;
   end

   // Generate sqrt_enable_o signal
   always_ff @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni)
         sqrt_enable_o <= 1'b0;
      else if (kill_i)
         sqrt_enable_o <= 1'b0;
      else if (sqrt_start_i && in_ready_o)
         sqrt_enable_o <= 1'b1;
      else if (done_o)
         sqrt_enable_o <= 1'b0;
      else
         sqrt_enable_o <= sqrt_enable_o;
   end

   logic fsm_enable;  // enable quotient and partial remainder calculation
   logic final_state; // last iteration flag

   // Disable iterations when result is special or kill_i is asserted
   assign fsm_enable  = ((start_q | (| iter_cnt)) && (~kill_i) && ~result_is_special_q);
   assign final_state = iter_cnt == iter_number; // '1' for last iteration

   // Iteration counter
   always_ff @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni)
         iter_cnt <= '0;
      else if (final_state) // reset counter on the final state
         iter_cnt <= '0;
      else if (fsm_enable) // one cycle after start_i is asserted
         iter_cnt <= iter_cnt + 1;
      else
         iter_cnt <= '0;
   end

   // Generate done_o 
   always_ff @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni)
         done_o <= 1'b0;
      else if (start_i && in_ready_o) begin
         if (result_is_special) // if result is special bypass div/sqrt
            done_o <= 1'b1;
         else
            done_o <= 1'b0;
      end else if (final_state)
         done_o <= 1'b1;
      else
         done_o <= 1'b0;
   end

   // Generate in_ready_o
   always_ff @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni)
         in_ready_o <= 1'b1;
      else if (start_i && in_ready_o) begin
         if (result_is_special) // if result is special output is ready
            in_ready_o <= 1'b1;
         else
            in_ready_o <= 1'b0;
      end else if (final_state | kill_i) // output is ready after final iteration
         in_ready_o <= 1'b1;
      else
         in_ready_o <= in_ready_o;
   end

   // ---------------------------------------
   // Iteration inputs processing for sqrt
   // ---------------------------------------
   logic [0:ITER_CELLS_NUM-1]                    iter_cell_carry; // iteration cell carry out
   logic [0:ITER_CELLS_NUM-1][PREC_EXT_BITS-1:0] iter_cell_sum;   // iteration cell sum

   logic [ITER_CELLS_NUM+1-1:0][PREC_EXT_BITS-1:0] sqrt_r;       // square root partial remainder
   logic [ITER_CELLS_NUM-1:0]  [PREC_EXT_BITS-1:0] sqrt_q;       // iteration cells inputs (result or result complement)
   logic [ITER_CELLS_NUM-1:0]  [PREC_EXT_BITS-1:0] q_sqrt;       // result after n iterations used for next partial remainder calculation
   logic [ITER_CELLS_NUM-1:0]  [PREC_EXT_BITS-1:0] q_sqrt_compl; // result complement used for next partial remainder calculation

   logic [ITER_CELLS_NUM-1:0][1:0] sqrt_di; // two radicand bits starting from MSBs
   logic [ITER_CELLS_NUM-1:0][1:0] sqrt_do; // iteration cell output, next partial remainder LSBs

   logic [ITER_CELLS_NUM-1:0] sqrt_quotient; // result digits calculated in one iteration (max. 4 digits)

   // If exponent is not even, shift radicand one bit to the right
   logic [PRECISION_BITS+1-1:0] sqrt_mant; // extended with one bit to cover odd exponent case
   assign sqrt_mant = dividend_exp_i[0] ? {1'b0, dividend_i} : {dividend_i, 1'b0};

   // Calculate result 1's complement for every iteration cell, format specific
   logic [ITER_CELLS_NUM-1:0][NUM_FORMATS-1:0][PREC_EXT_BITS-1:0] fmt_q_sqrt_com;
   for (genvar i = 0; i < int'(ITER_CELLS_NUM); i++) begin: iter_fmt_qsqrt_com
      for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : fmt_qsqrt_com
         // Precision bits for every format
         localparam int unsigned FP_PREC = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt)) + 1;
         // Generate for enabled formats
         if (FpFmtConfig[fmt]) begin : active_format
            // For narrower formats complement is stored in lower FP_PREC_BITS+1+4 bits, upper bits are set to '0'
            assign fmt_q_sqrt_com[i][fmt] = { {(PRECISION_BITS-FP_PREC) {1'b0}}, ~q_sqrt[i][FP_PREC+1+4-1:0] };
         end else begin : inactive_format
            assign fmt_q_sqrt_com[i][fmt] = '{default: fpuv_pkg::DONT_CARE};
         end
      end
      // Assign result complement according to destination format
      assign q_sqrt_compl[i] = fmt_q_sqrt_com[i][dst_fmt_i];
   end

   // Get calculated result digits, format specific
   logic [NUM_FORMATS-1:0][ITER_CELLS_NUM-1:0] fmt_sqrt_quotient;
   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : sqrt_quotient_fmt
      // Precision bits for every format
      localparam int unsigned FP_PREC = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt)) + 1;
      // Generate for enabled formats
      if (FpFmtConfig[fmt]) begin : active_format
         // For narrower formats result digit is in iter_cell_sum
         if (FP_PREC < PRECISION_BITS) begin : narrower_fmt
            for (genvar i = 0; i < ITER_CELLS_NUM; i++) begin
               assign fmt_sqrt_quotient[fmt][ITER_CELLS_NUM-1-i] = ~iter_cell_sum[i][FP_PREC+4];
            end
         // For binary64 format, result digits are output carries
         end else begin
            for (genvar i = 0; i < ITER_CELLS_NUM; i++) begin
               assign fmt_sqrt_quotient[fmt][ITER_CELLS_NUM-1-i] = iter_cell_carry[i];
            end
         end
      end else begin : inactive_format
         assign fmt_sqrt_quotient[fmt] = '{default: fpuv_pkg::DONT_CARE};
      end
   end
   // Assign result digits according to destination format
   assign sqrt_quotient = fmt_sqrt_quotient[dst_fmt_i];

   // Result digits used for next partial remainder calculation
   generate 
      case (ITER_CELLS_NUM)
         1: begin // generate for one iteration unit
            // One result digit is caclulated per iteration
            logic        qcnt_iter_0;  logic        qcnt_iter_1;  logic [1:0]  qcnt_iter_2;
            logic [2:0]  qcnt_iter_3;  logic [3:0]  qcnt_iter_4;  logic [4:0]  qcnt_iter_5;
            logic [5:0]  qcnt_iter_6;  logic [6:0]  qcnt_iter_7;  logic [7:0]  qcnt_iter_8;
            logic [8:0]  qcnt_iter_9;  logic [9:0]  qcnt_iter_10; logic [10:0] qcnt_iter_11;
            logic [11:0] qcnt_iter_12; logic [12:0] qcnt_iter_13; logic [13:0] qcnt_iter_14;
            logic [14:0] qcnt_iter_15; logic [15:0] qcnt_iter_16; logic [16:0] qcnt_iter_17;
            logic [17:0] qcnt_iter_18; logic [18:0] qcnt_iter_19; logic [19:0] qcnt_iter_20;
            logic [20:0] qcnt_iter_21; logic [21:0] qcnt_iter_22; logic [22:0] qcnt_iter_23;
            logic [23:0] qcnt_iter_24; logic [24:0] qcnt_iter_25; logic [25:0] qcnt_iter_26;
            logic [26:0] qcnt_iter_27; logic [27:0] qcnt_iter_28; logic [28:0] qcnt_iter_29;
            logic [29:0] qcnt_iter_30; logic [30:0] qcnt_iter_31; logic [31:0] qcnt_iter_32;
            logic [32:0] qcnt_iter_33; logic [33:0] qcnt_iter_34; logic [34:0] qcnt_iter_35;
            logic [35:0] qcnt_iter_36; logic [36:0] qcnt_iter_37; logic [37:0] qcnt_iter_38;
            logic [38:0] qcnt_iter_39; logic [39:0] qcnt_iter_40; logic [40:0] qcnt_iter_41;
            logic [41:0] qcnt_iter_42; logic [42:0] qcnt_iter_43; logic [43:0] qcnt_iter_44;
            logic [44:0] qcnt_iter_45; logic [45:0] qcnt_iter_46; logic [46:0] qcnt_iter_47;
            logic [47:0] qcnt_iter_48; logic [48:0] qcnt_iter_49; logic [49:0] qcnt_iter_50;
            logic [50:0] qcnt_iter_51; logic [51:0] qcnt_iter_52; logic [52:0] qcnt_iter_53;
            logic [53:0] qcnt_iter_54; logic [54:0] qcnt_iter_55; logic [55:0] qcnt_iter_56;

            // Assign result for every iteration
            assign qcnt_iter_0  = {1'b0          }; assign qcnt_iter_1  = {quotient[0]   }; assign qcnt_iter_2  = {quotient[1:0] };
            assign qcnt_iter_3  = {quotient[2:0] }; assign qcnt_iter_4  = {quotient[3:0] }; assign qcnt_iter_5  = {quotient[4:0] };
            assign qcnt_iter_6  = {quotient[5:0] }; assign qcnt_iter_7  = {quotient[6:0] }; assign qcnt_iter_8  = {quotient[7:0] };
            assign qcnt_iter_9  = {quotient[8:0] }; assign qcnt_iter_10 = {quotient[9:0] }; assign qcnt_iter_11 = {quotient[10:0]};
            assign qcnt_iter_12 = {quotient[11:0]}; assign qcnt_iter_13 = {quotient[12:0]}; assign qcnt_iter_14 = {quotient[13:0]};
            assign qcnt_iter_15 = {quotient[14:0]}; assign qcnt_iter_16 = {quotient[15:0]}; assign qcnt_iter_17 = {quotient[16:0]};
            assign qcnt_iter_18 = {quotient[17:0]}; assign qcnt_iter_19 = {quotient[18:0]}; assign qcnt_iter_20 = {quotient[19:0]};
            assign qcnt_iter_21 = {quotient[20:0]}; assign qcnt_iter_22 = {quotient[21:0]}; assign qcnt_iter_23 = {quotient[22:0]};
            assign qcnt_iter_24 = {quotient[23:0]}; assign qcnt_iter_25 = {quotient[24:0]}; assign qcnt_iter_26 = {quotient[25:0]};
            assign qcnt_iter_27 = {quotient[26:0]}; assign qcnt_iter_28 = {quotient[27:0]}; assign qcnt_iter_29 = {quotient[28:0]};
            assign qcnt_iter_30 = {quotient[29:0]}; assign qcnt_iter_31 = {quotient[30:0]}; assign qcnt_iter_32 = {quotient[31:0]};
            assign qcnt_iter_33 = {quotient[32:0]}; assign qcnt_iter_34 = {quotient[33:0]}; assign qcnt_iter_35 = {quotient[34:0]};
            assign qcnt_iter_36 = {quotient[35:0]}; assign qcnt_iter_37 = {quotient[36:0]}; assign qcnt_iter_38 = {quotient[37:0]};
            assign qcnt_iter_39 = {quotient[38:0]}; assign qcnt_iter_40 = {quotient[39:0]}; assign qcnt_iter_41 = {quotient[40:0]};
            assign qcnt_iter_42 = {quotient[41:0]}; assign qcnt_iter_43 = {quotient[42:0]}; assign qcnt_iter_44 = {quotient[43:0]};
            assign qcnt_iter_45 = {quotient[44:0]}; assign qcnt_iter_46 = {quotient[45:0]}; assign qcnt_iter_47 = {quotient[46:0]};
            assign qcnt_iter_48 = {quotient[47:0]}; assign qcnt_iter_49 = {quotient[48:0]}; assign qcnt_iter_50 = {quotient[49:0]};
            assign qcnt_iter_51 = {quotient[50:0]}; assign qcnt_iter_52 = {quotient[51:0]}; assign qcnt_iter_53 = {quotient[52:0]};
            assign qcnt_iter_54 = {quotient[53:0]}; assign qcnt_iter_55 = {quotient[54:0]}; assign qcnt_iter_56 = {quotient[55:0]};

            always_comb begin // the intermediate operands for sqrt
               unique case (iter_cnt)
                  6'b000000: begin // 0
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS:PRECISION_BITS-1];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-1){1'b0}}, qcnt_iter_0};
                  end
                  6'b000001: begin // 1
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-2:PRECISION_BITS-1-2];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-1){1'b0}}, qcnt_iter_1};
                  end
                  6'b000010: begin // 2
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-4:PRECISION_BITS-1-4];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-2){1'b0}}, qcnt_iter_2};
                  end
                  6'b000011: begin // 3
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-6:PRECISION_BITS-1-6];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-3){1'b0}}, qcnt_iter_3};
                  end
                  6'b000100: begin // 4
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-8:PRECISION_BITS-1-8];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-4){1'b0}}, qcnt_iter_4};
                  end
                  6'b000101: begin // 5
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-10:PRECISION_BITS-1-10];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-5){1'b0}}, qcnt_iter_5};
                  end
                  6'b000110: begin // 6
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-12:PRECISION_BITS-1-12];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-6){1'b0}}, qcnt_iter_6};
                  end
                  6'b000111: begin // 7
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-14:PRECISION_BITS-1-14];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-7){1'b0}}, qcnt_iter_7};
                  end
                  6'b001000: begin // 8
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-16:PRECISION_BITS-1-16];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-8){1'b0}}, qcnt_iter_8};
                  end
                  6'b001001: begin // 9
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-18:PRECISION_BITS-1-18];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-9){1'b0}}, qcnt_iter_9};
                  end
                  6'b001010: begin // 10
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-20:PRECISION_BITS-1-20];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-10){1'b0}}, qcnt_iter_10};
                  end
                  6'b001011: begin // 11
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-22:PRECISION_BITS-1-22];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-11){1'b0}}, qcnt_iter_11};
                  end
                  6'b001100: begin // 12
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-24:PRECISION_BITS-1-24];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-12){1'b0}}, qcnt_iter_12};
                  end
                  6'b001101: begin // 13
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-26:PRECISION_BITS-1-26];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-13){1'b0}}, qcnt_iter_13};
                  end
                  6'b001110: begin // 14
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-28:PRECISION_BITS-1-28];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-14){1'b0}}, qcnt_iter_14};
                  end
                  6'b001111: begin // 15
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-30:PRECISION_BITS-1-30];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-15){1'b0}}, qcnt_iter_15};
                  end
                  6'b010000: begin // 16
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-32:PRECISION_BITS-1-32];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-16){1'b0}}, qcnt_iter_16};
                  end
                  6'b010001: begin // 17
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-34:PRECISION_BITS-1-34];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-17){1'b0}}, qcnt_iter_17};
                  end
                  6'b010010: begin // 18
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-36:PRECISION_BITS-1-36];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-18){1'b0}}, qcnt_iter_18};
                  end
                  6'b010011: begin // 19
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-38:PRECISION_BITS-1-38];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-19){1'b0}}, qcnt_iter_19};
                  end
                  6'b010100: begin // 20
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-40:PRECISION_BITS-1-40];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-20){1'b0}}, qcnt_iter_20};
                  end
                  6'b010101: begin // 21
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-42:PRECISION_BITS-1-42];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-21){1'b0}}, qcnt_iter_21};
                  end
                  6'b010110: begin // 22
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-44:PRECISION_BITS-1-44];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-22){1'b0}}, qcnt_iter_22};
                  end
                  6'b010111: begin // 23
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-46:PRECISION_BITS-1-46];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-23){1'b0}}, qcnt_iter_23};
                  end
                  6'b011000: begin // 24
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-48:PRECISION_BITS-1-48];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-24){1'b0}}, qcnt_iter_24};
                  end
                  6'b011001: begin // 25
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-50:PRECISION_BITS-1-50];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-25){1'b0}}, qcnt_iter_25};
                  end
                  6'b011010: begin // 26
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-52:PRECISION_BITS-1-52];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-26){1'b0}}, qcnt_iter_26};
                  end
                  6'b011011: begin // 27
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-27){1'b0}}, qcnt_iter_27};
                  end
                  6'b011100: begin // 28
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-28){1'b0}}, qcnt_iter_28};
                  end
                  6'b011101: begin // 29
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-29){1'b0}}, qcnt_iter_29};
                  end
                  6'b011110: begin // 30
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-30){1'b0}}, qcnt_iter_30};
                  end
                  6'b011111: begin // 31
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-31){1'b0}}, qcnt_iter_31};
                  end
                  6'b100000: begin // 32
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-32){1'b0}}, qcnt_iter_32};
                  end
                  6'b100001: begin // 33
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-33){1'b0}}, qcnt_iter_33};
                  end
                  6'b100010: begin // 34
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-34){1'b0}}, qcnt_iter_34};
                  end
                  6'b100011: begin // 35
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-35){1'b0}}, qcnt_iter_35};
                  end
                  6'b100100: begin // 36
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-36){1'b0}}, qcnt_iter_36};
                  end
                  6'b100101: begin // 37
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-37){1'b0}}, qcnt_iter_37};
                  end
                  6'b100110: begin // 38
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-38){1'b0}}, qcnt_iter_38};
                  end
                  6'b100111: begin // 39
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-39){1'b0}}, qcnt_iter_39};
                  end
                  6'b101000: begin // 40
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-40){1'b0}}, qcnt_iter_40};
                  end
                  6'b101001: begin // 41
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-41){1'b0}}, qcnt_iter_41};
                  end
                  6'b101010: begin // 42
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-42){1'b0}}, qcnt_iter_42};
                  end
                  6'b101011: begin // 43
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-43){1'b0}}, qcnt_iter_43};
                  end
                  6'b101100: begin // 44
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-44){1'b0}}, qcnt_iter_44};
                  end
                  6'b101101: begin // 45
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-45){1'b0}}, qcnt_iter_45};
                  end
                  6'b101110: begin // 46
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-46){1'b0}}, qcnt_iter_46};
                  end
                  6'b101111: begin // 47
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-47){1'b0}}, qcnt_iter_47};
                  end
                  6'b110000: begin // 48
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-48){1'b0}}, qcnt_iter_48};
                  end
                  6'b110001: begin // 49
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-49){1'b0}}, qcnt_iter_49};
                  end
                  6'b110010: begin // 50
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-50){1'b0}}, qcnt_iter_50};
                  end
                  6'b110011: begin // 51
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-51){1'b0}}, qcnt_iter_51};
                  end
                  6'b110100: begin // 52
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-52){1'b0}}, qcnt_iter_52};
                  end
                  6'b110101: begin // 53
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-53){1'b0}}, qcnt_iter_53};
                  end
                  6'b110110: begin // 54
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-54){1'b0}}, qcnt_iter_54};
                  end
                  6'b110111: begin // 55
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-55){1'b0}}, qcnt_iter_55};
                  end
                  6'b111000: begin // 56
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-56){1'b0}}, qcnt_iter_56};
                  end
                  default: begin
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = '0;
                  end
               endcase

               sqrt_q[0] = (iter_cnt == 0 | quotient[0]) ? q_sqrt_compl[0] : q_sqrt[0];
            end
         end

         2: begin // generate for two iteration units
            // Two result digits are caclulated per iteration
            logic [1:0]  qcnt_iter_0;  logic [2:0]  qcnt_iter_1;  logic [4:0]  qcnt_iter_2;
            logic [6:0]  qcnt_iter_3;  logic [8:0]  qcnt_iter_4;  logic [10:0] qcnt_iter_5;
            logic [12:0] qcnt_iter_6;  logic [14:0] qcnt_iter_7;  logic [16:0] qcnt_iter_8;
            logic [18:0] qcnt_iter_9;  logic [20:0] qcnt_iter_10; logic [22:0] qcnt_iter_11;
            logic [24:0] qcnt_iter_12; logic [26:0] qcnt_iter_13; logic [28:0] qcnt_iter_14;
            logic [30:0] qcnt_iter_15; logic [32:0] qcnt_iter_16; logic [34:0] qcnt_iter_17;
            logic [36:0] qcnt_iter_18; logic [38:0] qcnt_iter_19; logic [40:0] qcnt_iter_20;
            logic [42:0] qcnt_iter_21; logic [44:0] qcnt_iter_22; logic [46:0] qcnt_iter_23;
            logic [48:0] qcnt_iter_24; logic [50:0] qcnt_iter_25; logic [52:0] qcnt_iter_26;
            logic [54:0] qcnt_iter_27; logic [56:0] qcnt_iter_28;

            // Assign result for every iteration
            assign  qcnt_iter_0  = {1'b0,           sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_1  = {quotient[1:0],  sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_2  = {quotient[3:0],  sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_3  = {quotient[5:0],  sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_4  = {quotient[7:0],  sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_5  = {quotient[9:0],  sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_6  = {quotient[11:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_7  = {quotient[13:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_8  = {quotient[15:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_9  = {quotient[17:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_10 = {quotient[19:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_11 = {quotient[21:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_12 = {quotient[23:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_13 = {quotient[25:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_14 = {quotient[27:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_15 = {quotient[29:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_16 = {quotient[31:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_17 = {quotient[33:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_18 = {quotient[35:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_19 = {quotient[37:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_20 = {quotient[39:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_21 = {quotient[41:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_22 = {quotient[43:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_23 = {quotient[45:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_24 = {quotient[47:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_25 = {quotient[49:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_26 = {quotient[51:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_27 = {quotient[53:0], sqrt_quotient[ITER_CELLS_NUM-1]};
            assign  qcnt_iter_28 = {quotient[55:0], sqrt_quotient[ITER_CELLS_NUM-1]};

            always_comb begin
               case(iter_cnt)
                  6'b000000: begin // 0
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS:PRECISION_BITS-1];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-1){1'b0}}, qcnt_iter_0[1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-2:PRECISION_BITS-1-2];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-2){1'b0}}, qcnt_iter_0[1:0]};
                  end
                  6'b000001: begin // 1
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-4:PRECISION_BITS-1-4];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-2){1'b0}}, qcnt_iter_1[2:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-6:PRECISION_BITS-1-6];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-3){1'b0}}, qcnt_iter_1[2:0]};
                  end
                  6'b000010: begin // 2
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-8:PRECISION_BITS-1-8];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-4){1'b0}}, qcnt_iter_2[4:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-10:PRECISION_BITS-1-10];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-5){1'b0}}, qcnt_iter_2[4:0]};
                  end
                  6'b000011: begin // 3
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-12:PRECISION_BITS-1-12];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-6){1'b0}}, qcnt_iter_3[6:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-14:PRECISION_BITS-1-14];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-7){1'b0}}, qcnt_iter_3[6:0]};
                  end
                  6'b000100: begin // 4
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-16:PRECISION_BITS-1-16];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-8){1'b0}}, qcnt_iter_4[8:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-18:PRECISION_BITS-1-18];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-9){1'b0}}, qcnt_iter_4[8:0]};
                  end
                  6'b000101: begin // 5
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-20:PRECISION_BITS-1-20];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-10){1'b0}}, qcnt_iter_5[10:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-22:PRECISION_BITS-1-22];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-11){1'b0}}, qcnt_iter_5[10:0]};
                  end
                  6'b000110: begin // 6
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-24:PRECISION_BITS-1-24];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-12){1'b0}}, qcnt_iter_6[12:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-26:PRECISION_BITS-1-26];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-13){1'b0}}, qcnt_iter_6[12:0]};
                  end
                  6'b000111: begin // 7
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-28:PRECISION_BITS-1-28];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-14){1'b0}}, qcnt_iter_7[14:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-30:PRECISION_BITS-1-30];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-15){1'b0}}, qcnt_iter_7[14:0]};
                  end
                  6'b001000: begin // 8
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-32:PRECISION_BITS-1-32];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-16){1'b0}}, qcnt_iter_8[16:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-34:PRECISION_BITS-1-34];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-17){1'b0}}, qcnt_iter_8[16:0]};
                  end
                  6'b001001: begin // 9
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-36:PRECISION_BITS-1-36];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-18){1'b0}}, qcnt_iter_9[18:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-38:PRECISION_BITS-1-38];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-19){1'b0}}, qcnt_iter_9[18:0]};
                  end
                  6'b001010: begin // 10
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-40:PRECISION_BITS-1-40];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-20){1'b0}}, qcnt_iter_10[20:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-42:PRECISION_BITS-1-42];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-21){1'b0}}, qcnt_iter_10[20:0]};
                  end
                  6'b001011: begin // 11
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-44:PRECISION_BITS-1-44];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-22){1'b0}}, qcnt_iter_11[22:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-46:PRECISION_BITS-1-46];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-23){1'b0}}, qcnt_iter_11[22:0]};
                  end
                  6'b001100: begin // 12
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-48:PRECISION_BITS-1-48];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-24){1'b0}}, qcnt_iter_12[24:1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-50:PRECISION_BITS-1-50];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-25){1'b0}}, qcnt_iter_12[24:0]};
                  end
                  6'b001101: begin // 13
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-52:PRECISION_BITS-1-52];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-26){1'b0}}, qcnt_iter_13[26:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-27){1'b0}}, qcnt_iter_13[26:0]};
                  end
                  6'b001110: begin // 14
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-28){1'b0}}, qcnt_iter_14[28:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-29){1'b0}}, qcnt_iter_14[28:0]};
                  end
                  6'b001111: begin // 15
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-30){1'b0}}, qcnt_iter_15[30:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-31){1'b0}}, qcnt_iter_15[30:0]};
                  end
                  6'b010000: begin // 16
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-32){1'b0}}, qcnt_iter_16[32:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-33){1'b0}}, qcnt_iter_16[32:0]};
                  end
                  6'b010001: begin // 17
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-34){1'b0}}, qcnt_iter_17[34:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-35){1'b0}}, qcnt_iter_17[34:0]};
                  end
                  6'b010010: begin // 18
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-36){1'b0}}, qcnt_iter_18[36:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-37){1'b0}}, qcnt_iter_18[36:0]};
                  end
                  6'b010011: begin // 19
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-38){1'b0}}, qcnt_iter_19[38:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-39){1'b0}}, qcnt_iter_19[38:0]};
                  end
                  6'b010100: begin // 20
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-40){1'b0}}, qcnt_iter_20[40:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-41){1'b0}}, qcnt_iter_20[40:0]};
                  end
                  6'b010101: begin // 21
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-42){1'b0}}, qcnt_iter_21[42:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-43){1'b0}}, qcnt_iter_21[42:0]};
                  end
                  6'b010110: begin // 22
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-44){1'b0}}, qcnt_iter_22[44:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-45){1'b0}}, qcnt_iter_22[44:0]};
                  end
                  6'b010111: begin // 23
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-46){1'b0}}, qcnt_iter_23[46:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-47){1'b0}}, qcnt_iter_23[46:0]};
                  end
                  6'b011000: begin // 24
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-48){1'b0}}, qcnt_iter_24[48:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-49){1'b0}}, qcnt_iter_24[48:0]};
                  end
                  6'b011001: begin // 25
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-50){1'b0}}, qcnt_iter_25[50:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-51){1'b0}}, qcnt_iter_25[50:0]};
                  end
                  6'b011010: begin // 26
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-52){1'b0}}, qcnt_iter_26[52:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-53){1'b0}}, qcnt_iter_26[52:0]};
                  end
                  6'b011011: begin // 27
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-54){1'b0}}, qcnt_iter_27[54:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-55){1'b0}}, qcnt_iter_27[54:0]};
                  end
                  6'b011100: begin // 28
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-56){1'b0}}, qcnt_iter_28[56:1]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-57){1'b0}}, qcnt_iter_28[56:0]};
                  end
                  default: begin
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS:PRECISION_BITS-1];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-1){1'b0}}, qcnt_iter_0[1]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-2:PRECISION_BITS-1-2];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-2){1'b0}}, qcnt_iter_0[1:0]};
                  end
               endcase

               sqrt_q[0] = (iter_cnt == 0 | quotient[0]) ? q_sqrt_compl[0] : q_sqrt[0];
               sqrt_q[1] = sqrt_quotient[ITER_CELLS_NUM-1] ? q_sqrt_compl[1] : q_sqrt[1];
            end
         end
         3: begin // generate for three iteration units
            // Three result digits are caclulated per iteration
            logic [2:0]  qcnt_iter_0;  logic [4:0]  qcnt_iter_1;  logic [7:0]  qcnt_iter_2;
            logic [10:0] qcnt_iter_3;  logic [13:0] qcnt_iter_4;  logic [16:0] qcnt_iter_5;
            logic [19:0] qcnt_iter_6;  logic [22:0] qcnt_iter_7;  logic [25:0] qcnt_iter_8;
            logic [28:0] qcnt_iter_9;  logic [31:0] qcnt_iter_10; logic [34:0] qcnt_iter_11;
            logic [37:0] qcnt_iter_12; logic [40:0] qcnt_iter_13; logic [43:0] qcnt_iter_14;
            logic [46:0] qcnt_iter_15; logic [49:0] qcnt_iter_16; logic [52:0] qcnt_iter_17;
            logic [55:0] qcnt_iter_18;

            // Assign result for every iteration
            assign  qcnt_iter_0  = {1'b0,           sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_1  = {quotient[2:0],  sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_2  = {quotient[5:0],  sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_3  = {quotient[8:0],  sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_4  = {quotient[11:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_5  = {quotient[14:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_6  = {quotient[17:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_7  = {quotient[20:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_8  = {quotient[23:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_9  = {quotient[26:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_10 = {quotient[29:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_11 = {quotient[32:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_12 = {quotient[35:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_13 = {quotient[38:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_14 = {quotient[41:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_15 = {quotient[44:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_16 = {quotient[47:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_17 = {quotient[50:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};
            assign  qcnt_iter_18 = {quotient[53:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2]};

            always_comb begin
               case(iter_cnt)
                  6'b000000: begin // 0
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS:PRECISION_BITS-1];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-1) {1'b0}}, qcnt_iter_0[2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-2:PRECISION_BITS-1-2];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-2) {1'b0}}, qcnt_iter_0[2:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-4:PRECISION_BITS-1-4];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-3) {1'b0}}, qcnt_iter_0[2:0]};
                  end
                  6'b000001: begin // 1
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-6:PRECISION_BITS-1-6];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-3) {1'b0}}, qcnt_iter_1[4:2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-8:PRECISION_BITS-1-8];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-4) {1'b0}}, qcnt_iter_1[4:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-10:PRECISION_BITS-1-10];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-5) {1'b0}}, qcnt_iter_1[4:0]};
                  end
                  6'b000010: begin // 2
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-12:PRECISION_BITS-1-12];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-6){1'b0}}, qcnt_iter_2[7:2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-14:PRECISION_BITS-1-14];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-7){1'b0}}, qcnt_iter_2[7:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-16:PRECISION_BITS-1-16];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-8){1'b0}}, qcnt_iter_2[7:0]};
                  end
                  6'b000011: begin // 3
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-18:PRECISION_BITS-1-18];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-9){1'b0}}, qcnt_iter_3[10:2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-20:PRECISION_BITS-1-20];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-10){1'b0}}, qcnt_iter_3[10:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-22:PRECISION_BITS-1-22];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-11){1'b0}}, qcnt_iter_3[10:0]};
                  end
                  6'b000100: begin // 4
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-24:PRECISION_BITS-1-24];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-12){1'b0}}, qcnt_iter_4[13:2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-26:PRECISION_BITS-1-26];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-13){1'b0}}, qcnt_iter_4[13:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-28:PRECISION_BITS-1-28];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-14){1'b0}}, qcnt_iter_4[13:0]};
                  end
                  6'b000101: begin // 5
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-30:PRECISION_BITS-1-30];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-15){1'b0}}, qcnt_iter_5[16:2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-32:PRECISION_BITS-1-32];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-16){1'b0}}, qcnt_iter_5[16:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-34:PRECISION_BITS-1-34];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-17){1'b0}}, qcnt_iter_5[16:0]};
                  end
                  6'b000110: begin // 6
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-36:PRECISION_BITS-1-36];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-18){1'b0}}, qcnt_iter_6[19:2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-38:PRECISION_BITS-1-38];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-19){1'b0}}, qcnt_iter_6[19:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-40:PRECISION_BITS-1-40];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-20){1'b0}}, qcnt_iter_6[19:0]};
                  end
                  6'b000111: begin // 7
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-42:PRECISION_BITS-1-42];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-21){1'b0}}, qcnt_iter_7[22:2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-44:PRECISION_BITS-1-44];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-22){1'b0}}, qcnt_iter_7[22:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-46:PRECISION_BITS-1-46];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-23){1'b0}}, qcnt_iter_7[22:0]};
                  end
                  6'b001000: begin // 8
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-48:PRECISION_BITS-1-48];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-24){1'b0}}, qcnt_iter_8[25:2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-50:PRECISION_BITS-1-50];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-25){1'b0}}, qcnt_iter_8[25:1]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-52:PRECISION_BITS-1-52];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-26){1'b0}}, qcnt_iter_8[25:0]};
                  end
                  6'b001001: begin // 9
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-27){1'b0}}, qcnt_iter_9[28:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-28){1'b0}}, qcnt_iter_9[28:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-29){1'b0}}, qcnt_iter_9[28:0]};
                  end
                  6'b001010: begin // 10
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-30){1'b0}}, qcnt_iter_10[31:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-31){1'b0}}, qcnt_iter_10[31:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-32){1'b0}}, qcnt_iter_10[31:0]};
                  end
                  6'b001011: begin // 11
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-33){1'b0}}, qcnt_iter_11[34:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-34){1'b0}}, qcnt_iter_11[34:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-35){1'b0}}, qcnt_iter_11[34:0]};
                  end
                  6'b001100: begin // 12
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-36){1'b0}}, qcnt_iter_12[37:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-37){1'b0}}, qcnt_iter_12[37:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-38){1'b0}}, qcnt_iter_12[37:0]};
                  end
                  6'b001101: begin // 13
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-39){1'b0}}, qcnt_iter_13[40:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-40){1'b0}}, qcnt_iter_13[40:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-41){1'b0}}, qcnt_iter_13[40:0]};
                  end
                  6'b001110: begin // 14
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-42){1'b0}}, qcnt_iter_14[43:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-43){1'b0}}, qcnt_iter_14[43:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-44){1'b0}}, qcnt_iter_14[43:0]};
                  end
                  6'b001111: begin // 15
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-45){1'b0}}, qcnt_iter_15[46:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-46){1'b0}}, qcnt_iter_15[46:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-47){1'b0}}, qcnt_iter_15[46:0]};
                  end
                  6'b010000: begin // 16
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-48){1'b0}}, qcnt_iter_16[49:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-49){1'b0}}, qcnt_iter_16[49:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-50){1'b0}}, qcnt_iter_16[49:0]};
                  end
                  6'b010001: begin // 17
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-51){1'b0}}, qcnt_iter_17[52:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-52){1'b0}}, qcnt_iter_17[52:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-53){1'b0}}, qcnt_iter_17[52:0]};
                  end
                  6'b010010: begin // 18
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-54){1'b0}}, qcnt_iter_18[55:2]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-55){1'b0}}, qcnt_iter_18[55:1]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-56){1'b0}}, qcnt_iter_18[55:0]};
                  end
                  default: begin
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS:PRECISION_BITS-1];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-1) {1'b0}}, qcnt_iter_0[2]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-2:PRECISION_BITS-1-2];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-2) {1'b0}}, qcnt_iter_0[2:1]};                     
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-4:PRECISION_BITS-1-4];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-3) {1'b0}}, qcnt_iter_0[2:0]};
                  end
               endcase

               sqrt_q[0] = (iter_cnt == 0 | quotient[0]) ? q_sqrt_compl[0] : q_sqrt[0];
               sqrt_q[1] = sqrt_quotient[ITER_CELLS_NUM-1] ? q_sqrt_compl[1] : q_sqrt[1];
               sqrt_q[2] = sqrt_quotient[ITER_CELLS_NUM-2] ? q_sqrt_compl[2] : q_sqrt[2];
            end 
         end
         4: begin // generate for four iteration units
            // Four result digits are caclulated per iteration
            logic [3:0]  qcnt_iter_0;  logic [6:0]  qcnt_iter_1;  logic [10:0] qcnt_iter_2;
            logic [14:0] qcnt_iter_3;  logic [18:0] qcnt_iter_4;  logic [22:0] qcnt_iter_5;
            logic [26:0] qcnt_iter_6;  logic [30:0] qcnt_iter_7;  logic [34:0] qcnt_iter_8;
            logic [38:0] qcnt_iter_9;  logic [42:0] qcnt_iter_10; logic [46:0] qcnt_iter_11;
            logic [50:0] qcnt_iter_12; logic [54:0] qcnt_iter_13;

            assign  qcnt_iter_0  = {1'b0,           sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_1  = {quotient[3:0],  sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_2  = {quotient[7:0],  sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_3  = {quotient[11:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_4  = {quotient[15:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_5  = {quotient[19:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_6  = {quotient[23:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_7  = {quotient[27:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_8  = {quotient[31:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_9  = {quotient[35:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_10 = {quotient[39:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_11 = {quotient[43:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_12 = {quotient[47:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};
            assign  qcnt_iter_13 = {quotient[51:0], sqrt_quotient[ITER_CELLS_NUM-1], sqrt_quotient[ITER_CELLS_NUM-2], sqrt_quotient[ITER_CELLS_NUM-3]};

            always_comb begin
               case(iter_cnt)
                  6'b000000: begin // 0
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS:PRECISION_BITS-1];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-1){1'b0}}, qcnt_iter_0[3]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-2:PRECISION_BITS-1-2];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-2){1'b0}}, qcnt_iter_0[3:2]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-4:PRECISION_BITS-1-4];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-3){1'b0}}, qcnt_iter_0[3:1]};
                     sqrt_di[3] = sqrt_mant[PRECISION_BITS-6:PRECISION_BITS-1-6];
                     q_sqrt[3]  = {{(PREC_EXT_BITS-4){1'b0}}, qcnt_iter_0[3:0]};
                  end
                  6'b000001: begin // 1
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-8:PRECISION_BITS-1-8];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-4){1'b0}}, qcnt_iter_1[6:3]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-10:PRECISION_BITS-1-10];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-5){1'b0}}, qcnt_iter_1[6:2]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-12:PRECISION_BITS-1-12];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-6){1'b0}}, qcnt_iter_1[6:1]};
                     sqrt_di[3] = sqrt_mant[PRECISION_BITS-14:PRECISION_BITS-1-14];
                     q_sqrt[3]  = {{(PREC_EXT_BITS-7){1'b0}}, qcnt_iter_1[6:0]};
                  end
                  6'b000010: begin // 2
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-16:PRECISION_BITS-1-16];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-8){1'b0}}, qcnt_iter_2[10:3]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-18:PRECISION_BITS-1-18];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-9){1'b0}}, qcnt_iter_2[10:2]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-20:PRECISION_BITS-1-20];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-10){1'b0}}, qcnt_iter_2[10:1]};
                     sqrt_di[3] = sqrt_mant[PRECISION_BITS-22:PRECISION_BITS-1-22];
                     q_sqrt[3]  = {{(PREC_EXT_BITS-11){1'b0}}, qcnt_iter_2[10:0]};
                  end
                  6'b000011: begin // 3
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-24:PRECISION_BITS-1-24];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-12){1'b0}}, qcnt_iter_3[14:3]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-26:PRECISION_BITS-1-26];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-13){1'b0}}, qcnt_iter_3[14:2]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-28:PRECISION_BITS-1-28];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-14){1'b0}}, qcnt_iter_3[14:1]};
                     sqrt_di[3] = sqrt_mant[PRECISION_BITS-30:PRECISION_BITS-1-30];
                     q_sqrt[3]  = {{(PREC_EXT_BITS-15){1'b0}}, qcnt_iter_3[14:0]};
                  end
                  6'b000100: begin // 4
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-32:PRECISION_BITS-1-32];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-16){1'b0}}, qcnt_iter_4[18:3]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-34:PRECISION_BITS-1-34];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-17){1'b0}}, qcnt_iter_4[18:2]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-36:PRECISION_BITS-1-36];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-18){1'b0}}, qcnt_iter_4[18:1]};
                     sqrt_di[3] = sqrt_mant[PRECISION_BITS-38:PRECISION_BITS-1-38];
                     q_sqrt[3]  = {{(PREC_EXT_BITS-19){1'b0}}, qcnt_iter_4[18:0]};
                  end
                  6'b000101: begin // 5
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-40:PRECISION_BITS-1-40];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-20){1'b0}}, qcnt_iter_5[22:3]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-42:PRECISION_BITS-1-42];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-21){1'b0}}, qcnt_iter_5[22:2]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-44:PRECISION_BITS-1-44];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-22){1'b0}}, qcnt_iter_5[22:1]};
                     sqrt_di[3] = sqrt_mant[PRECISION_BITS-46:PRECISION_BITS-1-46];
                     q_sqrt[3]  = {{(PREC_EXT_BITS-23){1'b0}}, qcnt_iter_5[22:0]};
                  end
                  6'b000110: begin // 6
                     sqrt_di[0] = sqrt_mant[PRECISION_BITS-48:PRECISION_BITS-1-48];
                     q_sqrt[0]  = {{(PREC_EXT_BITS-24){1'b0}}, qcnt_iter_6[26:3]};
                     sqrt_di[1] = sqrt_mant[PRECISION_BITS-50:PRECISION_BITS-1-50];
                     q_sqrt[1]  = {{(PREC_EXT_BITS-25){1'b0}}, qcnt_iter_6[26:2]};
                     sqrt_di[2] = sqrt_mant[PRECISION_BITS-52:PRECISION_BITS-1-52];
                     q_sqrt[2]  = {{(PREC_EXT_BITS-26){1'b0}}, qcnt_iter_6[26:1]};
                     sqrt_di[3] = 2'b00;
                     q_sqrt[3]  = {{(PREC_EXT_BITS-27){1'b0}}, qcnt_iter_6[26:0]};
                  end
                  6'b000111: begin // 7
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-28){1'b0}}, qcnt_iter_7[30:3]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-29){1'b0}}, qcnt_iter_7[30:2]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-30){1'b0}}, qcnt_iter_7[30:1]};
                     sqrt_di[3] = 2'b00;
                     q_sqrt[3]  = {{(PREC_EXT_BITS-31){1'b0}}, qcnt_iter_7[30:0]};
                  end
                  6'b001000: begin // 8
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-32){1'b0}}, qcnt_iter_8[34:3]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-33){1'b0}}, qcnt_iter_8[34:2]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-34){1'b0}}, qcnt_iter_8[34:1]};
                     sqrt_di[3] = 2'b00;
                     q_sqrt[3]  = {{(PREC_EXT_BITS-35){1'b0}}, qcnt_iter_8[34:0]};
                  end
                  6'b001001: begin // 9
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-36){1'b0}}, qcnt_iter_9[38:3]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-37){1'b0}}, qcnt_iter_9[38:2]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-38){1'b0}}, qcnt_iter_9[38:1]};
                     sqrt_di[3] = 2'b00;
                     q_sqrt[3]  = {{(PREC_EXT_BITS-39){1'b0}}, qcnt_iter_9[38:0]};
                  end
                  6'b001010: begin // 10
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-40){1'b0}}, qcnt_iter_10[42:3]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-41){1'b0}}, qcnt_iter_10[42:2]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-42){1'b0}}, qcnt_iter_10[42:1]};
                     sqrt_di[3] = 2'b00;
                     q_sqrt[3]  = {{(PREC_EXT_BITS-43){1'b0}}, qcnt_iter_10[42:0]};
                  end
                  6'b001011: begin // 11
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-44){1'b0}}, qcnt_iter_11[46:3]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-45){1'b0}}, qcnt_iter_11[46:2]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-46){1'b0}}, qcnt_iter_11[46:1]};
                     sqrt_di[3] = 2'b00;
                     q_sqrt[3]  = {{(PREC_EXT_BITS-47){1'b0}}, qcnt_iter_11[46:0]};
                  end
                  6'b001100: begin // 12
                     sqrt_di[0] = 2'b00;
                     q_sqrt[0]  = {{(PREC_EXT_BITS-48){1'b0}}, qcnt_iter_12[50:3]};
                     sqrt_di[1] = 2'b00;
                     q_sqrt[1]  = {{(PREC_EXT_BITS-49){1'b0}}, qcnt_iter_12[50:2]};
                     sqrt_di[2] = 2'b00;
                     q_sqrt[2]  = {{(PREC_EXT_BITS-50){1'b0}}, qcnt_iter_12[50:1]};
                     sqrt_di[3] = 2'b00;
                     q_sqrt[3]  = {{(PREC_EXT_BITS-51){1'b0}}, qcnt_iter_12[50:0]};
                  end
                  6'b001101: begin // 13
                      sqrt_di[0] = 2'b00;
                      q_sqrt[0]  = {{(PREC_EXT_BITS-52){1'b0}}, qcnt_iter_13[54:3]};
                      sqrt_di[1] = 2'b00;
                      q_sqrt[1]  = {{(PREC_EXT_BITS-53){1'b0}}, qcnt_iter_13[54:2]};
                      sqrt_di[2] = 2'b00;
                      q_sqrt[2]  = {{(PREC_EXT_BITS-54){1'b0}}, qcnt_iter_13[54:1]};
                      sqrt_di[3] = 2'b00;
                      q_sqrt[3]  = {{(PREC_EXT_BITS-55){1'b0}}, qcnt_iter_13[54:0]};
                  end
                  default: begin
                      sqrt_di[0] = sqrt_mant[PRECISION_BITS:PRECISION_BITS-1];
                      q_sqrt[0]  = {{(PREC_EXT_BITS-1){1'b0}}, qcnt_iter_0[3]};
                      sqrt_di[1] = sqrt_mant[PRECISION_BITS-2:PRECISION_BITS-1-2];
                      q_sqrt[1]  = {{(PREC_EXT_BITS-2){1'b0}}, qcnt_iter_0[3:2]};
                      sqrt_di[2] = sqrt_mant[PRECISION_BITS-4:PRECISION_BITS-1-4];
                      q_sqrt[2]  = {{(PREC_EXT_BITS-3){1'b0}}, qcnt_iter_0[3:1]};
                      sqrt_di[3] = sqrt_mant[PRECISION_BITS-6:PRECISION_BITS-1-6];
                      q_sqrt[3]  = {{(PREC_EXT_BITS-4){1'b0}}, qcnt_iter_0[3:0]};
                  end
               endcase

               sqrt_q[0] = (iter_cnt == 0 | quotient[0]) ? q_sqrt_compl[0] : q_sqrt[0];
               sqrt_q[1] = sqrt_quotient[ITER_CELLS_NUM-1] ? q_sqrt_compl[1] : q_sqrt[1];
               sqrt_q[2] = sqrt_quotient[ITER_CELLS_NUM-2] ? q_sqrt_compl[2] : q_sqrt[2];
               sqrt_q[3] = sqrt_quotient[ITER_CELLS_NUM-3] ? q_sqrt_compl[3] : q_sqrt[3];
            end
         end
      endcase
   endgenerate

   // Assign square root partial remainders
   assign sqrt_r[0] = (sqrt_start_q ? '0 : {part_remainder[PREC_EXT_BITS-1:0]}); // previous partial remainder
   // Calculate partial remainder for next iteration cell
   for (genvar i = 0; i < int'(ITER_CELLS_NUM); i++) begin: sqrt_r_iter
      assign sqrt_r[i+1] = {iter_cell_sum[i][PREC_EXT_BITS-1], iter_cell_sum[i][PRECISION_BITS+1:0], sqrt_do[i]};
   end

   // -----------------------------------------
   // Iteration inputs processing for division
   // -----------------------------------------
   logic [ITER_CELLS_NUM-1:0][PREC_EXT_BITS-1:0] iter_cell_div_a, iter_cell_div_b; // iteration cells inputs for division operation
   logic [ITER_CELLS_NUM-1:0]                    iter_sel_b;                       // select divisor or divisor complement for input b, '1' for divisor complement

   // Input processing for first iteration cell
   logic [NUM_FORMATS-1:0][PREC_EXT_BITS-1:0] fmt_first_cell_in_a;
   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : first_cell_input
      localparam int unsigned FMT_PREC_BITS = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt)) + 1; // mantissa bits + implicit bit

      if (FpFmtConfig[fmt]) begin : active_format
         // Partial remainder is shifted 1 bit to the left
         assign fmt_first_cell_in_a[fmt] = { part_remainder[PRECISION_BITS+3:PRECISION_BITS-FMT_PREC_BITS+3], quotient[0], 3'b000, {(PRECISION_BITS-FMT_PREC_BITS){1'b0}} };
      end else begin : inactive_format
         assign fmt_first_cell_in_a[fmt] = '{default: fpuv_pkg::DONT_CARE}; // format disabled
      end
   end
   assign iter_cell_div_a[0] = div_start_q ? dividend_sgn_ext : fmt_first_cell_in_a[dst_fmt_i];
   assign iter_sel_b[0]      = div_start_q ? 1'b1 : quotient[0];
   assign iter_cell_div_b[0] = iter_sel_b[0] ? divisor_sgn_comp : {divisor_sgn, 4'b0000};

   // Input processing for other enabled iteration cells 
   for (genvar i = 1; i < int'(ITER_CELLS_NUM); i++) begin : other_cells_inputs
      logic [NUM_FORMATS-1:0][PREC_EXT_BITS-1:0] fmt_other_cells_in_a;

      assign iter_sel_b[i] = ~iter_cell_sum[i-1][PREC_EXT_BITS-1]; // check sign of the partial remainder (output of the previous iteration)
      assign iter_cell_div_b[i] = iter_sel_b[i] ? divisor_sgn_comp : {divisor_sgn, 4'b0000};

      for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin 
         localparam int unsigned FMT_PREC_BITS = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt)) + 1; // mantissa bits + implicit bit

         if (FpFmtConfig[fmt]) begin : active_format
            // Partial remainder is shifted 1 bit to the left
            assign fmt_other_cells_in_a[fmt] = { iter_cell_sum[i-1][PRECISION_BITS+3:PRECISION_BITS-FMT_PREC_BITS+3], iter_sel_b[i], 3'b000, {(PRECISION_BITS-FMT_PREC_BITS){1'b0}} };
         end else begin : inactive_format
            assign fmt_other_cells_in_a[fmt] = '{default: fpuv_pkg::DONT_CARE}; // format disabled
         end
      end
      assign iter_cell_div_a[i] = fmt_other_cells_in_a[dst_fmt_i];
   end

   // -----------------
   // Iteration cells
   // -----------------
   logic [ITER_CELLS_NUM-1:0][PREC_EXT_BITS-1:0] iter_cell_in_a, iter_cell_in_b;   // iteration cells inputs
   // Instantiate iteration cells
   for (genvar i = 0; i < ITER_CELLS_NUM; i++) begin : cell_inst
      assign iter_cell_in_a[i] = sqrt_enable_o ? sqrt_r[i] : iter_cell_div_a[i];
      assign iter_cell_in_b[i] = sqrt_enable_o ? sqrt_q[i] : iter_cell_div_b[i];

      divsqrt_iter #(
         .WIDTH (PREC_EXT_BITS)
      ) i_divsqrt_iter (
         .a_i           ( iter_cell_in_a[i]  ),
         .b_i           ( iter_cell_in_b[i]  ),
         .div_enable_i  ( div_enable_o       ),
         .sqrt_enable_i ( sqrt_enable_o      ),
         .d_i           ( sqrt_di[i]         ),
         .d_o           ( sqrt_do[i]         ),
         .sum_o         ( iter_cell_sum[i]   ),
         .carry_o       ( iter_cell_carry[i] )
      );
   end

   // Calculate partial remainder for next iteration
   assign part_remainder_next = fsm_enable ? (sqrt_enable_o ? sqrt_r[ITER_CELLS_NUM] : iter_cell_sum[ITER_CELLS_NUM-1]) : part_remainder;

   // load partial remainder with next value
   `FF(part_remainder, part_remainder_next, '0)

   // Add calculated digit to quotient, quotient is shifted to the left
   assign quotient_next = fsm_enable ? (sqrt_enable_o ? {quotient[PRECISION_BITS+3-ITER_CELLS_NUM:0], sqrt_quotient}
                                                      : {quotient[PRECISION_BITS+3-ITER_CELLS_NUM:0], iter_cell_carry})
                                     : quotient;

   // load quotient with next value
   `FF(quotient, quotient_next, '0)

   // -----------------
   // Correction step
   // -----------------
   logic [PREC_EXT_BITS-1:0] div_final_remainder;  // correct remainder for division
   logic [PREC_EXT_BITS-1:0] sqrt_final_remainder; // correct remainder for sqrt
   logic                     div_correct_sticky;   // correct sticky bit for division
   logic                     sqrt_correct_sticky;  // correct sticky bit for sqrt
   logic                     correct_sticky;       // correct sticky bit

   // Correction step for negative final remainder (sqrt)
   logic [NUM_FORMATS-1:0][PREC_EXT_BITS-1:0] fmt_sqrt_remainder; // correct remainder, format specific
   logic [NUM_FORMATS-1:0]                    fmt_sqrt_sticky;    // correct sticky bit, format specific
   for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : fmt_sqrt_correction
      // Extended precision bits for every format
      localparam int unsigned FP_PREC_EXT = fpuv_pkg::man_bits(fpuv_pkg::fp_format_e'(fmt)) + 1 + 1 + 4;
      // Generate for enabled formats
      if (FpFmtConfig[fmt]) begin : active_format
         // For narrower formats partial remainder is stored in lower FP_PREC_BITS+1+4 bits upper bits are ignored
         always_comb begin
            if (part_remainder[FP_PREC_EXT-1] & done_o) begin // is final remainder negative
               fmt_sqrt_remainder[fmt] = part_remainder[FP_PREC_EXT-1:0] + {quotient[FP_PREC_EXT-2:0], 1'b1};
            end else // correction step not needed
               fmt_sqrt_remainder[fmt] = part_remainder;
         end
         // Sign bit of final remainder is ignored
         assign fmt_sqrt_sticky[fmt]  = done_o & (fmt_sqrt_remainder[fmt][FP_PREC_EXT-2:0] != '0);
      end else begin : inactive_format
         assign fmt_sqrt_remainder[fmt] = '{default: fpuv_pkg::DONT_CARE};
         assign fmt_sqrt_sticky[fmt]    = fpuv_pkg::DONT_CARE;
      end
   end
   assign sqrt_final_remainder = fmt_sqrt_remainder[dst_fmt_i];
   assign sqrt_correct_sticky  = fmt_sqrt_sticky[dst_fmt_i];

   // Correction step for negative final remainder (division)
   always_comb begin
      if (part_remainder[PREC_EXT_BITS-1] & done_o) // is final remainder negative
         div_final_remainder = part_remainder + {divisor_sgn, 4'b0};
      else // correction step not needed
         div_final_remainder = part_remainder;
   end
   // Sign bit of final remainder is ignored
   assign div_correct_sticky  = done_o & (div_final_remainder[PREC_EXT_BITS-2:0] != '0);

   assign correct_sticky = div_enable_o ? div_correct_sticky : sqrt_correct_sticky;

   // Result packing, format specific
   generate
      case (ITER_CELLS_NUM)
         1: begin // generate for one iteration cell
            always_comb begin
               unique case (dst_fmt_i)
                  fpuv_pkg::FP32:    result_mant_o = {quotient[FP32_MANT_BITS+3:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP32_MANT_BITS+1)    {1'b0}} };
                  fpuv_pkg::FP64:    result_mant_o = {quotient[SUPER_MAN_BITS+4:1],    quotient[0] | correct_sticky};                                               //+4
                  fpuv_pkg::FP16:    result_mant_o = {quotient[FP16_MANT_BITS+4:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16_MANT_BITS)    {1'b0}} }; //+4
                  fpuv_pkg::FP8:     result_mant_o = {quotient[FP16_MANT_BITS+4:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16_MANT_BITS)    {1'b0}} }; //+4
                  fpuv_pkg::FP16ALT: result_mant_o = {quotient[FP16ALT_MANT_BITS+4:1], quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16ALT_MANT_BITS) {1'b0}} }; //+4
                  default:           result_mant_o = {quotient[SUPER_MAN_BITS+4:1],    quotient[0] | correct_sticky};                                               //+4
               endcase 
            end
         end
         2: begin // generate for two iteration cells
            always_comb begin
               unique case (dst_fmt_i)
                  fpuv_pkg::FP32:    result_mant_o = {quotient[FP32_MANT_BITS+4:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP32_MANT_BITS)    {1'b0}} }; //+4
                  fpuv_pkg::FP64:    result_mant_o = {quotient[SUPER_MAN_BITS+3:1],    quotient[0] | correct_sticky, 1'b0};                                         //+3
                  fpuv_pkg::FP16:    result_mant_o = {quotient[FP16_MANT_BITS+3:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16_MANT_BITS+1)  {1'b0}} }; //+3
                  fpuv_pkg::FP8:     result_mant_o = {quotient[FP16_MANT_BITS+3:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16_MANT_BITS+1)  {1'b0}} }; //+3
                  fpuv_pkg::FP16ALT: result_mant_o = {quotient[FP16ALT_MANT_BITS+4:1], quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16ALT_MANT_BITS) {1'b0}} }; //+4
                  default:           result_mant_o = {quotient[SUPER_MAN_BITS+3:1],    quotient[0] | correct_sticky, 1'b0};                                         //+3
               endcase 
            end
         end
         3: begin // generate for three iteration cells
            always_comb begin
               unique case (dst_fmt_i)
                  fpuv_pkg::FP32:    result_mant_o = {quotient[FP32_MANT_BITS+3:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP32_MANT_BITS+1)  {1'b0}} }; //+3
                  fpuv_pkg::FP64:    result_mant_o = {quotient[SUPER_MAN_BITS+4:1],    quotient[0] | correct_sticky};                                               //+4
                  fpuv_pkg::FP16:    result_mant_o = {quotient[FP16_MANT_BITS+4:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16_MANT_BITS)    {1'b0}} }; //+4
                  fpuv_pkg::FP8:     result_mant_o = {quotient[FP16_MANT_BITS+4:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16_MANT_BITS)    {1'b0}} }; //+4
                  fpuv_pkg::FP16ALT: result_mant_o = {quotient[FP16ALT_MANT_BITS+4:1], quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16ALT_MANT_BITS) {1'b0}} }; //+4
                  default:           result_mant_o = {quotient[SUPER_MAN_BITS+4:1],    quotient[0] | correct_sticky};                                               //+4
               endcase 
            end
         end
         4: begin // generate for four iteration cells
            always_comb begin
               unique case (dst_fmt_i)
                  fpuv_pkg::FP32:    result_mant_o = {quotient[FP32_MANT_BITS+4:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP32_MANT_BITS)    {1'b0}} }; //+4
                  fpuv_pkg::FP64:    result_mant_o = {quotient[SUPER_MAN_BITS+3:1],    quotient[0] | correct_sticky, 1'b0};                                         //+3
                  fpuv_pkg::FP16:    result_mant_o = {quotient[FP16_MANT_BITS+5:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16_MANT_BITS-1)  {1'b0}} }; //+5
                  fpuv_pkg::FP8:     result_mant_o = {quotient[FP16_MANT_BITS+5:1],    quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16_MANT_BITS-1)  {1'b0}} }; //+5
                  fpuv_pkg::FP16ALT: result_mant_o = {quotient[FP16ALT_MANT_BITS+4:1], quotient[0] | correct_sticky, {(SUPER_MAN_BITS-FP16ALT_MANT_BITS) {1'b0}} }; //+4
                  default:           result_mant_o = {quotient[SUPER_MAN_BITS+3:1],    quotient[0] | correct_sticky, 1'b0};                                         //+3
               endcase 
            end
         end
      endcase 
   endgenerate

   // Result exponent
   logic signed [SUPER_EXP_BITS+2-1:0] preround_exp, preround_exp_q;
   logic signed [SUPER_EXP_BITS+2-1:0] exp_temp;

   // For division, exponent = exp_a - exp_b + BIAS
   // For square root, exponent = exp_a/2 + exp_a%2 + BIAS/2
   assign exp_temp = sqrt_start_q ? signed'(dividend_exp_i[SUPER_EXP_BITS+2-1:1]) : signed'(dividend_exp_i);
   always_comb begin 
      if (sqrt_start_q) begin 
         preround_exp = signed'(exp_temp) + signed'({1'b0, dividend_exp_i[0]}) + signed'(fpuv_pkg::bias(dst_fmt_i)/2);
      end else if (div_start_q) begin 
         preround_exp = signed'(exp_temp) - signed'(divisor_exp_i) + signed'(fpuv_pkg::bias(dst_fmt_i));
      end else
         preround_exp = preround_exp_q;
   end
   // Store result exponent
   `FF(preround_exp_q, preround_exp, '0)

   assign result_exp_o = preround_exp_q;

endmodule
