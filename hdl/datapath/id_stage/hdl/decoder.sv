/* -----------------------------------------------
* Project Name   : DRAC
* File           : decoder.sv
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

//`default_nettype none
import drac_pkg::*;
import riscv_pkg::*;

module decoder(
    input fetch_out_t decode_i,
    output instr_entry_t decode_instr_o
);

//TODO create a module that calculates the immediate
data64_t imm_value;
logic illegal_instruction;

immediate immediate(
    .instr_i(decode_i.inst),
    .imm_o(imm_value)
);

always_comb begin
    illegal_instruction = 1'b0;
    decode_instr_o.pc = decode_i.pc_inst;
    decode_instr_o.bpred = decode_i.bpred;
    // TODO: how to handle exceptions
    // decode_instr_o.ex;
    // Registers sources
    decode_instr_o.rs1 = decode_i.inst.common.rs1;
    decode_instr_o.rs2 = decode_i.inst.common.rs2;
    decode_instr_o.rd  = decode_i.inst.common.rd;
    // By default all enables to zero
    decode_instr_o.change_pc_ena = 1'b0;
    decode_instr_o.regfile_we    = 1'b0;
    decode_instr_o.regfile_w_sel = SEL_FROM_ALU;
    // does not really matter
    decode_instr_o.use_imm = 1'b0;
    decode_instr_o.use_pc  = 1'b0;
    
    decode_instr_o.alu_op = ALU_ADD;
    decode_instr_o.unit   = UNIT_ALU;
    // not sure if we should have this
    //decode_instr_o.instr_type;
    // By default use the imm value then it will change along the process
    decode_instr_o.result = imm_value; 


    case (decode_i.inst.common.opcode)
        // Load Upper immediate
        OP_LUI: begin
            decode_instr_o.regfile_we  = 1'b1;
            decode_instr_o.use_imm = 1'b1;
            decode_instr_o.rs1 = '0;
            decode_instr_o.alu_op = ALU_OR;
        end
        OP_AUIPC:begin
            decode_instr_o.regfile_we  = 1'b1;
            decode_instr_o.use_imm = 1'b1;
            decode_instr_o.use_pc = 1'b1;
            decode_instr_o.alu_op = ALU_ADD;          
        end
        OP_JAL: begin
            // TODO: to be fixed
            decode_instr_o.regfile_we = 1'b1;
            decode_instr_o.change_pc_ena = 1'b1;
            decode_instr_o.use_imm = 1'b1;
            decode_instr_o.use_pc = 1'b1;
            decode_instr_o.alu_op = ALU_ADD;
        end
        OP_JALR: begin
            decode_instr_o.regfile_we = 1'b1;
            
        end
        OP_BRANCH: begin
            
        end
        OP_LOAD:begin
            decode_instr_o.regfile_we = 1'b1;
            
        end
        OP_STORE: begin
            
        end
        OP_ALU_I: begin
            decode_instr_o.use_imm    = 1'b1;
            decode_instr_o.regfile_we = 1'b1;
            // we don't need a default cause all cases are there
            unique case (decode_i.inst.itype.func3)
                F3_ADDI: begin
                   decode_instr_o.alu_op = ALU_ADD;
                end
                F3_SLTI: begin
                    decode_instr_o.alu_op = ALU_SLT;
                end
                F3_SLTIU: begin
                    decode_instr_o.alu_op = ALU_SLTU;
                end
                F3_XORI: begin
                    decode_instr_o.alu_op = ALU_XOR;
                end
                F3_ORI: begin
                    decode_instr_o.alu_op = ALU_OR;
                end
                F3_ANDI: begin
                    decode_instr_o.alu_op = ALU_AND;
                end
                F3_SLLI: begin
                    decode_instr_o.alu_op = ALU_SLL;
                    // check for illegal isntruction
                    if (decode_i.inst.rtype.func7 != F7_NORMAL) begin
                        illegal_instruction = 1'b1;
                    end else begin
                        illegal_instruction = 1'b0;
                    end
                end
                F3_SRLAI: begin
                    case (decode_i.inst.rtype.func7)
                        F7_SRAI_SUB_SRA: begin
                            decode_instr_o.alu_op = ALU_SRA;
                        end
                        F7_NORMAL: begin
                            decode_instr_o.alu_op = ALU_SRL;
                        end
                        default: begin // check illegal instruction
                            illegal_instruction = 1'b1;
                        end
                    endcase             
                end
            endcase
            
        end
        OP_ALU: begin
            decode_instr_o.regfile_we = 1'b1;
            // we don't need a default cause all cases are there
            // TODO: should we check in decoder all possibilities of illegal instruction?
            unique case (decode_i.inst.rtype.func3)
                F3_ADD_SUB: begin
                    case (decode_i.inst.rtype.func7)
                        F7_SRAI_SUB_SRA: begin
                            decode_instr_o.alu_op = ALU_SUB;
                        end
                        F7_NORMAL: begin
                            decode_instr_o.alu_op = ALU_ADD;
                        end
                        default: begin // check illegal instruction
                            illegal_instruction = 1'b1;
                        end
                    endcase
                end
                F3_SLL: begin
                    decode_instr_o.alu_op = ALU_SLT;
                end
                F3_SLT: begin
                    decode_instr_o.alu_op = ALU_SLTU;
                end
                F3_SLTU: begin
                    decode_instr_o.alu_op = ALU_SLTU;
                end
                F3_XOR: begin
                    decode_instr_o.alu_op = ALU_XOR;
                end
                F3_SRL_SRA: begin
                    case (decode_i.inst.rtype.func7)
                        F7_SRAI_SUB_SRA: begin
                            decode_instr_o.alu_op = ALU_SRA;
                        end
                        F7_NORMAL: begin
                            decode_instr_o.alu_op = ALU_SRL;
                        end
                        default: begin // check illegal instruction
                            illegal_instruction = 1'b1;
                        end
                    endcase                        
                end
                F3_OR: begin
                    decode_instr_o.alu_op = ALU_OR;
                end
                F3_AND: begin
                    decode_instr_o.alu_op = ALU_AND;
                end
            endcase
            
        end
        OP_ALU_I_W: begin
            decode_instr_o.use_imm    = 1'b1;
            decode_instr_o.regfile_we = 1'b1;
            
        end
        OP_ALU_W: begin
            decode_instr_o.regfile_we = 1'b1;
            
        end
        OP_FENCE: begin
            // Not sure what we should do
        end
        OP_SYSTEM: begin
            
        end
        default: begin
            // By default this is not a valid instruction
            // is this an exception?
            illegal_instruction = 1'b1;
        end
    endcase

end

endmodule
//`default_nettype wire