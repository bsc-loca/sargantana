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

/* Every element product is a signed (SEW+1)x(SEW+1) multiplication of the
 * sign- or zero-extended source elements. The product is exact, so its low
 * 2*SEW bits already are the two's complement result: no magnitude
 * conversion before the multiplication nor negation after it.
 * These multipliers are the only arithmetic of the module: use_dsp maps them
 * to DSP blocks (Vivado keeps narrow products in LUTs by default).
 */
(* use_dsp = "yes" *) module vmul (
  input wire                  clk_i,          // Clock
  input wire                  rstn_i,         // Reset 
  input instr_type_t          instr_type_i,   // Instruction type
  input sew_t                 sew_i,          // Element width
  input bus64_t               data_vs1_i,     // 64-bit source operand 1
  input bus64_t               data_vs2_i,     // 64-bit source operand 2
  output bus64_t              data_vd_o,      // 64-bit result
  output bus128_t             full_data_o     // 128-bit generated result (needed for vsmul)
);

////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 0                                   //
////////////////////////////////////////////////////////////////////////////////

wire is_mulh_0 = ((instr_type_i == VMULH) || (instr_type_i == VMULHU) || (instr_type_i == VMULHSU));
wire is_signed_0 = ((instr_type_i != VMULHU) && (instr_type_i != VWMULU) && (instr_type_i != VWMACCU));
wire is_signed_unsigned_0 = ((instr_type_i == VMULHSU) || (instr_type_i == VWMULSU) || (instr_type_i == VWMACCUS));
wire is_unsigned_signed_0 = ((instr_type_i == VWMACCSU));
wire is_widened_0 = ((instr_type_i == VWMUL) || (instr_type_i == VWMULU) || (instr_type_i == VWMULSU) ||
                     (instr_type_i == VWMACC) || (instr_type_i == VWMACCU) || (instr_type_i == VWMACCSU) || (instr_type_i == VWMACCUS));
// vmul sees every instruction: only a SEW=64 multiplication may take the
// output from stage 2 (e.g. a vsetivli still carries the previous SEW)
wire is_mul64_0 = (sew_i == SEW_64) &&
                  ((instr_type_i == VMUL) || (instr_type_i == VMULH) || (instr_type_i == VMULHU) || (instr_type_i == VMULHSU) ||
                   (instr_type_i == VSMUL) || (instr_type_i == VMADD) || (instr_type_i == VNMSUB) ||
                   (instr_type_i == VMACC) || (instr_type_i == VNMSAC));

// A signed source is sign-extended, an unsigned one zero-extended
wire src1_signed_0 = (is_signed_0 ^ is_signed_unsigned_0);
wire src2_signed_0 = (is_signed_0 ^ is_unsigned_signed_0);

////////////////////////////////////////////////////////////////////////////////
//                              STAGE 0 -> STAGE 1                            //
////////////////////////////////////////////////////////////////////////////////

sew_t sew_1;

logic is_mulh_1;
logic is_mul64_1;
logic is_widened_1;
logic src1_signed_1;
logic src2_signed_1;

bus64_t src1_data_1;
bus64_t src2_data_1;

always_ff@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        sew_1                    <= SEW_8;
        is_mulh_1                <= 1'b0;
        is_mul64_1               <= 1'b0;
        is_widened_1             <= 1'b0;
        src1_signed_1            <= 1'b0;
        src2_signed_1            <= 1'b0;
        src1_data_1              <= 64'd0;
        src2_data_1              <= 64'd0;
    end
    else begin
        sew_1                    <= sew_i;
        is_mulh_1                <= is_mulh_0;
        is_mul64_1               <= is_mul64_0;
        is_widened_1             <= is_widened_0;
        src1_signed_1            <= src1_signed_0;
        src2_signed_1            <= src2_signed_0;
        src1_data_1              <= data_vs1_i;
        src2_data_1              <= data_vs2_i;
    end
end

////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 1                                   //
////////////////////////////////////////////////////////////////////////////////

// Source elements with one extension bit: {signed & msb, element}
logic signed [8:0]   src1_ext_8b  [7:0];
logic signed [8:0]   src2_ext_8b  [7:0];
logic signed [16:0]  src1_ext_16b [3:0];
logic signed [16:0]  src2_ext_16b [3:0];
logic signed [32:0]  src1_ext_32b [1:0];
logic signed [32:0]  src2_ext_32b [1:0];
logic signed [64:0]  src1_ext_64b;
logic signed [64:0]  src2_ext_64b;

// Exact products (2*SEW+2 bits), bits [2*SEW-1:0] are the 2*SEW-bit result
logic signed [17:0]  products_8b_1  [7:0];
logic signed [33:0]  products_16b_1 [3:0];
logic signed [65:0]  products_32b_1 [1:0];
/* verilator lint_off UNUSEDSIGNAL */
logic signed [129:0] product_64b_1; // Only bits [127:0] are registered
/* verilator lint_on UNUSEDSIGNAL */

