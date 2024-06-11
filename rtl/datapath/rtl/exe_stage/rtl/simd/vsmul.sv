/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vsmul.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gámez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Raúl G.   | 
 * -----------------------------------------------
 */

module vsmul
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input sew_t                 sew_i,          // Element width
    input vxrm_t                vxrm_i,         // Vector Fixed-Point Rounding Mode
    input bus128_t              data_i,         // Result of vmul module in 128-bit
    output bus64_t              data_vd_o,      // 64-bit result
    output logic                sat_ovf_o       // saturation done on overflow
);

function [7:0] trunc_16_to_8_bits(input [15:0] val_in);
    trunc_16_to_8_bits = val_in[15:8];
endfunction

function [15:0] trunc_32_to_16_bits(input [31:0] val_in);
    trunc_32_to_16_bits = val_in[31:16];
endfunction

function [31:0] trunc_64_to_32_bits(input [63:0] val_in);
    trunc_64_to_32_bits = val_in[63:32];
endfunction

function [63:0] trunc_127_to_64_bits(input [127:0] val_in);
    trunc_127_to_64_bits = val_in[126:63];
endfunction

logic [7:0][7:0] data_shifted_8;
logic [3:0][15:0] data_shifted_16;
logic [1:0][31:0] data_shifted_32;
logic [63:0] data_shifted_64;

logic [7:0][7:0] data_shifted;

/* Shift of the data
 *
 * We dont need to store SEW+1 bits of data because, as explained on the spec,
 * when getting a 2*SEW value from a SEW*SEW we have 2 sign bits and we only need 1
*/
always_comb begin
    case (sew_i)
        SEW_8: begin
            for (int i = 0; i < 8; ++i) begin
                data_shifted_8[i] = trunc_16_to_8_bits(data_i[16*i-1 +: 16]);
            end

            data_shifted = data_shifted_8;
        end
        SEW_16: begin
            for (int i = 0; i < 4; ++i) begin
                data_shifted_16[i] = trunc_32_to_16_bits(data_i[32*i-1 +: 32]);

                data_shifted[2*i] = data_shifted_16[i][7:0];
                data_shifted[2*i + 1] = data_shifted_16[i][15:8];
            end
        end
        SEW_32: begin
            for (int i = 0; i < 2; ++i) begin
                data_shifted_32[i] = trunc_64_to_32_bits(data_i[64*i-1 +: 64]);

                for (int j = 0; j < 3; ++j) begin
                    data_shifted[4*i + j] = data_shifted_32[i][8*j +: 8];
                end
                data_shifted[4*i + 3] = data_shifted_32[i][31:24];
            end
        end
        SEW_64: begin
            data_shifted_64 = trunc_127_to_64_bits(data_i);

            for (int j = 0; j < 7; ++j) begin
                data_shifted[j] = data_shifted_64[8*j +: 8];
            end

            data_shifted[7] = data_shifted_64[63:56];
        end
    endcase
end

logic [7:0] carry_in;

logic [7:0][7:0] results;
logic [7:0] carry_out;

/* Carry in
*/
always_comb begin
    carry_in[0] = 1'b0;
    case (sew_i)
        SEW_8: begin
            for (int i = 1; i < 8; ++i) begin
                carry_in[i] = 1'b0;
            end
        end
        SEW_16: begin
            for (int i = 1; i < 8; ++i) begin
                carry_in[i] = ((i%2) == 0) ? 1'b0 : carry_out[i - 1];
            end
        end
        SEW_32: begin
            for (int i = 1; i < 8; ++i) begin
                carry_in[i] = ((i%4) == 0) ? 1'b0 : carry_out[i - 1];
            end
        end
        SEW_64: begin
            for (int i = 1; i < 8; ++i) begin
                carry_in[i] = carry_out[i - 1];
            end
        end
    endcase
end


logic [7:0] to_add;

