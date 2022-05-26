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
 // input instr_type_t          instr_type_i,   // Instruction type
  input sew_t                 sew_i,          // Element width
  input bus_simd_t            data_vs_i,      // 128-bit source operand 1
  output bus_simd_t           red_data_vd_o   // 128-bit result (only cares last element)
);


////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 0                                   //
////////////////////////////////////////////////////////////////////////////////
logic is_vredsum_0;
sew_t sew_0;
bus_simd_t data_vs_0;

//assign is_vredsum_0 = (instr_type_i == VREDSUM);
assign sew_0 = sew_i;
assign data_vs_0 = data_vs_i;

////////////////////////////////////////////////////////////////////////////////
//                              STAGE 0 -> STAGE 1                            //
////////////////////////////////////////////////////////////////////////////////
//logic is_vredsum_1;
sew_t sew_1;
bus_simd_t data_vs_1;


always_ff@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
//        is_vredsum_1             <= 1'b0; 
        sew_1                    <= SEW_8;
        data_vs_1                <= '0;
    end
    else begin
//        is_vredsum_1             <= is_vredsum_0; 
        sew_1                    <= sew_0;
        data_vs_1                <= data_vs_0;
    end
end

////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 1                                   //
////////////////////////////////////////////////////////////////////////////////
always_comb begin
    //Vector Reduction Sum 
    case (sew_1)
        SEW_8: begin
            logic [15:0] res_l10;
            logic [15:0] res_l11;
            logic [15:0] res_l12;
            logic [15:0] res_l13;
            logic [15:0] res_l14;
            logic [15:0] res_l15;
            logic [15:0] res_l16;
            logic [15:0] res_l17;
            logic [31:0] res_l20;
            logic [31:0] res_l21;
            logic [31:0] res_l22;
            logic [31:0] res_l23;
            logic [63:0] res_l30;
            logic [63:0] res_l31;
            res_l10 = data_vs_1[15:8] + data_vs_1[7:0]; 
            res_l11 = data_vs_1[31:24] + data_vs_1[23:16]; 
            res_l12 = data_vs_1[47:40] + data_vs_1[39:32]; 
            res_l13 = data_vs_1[63:56] + data_vs_1[55:48]; 
            res_l14 = data_vs_1[79:72] + data_vs_1[71:64]; 
            res_l15 = data_vs_1[95:88] + data_vs_1[87:80]; 
            res_l16 = data_vs_1[111:104] + data_vs_1[103:96]; 
            res_l17 = data_vs_1[127:120] + data_vs_1[119:112]; 
            res_l20 = res_l10 + res_l11; 
            res_l21 = res_l12 + res_l13; 
            res_l22 = res_l14 + res_l15; 
            res_l23 = res_l16 + res_l17; 
            res_l30 = res_l20 + res_l21; 
            res_l31 = res_l22 + res_l23; 
            red_data_vd_o = {112'h0, res_l30 + res_l31};
        end
        SEW_16: begin
            logic [31:0] res_l10;
            logic [31:0] res_l11;
            logic [31:0] res_l12;
            logic [31:0] res_l13;
            logic [63:0] res_l20;
            logic [63:0] res_l21;
            res_l10 = data_vs_1[31:16] + data_vs_1[15:0]; 
            res_l11 = data_vs_1[63:48] + data_vs_1[47:32]; 
            res_l12 = data_vs_1[95:80] + data_vs_1[79:64]; 
            res_l13 = data_vs_1[127:112] + data_vs_1[111:96]; 
            res_l20 = res_l10 + res_l11; 
            res_l21 = res_l12 + res_l13; 
            red_data_vd_o = {112'h0, res_l20 + res_l21};
        end
        SEW_32: begin
            logic [63:0] res_l10;
            logic [63:0] res_l11;
            res_l10 = data_vs_1[63:32] + data_vs_1[31:0]; 
            res_l11 = data_vs_1[127:96] + data_vs_1[95:64]; 
            red_data_vd_o = {96'h0, res_l10 + res_l11};
        end
        SEW_64: begin
            red_data_vd_o = data_vs_1[127:64] + data_vs_1[63:0];
        end
        default : begin 
            red_data_vd_o = '0;
        end
    endcase

end
endmodule