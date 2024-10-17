/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : alu_add.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gámez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */

module alu_logic
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    input bus64_t data_rs2_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

bus64_t data_rs2_negated;

always_comb begin
    case (instr_type_i)
        XNOR, ORN, ANDN: begin
            data_rs2_negated = ~data_rs2_i;
        end
        default: begin
            data_rs2_negated = data_rs2_i;
        end
    endcase
end

// Operation
always_comb begin
    case (instr_type_i)
        AND_INST, ANDN: begin
            result_o = data_rs1_i & data_rs2_negated;
        end
        OR_INST, ORN: begin
            result_o = data_rs1_i | data_rs2_negated;
        end
        XOR_INST, XNOR: begin
            result_o = data_rs1_i ^ data_rs2_negated;
        end
        default: begin
            result_o = 64'b0;
        end
    endcase
end

endmodule