/* Calc to add for averaging
*/
always_comb begin
    for (int i = 0; i < 8; ++i) begin
        case (sew_i)
            SEW_8: begin
                for (int i = 0; i < 8; ++i) begin
                    case (vxrm_i)
                        RNU_V: begin
                            to_add[i] = data_i[16*i + 6];
                        end
                        RNE_V: begin
                            to_add[i] = data_i[16*i + 6] & ((data_i[16*i +: 5] != 0) | data_i[16*i + 7]);
                        end
                        RDN_V: begin
                            to_add[i] = 0;
                        end
                        ROD_V: begin
                            to_add[i] = (~data_i[16*i + 7]) & (data_i[16*i +: 6] != 0);
                        end
                    endcase
                end
            end
            SEW_16: begin
                for (int i = 0; i < 4; ++i) begin
                     case (vxrm_i)
                        RNU_V: begin
                            to_add[2*i] = data_i[32*i + 14];
                        end
                        RNE_V: begin
                            to_add[2*i] = data_i[32*i + 14] & ((data_i[32*i +: 13] != 0) | data_i[32*i + 15]);
                        end
                        RDN_V: begin
                            to_add[2*i] = 0;
                        end
                        ROD_V: begin
                            to_add[2*i] = (~data_i[32*i + 15]) & (data_i[32*i +: 14] != 0);
                        end
                    endcase
                    to_add[2*i + 1] = 1'b0;
                end
            end
            SEW_32: begin
                for (int i = 0; i < 2; ++i) begin
                     case (vxrm_i)
                        RNU_V: begin
                            to_add[4*i] = data_i[64*i + 30];
                        end
                        RNE_V: begin
                            to_add[4*i] = data_i[64*i + 30] & ((data_i[64*i +: 29] != 0) | data_i[64*i + 31]);
                        end
                        RDN_V: begin
                            to_add[4*i] = 0;
                        end
                        ROD_V: begin
                            to_add[4*i] = (~data_i[64*i + 31]) & (data_i[64*i +: 30] != 0);
                        end
                    endcase

                    for (int j = 1; j < 4; ++j) begin
                        to_add[4*i + j] = 1'b0;
                    end
                end
            end
            SEW_64: begin
                case (vxrm_i)
                    RNU_V: begin
                        to_add[0] = data_i[62];
                    end
                    RNE_V: begin
                        to_add[0] = data_i[62] & ((data_i[61:0] != 0) | data_i[63]);
                    end
                    RDN_V: begin
                        to_add[0] = 1'b0;
                    end
                    ROD_V: begin
                        to_add[0] = (~data_i[63]) & (data_i[62:0] != 0);
                    end
                endcase

                for (int i = 1; i < 8; ++i) begin
                    to_add[i] = 1'b0;
                end
            end
        endcase
    end
end

/* Averaging
*/
always_comb begin
    for (int i = 0; i < 8; ++i) begin
        {carry_out[i], results[i]} = {1'b0, data_shifted[i]} + {8'b0, to_add[i]} + {8'b0, carry_in[i]};
    end
end

logic [7:0] overflow;
/* Since we are only adding 1 (if adding) we can only get the case of overflow
 * of passing from 0x7F... to 0x80...
 * For an easy detect we can just compare if the most significant bit is different
 * between input element and output element and the result most significant bit is 1
*/

always_comb begin
    for (int i = 0; i < 8; ++i) begin
        overflow[i] = ((data_shifted[i][7] != results[i][7]) && (results[i][7] == 1'b1));
    end
end

/* Saturation and output
*/
always_comb begin
    case (sew_i)
        SEW_8: begin
            for (int i = 0; i < 8; i++) begin
                data_vd_o[8*i +: 8] = (overflow[i]) ? 8'h7F : results[i];
            end
        end
        SEW_16: begin
            for (int i = 0; i < 4; ++i) begin
                data_vd_o[16*i +: 16] = (overflow[2*i + 1]) ? 16'h7FFF : results[2*i +: 2];
            end
        end
        SEW_32: begin
            for (int i = 0; i < 4; ++i) begin
                data_vd_o[32*i +: 32] = (overflow[4*i + 3]) ? 32'h7FFFFFFF : results[4*i +: 4];
            end
        end
        SEW_64: begin
            data_vd_o = (overflow[7]) ? 64'h7FFFFFFFFFFFFFFF : results;
        end
    endcase
end

/* Saturation detected bit output
*/

always_comb begin
    case (sew_i)
        SEW_8: begin
            sat_ovf_o = overflow != 8'b0;
        end
        SEW_16: begin
            sat_ovf_o = overflow[7] | overflow[5] | overflow[3] | overflow[1];
        end
        SEW_32: begin
            sat_ovf_o = overflow[7] | overflow[3];
        end
        SEW_64: begin
            sat_ovf_o = overflow[7];
        end
        default: begin
            sat_ovf_o = 1'b0;
        end
    endcase
end

endmodule