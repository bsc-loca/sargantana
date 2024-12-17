/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : alu_logic.sv
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

// Operation
always_comb begin
    case (instr_type_i)
        AND_INST, ANDN, BCLR, BEXT: begin
            result_o = data_rs1_i & data_rs2_i;
        end
        OR_INST, ORN, BSET: begin
            result_o = data_rs1_i | data_rs2_i;
        end
        XOR_INST, XNOR_INST, BINV: begin
            result_o = data_rs1_i ^ data_rs2_i;
        end
        ORCB: begin
            for (int i = 0; i < (XLEN/8); ++i) begin
                result_o[8*i +: 8] = (data_rs1_i[8*i +: 8] == 8'b0) ? 8'b0 : 8'hFF;
            end
        end
        default: begin
            result_o = 64'b0;
        end
    endcase
end

endmodule