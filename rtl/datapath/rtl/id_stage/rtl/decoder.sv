/*
 * Copyright 2023 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

module decoder
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input   logic            clk_i,
    input   logic            rstn_i,
    input   logic            flush_i,
    input   logic            stall_i,
    input   if_id_stage_t    decode_i,
    input   [2:0]            frm_i, // FP rounding Mode from CSR
    input   [1:0]            csr_fs_i, 
    input   [1:0]            csr_vs_i, 
    output  id_ir_stage_t    decode_instr_o,
    output  jal_id_if_t      jal_id_if_o
);

	//Auxilar signals
	wire [6:0] F7_NORMAL_AUX;
	wire [6:0] F7_SRAI_SUB_SRA_AUX;
	assign F7_NORMAL_AUX = F7_NORMAL;
	assign F7_SRAI_SUB_SRA_AUX = F7_SRAI_SUB_SRA;


    bus64_t imm_value;
    logic xcpt_illegal_instruction_int;
    logic xcpt_addr_misaligned_int;
    addrPC_t ras_pc_int;
    logic ras_push_int;
    logic ras_pop_int;
    logic ras_link_rd_int;
    logic ras_link_rs1_int;

    logic check_frm;

    instr_entry_t decode_instr_int;

    immediate immediate_inst(
        .instr_i(decode_i.inst),
        .imm_o(imm_value)
    );

    always_comb begin
        xcpt_illegal_instruction_int = 1'b0;
        xcpt_addr_misaligned_int     = 1'b0;

        decode_instr_int.pc    = decode_i.pc_inst;
        decode_instr_int.bpred = decode_i.bpred;

        decode_instr_int.valid = decode_i.valid;
        // Registers sources
        decode_instr_int.rs1 = decode_i.inst.common.rs1;
        decode_instr_int.rs2 = decode_i.inst.common.rs2;
        decode_instr_int.rd  = decode_i.inst.common.rd;
        // Register sources valid bits
        decode_instr_int.use_rs1 = 1'b0;
        decode_instr_int.use_rs2 = 1'b0;
        decode_instr_int.use_fs1 = 1'b0;
        decode_instr_int.use_fs2 = 1'b0;
        decode_instr_int.use_fs3 = 1'b0;

        // Information for the ras performance
        ras_link_rd_int = decode_instr_int.rd == 5'h1 || decode_instr_int.rd == 5'h5;
        ras_link_rs1_int = decode_instr_int.rs1 == 5'h1 || decode_instr_int.rs1 == 5'h5;
        ras_push_int = 1'b0; //default value
        ras_pop_int = 1'b0; //default value

        // By default all enables to zero
        decode_instr_int.change_pc_ena = 1'b0;
        decode_instr_int.regfile_we    = 1'b0;
        decode_instr_int.fregfile_we   = 1'b0;
        // does not really matter
        decode_instr_int.use_imm = 1'b0;
        decode_instr_int.use_pc  = 1'b0;
        decode_instr_int.op_32   = 1'b0;
        // FP special
        decode_instr_int.rs3     = decode_i.inst.r4type.rs3;
        decode_instr_int.fmt     = FMT_S;
        decode_instr_int.frm     = op_frm_fp_t'(decode_i.inst.fprtype.rm);
        check_frm              = 1'b0;

        decode_instr_int.instr_type = ADD;
        `ifdef SIM_KONATA_DUMP
            decode_instr_int.id = decode_i.id;
        `endif

        
        decode_instr_int.unit   = UNIT_ALU;

        // Assign by default the immediate in the result
        decode_instr_int.imm = imm_value;
        // This is lowrisc related
        decode_instr_int.mem_size = {1'b0,decode_i.inst.common.func3};
        decode_instr_int.signed_op = 1'b0;

        jal_id_if_o.valid = 1'b0;
        jal_id_if_o.jump_addr = decode_i.pc_inst + 64'h04;

        // Signal that tells whether it is a csr or fence
        decode_instr_int.stall_csr_fence = 1'b0;

        `ifdef SIM_COMMIT_LOG
            decode_instr_int.inst = decode_i.inst;
        `endif

        decode_instr_int.mem_type = NOT_MEM;

        decode_instr_int.ex_valid = '0;

        if (!decode_i.ex.valid && decode_i.valid ) begin
            case (decode_i.inst.common.opcode)
                // Load Upper immediate
                OP_LUI: begin
                    decode_instr_int.regfile_we  = 1'b1;
                    decode_instr_int.use_imm = 1'b1;
                    decode_instr_int.rs1 = '0;
                    decode_instr_int.instr_type = OR;
                end
                OP_AUIPC:begin
                    decode_instr_int.regfile_we  = 1'b1;
                    decode_instr_int.use_imm = 1'b1;
                    decode_instr_int.use_pc = 1'b1;
                    decode_instr_int.instr_type = ADD;          
                end
                OP_JAL: begin
                    decode_instr_int.regfile_we = 1'b1; // we write pc+4 to rd
                    decode_instr_int.change_pc_ena = 1'b0; // Actually we change now
                    decode_instr_int.use_imm = 1'b1;
                    decode_instr_int.use_pc = 1'b1;
                    decode_instr_int.instr_type = JAL;
                    decode_instr_int.unit = UNIT_BRANCH;
                    // it is valid if there is no misaligned exception
                    xcpt_addr_misaligned_int = |imm_value[1:0];
                    jal_id_if_o.jump_addr = imm_value+decode_i.pc_inst; 
                    jal_id_if_o.valid = !xcpt_addr_misaligned_int & decode_i.valid &
                                        !((jal_id_if_o.jump_addr == decode_i.bpred.pred_addr) & 
                                        (decode_i.bpred.decision == PRED_TAKEN));
                    if (!xcpt_addr_misaligned_int && decode_i.valid && ras_link_rd_int) begin
                        ras_push_int = 1'b1;
                    end
                    
                end
                OP_JALR: begin
                    decode_instr_int.regfile_we = 1'b1;
                    decode_instr_int.change_pc_ena = 1'b1;
                    decode_instr_int.use_imm = 1'b0;
                    decode_instr_int.use_pc = 1'b0;
                    decode_instr_int.use_rs1 = 1'b1;
                    decode_instr_int.instr_type = JALR;
                    decode_instr_int.unit = UNIT_BRANCH;
                    // ISA says that func3 should be zero
                    if (decode_i.inst.itype.func3 != 'h0) begin
                        xcpt_illegal_instruction_int = 1'b1;
                    end
                    if (!xcpt_addr_misaligned_int && decode_i.valid) begin
                        if (!ras_link_rd_int && ras_link_rs1_int) begin
                            ras_pop_int = 1'b1;
                        end else if (ras_link_rd_int && !ras_link_rs1_int) begin
                            ras_push_int = 1'b1;
                        end else if (ras_link_rd_int && ras_link_rs1_int && decode_instr_int.rs1 == decode_instr_int.rd) begin
                            ras_push_int = 1'b1;
                        end else if (ras_link_rd_int && ras_link_rs1_int) begin
                            ras_pop_int = 1'b1;
                            ras_push_int = 1'b1;
                        end
                    end
                    jal_id_if_o.jump_addr = ras_pc_int; 
                    jal_id_if_o.valid = ras_pop_int && !((jal_id_if_o.jump_addr == decode_i.bpred.pred_addr) & 
                                        (decode_i.bpred.decision == PRED_TAKEN) && !flush_i && !stall_i);

                    decode_instr_int.bpred.pred_addr = jal_id_if_o.valid ? ras_pc_int : decode_i.bpred.pred_addr;
                    decode_instr_int.bpred.decision = (jal_id_if_o.valid || decode_i.bpred.decision == PRED_TAKEN) 
                                                    ? PRED_TAKEN : PRED_NOT_TAKEN;
                    decode_instr_int.bpred.is_branch = 1'b1;

                end
                OP_BRANCH: begin
                    decode_instr_int.regfile_we = 1'b0;
                    decode_instr_int.change_pc_ena = 1'b1;
                    decode_instr_int.use_imm = 1'b0;
                    decode_instr_int.use_pc = 1'b0;
                    decode_instr_int.use_rs1 = 1'b1;
                    decode_instr_int.use_rs2 = 1'b1;
                    decode_instr_int.unit = UNIT_BRANCH;
                    case (decode_i.inst.btype.func3)
                        F3_BEQ: begin
                            decode_instr_int.instr_type = BEQ;
                        end
                        F3_BNE: begin
                            decode_instr_int.instr_type = BNE;
                        end
                        F3_BLT: begin
                            decode_instr_int.instr_type = BLT;
                        end
                        F3_BGE: begin
                            decode_instr_int.instr_type = BGE;
                        end                    
                        F3_BLTU: begin
                            decode_instr_int.instr_type = BLTU;
                        end
                        F3_BGEU: begin
                            decode_instr_int.instr_type = BGEU;
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase 
                end
                OP_LOAD:begin
                    decode_instr_int.mem_type = LOAD;
                    decode_instr_int.regfile_we = 1'b1;
                    decode_instr_int.use_imm = 1'b0;
                    decode_instr_int.use_rs1 = 1'b1;
                    decode_instr_int.unit = UNIT_MEM;
                    case (decode_i.inst.itype.func3)
                        F3_LB: begin
                            decode_instr_int.instr_type = LB;
                        end
                        F3_LH: begin
                            decode_instr_int.instr_type = LH;
                        end
                        F3_LW: begin
                            decode_instr_int.instr_type = LW;
                        end
                        F3_LD: begin
                            decode_instr_int.instr_type = LD;
                        end                    
                        F3_LBU: begin
                            decode_instr_int.instr_type = LBU;
                        end
                        F3_LHU: begin
                            decode_instr_int.instr_type = LHU;
                        end
                        F3_LWU: begin
                            decode_instr_int.instr_type = LWU;
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_STORE: begin
                    decode_instr_int.mem_type = STORE;
                    decode_instr_int.regfile_we = 1'b0;
                    decode_instr_int.use_imm = 1'b0;
                    decode_instr_int.use_rs1 = 1'b1;
                    decode_instr_int.use_rs2 = 1'b1;
                    decode_instr_int.unit = UNIT_MEM;
                    case (decode_i.inst.itype.func3)
                        F3_SB: begin
                            decode_instr_int.instr_type = SB;
                        end
                        F3_SH: begin
                            decode_instr_int.instr_type = SH;
                        end
                        F3_SW: begin
                            decode_instr_int.instr_type = SW;
                        end
                        F3_SD: begin
                            decode_instr_int.instr_type = SD;
                        end                    
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_ATOMICS: begin
                    // NOTE (guillemlp) what to do with aq and rl?
                    decode_instr_int.mem_type = AMO;
                    decode_instr_int.regfile_we   = 1'b1;
                    decode_instr_int.use_imm      = 1'b0;
                    decode_instr_int.use_rs1      = 1'b1;
                    decode_instr_int.use_rs2      = 1'b1;
                    decode_instr_int.unit         = UNIT_MEM;
                    case (decode_i.inst.rtype.func3)
                        F3_ATOMICS: begin
                            case (decode_i.inst.rtype.func7[31:27])
                                LR_W: begin
                                    if (decode_i.inst.rtype.rs2 != 'h0) begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end else begin
                                        decode_instr_int.instr_type = AMO_LRW;
                                    end
                                end
                                SC_W: begin
                                    decode_instr_int.instr_type = AMO_SCW;
                                end
                                AMOSWAP_W: begin
                                    decode_instr_int.instr_type = AMO_SWAPW;
                                end
                                AMOADD_W: begin
                                    decode_instr_int.instr_type = AMO_ADDW;
                                end
                                AMOXOR_W: begin
                                    decode_instr_int.instr_type = AMO_XORW;
                                end
                                AMOAND_W: begin
                                    decode_instr_int.instr_type = AMO_ANDW;
                                end
                                AMOOR_W: begin
                                    decode_instr_int.instr_type = AMO_ORW;
                                end
                                AMOMIN_W: begin
                                    decode_instr_int.instr_type = AMO_MINW;
                                end
                                AMOMAX_W: begin
                                    decode_instr_int.instr_type = AMO_MAXW;
                                end
                                AMOMINU_W: begin
                                    decode_instr_int.instr_type = AMO_MINWU;
                                end
                                AMOMAXU_W: begin
                                    decode_instr_int.instr_type = AMO_MAXWU;
                                end
                                default: begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            endcase // decode_i.inst.rtype.func7[31:27]
                        end
                        F3_ATOMICS_64: begin
                            case (decode_i.inst.rtype.func7[31:27])
                                LR_D: begin
                                    if (decode_i.inst.rtype.rs2 != 'h0) begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end else begin
                                        decode_instr_int.instr_type = AMO_LRD;
                                    end
                                end
                                SC_D: begin
                                    decode_instr_int.instr_type = AMO_SCD;
                                end
                                AMOSWAP_D: begin
                                    decode_instr_int.instr_type = AMO_SWAPD;
                                end
                                AMOADD_D: begin
                                    decode_instr_int.instr_type = AMO_ADDD;
                                end
                                AMOXOR_D: begin
                                    decode_instr_int.instr_type = AMO_XORD;
                                end
                                AMOAND_D: begin
                                    decode_instr_int.instr_type = AMO_ANDD;
                                end
                                AMOOR_D: begin
                                    decode_instr_int.instr_type = AMO_ORD;
                                end
                                AMOMIN_D: begin
                                    decode_instr_int.instr_type = AMO_MIND;
                                end
                                AMOMAX_D: begin
                                    decode_instr_int.instr_type = AMO_MAXD;
                                end
                                AMOMINU_D: begin
                                    decode_instr_int.instr_type = AMO_MINDU;
                                end
                                AMOMAXU_D: begin
                                    decode_instr_int.instr_type = AMO_MAXDU;
                                end
                                default: begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            endcase // decode_i.inst.rtype.func7[31:27]
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase // decode_i.inst.rtype.func3
                end
                OP_ALU_I: begin
                    decode_instr_int.use_imm    = 1'b1;
                    decode_instr_int.use_rs1    = 1'b1;
                    decode_instr_int.regfile_we = 1'b1;
                    // we don't need a default cause all cases are there
                    unique case (decode_i.inst.itype.func3)
                        F3_ADDI: begin
                           decode_instr_int.instr_type = ADD;
                        end
                        F3_SLTI: begin
                            decode_instr_int.instr_type = SLT;
                        end
                        F3_SLTIU: begin
                            decode_instr_int.instr_type = SLTU;
                        end
                        F3_XORI: begin
                            decode_instr_int.instr_type = XOR;
                        end
                        F3_ORI: begin
                            decode_instr_int.instr_type = OR;
                        end
                        F3_ANDI: begin
                            decode_instr_int.instr_type = AND;
                        end
                        F3_SLLI: begin
                            decode_instr_int.instr_type = SLL;
                            // check for illegal instruction
                            if (decode_i.inst.rtype.func7[31:26] != F7_NORMAL_AUX[6:1]) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                xcpt_illegal_instruction_int = 1'b0;
                            end
                        end
                        F3_SRLAI: begin
                            case (decode_i.inst.rtype.func7[31:26])
                                F7_SRAI_SUB_SRA_AUX[6:1]: begin
                                    decode_instr_int.instr_type = SRA;
                                end
                                F7_NORMAL_AUX[6:1]: begin
                                    decode_instr_int.instr_type = SRL;
                                end
                                default: begin // check illegal instruction
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            endcase             
                        end
                    endcase
                end
                OP_ALU: begin
                    decode_instr_int.regfile_we = 1'b1;
                    decode_instr_int.use_rs1    = 1'b1;
                    decode_instr_int.use_rs2    = 1'b1;
                    unique case ({decode_i.inst.rtype.func7,decode_i.inst.rtype.func3})
                        {F7_NORMAL,F3_ADD_SUB}: begin
                            decode_instr_int.instr_type = ADD;
                        end
                        {F7_SRAI_SUB_SRA,F3_ADD_SUB}: begin
                            decode_instr_int.instr_type = SUB;
                        end
                        {F7_NORMAL,F3_SLL}: begin
                            decode_instr_int.instr_type = SLL;
                        end
                        {F7_NORMAL,F3_SLT}: begin
                            decode_instr_int.instr_type = SLT;
                        end
                        {F7_NORMAL,F3_SLTU}: begin
                            decode_instr_int.instr_type = SLTU;
                        end
                        {F7_NORMAL,F3_XOR}: begin
                            decode_instr_int.instr_type = XOR;
                        end
                        {F7_NORMAL,F3_SRL_SRA}: begin
                            decode_instr_int.instr_type = SRL;
                        end
                        {F7_SRAI_SUB_SRA,F3_SRL_SRA}: begin
                            decode_instr_int.instr_type = SRA;
                        end
                        {F7_NORMAL,F3_OR}: begin
                            decode_instr_int.instr_type = OR;
                        end
                        {F7_NORMAL,F3_AND}: begin
                            decode_instr_int.instr_type = AND;
                        end
                        // Mults and Divs
                        {F7_MUL_DIV,F3_MUL}: begin
                            decode_instr_int.instr_type = MUL;
                            decode_instr_int.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_MULH}: begin
                            decode_instr_int.instr_type = MULH;
                            decode_instr_int.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_MULHSU}: begin
                            decode_instr_int.instr_type = MULHSU;
                            decode_instr_int.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_MULHU}: begin
                            decode_instr_int.instr_type = MULHU;
                            decode_instr_int.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_DIV}: begin
                            decode_instr_int.instr_type = DIV;
                            decode_instr_int.unit = UNIT_DIV;
                            decode_instr_int.signed_op = 1'b1;
                        end
                        {F7_MUL_DIV,F3_DIVU}: begin
                            decode_instr_int.instr_type = DIVU;
                            decode_instr_int.unit = UNIT_DIV;
                        end
                        {F7_MUL_DIV,F3_REM}: begin
                            decode_instr_int.instr_type = REM;
                            decode_instr_int.unit = UNIT_DIV;
                            decode_instr_int.signed_op = 1'b1;
                        end
                        {F7_MUL_DIV,F3_REMU}: begin
                            decode_instr_int.instr_type = REMU;
                            decode_instr_int.unit = UNIT_DIV;
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_ALU_I_W: begin
                    decode_instr_int.regfile_we = 1'b1;
                    decode_instr_int.use_imm    = 1'b1;
                    decode_instr_int.use_rs1    = 1'b1;
                    decode_instr_int.op_32      = 1'b1;

                    case (decode_i.inst.itype.func3)
                        F3_64_ADDIW: begin
                           decode_instr_int.instr_type = ADDW;
                        end
                        F3_64_SLLIW: begin
                            decode_instr_int.instr_type = SLLW;
                            // check for illegal isntruction
                            if (decode_i.inst.rtype.func7 != F7_NORMAL) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                xcpt_illegal_instruction_int = 1'b0;
                            end
                        end
                        F3_64_SRLIW_SRAIW: begin
                            case (decode_i.inst.rtype.func7)
                                F7_64_SRAIW_SUBW_SRAW: begin
                                    decode_instr_int.instr_type = SRAW;
                                end
                                F7_64_NORMAL: begin
                                    decode_instr_int.instr_type = SRLW;
                                end
                                default: begin // check illegal instruction
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            endcase             
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_ALU_W: begin
                    decode_instr_int.regfile_we = 1'b1;
                    decode_instr_int.use_rs1    = 1'b1;
                    decode_instr_int.use_rs2    = 1'b1;
                    decode_instr_int.op_32 = 1'b1;
                    unique case ({decode_i.inst.rtype.func7,decode_i.inst.rtype.func3})
                        {F7_NORMAL,F3_64_ADDW_SUBW}: begin
                            decode_instr_int.instr_type = ADDW;
                        end
                        {F7_SRAI_SUB_SRA,F3_64_ADDW_SUBW}: begin
                            decode_instr_int.instr_type = SUBW;
                        end
                        {F7_NORMAL,F3_64_SLLW}: begin
                            decode_instr_int.instr_type = SLLW;
                        end
                        {F7_NORMAL,F3_64_SRLW_SRAW}: begin
                            decode_instr_int.instr_type = SRLW;
                        end
                        {F7_SRAI_SUB_SRA,F3_64_SRLW_SRAW}: begin
                            decode_instr_int.instr_type = SRAW;
                        end
                        // Mults and Divs
                        {F7_MUL_DIV,F3_MULW}: begin
                            decode_instr_int.instr_type = MULW;
                            decode_instr_int.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_DIVW}: begin
                            decode_instr_int.instr_type = DIVW;
                            decode_instr_int.unit = UNIT_DIV;
                            decode_instr_int.signed_op = 1'b1;
                        end
                        {F7_MUL_DIV,F3_DIVUW}: begin
                            decode_instr_int.instr_type = DIVUW;
                            decode_instr_int.unit = UNIT_DIV;
                        end
                        {F7_MUL_DIV,F3_REMW}: begin
                            decode_instr_int.instr_type = REMW;
                            decode_instr_int.unit = UNIT_DIV;
                            decode_instr_int.signed_op = 1'b1;
                        end
                        {F7_MUL_DIV,F3_REMUW}: begin
                            decode_instr_int.instr_type = REMUW;
                            decode_instr_int.unit = UNIT_DIV;
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                    
                end
                OP_LOAD_FP: begin
                    decode_instr_int.mem_type = LOAD;
                    decode_instr_int.use_imm = 1'b0;
                    decode_instr_int.unit = UNIT_MEM;
                    decode_instr_int.use_rs1    = 1'b1;
                    case (decode_i.inst.itype.func3)
                        F3_FLW: begin
                            if (csr_fs_i == 2'b00) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                decode_instr_int.instr_type = FLW;
                                decode_instr_int.fregfile_we = 1'b1;
                            end
                        end
                        F3_FLD: begin
                            if (csr_fs_i == 2'b00) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                decode_instr_int.instr_type = FLD;
                                decode_instr_int.fregfile_we = 1'b1;
                            end
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_STORE_FP: begin
                    decode_instr_int.mem_type = STORE;
                    decode_instr_int.unit = UNIT_MEM;
                    decode_instr_int.use_imm = 1'b0;
                    decode_instr_int.use_rs1 = 1'b1;
                    case (decode_i.inst.stype.func3)
                        F3_FLW: begin
                            //decode_instr_int.regfile_src = FPU_RF;
                            if (csr_fs_i == 2'b00) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                decode_instr_int.instr_type = FSW;
                                decode_instr_int.use_fs2    = 1'b1;
                            end
                        end
                        F3_FLD: begin
                            //decode_instr_int.regfile_src = FPU_RF;
                            if (csr_fs_i == 2'b00) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                decode_instr_int.instr_type = FSD;
                                decode_instr_int.use_fs2    = 1'b1;
                            end
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_FENCE: begin
                    // Prior riscv isa spec has both fence and
                    // fence i here, in the up to date spec this
                    // fence_i should be removed depending if no 
                    // Zifence is implemented 
                    // NOTE: Remove if spec is updated
                    case (decode_i.inst.itype.func3)
                        F3_FENCE: begin
                            decode_instr_int.instr_type = FENCE;
                            decode_instr_int.stall_csr_fence = 1'b1;
                        end
                        F3_FENCE_I: begin
                            decode_instr_int.instr_type = FENCE_I;
                            decode_instr_int.stall_csr_fence = 1'b1;
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                    
                end
                OP_SYSTEM: begin
                    decode_instr_int.use_imm    = 1'b1;
                    decode_instr_int.regfile_we = 1'b1;
                    decode_instr_int.unit = UNIT_SYSTEM;
                    decode_instr_int.stall_csr_fence = 1'b1;

                    case (decode_i.inst.itype.func3)     
                        F3_ECALL_EBREAK_ERET: begin
                            
                            decode_instr_int.regfile_we = 1'b0;

                            if (decode_i.inst.itype.rd != 'h0 ) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                case (decode_i.inst.rtype.func7)
                                    F7_ECALL_EBREAK_URET: begin
                                        if (decode_i.inst.itype.rs1 != 'h0) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            case (decode_i.inst.rtype.rs2)
                                                RS2_ECALL_ERET: begin
                                                    decode_instr_int.instr_type = ECALL;
                                                    decode_instr_int.stall_csr_fence = 1'b1;
                                                end
                                                RS2_EBREAK_SFENCEVM: begin
                                                    decode_instr_int.instr_type = EBREAK;
                                                    decode_instr_int.stall_csr_fence = 1'b1;
                                                end
                                                RS2_URET_SRET_MRET: begin
                                                    decode_instr_int.instr_type = URET;
                                                    decode_instr_int.stall_csr_fence = 1'b1;
                                                end
                                                default: begin
                                                    xcpt_illegal_instruction_int = 1'b1;
                                                end   
                                            endcase // decode_i.inst.rtype.rs2
                                        end
                                    end
                                    F7_SRET_WFI_ERET_SFENCE: begin
                                        if (decode_i.inst.itype.rs1 != 'h0) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            case (decode_i.inst.rtype.rs2)
                                                RS2_URET_SRET_MRET: begin
                                                    decode_instr_int.instr_type = SRET;
                                                    decode_instr_int.stall_csr_fence = 1'b1;
                                                end
                                                RS2_WFI: begin
                                                    decode_instr_int.instr_type = WFI;
                                                    decode_instr_int.stall_csr_fence = 1'b1;
                                                end
                                                RS2_EBREAK_SFENCEVM: begin
                                                    // SFENCE here is old ISA
                                                    decode_instr_int.instr_type = SFENCE_VMA;
                                                    decode_instr_int.stall_csr_fence = 1'b1;
                                                end
                                                default: begin
                                                    xcpt_illegal_instruction_int = 1'b1;
                                                end 
                                            endcase // decode_i.inst.rtype.rs2
                                        end
                                    end
                                    F7_MRET_MRTS: begin
                                        if (decode_i.inst.itype.rs1 != 'h0) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            case (decode_i.inst.rtype.rs2)
                                                RS2_URET_SRET_MRET: begin
                                                    decode_instr_int.instr_type = MRET;
                                                    decode_instr_int.stall_csr_fence = 1'b1;
                                                end
                                                default: begin
                                                    xcpt_illegal_instruction_int = 1'b1;
                                                end 
                                            endcase // decode_i.inst.rtype.rs2
                                        end
                                    end
                                    /*F7_HRTS: begin
                                        if (decode_i.inst.itype.rs1 != 'h0) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            case (decode_i.inst.rtype.rs2)
                                                RS2_MRTS_HRTS: begin
                                                    decode_instr_int.instr_type = HRTS;
                                                end
                                                default: begin
                                                    xcpt_illegal_instruction_int = 1'b1;
                                                end 
                                            endcase // decode_i.inst.rtype.rs2
                                        end
                                    end*/
                                    F7_SFENCE_VM:begin
                                        decode_instr_int.instr_type = SFENCE_VMA;
                                        decode_instr_int.stall_csr_fence = 1'b1;
                                    end
                                    default: begin // check illegal instruction
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                        end
                        F3_CSRRW: begin
                            decode_instr_int.use_rs1 = 1'b1;
                            decode_instr_int.instr_type = CSRRW;
                            decode_instr_int.stall_csr_fence = 1'b1;
                        end
                        F3_CSRRS: begin
                            decode_instr_int.use_rs1 = 1'b1;
                            decode_instr_int.instr_type = CSRRS;
                            decode_instr_int.stall_csr_fence = 1'b1;
                        end
                        F3_CSRRC: begin
                            decode_instr_int.use_rs1 = 1'b1;
                            decode_instr_int.instr_type = CSRRC;
                            decode_instr_int.stall_csr_fence = 1'b1;             
                        end
                        F3_CSRRWI: begin
                            decode_instr_int.instr_type = CSRRWI;
                            decode_instr_int.stall_csr_fence = 1'b1;             
                        end
                        F3_CSRRSI: begin
                            decode_instr_int.instr_type = CSRRSI;
                            decode_instr_int.stall_csr_fence = 1'b1;             
                        end
                        F3_CSRRCI: begin
                            decode_instr_int.instr_type = CSRRCI;
                            decode_instr_int.stall_csr_fence = 1'b1;             
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_FMADD,
                OP_FMSUB,
                OP_FNMSUB,
                OP_FNMADD: begin
                    // Fused Multiply Add
                    if (csr_fs_i == 2'b00) begin
                        xcpt_illegal_instruction_int = 1'b1;
                    end else begin
                        decode_instr_int.unit = UNIT_FPU;
                        decode_instr_int.fregfile_we = 1'b1;
                        decode_instr_int.use_imm = 1'b0;
                        decode_instr_int.use_fs1 = 1'b1;
                        decode_instr_int.use_fs2 = 1'b1;
                        decode_instr_int.use_fs3 = 1'b1;
                        check_frm = 1'b1;
                        // Select the instruction
                        unique case (decode_i.inst.r4type.opcode) 
                            OP_FMADD: begin
                                decode_instr_int.instr_type = FMADD;
                            end
                            OP_FMSUB: begin
                                decode_instr_int.instr_type = FMSUB;
                            end
                            OP_FNMSUB: begin
                                decode_instr_int.instr_type = FNMSUB;
                            end
                            default: begin // OP_FNMADD
                                decode_instr_int.instr_type = FNMADD;
                            end
                        endcase
                        // func2 is the fmt
                        // we only support the first two modes (S,D)
                        case (decode_i.inst.r4type.fmt)
                            FMT_S: begin
                                decode_instr_int.fmt = 1'b0;
                            end
                            FMT_D: begin
                                decode_instr_int.fmt = 1'b1;
                            end
                            default: begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end
                        endcase

                        if (check_frm) begin
                            unique case (decode_i.inst.fprtype.rm)
                                // Illegal modes
                                FRM_INV_1,
                                FRM_INV_2: begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                                FRM_DYN: begin // check dynamic one
                                    unique case (frm_i) inside // FRM from CSR
                                        FRM_INV_1,
                                        FRM_INV_2,
                                        FRM_DYN: begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                        default: begin
                                            //xcpt_illegal_instruction_int = 1'b0;
                                            decode_instr_int.frm = op_frm_fp_t'(frm_i);
                                        end 
                                    endcase
                                end
                                default: begin
                                    //xcpt_illegal_instruction_int = 1'b0;
                                end
                            endcase
                        end
                    end
                end
                OP_FP: begin
                    decode_instr_int.unit = UNIT_FPU;
                    decode_instr_int.fregfile_we = 1'b1;
                    decode_instr_int.use_imm = 1'b0;
                    decode_instr_int.use_fs1 = 1'b1;
                    decode_instr_int.use_fs2 = 1'b1;
                    if (csr_fs_i == 2'b00) begin
                        xcpt_illegal_instruction_int = 1'b1;
                    end else begin
                        case (decode_i.inst.fprtype.func5)
                            F5_FP_FADD: begin
                                decode_instr_int.instr_type = FADD;
                                check_frm = 1'b1;
                            end
                            F5_FP_FSUB: begin
                                decode_instr_int.instr_type = FSUB;
                                check_frm = 1'b1;
                            end
                            F5_FP_FMUL: begin
                                decode_instr_int.instr_type = FMUL;
                                check_frm = 1'b1;
                            end
                            F5_FP_FDIV: begin
                                decode_instr_int.instr_type = FDIV;
                                check_frm = 1'b1;
                            end
                            F5_FP_FSQRT: begin
                                decode_instr_int.instr_type = FSQRT;
                                check_frm = 1'b1;
                                decode_instr_int.use_fs2 = 1'b0;
                                /*if (decode_i.inst.rtype.rs2 != 5'b0) begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end*/
                            end
                            F5_FP_FSGNJ: begin
                                decode_instr_int.instr_type = FSGNJ;
                                // Check through rounding modes if illegal instr
                                if (!(decode_i.inst.fprtype.rm inside {[3'b000:3'b010]})) begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            end
                            F5_FP_FMIN_MAX: begin
                                decode_instr_int.instr_type = FMIN_MAX;
                                // Check through rounding modes if illegal instr
                                if (!(decode_i.inst.fprtype.rm inside {[3'b000:3'b001]})) begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            end
                            F5_FP_FCVT_F2I: begin // FP to Integer
                                decode_instr_int.instr_type = FCVT_F2I;
                                check_frm = 1'b1;
                                decode_instr_int.use_fs2 = 1'b0;
                                decode_instr_int.fregfile_we = 1'b0;
                                decode_instr_int.regfile_we = 1'b1;
                                // Check if FMT is FP32 then INT 32 then extens sign
                                decode_instr_int.op_32   = !decode_instr_int.rs2[1];
                                // Check through rounding modes if illegal instr
                                /*if (!(decode_i.inst.fprtype.rs2 inside {[5'b00000:5'b00011]})) begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end*/
                            end
                            F5_FP_FMV_F2I_FCLASS: begin // FP moves and classify
                                decode_instr_int.fregfile_we = 1'b0;
                                decode_instr_int.regfile_we = 1'b1;
                                decode_instr_int.use_fs2 = 1'b0;
                                case (decode_i.inst.fprtype.rm)
                                    3'b000: begin
                                        if (decode_i.inst.fprtype.fmt == FMT_FP_S) begin
                                            decode_instr_int.instr_type    = ADDW;
                                            decode_instr_int.op_32         = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type    = ADD;
                                            decode_instr_int.op_32         = 1'b0;
                                        end
                                        decode_instr_int.regfile_we    = 1'b1;
                                        decode_instr_int.use_imm       = 1'b0;
                                        decode_instr_int.unit          = UNIT_ALU;
                                        decode_instr_int.rs2           = 'h0;
                                        decode_instr_int.fregfile_we = 1'b0;
                                        decode_instr_int.use_imm       = 1'b0;
                                        decode_instr_int.use_rs1       = 1'b0;
                                        decode_instr_int.use_rs2       = 1'b1; // hack to sum with 0
                                        decode_instr_int.use_fs1       = 1'b1;
                                        decode_instr_int.use_fs2       = 1'b0;
                                    end
                                    3'b001: begin
                                        decode_instr_int.instr_type = FCLASS;
                                    end
                                    default: begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                            F5_FP_FCMP: begin // FP comp
                                decode_instr_int.instr_type = FCMP;
                                decode_instr_int.fregfile_we = 1'b0;
                                decode_instr_int.regfile_we = 1'b1;
                                // Check through rounding modes if illegal instr
                                if (!(decode_i.inst.fprtype.rm inside {[3'b000:3'b010]})) begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            end
                            F5_FP_FCVT_I2F: begin
                                decode_instr_int.instr_type    = FCVT_I2F;
                                decode_instr_int.use_fs1 = 1'b0;
                                decode_instr_int.use_fs2 = 1'b0;
                                decode_instr_int.use_rs1 = 1'b1;
                                decode_instr_int.fregfile_we = 1'b1;
                                decode_instr_int.regfile_we = 1'b0;
                                check_frm = 1'b1;
                                // Check through rounding modes if illegal instr
                                /*if (!(decode_i.inst.rtype.func3 inside {[5'b00000:5'b00011]})) begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end*/
                            end
                            F5_FP_FMV_I2F: begin // Move from integer reg to fp reg
                                decode_instr_int.instr_type = FMV_X2F;
                                decode_instr_int.use_fs1 = 1'b0;
                                decode_instr_int.use_fs2 = 1'b0;
                                decode_instr_int.use_rs1 = 1'b1;
                                decode_instr_int.use_rs2 = 1'b0;
                                // Check if FMT is FP32 then INT 32 then extens sign
                                if (decode_i.inst.fprtype.fmt == FMT_FP_S) begin
                                    decode_instr_int.op_32   = 1'b1;
                                end else begin
                                    decode_instr_int.op_32   = 1'b0;
                                end
                                if (decode_i.inst.fprtype.rm != 3'b000) begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            end
                            // D2S & S2D specific 
                            F5_FP_FCVT_SD: begin
                                decode_instr_int.instr_type = FCVT_F2F;
                                decode_instr_int.use_fs2 = 1'b0;
                                check_frm = 1'b1;
                            end
                            default: begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end
                        endcase

                        unique case (decode_i.inst.fprtype.fmt)
                            FMT_FP_S: begin
                                decode_instr_int.fmt = FMT_S;
                            end
                            FMT_FP_D: begin
                                decode_instr_int.fmt = FMT_D;
                            end
                            default: begin
                                xcpt_illegal_instruction_int = 1'b0;
                            end
                        endcase

                        if (check_frm) begin
                            unique case (decode_i.inst.fprtype.rm)
                                // Illegal modes
                                FRM_INV_1,
                                FRM_INV_2: begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                                FRM_DYN: begin // check dynamic one
                                    unique case (frm_i) inside // FRM from CSR
                                        FRM_INV_1,
                                        FRM_INV_2,
                                        FRM_DYN: begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                        default: begin
                                            //xcpt_illegal_instruction_int = 1'b0;
                                            decode_instr_int.frm = op_frm_fp_t'(frm_i);
                                        end 
                                    endcase
                                end
                                default: begin
                                    //xcpt_illegal_instruction_int = 1'b0;
                                end
                            endcase
                        end
                    end
                end
                OP_CUSTOM0: begin
                    decode_instr_int.regfile_we = 1'b1;
                    decode_instr_int.use_rs1 = 1'b1;
                    decode_instr_int.use_rs2 = 1'b1;
                    unique case ({decode_i.inst.rtype.func7,decode_i.inst.rtype.func3})
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                default: begin
                    // By default this is not a valid instruction
                    xcpt_illegal_instruction_int = 1'b1;
                end
            endcase
        end
    end

    // handle exceptions
    always_comb begin 
        decode_instr_o.instr = decode_instr_int;
        if (!decode_i.ex.valid) begin 
            if (xcpt_addr_misaligned_int) begin
                decode_instr_o.ex.valid  = 1'b1;
                decode_instr_o.ex.cause  = INSTR_ADDR_MISALIGNED;
                decode_instr_o.ex.origin = jal_id_if_o.jump_addr; // this gives a hint
                decode_instr_o.instr.ex_valid = 1'b1; 
            end else if (xcpt_illegal_instruction_int) begin
                decode_instr_o.ex.valid  = 1'b1;
                decode_instr_o.ex.cause  = ILLEGAL_INSTR;
                decode_instr_o.ex.origin = 'h0;
                decode_instr_o.instr.ex_valid = 1'b1;
            end else begin
                decode_instr_o.ex.valid  = 'h0;
                decode_instr_o.ex.cause  = NONE;
                decode_instr_o.ex.origin = 'h0;
                decode_instr_o.instr.ex_valid = 1'b0;
            end
        end else begin // this means there is an exception
            decode_instr_o.ex = decode_i.ex;
            decode_instr_o.instr.ex_valid = decode_i.ex.valid;
        end
    end

    return_address_stack return_address_stack_inst(
        .rstn_i(rstn_i),
        .clk_i(clk_i),
        .pc_execution_i(decode_instr_int.pc + 64'h4),
        .push_i(ras_push_int && !stall_i && !flush_i),
        .pop_i(ras_pop_int && !stall_i && !flush_i),
        .return_address_o(ras_pc_int));

endmodule
//`default_nettype wire
