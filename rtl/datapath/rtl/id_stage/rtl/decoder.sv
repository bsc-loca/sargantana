/* -----------------------------------------------
* Project Name   : DRAC
* File           : decoder.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : RISCV ISA
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
    input   if_id_stage_t    decode_i,
    output  instr_entry_t    decode_instr_o,
    output  jal_id_if_t      jal_id_if_o
);

    bus64_t imm_value;
    logic xcpt_illegal_instruction_int;
    logic xcpt_addr_misaligned_int;

    immediate immediate_inst(
        .instr_i(decode_i.inst),
        .imm_o(imm_value)
    );

    always_comb begin
        xcpt_illegal_instruction_int = 1'b0;
        xcpt_addr_misaligned_int     = 1'b0;

        decode_instr_o.pc    = decode_i.pc_inst;
        decode_instr_o.bpred = decode_i.bpred;

        decode_instr_o.valid = decode_i.valid;
        // Registers sources
        decode_instr_o.rs1 = decode_i.inst.common.rs1;
        decode_instr_o.rs2 = decode_i.inst.common.rs2;
        decode_instr_o.rd  = decode_i.inst.common.rd;
        // By default all enables to zero
        decode_instr_o.change_pc_ena = 1'b0;
        decode_instr_o.regfile_we    = 1'b0;
        // does not really matter
        decode_instr_o.use_imm = 1'b0;
        decode_instr_o.use_pc  = 1'b0;
        decode_instr_o.op_32   = 1'b0;

        decode_instr_o.instr_type = ADD;

        
        decode_instr_o.unit   = UNIT_ALU;

        // Assign by default the immediate in the result
        decode_instr_o.result = imm_value;
        // This is lowrisc related
        decode_instr_o.mem_size = decode_i.inst.common.func3;
        decode_instr_o.signed_op = 1'b0;

        jal_id_if_o.valid = 1'b0;
        jal_id_if_o.jump_addr = 64'b0;

        // Signal that tells whether it is a csr or fence
        decode_instr_o.stall_csr_fence = 1'b0;

        `ifdef VERILATOR
            decode_instr_o.inst = decode_i.inst;
        `endif


        if (!decode_i.ex.valid && decode_i.valid ) begin


            case (decode_i.inst.common.opcode)
                // Load Upper immediate
                OP_LUI: begin
                    decode_instr_o.regfile_we  = 1'b1;
                    decode_instr_o.use_imm = 1'b1;
                    decode_instr_o.rs1 = '0;
                    decode_instr_o.instr_type = OR;
                end
                OP_AUIPC:begin
                    decode_instr_o.regfile_we  = 1'b1;
                    decode_instr_o.use_imm = 1'b1;
                    decode_instr_o.use_pc = 1'b1;
                    decode_instr_o.instr_type = ADD;          
                end
                OP_JAL: begin
                    decode_instr_o.regfile_we = 1'b1; // we write pc+4 to rd
                    decode_instr_o.change_pc_ena = 1'b0; // Actually we change now
                    decode_instr_o.use_imm = 1'b1;
                    decode_instr_o.use_pc = 1'b1;
                    decode_instr_o.instr_type = JAL;
                    decode_instr_o.unit = UNIT_BRANCH;
                    // it is valid if there is no misaligned exception
                    xcpt_addr_misaligned_int = |imm_value[1:0]; 
                    jal_id_if_o.valid = !xcpt_addr_misaligned_int & decode_i.valid;
                    jal_id_if_o.jump_addr = imm_value+decode_i.pc_inst;
                end
                OP_JALR: begin
                    decode_instr_o.regfile_we = 1'b1;
                    decode_instr_o.change_pc_ena = 1'b1;
                    decode_instr_o.use_imm = 1'b1;
                    decode_instr_o.use_pc = 1'b1;
                    decode_instr_o.instr_type = JALR;
                    decode_instr_o.unit = UNIT_BRANCH;
                    // ISA says that func3 should be zero
                    if (decode_i.inst.itype.func3 != 'h0) begin
                        xcpt_illegal_instruction_int = 1'b1;
                    end
                end
                OP_BRANCH: begin
                    decode_instr_o.regfile_we = 1'b0;
                    decode_instr_o.change_pc_ena = 1'b1;
                    decode_instr_o.use_imm = 1'b1;
                    decode_instr_o.use_pc = 1'b1;
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
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase 
                end
                OP_LOAD:begin
                    decode_instr_o.regfile_we = 1'b1;
                    decode_instr_o.use_imm = 1'b1;
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
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_STORE: begin
                    decode_instr_o.regfile_we = 1'b0;
                    decode_instr_o.use_imm = 1'b1;
                    decode_instr_o.unit = UNIT_MEM;
                    case (decode_i.inst.itype.func3)
                        F3_SB: begin
                            decode_instr_o.instr_type = SB;
                        end
                        F3_SH: begin
                            decode_instr_o.instr_type = SH;
                        end
                        F3_SW: begin
                            decode_instr_o.instr_type = SW;
                        end
                        F3_SD: begin
                            decode_instr_o.instr_type = SD;
                        end                    
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_ATOMICS: begin
                    // NOTE (guillemlp) what to do with aq and rl?
                    decode_instr_o.regfile_we   = 1'b1;
                    // NOTE (guillemlp) if aq and rl are used maybe the imm is needed
                    decode_instr_o.use_imm      = 1'b0;
                    decode_instr_o.unit         = UNIT_MEM;
                    case (decode_i.inst.rtype.func3)
                        F3_ATOMICS: begin
                            case (decode_i.inst.rtype.func7[31:27])
                                LR_W: begin
                                    if (decode_i.inst.rtype.rs2 != 'h0) begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end else begin
                                        decode_instr_o.instr_type = AMO_LRW;
                                    end
                                end
                                SC_W: begin
                                    decode_instr_o.instr_type = AMO_SCW;
                                end
                                AMOSWAP_W: begin
                                    decode_instr_o.instr_type = AMO_SWAPW;
                                end
                                AMOADD_W: begin
                                    decode_instr_o.instr_type = AMO_ADDW;
                                end
                                AMOXOR_W: begin
                                    decode_instr_o.instr_type = AMO_XORW;
                                end
                                AMOAND_W: begin
                                    decode_instr_o.instr_type = AMO_ANDW;
                                end
                                AMOOR_W: begin
                                    decode_instr_o.instr_type = AMO_ORW;
                                end
                                AMOMIN_W: begin
                                    decode_instr_o.instr_type = AMO_MINW;
                                end
                                AMOMAX_W: begin
                                    decode_instr_o.instr_type = AMO_MAXW;
                                end
                                AMOMINU_W: begin
                                    decode_instr_o.instr_type = AMO_MINWU;
                                end
                                AMOMAXU_W: begin
                                    decode_instr_o.instr_type = AMO_MAXWU;
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
                                        decode_instr_o.instr_type = AMO_LRD;
                                    end
                                end
                                SC_D: begin
                                    decode_instr_o.instr_type = AMO_SCD;
                                end
                                AMOSWAP_D: begin
                                    decode_instr_o.instr_type = AMO_SWAPD;
                                end
                                AMOADD_D: begin
                                    decode_instr_o.instr_type = AMO_ADDD;
                                end
                                AMOXOR_D: begin
                                    decode_instr_o.instr_type = AMO_XORD;
                                end
                                AMOAND_D: begin
                                    decode_instr_o.instr_type = AMO_ANDD;
                                end
                                AMOOR_D: begin
                                    decode_instr_o.instr_type = AMO_ORD;
                                end
                                AMOMIN_D: begin
                                    decode_instr_o.instr_type = AMO_MIND;
                                end
                                AMOMAX_D: begin
                                    decode_instr_o.instr_type = AMO_MAXD;
                                end
                                AMOMINU_D: begin
                                    decode_instr_o.instr_type = AMO_MINDU;
                                end
                                AMOMAXU_D: begin
                                    decode_instr_o.instr_type = AMO_MAXDU;
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
                    decode_instr_o.use_imm    = 1'b1;
                    decode_instr_o.regfile_we = 1'b1;
                    // we don't need a default cause all cases are there
                    unique case (decode_i.inst.itype.func3)
                        F3_ADDI: begin
                           decode_instr_o.instr_type = ADD;
                        end
                        F3_SLTI: begin
                            decode_instr_o.instr_type = SLT;
                        end
                        F3_SLTIU: begin
                            decode_instr_o.instr_type = SLTU;
                        end
                        F3_XORI: begin
                            decode_instr_o.instr_type = XOR;
                        end
                        F3_ORI: begin
                            decode_instr_o.instr_type = OR;
                        end
                        F3_ANDI: begin
                            decode_instr_o.instr_type = AND;
                        end
                        F3_SLLI: begin
                            decode_instr_o.instr_type = SLL;
                            // check for illegal instruction
                            if (decode_i.inst.rtype.func7[31:26] != F7_NORMAL[6:1]) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                xcpt_illegal_instruction_int = 1'b0;
                            end
                        end
                        F3_SRLAI: begin
                            case (decode_i.inst.rtype.func7[31:26])
                                F7_SRAI_SUB_SRA[6:1]: begin
                                    decode_instr_o.instr_type = SRA;
                                end
                                F7_NORMAL[6:1]: begin
                                    decode_instr_o.instr_type = SRL;
                                end
                                default: begin // check illegal instruction
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            endcase             
                        end
                    endcase
                end
                OP_ALU: begin
                    decode_instr_o.regfile_we = 1'b1;
                    unique case ({decode_i.inst.rtype.func7,decode_i.inst.rtype.func3})
                        {F7_NORMAL,F3_ADD_SUB}: begin
                            decode_instr_o.instr_type = ADD;
                        end
                        {F7_SRAI_SUB_SRA,F3_ADD_SUB}: begin
                            decode_instr_o.instr_type = SUB;
                        end
                        {F7_NORMAL,F3_SLL}: begin
                            decode_instr_o.instr_type = SLL;
                        end
                        {F7_NORMAL,F3_SLT}: begin
                            decode_instr_o.instr_type = SLT;
                        end
                        {F7_NORMAL,F3_SLTU}: begin
                            decode_instr_o.instr_type = SLTU;
                        end
                        {F7_NORMAL,F3_XOR}: begin
                            decode_instr_o.instr_type = XOR;
                        end
                        {F7_NORMAL,F3_SRL_SRA}: begin
                            decode_instr_o.instr_type = SRL;
                        end
                        {F7_SRAI_SUB_SRA,F3_SRL_SRA}: begin
                            decode_instr_o.instr_type = SRA;
                        end
                        {F7_NORMAL,F3_OR}: begin
                            decode_instr_o.instr_type = OR;
                        end
                        {F7_NORMAL,F3_AND}: begin
                            decode_instr_o.instr_type = AND;
                        end
                        // Mults and Divs
                        {F7_MUL_DIV,F3_MUL}: begin
                            decode_instr_o.instr_type = MUL;
                            decode_instr_o.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_MULH}: begin
                            decode_instr_o.instr_type = MULH;
                            decode_instr_o.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_MULHSU}: begin
                            decode_instr_o.instr_type = MULHSU;
                            decode_instr_o.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_MULHU}: begin
                            decode_instr_o.instr_type = MULHU;
                            decode_instr_o.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_DIV}: begin
                            decode_instr_o.instr_type = DIV;
                            decode_instr_o.unit = UNIT_DIV;
                            decode_instr_o.signed_op = 1'b1;
                        end
                        {F7_MUL_DIV,F3_DIVU}: begin
                            decode_instr_o.instr_type = DIVU;
                            decode_instr_o.unit = UNIT_DIV;
                        end
                        {F7_MUL_DIV,F3_REM}: begin
                            decode_instr_o.instr_type = REM;
                            decode_instr_o.unit = UNIT_DIV;
                            decode_instr_o.signed_op = 1'b1;
                        end
                        {F7_MUL_DIV,F3_REMU}: begin
                            decode_instr_o.instr_type = REMU;
                            decode_instr_o.unit = UNIT_DIV;
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                OP_ALU_I_W: begin
                    decode_instr_o.use_imm    = 1'b1;
                    decode_instr_o.regfile_we = 1'b1;
                    decode_instr_o.op_32 = 1'b1;

                    case (decode_i.inst.itype.func3)
                        F3_64_ADDIW: begin
                           decode_instr_o.instr_type = ADDW;
                        end
                        F3_64_SLLIW: begin
                            decode_instr_o.instr_type = SLLW;
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
                                    decode_instr_o.instr_type = SRAW;
                                end
                                F7_64_NORMAL: begin
                                    decode_instr_o.instr_type = SRLW;
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
                    decode_instr_o.regfile_we = 1'b1;
                    decode_instr_o.op_32 = 1'b1;
                    unique case ({decode_i.inst.rtype.func7,decode_i.inst.rtype.func3})
                        {F7_NORMAL,F3_64_ADDW_SUBW}: begin
                            decode_instr_o.instr_type = ADDW;
                        end
                        {F7_SRAI_SUB_SRA,F3_64_ADDW_SUBW}: begin
                            decode_instr_o.instr_type = SUBW;
                        end
                        {F7_NORMAL,F3_64_SLLW}: begin
                            decode_instr_o.instr_type = SLLW;
                        end
                        {F7_NORMAL,F3_64_SRLW_SRAW}: begin
                            decode_instr_o.instr_type = SRLW;
                        end
                        {F7_SRAI_SUB_SRA,F3_64_SRLW_SRAW}: begin
                            decode_instr_o.instr_type = SRAW;
                        end
                        // Mults and Divs
                        {F7_MUL_DIV,F3_MULW}: begin
                            decode_instr_o.instr_type = MULW;
                            decode_instr_o.unit = UNIT_MUL;
                        end
                        {F7_MUL_DIV,F3_DIVW}: begin
                            decode_instr_o.instr_type = DIVW;
                            decode_instr_o.unit = UNIT_DIV;
                            decode_instr_o.signed_op = 1'b1;
                        end
                        {F7_MUL_DIV,F3_DIVUW}: begin
                            decode_instr_o.instr_type = DIVUW;
                            decode_instr_o.unit = UNIT_DIV;
                        end
                        {F7_MUL_DIV,F3_REMW}: begin
                            decode_instr_o.instr_type = REMW;
                            decode_instr_o.unit = UNIT_DIV;
                            decode_instr_o.signed_op = 1'b1;
                        end
                        {F7_MUL_DIV,F3_REMUW}: begin
                            decode_instr_o.instr_type = REMUW;
                            decode_instr_o.unit = UNIT_DIV;
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
                        // implement fence as fence i 
                        // to be more restrictive
                        F3_FENCE: begin
                            decode_instr_o.instr_type = FENCE;
                            decode_instr_o.stall_csr_fence = 1'b1;
                        end
                        F3_FENCE_I: begin
                            decode_instr_o.instr_type = FENCE_I;
                            decode_instr_o.stall_csr_fence = 1'b1;
                        end
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                    
                end
                OP_SYSTEM: begin
                    decode_instr_o.use_imm    = 1'b1;
                    decode_instr_o.regfile_we = 1'b1;
                    decode_instr_o.unit = UNIT_SYSTEM;

                    case (decode_i.inst.itype.func3)     
                        F3_ECALL_EBREAK_ERET: begin
                            
                            decode_instr_o.regfile_we = 1'b0;

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
                                                    decode_instr_o.instr_type = ECALL;
                                                    decode_instr_o.stall_csr_fence = 1'b1;
                                                end
                                                RS2_EBREAK_SFENCEVM: begin
                                                    decode_instr_o.instr_type = EBREAK;
                                                    decode_instr_o.stall_csr_fence = 1'b1;
                                                end
                                                RS2_URET_SRET_MRET: begin
                                                    decode_instr_o.instr_type = URET;
                                                    decode_instr_o.stall_csr_fence = 1'b1;
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
                                                    decode_instr_o.instr_type = SRET;
                                                    decode_instr_o.stall_csr_fence = 1'b1;
                                                end
                                                RS2_WFI: begin
                                                    decode_instr_o.instr_type = WFI;
                                                    decode_instr_o.stall_csr_fence = 1'b1;
                                                end
                                                RS2_EBREAK_SFENCEVM: begin
                                                    // SFENCE here is old ISA
                                                    // TODO (guillemlp): check and delete this option 
                                                    decode_instr_o.instr_type = SFENCE_VMA;
                                                    decode_instr_o.stall_csr_fence = 1'b1;
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
                                                    decode_instr_o.instr_type = MRET;
                                                    decode_instr_o.stall_csr_fence = 1'b1;
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
                                                    decode_instr_o.instr_type = HRTS;
                                                end
                                                default: begin
                                                    xcpt_illegal_instruction_int = 1'b1;
                                                end 
                                            endcase // decode_i.inst.rtype.rs2
                                        end
                                    end*/
                                    F7_SFENCE_VM:begin
                                        decode_instr_o.instr_type = SFENCE_VMA;
                                        decode_instr_o.stall_csr_fence = 1'b1;
                                    end
                                    default: begin // check illegal instruction
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                        end
                        F3_CSRRW: begin
                           decode_instr_o.instr_type = CSRRW;
                           decode_instr_o.stall_csr_fence = 1'b1;
                        end
                        F3_CSRRS: begin
                            decode_instr_o.instr_type = CSRRS;
                            decode_instr_o.stall_csr_fence = 1'b1;
                        end
                        F3_CSRRC: begin
                            decode_instr_o.instr_type = CSRRC;
                            decode_instr_o.stall_csr_fence = 1'b1;             
                        end
                        F3_CSRRWI: begin
                            decode_instr_o.instr_type = CSRRWI;
                            decode_instr_o.stall_csr_fence = 1'b1;             
                        end
                        F3_CSRRSI: begin
                            decode_instr_o.instr_type = CSRRSI;
                            decode_instr_o.stall_csr_fence = 1'b1;             
                        end
                        F3_CSRRCI: begin
                            decode_instr_o.instr_type = CSRRCI;
                            decode_instr_o.stall_csr_fence = 1'b1;             
                        end
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
        if (!decode_i.ex.valid) begin 
            if (xcpt_addr_misaligned_int) begin
                decode_instr_o.ex.valid  = 1'b1;
                decode_instr_o.ex.cause  = INSTR_ADDR_MISALIGNED;
                decode_instr_o.ex.origin = jal_id_if_o.jump_addr; // this gives a hint 
            end else if (xcpt_illegal_instruction_int) begin
                decode_instr_o.ex.valid  = 1'b1;
                decode_instr_o.ex.cause  = ILLEGAL_INSTR;
                decode_instr_o.ex.origin = 'h0;
            end else begin
                decode_instr_o.ex.valid  = 'h0;
                decode_instr_o.ex.cause  = NONE;
                decode_instr_o.ex.origin = 'h0;
            end
        end else begin // this means there is an exception
            decode_instr_o.ex = decode_i.ex;
        end
    end

endmodule
//`default_nettype wire
