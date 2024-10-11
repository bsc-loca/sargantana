/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : alu_shift.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gämez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */

module alu_shift
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    input bus64_t data_rs2_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

bus64_t res_sll;
bus64_t res_srl;
bus64_t res_srlw;
bus64_t res_sra;
bus64_t res_sraw;

logic [5:0] shamt;

// Shift amount
always_comb begin
    case (instr_type_i)
        SLL, SRL, SRA: begin
            shamt = data_rs2_i[5:0];
        end
        SLLW, SRLW, SRAW: begin
            shamt = {1'b0, data_rs2_i[4:0]};
        end
        default: begin
            shamt = 6'b0;
        end
    endcase
end

// Operation
assign res_sll = data_rs1_i << shamt;
assign res_srl = data_rs1_i >> shamt;
assign res_srlw = data_rs1_i[31:0] >> shamt;
assign res_sra = $signed(data_rs1_i) >>> shamt;
assign res_sraw = $signed(data_rs1_i[31:0]) >>> shamt;


// Output
always_comb begin
    case (instr_type_i)
        SLL, SLLW: begin
            result_o = res_sll;
        end
        SRL: begin
            result_o = res_srl;
        end
        SRLW: begin
            result_o = res_srlw;
        end
        SRA: begin
            result_o = res_sra;
        end
        SRAW: begin
            result_o = res_sraw;
        end
        default: begin
            result_o = 64'b0;
        end
    endcase
end
endmodule