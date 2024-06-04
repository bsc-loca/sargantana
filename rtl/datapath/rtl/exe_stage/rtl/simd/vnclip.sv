/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vnclip
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Juan Antonio Rodriguez Gracia
 * Email(s)       : juan.rodriguez4@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Juan Antonio Rodriguez |
 *
 */

module vnclip 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input vxrm_t                vxrm_i,         // Vector Fixed-Point Rounding Mode
    input bus64_t               data_vs1_i,     // 64-bit source operand 1
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o,      // 64-bit result
    output logic                sat_ovf_o       // Saturation done on overflow
);

localparam [63:0] UNSIGNED_RANGE_SEW_32 = 2**32;
localparam [63:0] SIGNED_RANGE_SEW_32 = 2**(32-1);
localparam [16:0] UNSIGNED_RANGE_SEW_16 = 2**16;
localparam [16:0] SIGNED_RANGE_SEW_16 = 2**(16-1);
localparam [8:0] UNSIGNED_RANGE_SEW_8 = 2**8;
localparam [8:0] SIGNED_RANGE_SEW_8 = 2**(8-1);



function [7:0] trunc_17_to_8_bits(input [16:0] val_in);
    trunc_17_to_8_bits = val_in[7:0];
endfunction

function [15:0] trunc_17_to_16_bits(input [16:0] val_in);
    trunc_17_to_16_bits = val_in[15:0];
endfunction

function [15:0] trunc_33_to_16_bits(input [32:0] val_in);
    trunc_33_to_16_bits = val_in[15:0];
endfunction

function [31:0] trunc_33_to_32_bits(input [32:0] val_in);
    trunc_33_to_32_bits = val_in[31:0];
endfunction

function [15:0] trunc_34_to_16_bits(input [33:0] val_in);
    trunc_34_to_16_bits = val_in[15:0];
endfunction

function [63:0] trunc_65_to_64_bits(input [64:0] val_in);
    trunc_65_to_64_bits = val_in[63:0];
endfunction

function [31:0] trunc_65_to_32_bits(input [64:0] val_in);
    trunc_65_to_32_bits = val_in[31:0];
endfunction

function [31:0] trunc_66_to_32_bits(input [65:0] val_in);
    trunc_66_to_32_bits = val_in[31:0];
endfunction

function [63:0] trunc_129_to_64_bits(input [128:0] val_in);
    trunc_129_to_64_bits = val_in[63:0];
endfunction


function [63:0] trunc_130_to_64_bits(input [129:0] val_in);
    trunc_130_to_64_bits = val_in[63:0];
endfunction



