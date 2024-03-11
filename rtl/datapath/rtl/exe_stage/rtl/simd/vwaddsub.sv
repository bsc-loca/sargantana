/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vwaddsub.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Xavier Carril Gil
 * Email(s)       : xavier.carril@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Xavier C. | 
 * -----------------------------------------------
 */

module vwaddsub 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input bus32_t               data_vs1_i,     // 32-bit source operand 1
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);

function [15:0] trunc_16bits(input [16:0] val_in);
    trunc_16bits = val_in[15:0];
endfunction

function [31:0] trunc_32bits(input [32:0] val_in);
    trunc_32bits = val_in[31:0];
endfunction

function [63:0] trunc_64bits(input [64:0] val_in);
    trunc_64bits = val_in[63:0];
endfunction

always_comb begin
    case (sew_i)
        SEW_8: 
            for (int i = 0; i < 4; i++) begin
                case(instr_type_i)
                    VWADD:  data_vd_o[16*i +: 16] = $signed(data_vs2_i[8*i +: 8]) + $signed(data_vs1_i[8*i +: 8]);
                    VWADDU: data_vd_o[16*i +: 16] = $unsigned(data_vs2_i[8*i +: 8]) + $unsigned(data_vs1_i[8*i +: 8]);
                    VWSUB:  data_vd_o[16*i +: 16] = $signed(data_vs2_i[8*i +: 8]) - $signed(data_vs1_i[8*i +: 8]);
                    VWSUBU: data_vd_o[16*i +: 16] = $unsigned(data_vs2_i[8*i +: 8]) - $unsigned(data_vs1_i[8*i +: 8]);

                    VWADDW:  data_vd_o[16*i +: 16] = trunc_16bits($signed(data_vs2_i[16*i +: 16]) + $signed({{8{data_vs1_i[(8*i)+7]}},data_vs1_i[8*i +: 8]}));
                    VWADDUW: data_vd_o[16*i +: 16] = trunc_16bits($unsigned(data_vs2_i[16*i +: 16]) + $unsigned(data_vs1_i[8*i +: 8]));
                    VWSUBW:  data_vd_o[16*i +: 16] = trunc_16bits($signed(data_vs2_i[16*i +: 16]) - $signed({{8{data_vs1_i[(8*i)+7]}},data_vs1_i[8*i +: 8]}));
                    VWSUBUW: data_vd_o[16*i +: 16] = trunc_16bits($unsigned(data_vs2_i[16*i +: 16]) - $unsigned(data_vs1_i[8*i +: 8]));

                    default: data_vd_o[16*i +: 16] = 16'b0;
                endcase
            end
        SEW_16: 
            for (int i = 0; i < 2; i++) begin
                case(instr_type_i)
                    VWADD: data_vd_o[32*i +: 32] = $signed(data_vs2_i[16*i +: 16]) + $signed(data_vs1_i[16*i +: 16]);
                    VWADDU: data_vd_o[32*i +: 32] = $unsigned(data_vs2_i[16*i +: 16]) + $unsigned(data_vs1_i[16*i +: 16]);
                    VWSUB:  data_vd_o[32*i +: 32] = $signed(data_vs2_i[16*i +: 16]) - $signed(data_vs1_i[16*i +: 16]);
                    VWSUBU: data_vd_o[32*i +: 32] = $unsigned(data_vs2_i[16*i +: 16]) - $unsigned(data_vs1_i[16*i +: 16]);

                    VWADDW: data_vd_o[32*i +: 32] = trunc_32bits($signed(data_vs2_i[32*i +: 32]) + $signed({{16{data_vs1_i[(16*i)+15]}},data_vs1_i[16*i +: 16]}));
                    VWADDUW: data_vd_o[32*i +: 32] = trunc_32bits($unsigned(data_vs2_i[32*i +: 32]) + $unsigned(data_vs1_i[16*i +: 16]));
                    VWSUBW:  data_vd_o[32*i +: 32] = trunc_32bits($signed(data_vs2_i[32*i +: 32]) - $signed({{16{data_vs1_i[(16*i)+15]}},data_vs1_i[16*i +: 16]}));
                    VWSUBUW: data_vd_o[32*i +: 32] = trunc_32bits($unsigned(data_vs2_i[32*i +: 32]) - $unsigned(data_vs1_i[16*i +: 16]));

                    default: data_vd_o[32*i +: 32] = 32'b0;
                endcase
            end
        SEW_32: 
            case(instr_type_i)
                VWADD:  data_vd_o[63:0] = $signed(data_vs2_i[31:0]) + $signed(data_vs1_i[31:0]);
                VWADDU: data_vd_o[63:0] = $unsigned(data_vs2_i[31:0]) + $unsigned(data_vs1_i[31:0]);
                VWSUB:  data_vd_o[63:0] = $signed(data_vs2_i[31:0]) - $signed(data_vs1_i[31:0]);
                VWSUBU: data_vd_o[63:0] = $unsigned(data_vs2_i[31:0]) - $unsigned(data_vs1_i[31:0]);

                VWADDW:  data_vd_o[63:0] = trunc_64bits($signed(data_vs2_i[63:0]) + $signed({{32{data_vs1_i[31]}},data_vs1_i[31:0]}));
                VWADDUW: data_vd_o[63:0] = trunc_64bits($unsigned(data_vs2_i[63:0]) + $unsigned(data_vs1_i[31:0]));
                VWSUBW:  data_vd_o[63:0] = trunc_64bits($signed(data_vs2_i[63:0]) - $signed({{32{data_vs1_i[31]}},data_vs1_i[31:0]}));
                VWSUBUW: data_vd_o[63:0] = trunc_64bits($unsigned(data_vs2_i[63:0]) - $unsigned(data_vs1_i[31:0]));

                default: data_vd_o[63:0] = 64'b0;
            endcase
        default:
            case(instr_type_i)
                VWADD:  data_vd_o[63:0] = $signed(data_vs2_i[31:0]) + $signed(data_vs1_i[31:0]);
                VWADDU: data_vd_o[63:0] = $unsigned(data_vs2_i[31:0]) + $unsigned(data_vs1_i[31:0]);
                VWSUB:  data_vd_o[63:0] = $signed(data_vs2_i[31:0]) - $signed(data_vs1_i[31:0]);
                VWSUBU: data_vd_o[63:0] = $unsigned(data_vs2_i[31:0]) - $unsigned(data_vs1_i[31:0]);

                VWADDW:  data_vd_o[63:0] = trunc_64bits($signed(data_vs2_i[63:0]) + $signed({{32{data_vs1_i[31]}},data_vs1_i[31:0]}));
                VWADDUW: data_vd_o[63:0] = trunc_64bits($unsigned(data_vs2_i[63:0]) + $unsigned(data_vs1_i[31:0]));
                VWSUBW:  data_vd_o[63:0] = trunc_64bits($signed(data_vs2_i[63:0]) - $signed({{32{data_vs1_i[31]}},data_vs1_i[31:0]}));
                VWSUBUW: data_vd_o[63:0] = trunc_64bits($unsigned(data_vs2_i[63:0]) - $unsigned(data_vs1_i[31:0]));

                default: data_vd_o[63:0] = 64'b0;
            endcase
    endcase
end

endmodule
