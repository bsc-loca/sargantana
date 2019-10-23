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
    input if_id_stage_t decode_i,
    output instr_entry_t decode_instr_o
);

    bus64_t imm_value;
    logic illegal_instruction;

    immediate immediate_inst(
        .instr_i(decode_i.inst),
        .imm_o(imm_value)
    );

    always_comb begin
        illegal_instruction = 1'b0;

        decode_instr_o.pc = decode_i.pc_inst;
        decode_instr_o.bpred = decode_i.bpred;
        // TODO: how to handle exceptions
        decode_instr_o.ex.cause = NONE;
        decode_instr_o.ex.origin = 'h0;
        decode_instr_o.ex.valid = 'h0;
        decode_instr_o.valid = decode_i.valid;
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
        decode_instr_o.op_32   = 1'b0;

        decode_instr_o.instr_type = ADD;

        
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
                decode_instr_o.instr_type = OR;
            end
            OP_AUIPC:begin
                decode_instr_o.regfile_we  = 1'b1;
                decode_instr_o.use_imm = 1'b1;
                decode_instr_o.use_pc = 1'b1;
                decode_instr_o.alu_op = ALU_ADD;
                decode_instr_o.instr_type = ADD;          
            end
            OP_JAL: begin
                // TODO: to be fixed
                decode_instr_o.regfile_we = 1'b1; // we write pc+4 to rd
                decode_instr_o.change_pc_ena = 1'b1;
                decode_instr_o.use_imm = 1'b1;
                decode_instr_o.use_pc = 1'b1;
                decode_instr_o.instr_type = JAL;
                decode_instr_o.regfile_w_sel = SEL_FROM_BRANCH;
                decode_instr_o.unit = UNIT_BRANCH;
            end
            OP_JALR: begin
                decode_instr_o.regfile_we = 1'b1;
                decode_instr_o.change_pc_ena = 1'b1;
                decode_instr_o.use_imm = 1'b1;
                decode_instr_o.use_pc = 1'b1;
                decode_instr_o.instr_type = JALR;
                decode_instr_o.regfile_w_sel = SEL_FROM_BRANCH;
                decode_instr_o.unit = UNIT_BRANCH;
            end
            OP_BRANCH: begin
                decode_instr_o.regfile_we = 1'b0;
                decode_instr_o.change_pc_ena = 1'b1;
                decode_instr_o.use_imm = 1'b1;
                decode_instr_o.use_pc = 1'b1;
                decode_instr_o.regfile_w_sel = SEL_FROM_BRANCH;
                decode_instr_o.unit = UNIT_BRANCH;
                case (decode_i.inst.btype.func3)
                    F3_BEQ: begin
                        decode_instr_o.instr_type = BEQ;
                    end
                    F3_BNE: begin
                        decode_instr_o.instr_type = BNE;
                    end
                    F3_BLT: begin
                        decode_instr_o.instr_type = BLT;
                    end
                    F3_BGE: begin
                        decode_instr_o.instr_type = BGE;
                    end                    
                    F3_BLTU: begin
                        decode_instr_o.instr_type = BLTU;
                    end
                    F3_BGEU: begin
                        decode_instr_o.instr_type = BGEU;
                    end
                    default: begin
                        illegal_instruction = 1'b1;
                    end
                endcase 
            end
            OP_LOAD:begin
                decode_instr_o.regfile_we = 1'b1;
                decode_instr_o.use_imm = 1'b1;
                decode_instr_o.regfile_w_sel = SEL_FROM_MEM;
                decode_instr_o.unit = UNIT_MEM;
                case (decode_i.inst.itype.func3)
                    F3_LB: begin
                        decode_instr_o.instr_type = LB;
                    end
                    F3_LH: begin
                        decode_instr_o.instr_type = LH;
                    end
                    F3_LW: begin
                        decode_instr_o.instr_type = LW;
                    end
                    F3_LD: begin
                        decode_instr_o.instr_type = LD;
                    end                    
                    F3_LBU: begin
                        decode_instr_o.instr_type = LBU;
                    end
                    F3_LHU: begin
                        decode_instr_o.instr_type = LHU;
                    end
                    F3_LWU: begin
                        decode_instr_o.instr_type = LWU;
                    end
                    default: begin
                        illegal_instruction = 1'b1;
                    end
                endcase
            end
            OP_STORE: begin
                decode_instr_o.regfile_we = 1'b0;
                decode_instr_o.use_imm = 1'b1;
                decode_instr_o.regfile_w_sel = SEL_FROM_MEM;
                decode_instr_o.unit = UNIT_MEM;
                case (decode_i.inst.itype.func3)
                    STORE_SB: begin
                        decode_instr_o.instr_type = SB;
                    end
                    STORE_SH: begin
                        decode_instr_o.instr_type = SH;
                    end
                    STORE_SW: begin
                        decode_instr_o.instr_type = SW;
                    end
                    STORE_SD: begin
                        decode_instr_o.instr_type = SD;
                    end                    
                    default: begin
                        illegal_instruction = 1'b1;
                    end
                endcase
                
            end
            OP_ALU_I: begin
                decode_instr_o.use_imm    = 1'b1;
                decode_instr_o.regfile_we = 1'b1;
                // we don't need a default cause all cases are there
                unique case (decode_i.inst.itype.func3)
                    F3_ADDI: begin
                       decode_instr_o.alu_op = ALU_ADD;
                       decode_instr_o.instr_type = ADD;
                    end
                    F3_SLTI: begin
                        decode_instr_o.alu_op = ALU_SLT;
                        decode_instr_o.instr_type = SLT;
                    end
                    F3_SLTIU: begin
                        decode_instr_o.alu_op = ALU_SLTU;
                        decode_instr_o.instr_type = SLTU;
                    end
                    F3_XORI: begin
                        decode_instr_o.alu_op = ALU_XOR;
                        decode_instr_o.instr_type = XOR;
                    end
                    F3_ORI: begin
                        decode_instr_o.alu_op = ALU_OR;
                        decode_instr_o.instr_type = OR;
                    end
                    F3_ANDI: begin
                        decode_instr_o.alu_op = ALU_AND;
                        decode_instr_o.instr_type = AND;
                    end
                    F3_SLLI: begin
                        decode_instr_o.alu_op = ALU_SLL;
                        decode_instr_o.instr_type = SLL;
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
                                decode_instr_o.instr_type = SRA;
                            end
                            F7_NORMAL: begin
                                decode_instr_o.alu_op = ALU_SRL;
                                decode_instr_o.instr_type = SRL;
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
                                decode_instr_o.instr_type = SUB;
                            end
                            F7_NORMAL: begin
                                decode_instr_o.alu_op = ALU_ADD;
                                decode_instr_o.instr_type = ADD;
                            end
                            default: begin // check illegal instruction
                                illegal_instruction = 1'b1;
                            end
                        endcase
                    end
                    F3_SLL: begin
                        decode_instr_o.alu_op = ALU_SLL;
                        decode_instr_o.instr_type = SLL;
                    end
                    F3_SLT: begin
                        decode_instr_o.alu_op = ALU_SLT;
                        decode_instr_o.instr_type = SLT;
                    end
                    F3_SLTU: begin
                        decode_instr_o.alu_op = ALU_SLTU;
                        decode_instr_o.instr_type = SLTU;
                    end
                    F3_XOR: begin
                        decode_instr_o.alu_op = ALU_XOR;
                        decode_instr_o.instr_type = XOR;
                    end
                    F3_SRL_SRA: begin
                        case (decode_i.inst.rtype.func7)
                            F7_SRAI_SUB_SRA: begin
                                decode_instr_o.alu_op = ALU_SRA;
                                decode_instr_o.instr_type = SRA;
                            end
                            F7_NORMAL: begin
                                decode_instr_o.alu_op = ALU_SRL;
                                decode_instr_o.instr_type = SRL;
                            end
                            default: begin // check illegal instruction
                                illegal_instruction = 1'b1;
                            end
                        endcase                        
                    end
                    F3_OR: begin
                        decode_instr_o.alu_op = ALU_OR;
                        decode_instr_o.instr_type = OR;
                    end
                    F3_AND: begin
                        decode_instr_o.alu_op = ALU_AND;
                        decode_instr_o.instr_type = AND;
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
                decode_instr_o.instr_type = FENCE;
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