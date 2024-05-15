/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vsaaddsub.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gámez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Raúl G.   | 
 *  0.2        | Raúl G.   | Add subsection 12.2.
 * -----------------------------------------------
 */

module vsaaddsub 
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

logic [7:0] carry_in;
logic [7:0] carry_out;
logic [7:0] overflow;
bus64_t data_vs1;
bus64_t data_vs2;

logic [7:0][7:0] data_a;
logic [7:0][7:0] data_b;
logic [7:0][7:0] results;

logic is_saddu;
logic is_sadd;
logic is_ssubu;
logic is_ssub;

logic is_aaddu;
logic is_aadd;
logic is_asubu;
logic is_asub;

logic is_sub;

logic is_averaging;

assign is_saddu = (instr_type_i == VSADDU);
assign is_sadd  = (instr_type_i == VSADD);
assign is_ssubu = (instr_type_i == VSSUBU);
assign is_ssub  = (instr_type_i == VSSUB);

assign is_aaddu = (instr_type_i == VAADDU);
assign is_aadd  = (instr_type_i == VAADD);
assign is_asubu = (instr_type_i == VASUBU);
assign is_asub  = (instr_type_i == VASUB);

assign is_averaging = (is_aadd || is_aaddu || is_asub || is_asubu);

assign is_sub = (is_ssubu || is_ssub || is_asub || is_asubu);

always_comb begin
    if (is_sub) begin
        data_vs1 = ~data_vs1_i;
        data_vs2 = data_vs2_i;
    end else begin
        data_vs1 = data_vs1_i;
        data_vs2 = data_vs2_i;
    end

    // Depending on the element width each byte adder selects it's carry_in
    // - In case the previous sum is computing the same element, the carry_out of
    //   the previous sum is selected
    // - Otherwise, if the operation is a sub a 1'b1 is selected
    // - Otherwise, 1'b0 is selected because the operation is a sum
    carry_in[0] = (is_sub) ? 1'b1 : 1'b0;
    carry_in[1] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                    carry_out[0] : (is_sub) ?
                    1'b1 : 1'b0;
    carry_in[2] = ((sew_i == SEW_32) || (sew_i == SEW_64)) ?
                    carry_out[1] : (is_sub) ?
                    1'b1 : 1'b0;
    carry_in[3] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                    carry_out[2] : (is_sub) ?
                    1'b1 : 1'b0;
    carry_in[4] = (sew_i == SEW_64) ?
                    carry_out[3] : (is_sub) ?
                    1'b1 : 1'b0;
    carry_in[5] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                    carry_out[4] : (is_sub) ?
                    1'b1 : 1'b0;
    carry_in[6] = ((sew_i == SEW_32) || (sew_i == SEW_64)) ?
                    carry_out[5] : (is_sub) ?
                    1'b1 : 1'b0;
    carry_in[7] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                    carry_out[6] : (is_sub) ?
                    1'b1 : 1'b0;
end

// Operation
always_comb begin
    for (int i = 0; i < 8; i++) begin
        data_a[i] = data_vs1[i*8 +: 8];
        data_b[i] = data_vs2[i*8 +: 8];
        {carry_out[i], results[i]} = data_a[i] + data_b[i] + carry_in[i];
    end
end


// Overflow detection
always_comb begin
    for (int i = 0; i < 8; i++) begin
        case (instr_type_i)
            // The overflow on a sum without sign is the carry
            VSADDU:
                overflow[i] = carry_out[i];
            // The overflow on a signed sum is when the sign of the operators are equal and
            // the sign of the result is different of these
            VSADD:
                overflow[i] = (data_a[i][7] ^ results[i][7]) & (data_b[i][7] ^ results[i][7]);
            // The overflow on a sub without sign is the carry negated
            VSSUBU:
                overflow[i] = ~carry_out[i];
            // The overflow on a signed sub is when the sign of the operands are different
            // and the sign of the result is equal to the sign of the second operand ->
            // different of the first operand
            VSSUB:
                overflow[i] = (data_vs1_i[7 + i*8] ^ data_b[i][7]) & (data_b[i][7] ^ results[i][7]);
            default:
                overflow[i] = 1'b0;
        endcase
    end
