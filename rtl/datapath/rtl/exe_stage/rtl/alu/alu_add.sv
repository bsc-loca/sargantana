/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : alu_add.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gämez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */

module alu_add
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    input bus64_t data_rs2_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

function [63:0] trunc_65_64(input [64:0] val_in);
  trunc_65_64 = val_in[63:0];
endfunction

bus64_t data_rs2_op;
logic carry_in;

// Negation and carry in for subtracting
always_comb begin
    case (instr_type_i)
        SUB, SUBW: begin
            data_rs2_op = ~data_rs2_i;
            carry_in = 1'b1;
        end
        default: begin
            data_rs2_op = data_rs2_i;
            carry_in = 1'b0;
        end
    endcase
end

// Operation
assign result_o = trunc_65_64(data_rs1_i + data_rs2_op + carry_in);

endmodule