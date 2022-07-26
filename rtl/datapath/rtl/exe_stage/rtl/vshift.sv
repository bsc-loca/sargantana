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
logic is_signed;
logic is_left;

always_comb begin
    //If we need to perform a left shift, we flip all of the vs2 bits invert
    //the vs1 elements, perform a right shift, and then flip all the bits of
    //the result.

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
    endcase
            

    is_signed = instr_type_i == VSRA ? 1'b1 : 1'b0;
    is_left   = instr_type_i == VSLL ? 1'b1 : 1'b0;

    data_a = is_left ? data_vs2_flipped : data_vs2_i;
    data_b = is_left ? data_vs1_flipped : data_vs1_i;

    case (sew_i)
        //If the operation is signed, we append the most significant bit of
        //the element to itself. Otherwise, we append
        //a 0 to ensure an unsigned shift.

        SEW_8: begin
            for (int i = 0; i<8; ++i) begin
                data_vd[(i*8)+:8] = $signed({is_signed & data_a[(i*8)+7], data_a[(i*8)+:8]}) >>> data_b[(i*8)+:3];
            end
        end
        SEW_16: begin
            for (int i = 0; i<4; ++i) begin
                data_vd[(i*16)+:16] = $signed({is_signed & data_a[(i*16)+15], data_a[(i*16)+:16]}) >>> data_b[(i*16)+:4];
            end
        end
        SEW_32: begin
            for (int i = 0; i<2; ++i) begin
                data_vd[(i*32)+:32] = $signed({is_signed & data_a[(i*32)+31], data_a[(i*32)+:32]}) >>> data_b[(i*32)+:5];
            end
        end
        SEW_64: begin
            data_vd = $signed({is_signed & data_a[63], data_a}) >>> data_b[5:0];
        end
    endcase

    for (int i = 0; i<64; ++i) begin
        //If the shift was to the left, we flip the result back.
        data_vd_flipped[i] = data_vd[63-i];
    end

    data_vd_o = is_left ? data_vd_flipped : data_vd;
end
endmodule
