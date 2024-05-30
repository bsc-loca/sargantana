/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vshift.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Gerard Candón Arenas
 * Email(s)       : gerard.candon@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Gerard C. | 
 * -----------------------------------------------
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

//This module performs vector shifting operations. The strategy is to use
//only right signed shifters while supporting all types of shifts.

bus64_t data_vs1_flipped;
bus64_t data_vs2_flipped;
bus64_t data_a;
bus64_t data_b;
bus64_t data_vd;
bus64_t data_vd_flipped;
bus64_t rounding_increment;
logic is_signed;
logic is_left;
logic is_narrow;
logic [15:0] tmp_data_16b;
logic [31:0] tmp_data_32b;
logic [63:0] tmp_data_64b;
logic is_scaling;

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
    //If we need to perform a left shift, we flip all of the vs2 bits invert
    //the vs1 elements, perform a right shift, and then flip all the bits of
    //the result.

    // Remove latches
    tmp_data_16b = '0;
    tmp_data_32b = '0;
    tmp_data_64b = '0;

    for (int i = 0; i<64; ++i) begin
        data_vs2_flipped[i] = data_vs2_i[63-i];
    end
    
    case (sew_i)
        SEW_8: begin
            for (int i = 0; i<8; ++i) begin
                data_vs1_flipped[(i*8)+:8] = data_vs1_i[63-(i*8) -: 8];
            end
        end
        SEW_16: begin
            for (int i = 0; i<4; ++i) begin
                data_vs1_flipped[(i*16)+:16] = data_vs1_i[63-(i*16) -: 16];
            end
        end
        SEW_32: begin
            for (int i = 0; i<2; ++i) begin
                data_vs1_flipped[(i*32)+:32] = data_vs1_i[63-(i*32) -: 32];
            end
        end
        SEW_64: begin
            data_vs1_flipped = data_vs1_i;
        end
        default: begin
            data_vs1_flipped = 64'b0;
        end
    endcase

    is_signed = ((instr_type_i == VSRA) || (instr_type_i == VNSRA) || (instr_type_i == VSSRA)) ? 1'b1 : 1'b0;
    is_left   = (instr_type_i == VSLL) ? 1'b1 : 1'b0;
    is_narrow = ((instr_type_i == VNSRL) || (instr_type_i == VNSRA)) ? 1'b1 : 1'b0;
    is_scaling = ((instr_type_i == VSSRL) || (instr_type_i == VSSRA)) ? 1'b1 : 1'b0;

    data_a = is_left ? data_vs2_flipped : data_vs2_i;
    data_b = is_left ? data_vs1_flipped : data_vs1_i;

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
                                    rounding_increment[i] = rounding_increment[i] | velements_a.sew8[i][j]; 
                                end
                            end
                        end
                        rounding_increment[i] = (rounding_increment[i] | velements_a.sew8[i][(data_b[(i*8)+:3])+:1]) & velements_a.sew8[i][((data_b[(i*8)+:3])-1)+:1];  
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
                        rounding_increment[i] = (rounding_increment[i] | velements_a.sew16[i][(data_b[(i*16)+:4])+:1]) & velements_a.sew16[i][((data_b[(i*16)+:4])-1)+:1];  
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
                        rounding_increment[i] = (rounding_increment[i] | velements_a.sew32[i][(data_b[(i*32)+:5])+:1]) & velements_a.sew32[i][((data_b[(i*32)+:5])-1)+:1];  
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
                    rounding_increment[0] = (rounding_increment[0] | data_a[(data_b[5:0])+:1]) & data_a[((data_b[5:0])-1)+:1];  
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

    data_vd = '0;
    if (is_narrow) begin
        case (sew_i)
            SEW_8: begin
                for (int i = 0; i<4; ++i) begin
                    tmp_data_16b = $signed({is_signed & data_a[(i*16)+15], data_a[(i*16)+:16]}) >>> data_b[(i*8)+:4];
                    data_vd[(i*8)+:8] = tmp_data_16b[7:0];
                end
            end
            SEW_16: begin
                for (int i = 0; i<2; ++i) begin
                    tmp_data_32b = $signed({is_signed & data_a[(i*32)+31], data_a[(i*32)+:32]}) >>> data_b[(i*16)+:5];
                    data_vd[(i*16)+:16] = tmp_data_32b[15:0];
                end
            end
            SEW_32: begin
                tmp_data_64b = $signed({is_signed & data_a[63], data_a}) >>> data_b[5:0];
                data_vd[31:0] = tmp_data_64b[31:0];
            end
            default: begin
                data_vd = $signed({is_signed & data_a[63], data_a}) >>> data_b[5:0];
            end
        endcase   
    end else begin
        case (sew_i)
            //If the operation is signed, we append the most significant bit of
            //the element to itself. Otherwise, we append
            //a 0 to ensure an unsigned shift.

            SEW_8: begin
                for (int i = 0; i<8; ++i) begin
                    data_vd[(i*8)+:8] = $signed({is_signed & data_a[(i*8)+7], data_a[(i*8)+:8]}) >>> data_b[(i*8)+:3];
                    if (is_scaling) begin
                        data_vd[(i*8)+:8] = data_vd[(i*8)+:8] + rounding_increment[i];
                    end
                end
            end
            SEW_16: begin
                for (int i = 0; i<4; ++i) begin
                    data_vd[(i*16)+:16] = $signed({is_signed & data_a[(i*16)+15], data_a[(i*16)+:16]}) >>> data_b[(i*16)+:4];
                    if (is_scaling) begin
                        data_vd[(i*16)+:16] = data_vd[(i*16)+:16] + rounding_increment[i];
                    end
                end
            end
            SEW_32: begin
                for (int i = 0; i<2; ++i) begin
                    data_vd[(i*32)+:32] = $signed({is_signed & data_a[(i*32)+31], data_a[(i*32)+:32]}) >>> data_b[(i*32)+:5];
                    if (is_scaling) begin
                        data_vd[(i*32)+:32] = data_vd[(i*32)+:32] + rounding_increment[i];
                    end
                end
            end
            SEW_64: begin
                data_vd = $signed({is_signed & data_a[63], data_a}) >>> data_b[5:0];
                if (is_scaling) begin
                    data_vd= data_vd + rounding_increment[0];
                end
            end
            default: begin
                data_vd = 64'b0;
            end
        endcase
    end

    for (int i = 0; i<64; ++i) begin
        //If the shift was to the left, we flip the result back.
        data_vd_flipped[i] = data_vd[63-i];
    end
        
    data_vd_o = is_left ? data_vd_flipped : data_vd;
end
endmodule
