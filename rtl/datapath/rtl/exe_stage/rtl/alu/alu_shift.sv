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

function [63:0] trunc_65_64(input [64:0] val_in);
  trunc_65_64 = val_in[63:0];
endfunction

function [5:0] trunc_7_6(input [6:0] val_in);
  trunc_7_6 = val_in[5:0];
endfunction

bus64_t res_sll;
bus64_t res_srl;
bus64_t res_sra;

logic [5:0] shamt;

// Shift amount
always_comb begin
    case (instr_type_i)
        SLL, SRL, SRA, SLLIUW, ROL, ROR, BSET, BCLR, BEXT, BINV: begin
            shamt = data_rs2_i[5:0];
        end
        SLLW, SRLW, SRAW, ROLW, RORW: begin
            shamt = {1'b0, data_rs2_i[4:0]};
        end
        default: begin
            shamt = 6'b0;
        end
    endcase
end

logic [5:0] rotation_shift;
logic [6:0] rotation_shift_comp;

always_comb begin
    case (instr_type_i)
            ROLW, RORW: begin
                rotation_shift = shamt;
                rotation_shift_comp = 32 - shamt;
            end
            default: begin // ROL, ROR
                rotation_shift = shamt;
                rotation_shift_comp = 64 - shamt;
            end
    endcase
end

logic [5:0] shamt_sll;
logic [5:0] shamt_srl;
logic [6:0] shamt_sra;

// Select shamt or rotation value
always_comb begin
    case (instr_type_i)
        ROR, RORW: begin
            shamt_srl = rotation_shift;
            shamt_sll = trunc_7_6(rotation_shift_comp);
        end
        ROL, ROLW: begin
            shamt_sll = rotation_shift;
            shamt_srl = trunc_7_6(rotation_shift_comp);
        end
        default: begin //SLL, SRL, SRA, SLLIUW, SLLW, SRLW, SRAW
            shamt_sll = shamt;
            shamt_srl = shamt;
        end
    endcase
    shamt_sra = shamt_srl;
end

logic[64:0] sra_data; // needed for masking rotations

always_comb begin
    case (instr_type_i)
        ROL, ROR: begin
            sra_data = {1'b1, 64'b0};
        end
        ROLW, RORW: begin
            sra_data = {33'h1FFFFFFFF, 32'b0};
        end
        default: begin
            sra_data = {data_rs1_i[63], data_rs1_i};
        end
    endcase
end

bus64_t sll_data;

always_comb begin
    case (instr_type_i)
        BSET, BCLR, BINV: begin
            sll_data = {63'b0, 1'b1};
        end
        default: begin
            sll_data = data_rs1_i;
        end
    endcase
end

// Operation
assign res_sll = sll_data << shamt_sll;
assign res_srl = data_rs1_i >> shamt_srl;
assign res_sra = trunc_65_64($signed(sra_data) >>> shamt_sra);


bus64_t res_left;
bus64_t res_right;

// Output
always_comb begin
    case (instr_type_i)
        SLL, SLLW, SLLIUW, BSET, BCLR, BINV: begin
            res_left = 64'b0;
            res_right = 64'b0;
            result_o = res_sll;
        end
        SRL, SRLW: begin
            res_left = 64'b0;
            res_right = 64'b0;
            result_o = res_srl;
        end
        SRA, SRAW, BEXT: begin
            res_left = 64'b0;
            res_right = 64'b0;
            result_o = res_sra;
        end
        ROR, ROL, RORW, ROLW: begin
            res_left = res_sll & res_sra;
            res_right = res_srl & (~res_sra);
            result_o = (res_sll & res_sra) | (res_srl & ~res_sra);
        end
        default: begin
            res_left = 64'b10;
            res_right = 64'b11;
            result_o = 64'b01;
        end
    endcase
end
endmodule