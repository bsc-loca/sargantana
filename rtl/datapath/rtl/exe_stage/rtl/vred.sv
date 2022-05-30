/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vred.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Xavier Carril & Lorién López 
 * Email(s)       : xavier.carril@bsc.es & lorien.lopez@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

module vred (
  input wire                  clk_i,          // Clock
  input wire                  rstn_i,         // Reset 
  input instr_type_t          instr_type_i,   // Instruction type
  input sew_t                 sew_i,          // Element width
  input bus_simd_t            data_fu_i,      // Result of vs1[0] and vs2[0] in data_fu[0]
  input bus_simd_t            data_vs2_i,     // 128-bit source operand 
  output bus_simd_t           red_data_vd_o   // 128-bit result (only cares last element)
);


////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 0                                   //
////////////////////////////////////////////////////////////////////////////////
sew_t sew_0;
bus_simd_t data_vs_0;
instr_type_t instr_type_0;

assign sew_0 = sew_i;
assign instr_type_0 = instr_type_i;

always_comb begin
    case(sew_0)
        SEW_8: begin
            data_vs_0 = {data_vs2_i[127:8], data_fu_i[7:0]};
        end
        SEW_16: begin
            data_vs_0 = {data_vs2_i[127:16], data_fu_i[15:0]};
        end
        SEW_32: begin
            data_vs_0 = {data_vs2_i[127:32], data_fu_i[31:0]};
        end
        SEW_64: begin
            data_vs_0 = {data_vs2_i[127:64], data_fu_i[63:0]};
        end
    endcase
end

////////////////////////////////////////////////////////////////////////////////
//                              STAGE 0 -> STAGE 1                            //
////////////////////////////////////////////////////////////////////////////////
sew_t sew_1;
bus_simd_t data_vs_1;
instr_type_t instr_type_1;

always_ff@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        sew_1                    <= SEW_8;
        data_vs_1                <= '0;
        instr_type_1             <= ADD;
    end
    else begin
        sew_1                    <= sew_0;
        data_vs_1                <= data_vs_0;
        instr_type_1             <= instr_type_0;
    end
end

