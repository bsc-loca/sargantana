/* -----------------------------------------------
* Project Name   : DRAC
* File           : immediate.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

import drac_pkg::*;
import riscv_pkg::*;

module immediate(
	input riscv_pkg::instruction_t instr_i,
	output data64_t imm_o
);
	data64_t imm_itype;
    data64_t imm_stype;
    data64_t imm_btype;
    data64_t imm_utype;
	data64_t imm_jtype;
    data64_t imm_uitype;
    //TODO immediate of CSR

	assign imm_itype = {{52{instr_i[31]}}, instr_i.itype.imm};
    
    assign imm_stype = {{52{instr_i[31]}}, instr_i.stype.imm5, instr_i.stype.imm0};
    
    assign imm_btype = {{51{instr_i[31]}}, instr_i.btype.imm11, instr_i.btype.imm5, instr_i.btype.imm1, 1'b0};
    
    assign imm_utype = {{32{instr_i[31]}}, instr_i.utype.imm, 12'b0};

    assign imm_jtype = {{32{instr_i[31]}}, instr_i.jtype.imm20,
                                         instr_i.jtype.imm12, 
                                         instr_i.jtype.imm11,
                                         instr_i.jtype.imm1, 1'b0};
    
    // No sign extended
    assign imm_uitype = {{59{1'b0}}, instr_i.common.rs1};


    always_comb begin
        case(instr_i.common.opcode)
            riscv_pkg::OP_LUI,
            riscv_pkg::OP_AUIPC: begin
                imm_o = imm_utype;
            end
            riscv_pkg::OP_JAL: begin
                imm_o = imm_jtype;
            end
            riscv_pkg::OP_JALR,
            riscv_pkg::OP_LOAD,
            riscv_pkg::OP_ALU_I,
            riscv_pkg::OP_ALU_I_W: begin
                imm_o = imm_itype;
            end
            riscv_pkg::OP_BRANCH: begin
                imm_o = imm_btype;
            end
            riscv_pkg::OP_STORE: begin
                imm_o = imm_stype;
            end
            riscv_pkg::OP_SYSTEM: begin
                // we could filter here for only the important CSR
                case (instr_i.itype.func3)
                    F3_CSRRWI,
                    F3_CSRRSI,
                    F3_CSRRCI: begin
                        imm_o = imm_uitype;        
                    end
                    default: begin
                        imm_o = 64'b0;
                    end
                endcase             
            end
            default: begin
                imm_o = 64'b0;
            end
        endcase
    end

endmodule