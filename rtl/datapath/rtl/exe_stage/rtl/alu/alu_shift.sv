/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : alu_shift.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gámez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Raúl G.   | 
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

function [63:0] trunc_127_64(input [126:0] val_in);
  trunc_127_64 = val_in[63:0];
endfunction

logic[126:0] base_shifting;

always_comb begin
    case (instr_type_i)
        SRL, SRLW: begin
            base_shifting[126:64] = '0;
            base_shifting[63] = data_rs1_i[63];
            base_shifting[62:0] = data_rs1_i[62:0];
        end
        SRA, BEXT, SRAW: begin
            base_shifting[126:64] = {63{data_rs1_i[63]}};
            base_shifting[63] = data_rs1_i[63];
            base_shifting[62:0] = data_rs1_i[62:0];
        end
        ROR, RORW: begin
            base_shifting[126:64] = data_rs1_i[62:0];
            base_shifting[63] = data_rs1_i[63];
            base_shifting[62:0] = data_rs1_i[62:0];
        end
        SLL, SLLW, SLLIUW: begin
            base_shifting[126:64] = data_rs1_i[63:1];
            base_shifting[63] = data_rs1_i[0];
            base_shifting[62:0] = '0;
        end
        BSET, BINV, BCLR: begin
            base_shifting[126:64] = '0;
            base_shifting[63] = 1'b1;
            base_shifting[62:0] = '0;
        end
        ROL, ROLW: begin
            base_shifting[126:64] = data_rs1_i[63:1];
            base_shifting[63] = data_rs1_i[0];
            base_shifting[62:0] = data_rs1_i[63:1];
        end
        default: begin
            base_shifting = '0;
        end
    endcase
end
logic[6:0] amount_shifting;

always_comb begin
    case (instr_type_i)
        SLL, SLLIUW, ROL, BSET, BCLR, BINV: begin
            amount_shifting = {1'b0, ~data_rs2_i[5:0]};
        end
        SRLW, SRAW, RORW: begin
            amount_shifting = {2'b0, data_rs2_i[4:0]};
        end
        SLLW, ROLW: begin
            amount_shifting = {2'b01, ~data_rs2_i[4:0]};
        end
        default: begin
            amount_shifting = {1'b0, data_rs2_i[5:0]};
        end
    endcase
end

assign result_o = trunc_127_64(base_shifting >> amount_shifting);
endmodule