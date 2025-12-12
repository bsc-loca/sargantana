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

module vshift
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input vxrm_t                vxrm_i,         // Fixed-point rounding mode
    input bus64_t               data_vs1_i,     // 64-bit source operand 1
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);

function [7:0] trunc_9_8(input [8:0] val_in);
  trunc_9_8 = val_in[7:0];
endfunction

function [15:0] trunc_17_16(input [16:0] val_in);
  trunc_17_16 = val_in[15:0];
endfunction

function [31:0] trunc_33_32(input [32:0] val_in);
  trunc_33_32 = val_in[31:0];
endfunction

function [63:0] trunc_65_64(input [64:0] val_in);
  trunc_65_64 = val_in[63:0];
endfunction

function [63:0] trunc_127_64(input [126:0] val_in);
  trunc_127_64 = val_in[63:0];
endfunction

function [31:0] trunc_127_32(input [126:0] val_in);
  trunc_127_32 = val_in[31:0];
endfunction

function [31:0] trunc_63_32(input [62:0] val_in);
  trunc_63_32 = val_in[31:0];
endfunction

function [15:0] trunc_63_16(input [62:0] val_in);
  trunc_63_16 = val_in[15:0];
endfunction

function [15:0] trunc_31_16(input [30:0] val_in);
  trunc_31_16 = val_in[15:0];
endfunction

function [7:0] trunc_31_8(input [30:0] val_in);
  trunc_31_8 = val_in[7:0];
endfunction

function [7:0] trunc_15_8(input [14:0] val_in);
  trunc_15_8 = val_in[7:0];
endfunction


bus64_t data_a;
bus64_t data_b;
bus64_t data_vd;
bus64_t data_vd_scaled;
bus64_t rounding_increment;
logic is_signed;
logic is_left;
logic is_narrow;
logic is_scaling;
logic is_widening;

typedef union packed {
    logic [0:0][63:0] sew64;
    logic [1:0][31:0] sew32;
    logic [3:0][15:0] sew16;
    logic [7:0][ 7:0] sew8;
} vector_elements;

vector_elements velements_a, velements_b;
assign velements_a = data_a;
assign velements_b = data_b;

