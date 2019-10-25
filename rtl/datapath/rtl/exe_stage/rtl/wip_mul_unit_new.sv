/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : mul_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */
 
import drac_pkg::*;
//`default_nettype none

module mul_unit (
    input  logic [2:0]  func3_i,
    input  logic        int_32_i,
    input  bus64_t      rs1_i,         // rs1
    input  bus64_t      rs2_i,         // rs2
    output bus64_t      result_o
);

// Declarations
logic same_sign;
bus64_t rs1_def;
bus64_t rs2_def;
logic neg_def;
bus128_t result_128;
bus128_t result_128_def;
bus64_t result_64;

assign same_sign = int_32_i ? ~(rs2_i[31] ^ rs1_i[31]) : ~(rs2_i[63] ^ rs1_i[63]);

// Source Operands, convert if source is negative and operation is signed
always@(*) begin
    case ({func3_i})
        3'b000: begin  // Multiply word, Low part, Signed - MUL , MULW
            rs1_def = ((rs1_i[63]  & !int_32_i) | (rs1_i[31]  & int_32_i)) ?
                        ~rs1_i + 64'b1 : rs1_i;
            rs2_def = ((rs2_i[63]  & !int_32_i) | (rs2_i[31]  & int_32_i)) ?
                        ~rs2_i + 64'b1 : rs2_i;
            neg_def  = !same_sign;
        end
        3'b001: begin  // Multiply word, High part, Signed - MULH
            rs1_def = (rs1_i[63])  ? ~rs1_i + 64'b1 : rs1_i;
            rs2_def = (rs2_i[63])  ? ~rs2_i + 64'b1 : rs2_i;
            neg_def  = !same_sign;
        end
        3'b010: begin  // Multiply word, High part, SignedxUnsigned - MULHSU
            rs1_def = (rs1_i[63])  ? ~rs1_i + 64'b1 : rs1_i;
            rs2_def = rs2_i;
            neg_def  = rs1_i[63];
        end
        3'b011: begin  //  Multiply word, High part, Unsigned Unsigned MULHU
            rs1_def = rs1_i;
            rs2_def = rs2_i;
            neg_def  = 1'b0;
        end
        default: begin
            rs1_def = 64'b0;
            rs2_def = 64'b0;
            neg_def  = 1'b0;
        end
    endcase
end

assign result_128 = rs1_def * rs2_def;
// Convert if the result is negative
assign result_128_def = neg_def ? ~result_128 + 128'b1 : result_128;

// Select correct word
always@(*) begin
    case ({func3_i})
        3'b000: begin  // Multiply word, Low part, Signed - MUL , MULW
            result_64 = result_128_def[63:0];
        end
        3'b001: begin  // Multiply word, High part, Signed - MULH
            result_64 = result_128_def[127:64];
        end
        3'b010: begin  // Multiply word, High part, SignedxUnsigned - MULHSU
            result_64 =  result_128_def[127:64];
        end
        3'b011: begin  //  Multiply word, High part, Unsigned Unsigned MULHU
            result_64 = result_128_def[127:64];
        end
        default: begin
            result_64 = 64'b0;
        end
    endcase
end 

assign result_o = result_64;

endmodule
//`default_nettype wire