////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 1                                   //
////////////////////////////////////////////////////////////////////////////////
logic [15:0] res_l1 [7:0];
logic [31:0] res_l2 [3:0];
logic [63:0] res_l3 [1:0];
always_comb begin
    res_l1 = '{default:'{default:'0}};
    res_l2 = '{default:'{default:'0}};
    res_l3 = '{default:'{default:'0}};
    case (instr_type_1)
        //Vector Reduction Sum 
        VREDSUM: begin
            case (sew_1)
                SEW_8: begin
                    for (int i=0; i < 8; i++) res_l1[i] = data_vs_1[i*16+8 +: 8] + data_vs_1[i*16 +: 8];
                    for (int i=0; i < 4; i++) res_l2[i] = res_l1[i*2] + res_l1[i*2+1];
                    for (int i=0; i < 2; i++) res_l3[i] = res_l2[i*2] + res_l2[i*2+1];
                    red_data_vd_o = {112'h0, res_l3[0] + res_l3[1]};
                end
                SEW_16: begin
                    for (int i=0; i < 4; i++) res_l1[i] = data_vs_1[i*32+16 +: 16] + data_vs_1[i*32 +: 16];
                    for (int i=0; i < 2; i++) res_l2[i] = res_l1[i*2] + res_l1[i*2+1];
                    red_data_vd_o = {112'h0, res_l2[0] + res_l2[1]};
                end
                SEW_32: begin
                    for (int i=0; i < 2; i++) res_l1[i] = data_vs_1[i*64+32 +: 32] + data_vs_1[i*64 +: 32];
                    red_data_vd_o = {96'h0, res_l1[0] + res_l1[1]};
                end
                SEW_64: begin
                    red_data_vd_o = data_vs_1[127:64] + data_vs_1[63:0];
                end
                default : begin 
                    red_data_vd_o = '0;
                end
            endcase
        end
        //Vector Reduction AND
        VREDAND: begin
            case (sew_1)
                SEW_8: begin
                    for (int i=0; i < 8; i++) res_l1[i] = data_vs_1[i*16+8 +: 8] & data_vs_1[i*16 +: 8];
                    for (int i=0; i < 4; i++) res_l2[i] = res_l1[i*2] & res_l1[i*2+1];
                    for (int i=0; i < 2; i++) res_l3[i] = res_l2[i*2] & res_l2[i*2+1];
                    red_data_vd_o = {112'h0, res_l3[0] & res_l3[1]};
                end
                SEW_16: begin
                    for (int i=0; i < 4; i++) res_l1[i] = data_vs_1[i*32+16 +: 16] & data_vs_1[i*32 +: 16];
                    for (int i=0; i < 2; i++) res_l2[i] = res_l1[i*2] & res_l1[i*2+1];
                    red_data_vd_o = {112'h0, res_l2[0] & res_l2[1]};
                end
                SEW_32: begin
                    for (int i=0; i < 2; i++) res_l1[i] = data_vs_1[i*64+32 +: 32] & data_vs_1[i*64 +: 32];
                    red_data_vd_o = {96'h0, res_l1[0] & res_l1[1]};
                end
                SEW_64: begin
                    red_data_vd_o = data_vs_1[127:64] & data_vs_1[63:0];
                end
                default : begin 
                    red_data_vd_o = '0;
                end
            endcase
        end
        //Vector Reduction OR
        VREDOR: begin
            case (sew_1)
                SEW_8: begin
                    for (int i=0; i < 8; i++) res_l1[i] = data_vs_1[i*16+8 +: 8] | data_vs_1[i*16 +: 8];
                    for (int i=0; i < 4; i++) res_l2[i] = res_l1[i*2] | res_l1[i*2+1];
                    for (int i=0; i < 2; i++) res_l3[i] = res_l2[i*2] | res_l2[i*2+1];
                    red_data_vd_o = {112'h0, res_l3[0] | res_l3[1]};
                end
                SEW_16: begin
                    for (int i=0; i < 4; i++) res_l1[i] = data_vs_1[i*32+16 +: 16] | data_vs_1[i*32 +: 16];
                    for (int i=0; i < 2; i++) res_l2[i] = res_l1[i*2] | res_l1[i*2+1];
                    red_data_vd_o = {112'h0, res_l2[0] | res_l2[1]};
                end
                SEW_32: begin
                    for (int i=0; i < 2; i++) res_l1[i] = data_vs_1[i*64+32 +: 32] | data_vs_1[i*64 +: 32];
                    red_data_vd_o = {96'h0, res_l1[0] | res_l1[1]};
                end
                SEW_64: begin
                    red_data_vd_o = data_vs_1[127:64] | data_vs_1[63:0];
                end
                default : begin 
                    red_data_vd_o = '0;
                end
            endcase
        end
        //Vector Reduction XOR 
        VREDXOR: begin
            case (sew_1)
                SEW_8: begin
                    for (int i=0; i < 8; i++) res_l1[i] = data_vs_1[i*16+8 +: 8] ^ data_vs_1[i*16 +: 8];
                    for (int i=0; i < 4; i++) res_l2[i] = res_l1[i*2] ^ res_l1[i*2+1];
                    for (int i=0; i < 2; i++) res_l3[i] = res_l2[i*2] ^ res_l2[i*2+1];
                    red_data_vd_o = {112'h0, res_l3[0] ^ res_l3[1]};
                end
                SEW_16: begin
                    for (int i=0; i < 4; i++) res_l1[i] = data_vs_1[i*32+16 +: 16] ^ data_vs_1[i*32 +: 16];
                    for (int i=0; i < 2; i++) res_l2[i] = res_l1[i*2] ^ res_l1[i*2+1];
                    red_data_vd_o = {112'h0, res_l2[0] ^ res_l2[1]};
                end
                SEW_32: begin
                    for (int i=0; i < 2; i++) res_l1[i] = data_vs_1[i*64+32 +: 32] ^ data_vs_1[i*64 +: 32];
                    red_data_vd_o = {96'h0, res_l1[0] ^ res_l1[1]};
                end
                SEW_64: begin
                    red_data_vd_o = data_vs_1[127:64] ^ data_vs_1[63:0];
                end
                default : begin 
                    red_data_vd_o = '0;
                end
            endcase
        end
        default: begin
            res_l1 = '{default:'{default:'0}};
            res_l2 = '{default:'{default:'0}};
            res_l3 = '{default:'{default:'0}};
            red_data_vd_o = '0;
        end 
    endcase
end
endmodule