always_comb begin
    is_signed = ((instr_type_i == VSRA) || (instr_type_i == VNSRA) || (instr_type_i == VSSRA)) ? 1'b1 : 1'b0;
    is_left   = ((instr_type_i == VSLL) || (instr_type_i == VROL) || (instr_type_i == VWSLL)) ? 1'b1 : 1'b0;
    is_narrow = ((instr_type_i == VNSRL) || (instr_type_i == VNSRA)) ? 1'b1 : 1'b0;
    is_scaling = ((instr_type_i == VSSRL) || (instr_type_i == VSSRA)) ? 1'b1 : 1'b0;
    is_widening = ((instr_type_i == VWSLL)) ? 1'b1 : 1'b0;

    data_a = data_vs2_i;
    data_b = data_vs1_i;

    rounding_increment = 'h0;
    case (sew_i)
        SEW_8: begin
            for (int i = 0; i<8; ++i) begin
                case (vxrm_i)
                    RNU_V: begin
                        if ((data_b[(i*8)+:3]) != 'h0) begin
                            rounding_increment[i] = velements_a.sew8[i][((data_b[(i*8)+:3])-1)+:1];
                        end
                    end
                    RNE_V: begin
                        if ((data_b[(i*8)+:3]) > 'h1) begin
                            for (int j = 0; j < 6; ++j) begin // max shift 7, d-2 = 5
                                if (j < (data_b[(i*8)+:3]-1)) begin
                                    rounding_increment[i] = rounding_increment[i] | velements_a.sew8[i][j]; // v[d-2:0] != 0
                                end
                            end
                        end
                        rounding_increment[i] = (rounding_increment[i] | velements_a.sew8[i][(data_b[(i*8)+:3])]);
                        
                        if ((data_b[(i*8)+:3]) != 'h0) begin
                            rounding_increment[i] = (rounding_increment[i] & velements_a.sew8[i][((data_b[(i*8)+:3])-1)+:1]);
                        end else begin
                            rounding_increment[i] = 'h0; // and with 0 is always 0
                        end
                    end
                    RDN_V: begin
                        rounding_increment[i] = 1'b0;
                    end
                    ROD_V: begin
                        if ((data_b[(i*8)+:3]) != 'h0) begin
                            for (int j = 0; j < 7; ++j) begin // max shift 7, d-1 = 6
                                if (j < (data_b[(i*8)+:3])) begin
                                    rounding_increment[i] = rounding_increment[i] | velements_a.sew8[i][j];
                                end
                            end
                        end
                        rounding_increment[i] = rounding_increment[i] & (~velements_a.sew8[i][((data_b[(i*8)+:3]))+:1]);
                    end
                    default:
                        rounding_increment[i] = 1'b0;
                endcase
            end
        end
        SEW_16: begin
            for (int i = 0; i<4; ++i) begin
                case (vxrm_i)
                    RNU_V: begin
                        if ((data_b[(i*16)+:4]) != 'h0) begin
                            rounding_increment[i] = velements_a.sew16[i][((data_b[(i*16)+:4])-1)+:1];
                        end
                    end
                    RNE_V: begin
                        if ((data_b[(i*16)+:4]) > 'h1) begin
                            for (int j = 0; j < 14; ++j) begin // max shift 7, d-2 = 5
                                if (j < (data_b[(i*16)+:4]-1)) begin
                                    rounding_increment[i] = rounding_increment[i] | velements_a.sew16[i][j];
                                end
                            end
                        end
                        rounding_increment[i] = (rounding_increment[i] | velements_a.sew16[i][(data_b[(i*16)+:4])+:1]);

                        if ((data_b[(i*16)+:4]) != 'h0) begin
                            rounding_increment[i] = (rounding_increment[i] & velements_a.sew16[i][((data_b[(i*16)+:4])-1)+:1]);
                        end else begin
                            rounding_increment[i] = 'h0; // and with 0 is always 0
                        end
                    end
                    RDN_V: begin
                        rounding_increment[i] = 1'b0;
                    end
                    ROD_V: begin
                        if ((data_b[(i*16)+:4]) != 'h0) begin
                            for (int j = 0; j < 15; ++j) begin // max shift 7, d-1 = 6
                                if (j < (data_b[(i*16)+:4])) begin
                                    rounding_increment[i] = rounding_increment[i] | velements_a.sew16[i][j];
                                end
                            end
                        end
                        rounding_increment[i] = rounding_increment[i] & (~velements_a.sew16[i][((data_b[(i*16)+:4]))+:1]);
                    end
                    default:
                        rounding_increment[i] = 1'b0;
                endcase
            end
        end
        SEW_32: begin
            for (int i = 0; i<2; ++i) begin
                case (vxrm_i)
                    RNU_V: begin
                        if ((data_b[(i*32)+:5]) != 'h0) begin
                            rounding_increment[i] = velements_a.sew32[i][((data_b[(i*32)+:5])-1)+:1];
                        end
                    end
                    RNE_V: begin
                        if ((data_b[(i*32)+:5]) > 'h1) begin
                            for (int j = 0; j < 30; ++j) begin // max shift 7, d-2 = 5
                                if (j < (data_b[(i*32)+:5]-1)) begin
                                    rounding_increment[i] = rounding_increment[i] | velements_a.sew32[i][j];
                                end
                            end
                        end
                        rounding_increment[i] = (rounding_increment[i] | velements_a.sew32[i][(data_b[(i*32)+:5])+:1]);

                        if ((data_b[(i*32)+:5]) != 'h0) begin
                            rounding_increment[i] = (rounding_increment[i] & velements_a.sew32[i][((data_b[(i*32)+:5])-1)+:1]);
                        end else begin
                            rounding_increment[i] = 'h0; // and with 0 is always 0
                        end
                    end
                    RDN_V: begin
                        rounding_increment[i] = 1'b0;
                    end
                    ROD_V: begin
                        if ((data_b[(i*32)+:5]) != 'h0) begin
                            for (int j = 0; j < 31; ++j) begin // max shift 7, d-1 = 6
                                if (j < (data_b[(i*32)+:5])) begin
                                    rounding_increment[i] = rounding_increment[i] | velements_a.sew32[i][j];
                                end
                            end
                        end
                        rounding_increment[i] = rounding_increment[i] & (~velements_a.sew32[i][((data_b[(i*32)+:5]))+:1]);
                    end
                    default:
                        rounding_increment[i] = 1'b0;
                endcase
            end
        end
        SEW_64: begin
            case (vxrm_i)
                RNU_V: begin
                    if ((data_b[5:0]) != 'h0) begin
                        rounding_increment[0] = data_a[((data_b[5:0])-1)+:1];
                    end
                end
                RNE_V: begin
                    if ((data_b[5:0]) > 'h1) begin
                        for (int j = 0; j < 62; ++j) begin // max shift 7, d-2 = 5
                            if (j < (data_b[5:0])) begin
                                rounding_increment[0] = rounding_increment[0] | data_a[j];
                            end
                        end
                    end
                    rounding_increment[0] = (rounding_increment[0] | data_a[(data_b[5:0])+:1]);
                    
                    if ((data_b[5:0]) != 'h0) begin
                        rounding_increment[0] = (rounding_increment[0] & data_a[((data_b[5:0])-1)+:1]);
                    end else begin
                        rounding_increment[0] = 'h0; // and with 0 is always 0
                    end
                end
                RDN_V: begin
                    rounding_increment[0] = 1'b0;
                end
                ROD_V: begin
                    if ((data_b[5:0]) != 'h0) begin
                        for (int j = 0; j < 63; ++j) begin // max shift 7, d-1 = 6
                            if (j < (data_b[5:0])) begin
                                rounding_increment[0] = rounding_increment[0] | data_a[j];
                            end
                        end
                    end
                    rounding_increment[0] = rounding_increment[0] & (~data_a[(data_b[5:0])+:1]);
                end
                default:
                    rounding_increment[0] = 1'b0;
            endcase
        end
    endcase
end



logic[14:0] data_sew8[7:0];
logic[30:0] data_sew16[3:0];
logic[62:0] data_sew32[1:0];
logic[126:0] data_sew64;

sew_t sew_shifting;

logic[6:0] shift_amount[7:0];

always_comb begin
    for (int i = 0; i < 8; ++i) begin
        shift_amount[i] = '0;
    end

    if (is_narrow || is_widening) begin
        case (sew_i)
            SEW_8: begin
                sew_shifting = SEW_16;
            end
            SEW_16: begin
                sew_shifting = SEW_32;
            end
            SEW_32: begin
                sew_shifting = SEW_64;
            end
            default: begin
                sew_shifting = sew_i;
            end
        endcase
    end
    else begin
        sew_shifting = sew_i;
    end

    case (sew_i)
        SEW_8: begin
            for (int i = 0; i < 8; ++i) begin
                if (is_left) begin
                    if (is_widening) begin
                        shift_amount[i] = {3'b0, ~velements_b.sew8[i][3:0]};
                    end
                    else begin
                        shift_amount[i] = {4'b0, ~velements_b.sew8[i][2:0]};
                    end
                end
                else begin
                    if (is_narrow) begin
                        shift_amount[i] = {3'b0, velements_b.sew8[i][3:0]};
                    end
                    else begin
                        shift_amount[i] = {4'b0, velements_b.sew8[i][2:0]};
                    end
                end
            end
        end
        SEW_16: begin
            for (int i = 0; i < 4; ++i) begin
                if (is_left) begin
                    if (is_widening) begin
                        shift_amount[i] = {2'b0, ~velements_b.sew16[i][4:0]};
                    end
                    else begin
                        shift_amount[i] = {3'b0, ~velements_b.sew16[i][3:0]};
                    end
                end
                else begin
                    if (is_narrow) begin
                        shift_amount[i] = {2'b0, velements_b.sew16[i][4:0]};
                    end
                    else begin
                        shift_amount[i] = {3'b0, velements_b.sew16[i][3:0]};
                    end
                end
            end
        end
        SEW_32: begin
            for (int i = 0; i < 2; ++i) begin
                if (is_left) begin
                    if (is_widening) begin
                        shift_amount[i] = {1'b0, ~velements_b.sew32[i][5:0]};
                    end
                    else begin
                        shift_amount[i] = {2'b0, ~velements_b.sew32[i][4:0]};
                    end
                end
                else begin
                    if (is_narrow) begin
                        shift_amount[i] = {1'b0, velements_b.sew32[i][5:0]};
                    end
                    else begin
                        shift_amount[i] = {2'b0, velements_b.sew32[i][4:0]};
                    end
                end
            end
        end
        SEW_64: begin
            if (is_left) begin
                shift_amount[0] = {1'b0, ~velements_b.sew64[0][5:0]};
            end
            else begin
                shift_amount[0] = {1'b0, velements_b.sew64[0][5:0]};
            end
        end
        default: begin
            for (int i = 0; i < 8; ++i) begin
                shift_amount[i] = '0;
            end
        end
    endcase


    data_vd = '0;
    data_vd_scaled = '0;
    for (int i = 0; i < 8; ++i) begin
        data_sew8[i] = '0;
    end
    for (int i = 0; i < 4; ++i) begin
        data_sew16[i] = '0;
    end
    for (int i = 0; i < 2; ++i) begin
        data_sew32[i] = '0;
    end
    data_sew64 = '0;

    case (sew_shifting)
        SEW_8: begin
            for (int i = 0; i < 8; ++i) begin
                case (instr_type_i)
                    VSLL: begin
                        data_sew8[i][14:8] = velements_a.sew8[i][7:1];
                        data_sew8[i][7] = velements_a.sew8[i][0];
                        data_sew8[i][6:0] = '0;
                    end
                    VSRL, VSSRL, VNSRL: begin
                        data_sew8[i][14:8] = '0;
                        data_sew8[i][7] = velements_a.sew8[i][7];
                        data_sew8[i][6:0] = velements_a.sew8[i][6:0];
                    end
                    VSRA, VSSRA, VNSRA: begin
                        data_sew8[i][14:8] = {7{velements_a.sew8[i][7]}};
                        data_sew8[i][7] = velements_a.sew8[i][7];
                        data_sew8[i][6:0] = velements_a.sew8[i][6:0];
                    end
                    VROL: begin
                        data_sew8[i][14:8] = velements_a.sew8[i][7:1];
                        data_sew8[i][7] = velements_a.sew8[i][0];
                        data_sew8[i][6:0] = velements_a.sew8[i][7:1];
                    end
                    VROR: begin
                        data_sew8[i][14:8] = velements_a.sew8[i][6:0];
                        data_sew8[i][7] = velements_a.sew8[i][7];
                        data_sew8[i][6:0] = velements_a.sew8[i][6:0];
                    end
                    default: begin
                        data_sew8[i] = '0;
                    end
                endcase

                data_vd[8*i +: 8] = trunc_15_8(data_sew8[i] >> shift_amount[i]);

                if (is_scaling) begin
                    data_vd_scaled[8*i +: 8] = trunc_9_8(data_vd[8*i +: 8] + rounding_increment[i]);
                end
                else begin
                    data_vd_scaled[8*i +: 8] = data_vd[8*i +: 8];
                end
            end
        end
        SEW_16: begin
            for (int i = 0; i < 4; ++i) begin
                case (instr_type_i)
                    VSLL: begin
                        data_sew16[i][30:16] = velements_a.sew16[i][15:1];
                        data_sew16[i][15] = velements_a.sew16[i][0];
                        data_sew16[i][14:0] = '0;
                    end
                    VSRL, VSSRL, VNSRL: begin
                        data_sew16[i][30:16] = '0;
                        data_sew16[i][15] = velements_a.sew16[i][15];
                        data_sew16[i][14:0] = velements_a.sew16[i][14:0];
                    end
                    VSRA, VSSRA, VNSRA: begin
                        data_sew16[i][30:16] = {15{velements_a.sew16[i][15]}};
                        data_sew16[i][15] = velements_a.sew16[i][15];
                        data_sew16[i][14:0] = velements_a.sew16[i][14:0];
                    end
                    VROL: begin
                        data_sew16[i][30:16] = velements_a.sew16[i][15:1];
                        data_sew16[i][15] = velements_a.sew16[i][0];
                        data_sew16[i][14:0] = velements_a.sew16[i][15:1];
                    end
                    VROR: begin
                        data_sew16[i][30:16] = velements_a.sew16[i][14:0];
                        data_sew16[i][15] = velements_a.sew16[i][15];
                        data_sew16[i][14:0] = velements_a.sew16[i][14:0];
                    end
                    VWSLL: begin
                        data_sew16[i][30:23] = '0;
                        data_sew16[i][22:16] = velements_a.sew8[i][7:1];
                        data_sew16[i][15] = velements_a.sew8[i][0];
                        data_sew16[i][14:0] = '0;
                    end
                    default: begin
                        data_sew16[i] = '0;
                    end
                endcase

                if (is_narrow) begin
                    data_vd[8*i +: 8] = trunc_31_8(data_sew16[i] >> shift_amount[i]);
                end
                else begin
                    data_vd[16*i +: 16] = trunc_31_16(data_sew16[i] >> shift_amount[i]);
                end

                if (is_scaling) begin
                    data_vd_scaled[16*i +: 16] = trunc_17_16(data_vd[16*i +: 16] + rounding_increment[i]);
                end
                else begin
                    if (is_narrow) begin
                        data_vd_scaled[8*i +: 8] = data_vd[8*i +: 8];
                    end
                    else begin
                        data_vd_scaled[16*i +: 16] = data_vd[16*i +: 16];
                    end
                end
            end
        end
        SEW_32: begin
            for (int i = 0; i < 2; ++i) begin
                case (instr_type_i)
                    VSLL: begin
                        data_sew32[i][62:32] = velements_a.sew32[i][31:1];
                        data_sew32[i][31] = velements_a.sew32[i][0];
                        data_sew32[i][30:0] = '0;
                    end
                    VSRL, VSSRL, VNSRL: begin
                        data_sew32[i][62:32] = '0;
                        data_sew32[i][31] = velements_a.sew32[i][31];
                        data_sew32[i][30:0] = velements_a.sew32[i][30:0];
                    end
                    VSRA, VSSRA, VNSRA: begin
                        data_sew32[i][62:32] = {31{velements_a.sew32[i][31]}};
                        data_sew32[i][31] = velements_a.sew32[i][31];
                        data_sew32[i][30:0] = velements_a.sew32[i][30:0];
                    end
                    VROL: begin
                        data_sew32[i][62:32] = velements_a.sew32[i][31:1];
                        data_sew32[i][31] = velements_a.sew32[i][0];
                        data_sew32[i][30:0] = velements_a.sew32[i][31:1];
                    end
                    VROR: begin
                        data_sew32[i][62:32] = velements_a.sew32[i][30:0];
                        data_sew32[i][31] = velements_a.sew32[i][31];
                        data_sew32[i][30:0] = velements_a.sew32[i][30:0];
                    end
                    VWSLL: begin
                        data_sew32[i][62:47] = '0;
                        data_sew32[i][46:32] = velements_a.sew16[i][15:1];
                        data_sew32[i][31] = velements_a.sew16[i][0];
                        data_sew32[i][30:0] = '0;
                    end
                    default: begin
                        data_sew32[i] = '0;
                    end
                endcase

                if (is_narrow) begin
                    data_vd[16*i +: 16] = trunc_63_16(data_sew32[i] >> shift_amount[i]);
                end
                else begin
                    data_vd[32*i +: 32] = trunc_63_32(data_sew32[i] >> shift_amount[i]);
                end

                if (is_scaling) begin
                    data_vd_scaled[32*i +: 32] = trunc_33_32(data_vd[32*i +: 32] + rounding_increment[i]);
                end
                else begin
                    if (is_narrow) begin
                        data_vd_scaled[16*i +: 16] = data_vd[16*i +: 16];
                    end
                    else begin
                        data_vd_scaled[32*i +: 32] = data_vd[32*i +: 32];
                    end
                end
            end
        end
        SEW_64: begin
            case (instr_type_i)
                VSLL: begin
                    data_sew64[126:64] = velements_a.sew64[0][63:1];
                    data_sew64[63] = velements_a.sew64[0][0];
                    data_sew64[62:0] = '0;
                end
                VSRL, VSSRL, VNSRL: begin
                    data_sew64[126:64] = '0;
                    data_sew64[63] = velements_a.sew64[0][63];
                    data_sew64[62:0] = velements_a.sew64[0][62:0];
                end
                VSRA, VSSRA, VNSRA: begin
                    data_sew64[126:64] = {63{velements_a.sew64[0][63]}};
                    data_sew64[63] = velements_a.sew64[0][63];
                    data_sew64[62:0] = velements_a.sew64[0][62:0];
                end
                VROL: begin
                    data_sew64[126:64] = velements_a.sew64[0][63:1];
                    data_sew64[63] = velements_a.sew64[0][0];
                    data_sew64[62:0] = velements_a.sew64[0][63:1];
                end
                VROR: begin
                    data_sew64[126:64] = velements_a.sew64[0][62:0];
                    data_sew64[63] = velements_a.sew64[0][63];
                    data_sew64[62:0] = velements_a.sew64[0][62:0];
                end
                VWSLL: begin
                    data_sew64[126:95] = '0;
                    data_sew64[94:64] = velements_a.sew32[0][31:1];
                    data_sew64[63] = velements_a.sew32[0][0];
                    data_sew64[62:0] = '0;
                end
                default: begin
                    data_sew64 = '0;
                end
            endcase

            if (is_narrow) begin
                data_vd[31:0] = trunc_127_32(data_sew64 >> shift_amount[0]);
            end
            else begin
                data_vd = trunc_127_64(data_sew64 >> shift_amount[0]);
            end

            if (is_scaling) begin
                data_vd_scaled = trunc_65_64(data_vd + rounding_increment[0]);
            end
            else begin
                if (is_narrow) begin
                    data_vd_scaled = data_vd[31:0];
                end
                else begin
                    data_vd_scaled = data_vd;
                end
            end
        end
        default: begin
            data_sew64 = '0;
        end
    endcase

    data_vd_o = data_vd_scaled;
end
endmodule