end

logic [7:0] to_add;

// Select result: operation result if no overflow, saturation if overflow
always_comb begin
    case (sew_i)
        SEW_8:
            for (int i = 0; i < 8 ; i++) begin
                case (vxrm_i)
                    RNU_V:
                        to_add[i] = results[i][0];
                    RNE_V:
                        to_add[i] = results[i][0] & results[i][1]; // Due to be a shift of 1 the part of v[d-2:0] does not make sense because it would be v[-1:0]
                    RDN_V:
                        to_add[i] = 1'b0;
                    ROD_V:
                        to_add[i] = ~results[i][1] & results[i][0]; // results[0] is the same as results[d-1:0] != 0
                    default:
                        to_add[i] = 1'b0;
                endcase

                case (instr_type_i)
                    VSADDU:
                        data_vd_o[i*8 +: 8] = (overflow[i]) ? 8'hFF : results[i];
                    VSADD, VSSUB:
                        data_vd_o[i*8 +: 8] = (overflow[i]) ? 8'h7F + carry_out[i] : results[i];
                    VSSUBU:
                        data_vd_o[i*8 +: 8] = (overflow[i]) ? 8'h00 : results[i];
                    VAADDU:
                        data_vd_o[i*8 +: 8] = {carry_out[i], results[i][7:1]} + to_add[i];
                    VASUBU:
                        data_vd_o[i*8 +: 8] = {~carry_out[i], results[i][7:1]} + to_add[i];
                    VAADD, VASUB:
                        data_vd_o[i*8 +: 8] = {results[i][7], results[i][7:1]} + to_add[i];
                    default:
                        data_vd_o = 64'h0000000000000000;
                endcase

            end

        SEW_16:
            for (int i = 0; i < 4; i++) begin
                case (vxrm_i)
                    RNU_V:
                        to_add[i] = results[2*(i + 1) - 1][0];
                    RNE_V:
                        to_add[i] = results[2*(i + 1) - 1][0] & results[2*(i + 1) - 1][1]; // Due to be a shift of 1 the part of v[d-2:0] does not make sense because it would be v[-1:0]
                    RDN_V:
                        to_add[i] = 1'b0;
                    ROD_V:
                        to_add[i] = ~results[2*(i + 1) - 1][1] & results[2*(i + 1) - 1][0]; // results[0] is the same as results[d-1:0] != 0
                    default:
                        to_add[i] = 1'b0;
                endcase


                case (instr_type_i)
                    VSADDU:
                        data_vd_o[16*i +: 16] = (overflow[2*(i + 1) - 1]) ? 16'hFFFF : results[2*i +: 2];
                    VSADD, VSSUB:
                        data_vd_o[16*i +: 16] = (overflow[2*(i + 1) - 1]) ?
                                                    16'h7FFF + carry_out[2*(i + 1) - 1] : results[2*i +: 2];
                    VSSUBU:
                        data_vd_o[16*i +: 16] = (overflow[2*(i + 1) - 1]) ? 8'h00 : results[2*i +: 2];
                    VAADDU:
                        data_vd_o[16*i +: 16] = {carry_out[2*(i + 1) - 1], results[2*(i + 1) - 1], results[2*(i + 1) - 2][7:1]} + to_add[i];
                    VASUBU:
                        data_vd_o[16*i +: 16] = {~carry_out[2*(i + 1) - 1], results[2*(i + 1) - 1], results[2*(i + 1) - 2][7:1]} + to_add[i];
                    VAADD, VASUB:
                        data_vd_o[16*i +: 16] = {results[2*(i + 1) - 1][7], results[2*(i + 1) - 1], results[2*(i + 1) - 2][7:1]} + to_add[i];
                    default:
                        data_vd_o = 64'h0000000000000000;
                endcase
            end
        SEW_32:
            for (int i = 0; i < 2; i++) begin
                case (vxrm_i)
                    RNU_V:
                        to_add[i] = results[4*(i + 1) - 1][0];
                    RNE_V:
                        to_add[i] = results[4*(i + 1) - 1][0] & results[4*(i + 1) - 1][1]; // Due to be a shift of 1 the part of v[d-2:0] does not make sense because it would be v[-1:0]
                    RDN_V:
                        to_add[i] = 1'b0;
                    ROD_V:
                        to_add[i] = ~results[4*(i + 1) - 1][1] & results[4*(i + 1) - 1][0]; // results[0] is the same as results[d-1:0] != 0
                    default:
                        to_add[i] = 1'b0;
                endcase

               case (instr_type_i)
                    VSADDU:
                        data_vd_o[32*i +: 32] = (overflow[4*(i + 1) - 1]) ? 32'hFFFFFFFF : results[4*i +: 4];
                    VSADD, VSSUB:
                        data_vd_o[32*i +: 32] = (overflow[4*(i + 1) - 1]) ? 
                                                    32'h7FFFFFFF + carry_out[4*(i + 1) - 1] : results[4*i +: 4];
                    VSSUBU:
                        data_vd_o[32*i +: 32] = (overflow[4*(i + 1) - 1]) ? 32'h00000000 : results[4*i +: 4];
                    VAADDU:
                        data_vd_o[32*i +: 32] = {carry_out[4*(i + 1) - 1], results[4*(i + 1) - 1], results[4*(i + 1) - 2], results[4*(i + 1) - 3], results[4*(i + 1) - 4][7:1]} + to_add[i];
                    VASUBU:
                        data_vd_o[32*i +: 32] = {~carry_out[4*(i + 1) - 1], results[4*(i + 1) - 1], results[4*(i + 1) - 2], results[4*(i + 1) - 3], results[4*(i + 1) - 4][7:1]} + to_add[i];
                    VAADD, VASUB:
                        data_vd_o[32*i +: 32] = {results[4*(i + 1) - 1][7], results[4*(i + 1) - 1], results[4*(i + 1) - 2], results[4*(i + 1) - 3], results[4*(i + 1) - 4][7:1]} + to_add[i];
                    default:
                        data_vd_o = 64'h0000000000000000;
                endcase
            end
        SEW_64: begin
            case (vxrm_i)
                RNU_V:
                    to_add[0] = results[0][0];
                RNE_V:
                    to_add[0] = results[0][0] & results[0][1]; // Due to be a shift of 1 the part of v[d-2:0] does not make sense because it would be v[-1:0]
                RDN_V:
                    to_add[0] = 1'b0;
                ROD_V:
                    to_add[0] = ~results[0][1] & results[0][0]; // results[0] is the same as results[d-1:0] != 0
                default:
                    to_add[0] = 1'b0;
            endcase

            case (instr_type_i)
                VSADDU:
                    data_vd_o = (overflow[7]) ? 64'hFFFFFFFFFFFFFFFF : results;
                VSADD, VSSUB:
                    data_vd_o = (overflow[7]) ? 
                                        64'h7FFFFFFFFFFFFFFF + carry_out[7] : results;
                VSSUBU:
                    data_vd_o = (overflow[7]) ? 64'h0000000000000000 : results;
                VAADDU:
                    data_vd_o = {carry_out[7], results[7], results[6], results[5], results[4], results[3], results[2], results[1], results[0][7:1]} + to_add[0];
                VASUBU:
                    data_vd_o = {~carry_out[7], results[7], results[6], results[5], results[4], results[3], results[2], results[1], results[0][7:1]} + to_add[0];
                VAADD, VASUB:
                    data_vd_o = {results[7][7], results[7], results[6], results[5], results[4], results[3], results[2], results[1], results[0][7:1]} + to_add[0];
                default:
                    data_vd_o = 64'h0000000000000000;
            endcase
        end
        default:
            data_vd_o = 64'h0000000000000000;
    endcase
end

// Send overflow detected
always_comb begin
    case (sew_i)
        SEW_8: begin
            sat_ovf_o = overflow != 8'b0;
        end
        SEW_16: begin
            sat_ovf_o = overflow[1] | overflow [3] | overflow[5] | overflow[7];
        end
        SEW_32: begin
            sat_ovf_o = overflow[3] | overflow [7];
        end
        SEW_64: begin
            sat_ovf_o = overflow[7];
        end
        default: begin
            sat_ovf_o = overflow[7];
        end
    endcase

end

endmodule