always_comb begin
    for (int i = 0; i < 8; i++) begin
        src1_ext_8b[i]   = {src1_signed_1 & src1_data_1[i*8+7], src1_data_1[i*8+:8]};
        src2_ext_8b[i]   = {src2_signed_1 & src2_data_1[i*8+7], src2_data_1[i*8+:8]};
        products_8b_1[i] = $signed(src1_ext_8b[i]) * $signed(src2_ext_8b[i]);
    end
    for (int i = 0; i < 4; i++) begin
        src1_ext_16b[i]   = {src1_signed_1 & src1_data_1[i*16+15], src1_data_1[i*16+:16]};
        src2_ext_16b[i]   = {src2_signed_1 & src2_data_1[i*16+15], src2_data_1[i*16+:16]};
        products_16b_1[i] = $signed(src1_ext_16b[i]) * $signed(src2_ext_16b[i]);
    end
    for (int i = 0; i < 2; i++) begin
        src1_ext_32b[i]   = {src1_signed_1 & src1_data_1[i*32+31], src1_data_1[i*32+:32]};
        src2_ext_32b[i]   = {src2_signed_1 & src2_data_1[i*32+31], src2_data_1[i*32+:32]};
        products_32b_1[i] = $signed(src1_ext_32b[i]) * $signed(src2_ext_32b[i]);
    end
    src1_ext_64b  = {src1_signed_1 & src1_data_1[63], src1_data_1};
    src2_ext_64b  = {src2_signed_1 & src2_data_1[63], src2_data_1};
    product_64b_1 = $signed(src1_ext_64b) * $signed(src2_ext_64b);
end

////////////////////////////////////////////////////////////////////////////////
//                              STAGE 1 -> STAGE 2                            //
////////////////////////////////////////////////////////////////////////////////

sew_t sew_2;

logic is_mulh_2;
logic is_mul64_2;

bus128_t product_64b_2;

always_ff@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        sew_2                    <= SEW_8;
        is_mulh_2                <= 1'b0;
        is_mul64_2               <= 1'b0;
        product_64b_2            <= 128'd0;
    end
    else begin
        sew_2                    <= sew_1;
        is_mulh_2                <= is_mulh_1;
        is_mul64_2               <= is_mul64_1;
        product_64b_2            <= product_64b_1[127:0];
    end
end

////////////////////////////////////////////////////////////////////////////////
//                                OUTPUT MUX                                  //
////////////////////////////////////////////////////////////////////////////////

bus64_t data_vd_o1;
bus64_t data_vd_o2;

bus128_t full_data_o1;
bus128_t full_data_o2;

// Output the results (8, 16, 32 bits)
always_comb begin
    data_vd_o1   = 64'b0;
    full_data_o1 = 128'b0;
    unique case (sew_1)
        SEW_8 : begin
            if (is_widened_1) begin
                for (int i = 0; i < 4; i++) begin
                    data_vd_o1[i*16+:16] = products_8b_1[i][15:0];
                end
            end
            else begin
                for (int i = 0; i < 8; i++) begin
                    data_vd_o1[i*8+:8]     = (is_mulh_1) ? products_8b_1[i][15:8] : products_8b_1[i][7:0];
                    full_data_o1[i*16+:16] = products_8b_1[i][15:0];
                end
            end
        end
        SEW_16 : begin
            if (is_widened_1) begin
                for (int i = 0; i < 2; i++) begin
                    data_vd_o1[i*32+:32] = products_16b_1[i][31:0];
                end
            end
            else begin
                for (int i = 0; i < 4; i++) begin
                    data_vd_o1[i*16+:16]   = (is_mulh_1) ? products_16b_1[i][31:16] : products_16b_1[i][15:0];
                    full_data_o1[i*32+:32] = products_16b_1[i][31:0];
                end
            end
        end
        SEW_32 : begin
            if (is_widened_1) begin
                data_vd_o1 = products_32b_1[0][63:0];
            end
            else begin
                for (int i = 0; i < 2; i++) begin
                    data_vd_o1[i*32+:32]   = (is_mulh_1) ? products_32b_1[i][63:32] : products_32b_1[i][31:0];
                    full_data_o1[i*64+:64] = products_32b_1[i][63:0];
                end
            end
        end
        default : begin
            // SEW_64: the result leaves from stage 2
            data_vd_o1 = 64'b0;
        end
    endcase
end

// Output the results (64 bits)
always_comb begin
    unique case (sew_2)
        SEW_64 : begin
            data_vd_o2   = (is_mulh_2) ? product_64b_2[127:64] : product_64b_2[63:0];
            full_data_o2 = product_64b_2;
        end
        default : begin
            data_vd_o2   = 64'b0;
            full_data_o2 = 128'b0;
        end
    endcase
end

// Needed for multiplication + add/subtract
assign data_vd_o = (is_mul64_2) ? data_vd_o2 : data_vd_o1;
assign full_data_o = (is_mul64_2) ? full_data_o2 : full_data_o1;

endmodule
