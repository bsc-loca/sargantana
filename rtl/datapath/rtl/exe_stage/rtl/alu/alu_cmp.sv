/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : alu_cmp.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gämez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */

module alu_cmp
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    input bus64_t data_rs2_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

logic slt;
logic sltu;

assign slt = $signed(data_rs1_i) < $signed(data_rs2_i);
assign sltu = data_rs1_i < data_rs2_i;

always_comb begin
    case (instr_type_i)
        SLT: begin
            result_o = {63'b0, slt};
        end
        SLTU: begin
            result_o = {63'b0, sltu};
        end
        /*MIN: begin
            result_o = slt ? data_rs1_i : data_rs2_i;
        end
        MINU: begin
            result_o = sltu ? data_rs1_i : data_rs2_i;
        end
        MAX: begin
            result_o = slt ? data_rs2_i : data_rs1_i;
        end
        MAXU: begin
            result_o = sltu ? data_rs2_i : data_rs1_i;
        end*/
        default: begin
            result_o = 64'b0;
        end
    endcase
end

endmodule