bus64_t pre_result_vd_o;
bus64_t prev_truncate_shift;
bus64_t d_shifted_value;
logic [3:0] not_negative;
logic [3:0] to_add;
logic [129:0] tmp;
//rounding and saturation
always_comb begin
    pre_result_vd_o = '0;
    d_shifted_value = '0;
    case (sew_i)
        SEW_32: begin
            case (vxrm_i)
                RNU_V: begin
                    to_add[0] = data_vs2_i[data_vs1_i[5:0]-1]; //v[d-1]
                end
                RNE_V: begin
                    not_negative[0] = (data_vs1_i[5:0]-2) >= 0;
                    tmp = data_vs2_i << (64 - (data_vs1_i[5:0]-2));
                    d_shifted_value = trunc_130_to_64_bits(tmp);
                    to_add[0] = data_vs2_i[data_vs1_i[5:0]-1] & //v[d-1] & (v[d-2:0]≠0 | v[d])
                                (((d_shifted_value != '0) & not_negative[0])
                                | (data_vs2_i[data_vs1_i[5:0]]));
                end    
                RDN_V: begin
                    to_add[0] = 1'b0; 
                end
                ROD_V: begin
                    not_negative[0] = (data_vs1_i[5:0]-2) >= 0;
                    tmp[128:0] = data_vs2_i << (64 - (data_vs1_i[5:0]-1));
                    d_shifted_value = trunc_129_to_64_bits(tmp[128:0]);
                    to_add[0] = ((!data_vs2_i[data_vs1_i[5:0]]) & 
                                ((d_shifted_value != '0) & not_negative[0])); //!v[d] & v[d-1:0]≠0
                end
                default:
                    to_add[0] = 1'b0;
            endcase
            case (instr_type_i)
                VNCLIP: begin
                    prev_truncate_shift = ($signed(data_vs2_i) >>> data_vs1_i[5:0]);
                    pre_result_vd_o = trunc_65_to_64_bits(prev_truncate_shift + to_add[0]);
                end
                VNCLIPU: begin
                    prev_truncate_shift = (data_vs2_i >> data_vs1_i[5:0]);
                    pre_result_vd_o = trunc_65_to_64_bits(prev_truncate_shift + to_add[0]);                
                end
                default: begin
                    pre_result_vd_o = 64'h0000000000000000;
                end
            endcase  
        end        
        SEW_16: begin
            for (int i = 0; i < 2; i++) begin
                case (vxrm_i)
                    RNU_V: begin
                        to_add[i] = data_vs2_i[(i*16 + data_vs1_i[i*16 +: 5])-1]; //v[d-1]
                    end
                    RNE_V: begin
                        not_negative[i] = (data_vs1_i[i*8 +: 4]-2) >= 0;
                        tmp[66*i +: 66] = data_vs2_i[i*16 +: 16] << (16 - (data_vs1_i[i*8 +: 4]-2));
                        d_shifted_value[i*32 +: 32] = trunc_66_to_32_bits(tmp[66*i +: 66]);
                        to_add[i] = data_vs2_i[(data_vs1_i[i*16 +: 5]-1)+(i*32)] & 
                                    (((d_shifted_value[i*32 +: 32] != '0) & not_negative[i])
                                    | (data_vs2_i[(data_vs1_i[i*16 +: 5] + (i*32))]));//v[d-1] & (v[d-2:0]≠0 | v[d])
                    end
                    RDN_V: begin
                        to_add[i] = 1'b0;
                    end
                    ROD_V: begin
                        not_negative[i] = (data_vs1_i[i*8 +: 4]-1) >= 0;
                        tmp[65*i +: 65] = data_vs2_i[i*32 +: 32] << (32 - (data_vs1_i[i*16 +: 5]-1));
                        d_shifted_value[i*32 +: 32] = trunc_65_to_32_bits(tmp[65*i +: 65]);
                        to_add[i] = ((!data_vs2_i[(data_vs1_i[i*16 +: 5]+(i*32))]) & 
                                    ((d_shifted_value[i*32 +: 32] != '0) & not_negative[i])); //!v[d] & v[d-1:0]≠0                      
                    end
                    default: begin
                        to_add[i] = 1'b0;
                    end
                endcase
                case (instr_type_i)
                    VNCLIP: begin
                        prev_truncate_shift[i*32 +: 32] = ($signed(data_vs2_i[i*32 +: 32]) >>> data_vs1_i[i*16 +: 5]);
                        //pre_result_vd_o[i*32 +: 32] = trunc_33_to_32_bits(($signed(data_vs2_i[i*32 +: 32]) >>> data_vs1_i[i*16 +: 5]) + to_add[i]);
                        pre_result_vd_o[i*32 +: 32] = trunc_33_to_32_bits(prev_truncate_shift[i*32 +: 32] + to_add[i]);
                    end
                    VNCLIPU: begin
                        prev_truncate_shift[i*32 +: 32] = (data_vs2_i[i*32 +: 32] >> data_vs1_i[i*16 +: 5]);
                        pre_result_vd_o[i*32 +: 32] = trunc_33_to_32_bits(prev_truncate_shift[i*32 +: 32] + to_add[i]);
                    end
                    default:
                        pre_result_vd_o = 64'h0000000000000000;
                endcase 
            end
        end        
        SEW_8: begin
            for (int i = 0; i < 4; i++) begin
                case (vxrm_i)
                    RNU_V: begin
                        to_add[i] = data_vs2_i[(i*8 + data_vs1_i[i*8 +: 4])-1]; //v[d-1]
                    end
                    RNE_V: begin
                        not_negative[i] = (data_vs1_i[i*8 +: 4]-2) >= 0;
                        tmp[i*34 +: 34] = data_vs2_i[i*16 +: 16] << (16 - (data_vs1_i[i*8 +: 4]-2));
                        d_shifted_value[i*16 +: 16] = trunc_34_to_16_bits(tmp[i*34 +: 34]);
                        to_add[i] = data_vs2_i[(data_vs1_i[i*8 +: 4]-1)+(i*16)] & 
                                    (((d_shifted_value[i*16 +: 16] != '0) & not_negative[i])
                                    | (data_vs2_i[(data_vs1_i[i*8 +: 4]+(i*16))]));//v[d-1] & (v[d-2:0]≠0 | v[d])
                    end
                    RDN_V: begin
                        to_add[i] = 1'b0;
                    end
                    ROD_V: begin
                        not_negative[i] = (data_vs1_i[i*8 +: 4]-1) >= 0;
                        tmp[i*33 +: 33] = data_vs2_i[i*16 +: 16] << (16 - (data_vs1_i[i*8 +: 4]-1));
                        d_shifted_value[i*16 +: 16] = trunc_33_to_16_bits(tmp[i*33 +: 33]);
                        to_add[i] = ((!data_vs2_i[data_vs1_i[i*8 +: 4]+(i*16)]) & 
                                    ((d_shifted_value[i*16 +: 16] != '0) & not_negative[i])); //!v[d] & v[d-1:0]≠0                      
                    end
                    default: begin
                        to_add[i] = 1'b0;
                    end
                endcase
                case (instr_type_i)
                    VNCLIP: begin
                        prev_truncate_shift[i*16 +: 16] = ($signed(data_vs2_i[i*16 +: 16]) >>> data_vs1_i[i*8 +: 4]);
                        pre_result_vd_o[i*16 +: 16] = trunc_17_to_16_bits(prev_truncate_shift[i*16 +: 16] + to_add[i]);
                    end
                    VNCLIPU: begin
                        prev_truncate_shift[i*16 +: 16] = (data_vs2_i[i*16 +: 16] >> data_vs1_i[i*8 +: 4]);
                        pre_result_vd_o[i*16 +: 16] = trunc_17_to_16_bits(prev_truncate_shift[i*16 +: 16] + to_add[i]);
                    end
                    default:
                        pre_result_vd_o = 64'h0000000000000000;
                endcase 
            end
        end
        default: begin
            pre_result_vd_o = 64'h0000000000000000;
        end
    endcase
end


// detects overlow and saturation
always_comb begin
    sat_ovf_o = '0;
    data_vd_o = '0;
    case (sew_i)
        SEW_32: begin
            case (instr_type_i)
                VNCLIPU: begin
                    if(pre_result_vd_o > UNSIGNED_RANGE_SEW_32) begin
                        sat_ovf_o = '1;
                        data_vd_o = '1;
                    end else begin 
                        sat_ovf_o = '0;
                        data_vd_o = pre_result_vd_o;
                    end
                end
                VNCLIP: begin
                    if($signed(pre_result_vd_o[63:0]) > $signed((SIGNED_RANGE_SEW_32-1))) begin
                        sat_ovf_o = '1;
                        data_vd_o = 'h7fffffff;
                    end else begin 
                        sat_ovf_o = '0;
                        data_vd_o = pre_result_vd_o;
                    end
                end                                                      
                default: begin
                    data_vd_o = '0;
                end
            endcase     
        end
        SEW_16: begin
            for (int i = 0; i < 2; i++) begin
                case (instr_type_i)
                    VNCLIPU: begin
                        if(pre_result_vd_o[i*32 +: 32] > UNSIGNED_RANGE_SEW_16) begin
                            sat_ovf_o = '1;
                            data_vd_o[i*16 +: 16] = '1;
                        end else begin 
                            sat_ovf_o = '0;
                            data_vd_o[i*16 +: 16] = pre_result_vd_o[i*32 +: 16];
                        end
                    end
                    VNCLIP: begin
                        if($signed(pre_result_vd_o[i*32 +: 32]) > $signed((SIGNED_RANGE_SEW_16 - 1))) begin
                            sat_ovf_o = '1;
                            data_vd_o[i*16 +: 15] = '1;
                        end else begin 
                            sat_ovf_o = '0;
                            data_vd_o[i*16 +: 16] = pre_result_vd_o[i*32 +: 16];
                        end
                    end                                                          
                    default: begin
                        data_vd_o = '0;
                    end
                endcase
            end     
        end
        SEW_8: begin
            for (int i = 0; i < 4; i++) begin
                case (instr_type_i)
                    VNCLIPU: begin
                        if(pre_result_vd_o[i*16 +: 16] > UNSIGNED_RANGE_SEW_8) begin
                            sat_ovf_o = '1;
                            data_vd_o[i*8 +: 8] = '1;
                        end else begin 
                            sat_ovf_o = '0;
                            data_vd_o[i*8 +: 8] = pre_result_vd_o[i*16 +: 8];
                        end
                    end
                    VNCLIP: begin
                        if($signed(pre_result_vd_o[i*16 +: 16]) > $signed((SIGNED_RANGE_SEW_8 - 1))) begin
                            sat_ovf_o = '1;
                            data_vd_o[i*8 +: 7] = '1;
                        end else begin 
                            sat_ovf_o = '0;
                            data_vd_o[i*8 +: 8] = pre_result_vd_o[i*16 +: 8];
                        end
                    end                                                          
                    default: begin
                        data_vd_o = '0;
                    end
                endcase
            end     
        end                               
        default: begin
            sat_ovf_o = '0;
            data_vd_o = '0;
        end
    endcase
end


endmodule