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

module decoder
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input   logic            clk_i,
    input   logic            rstn_i,
    input   logic            flush_i,
    input   logic            stall_i,
    input   if_id_stage_t    decode_i,
    input   logic [2:0]      frm_i, // FP rounding Mode from CSR
    input   logic [1:0]      csr_fs_i, 
    input   logic [1:0]      csr_vs_i, 
    input   bus64_t          vset_rs2_i,
    input   bus64_t          vset_rs1_i,
    input   logic            write_vset_i,
    input   logic            commit_vset_i,
    input   logic            recover_commit_exception_i,
    input   logic            recover_last_misspredict_i,
    input   logic [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] vset_index_misspredict_i,    
    input   logic            debug_mode_en_i,
    output  logic [VMAXELEM_LOG:0] vl_short_o,
    output  logic [VTYPE_LENGTH:0] prev_vtype_o,     // First uncommitted vtype
    output  id_ir_stage_t    decode_instr_o,
    output  jal_id_if_t      jal_id_if_o,
    output  logic            full_vset_queue_o 
);

	//Auxilar signals
	localparam [5:0] F7_NORMAL_AUX = F7_NORMAL >> 1;
    bus64_t imm_value;
    logic xcpt_illegal_instruction_int;
    logic xcpt_addr_misaligned_int;
    addrPC_t ras_pc_int;
    logic ras_push_int;
    logic ras_pop_int;
    logic ras_link_rd_int;
    logic ras_link_rs1_int;

    logic check_frm;

    vreg_t emul_mask; 

    instr_entry_t decode_instr_int;

    //VLA, vtype 
    logic [VMAXELEM_LOG:0] vl, vl_short;
    sew_t sew;
    logic is_vset_instr, vl_0, vill, is_cycle_vset, write_vset_int, vta_int, vma_int;
    logic [2:0] vlmul_int;
    logic [VMAXELEM_LOG:0] vlmax_int;
    logic v_2sew_en_int;

    bus64_t avl_value_if_zero_int, avl_value_int;
    logic [3:0] rw_cmd_int;
    logic [11:0] vtype_int;
    logic [$clog2(VSET_QUEUE_NUM_ENTRIES)-1:0] vset_index_int;




    // Truncate Function
    function [63:0] trunc_65_64(input [64:0] val_in);
        trunc_65_64 = val_in[63:0];
    endfunction

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
        decode_instr_int.vs1 = decode_i.inst.vtype.vs1;
        decode_instr_int.vs2 = decode_i.inst.vtype.vs2;
        decode_instr_int.vd  = decode_i.inst.vtype.vd;
        // Register sources valid bits
        decode_instr_int.use_rs1 = 1'b0;
        decode_instr_int.use_rs2 = 1'b0;
        decode_instr_int.use_vs1 = 1'b0;
        decode_instr_int.use_vs2 = 1'b0;
        decode_instr_int.use_mask = 1'b0;
        decode_instr_int.use_old_vd = 1'b0;
        decode_instr_int.is_opvx = 1'b0;
        decode_instr_int.is_opvi = 1'b0;
        decode_instr_int.sew = sew;
        decode_instr_int.vl = vl;
        decode_instr_int.vta = vta_int;
        decode_instr_int.vma = vma_int;
        decode_instr_int.vlmax = vlmax_int;
        decode_instr_int.vset_index = vset_index_int;


        decode_instr_int.use_fs1 = 1'b0;
        decode_instr_int.use_fs2 = 1'b0;
        decode_instr_int.use_fs3 = 1'b0;

        // Information for the ras performance
        ras_link_rd_int = (decode_instr_int.rd == 5'h1) || (decode_instr_int.rd == 5'h5);
        ras_link_rs1_int = (decode_instr_int.rs1 == 5'h1) || (decode_instr_int.rs1 == 5'h5);
        ras_push_int = 1'b0; //default value
        ras_pop_int = 1'b0; //default value

        // By default all enables to zero
        decode_instr_int.regfile_we    = 1'b0;
        decode_instr_int.vregfile_we   = 1'b0;
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
        jal_id_if_o.jump_addr = trunc_65_64(decode_i.pc_inst + 64'h04);

        // Signal that tells whether it is a csr or fence
        decode_instr_int.stall_csr_fence = 1'b0;
        decode_instr_int.stall_vset_fence = 1'b0;

        `ifdef SIM_COMMIT_LOG
            decode_instr_int.inst = decode_i.inst;
        `endif

        decode_instr_int.mem_type = NOT_MEM;

        decode_instr_int.ex_valid = '0;

        case (sew)
            SEW_8: emul_mask = {{(VREGFILE_WIDTH-2){1'b0}},decode_i.inst.vltype.width[13:12]};
            SEW_16: emul_mask = (decode_i.inst.vltype.width[13:12] == 2'b11) ? 'b00010 : 'b00001;
            SEW_32: emul_mask = 'b00001;
            default: emul_mask = 'b00000; 
        endcase

        if (!decode_i.ex.valid && decode_i.valid ) begin
            case (decode_i.inst.common.opcode)
                // Load Upper immediate
                OP_LUI: begin
                    decode_instr_int.regfile_we  = 1'b1;
                    decode_instr_int.use_imm = 1'b1;
                    decode_instr_int.rs1 = '0;
                    decode_instr_int.instr_type = OR_INST;
                end
                OP_AUIPC:begin
                    decode_instr_int.regfile_we  = 1'b1;
                    decode_instr_int.use_imm = 1'b1;
                    decode_instr_int.use_pc = 1'b1;
                    decode_instr_int.instr_type = ADD;          
                end
                OP_JAL: begin
                    decode_instr_int.regfile_we = 1'b1; // we write pc+4 to rd
                    decode_instr_int.use_imm = 1'b1;
                    decode_instr_int.use_pc = 1'b1;
                    decode_instr_int.instr_type = JAL;
                    decode_instr_int.unit = UNIT_BRANCH;
                    // it is valid if there is no misaligned exception
                    xcpt_addr_misaligned_int = |imm_value[1:0];
                    jal_id_if_o.jump_addr = trunc_65_64(imm_value+decode_i.pc_inst); 
                    jal_id_if_o.valid = !xcpt_addr_misaligned_int & decode_i.valid &
                                        !((jal_id_if_o.jump_addr == decode_i.bpred.pred_addr) & 
                                        (decode_i.bpred.decision == PRED_TAKEN));
                    if (!xcpt_addr_misaligned_int && decode_i.valid && ras_link_rd_int) begin
                        ras_push_int = 1'b1;
                    end
                    
                end
                OP_JALR: begin
                    decode_instr_int.regfile_we = 1'b1;
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
                        end else if ((ras_link_rd_int && ras_link_rs1_int) && (decode_instr_int.rs1 == decode_instr_int.rd)) begin
                            ras_push_int = 1'b1;
                        end else if (ras_link_rd_int && ras_link_rs1_int) begin
                            ras_pop_int = 1'b1;
                            ras_push_int = 1'b1;
                        end
                    end
                    jal_id_if_o.jump_addr = ras_pc_int; 
                    jal_id_if_o.valid = ras_pop_int && !((((jal_id_if_o.jump_addr == decode_i.bpred.pred_addr) &
                                                        (decode_i.bpred.decision == PRED_TAKEN)) && (!flush_i)) && !stall_i);

                    decode_instr_int.bpred.pred_addr = jal_id_if_o.valid ? ras_pc_int : decode_i.bpred.pred_addr;
                    decode_instr_int.bpred.decision = (jal_id_if_o.valid || (decode_i.bpred.decision == PRED_TAKEN)) 
                                                    ? PRED_TAKEN : PRED_NOT_TAKEN;
                    decode_instr_int.bpred.is_branch = 1'b1;

                end
                OP_BRANCH: begin
                    decode_instr_int.regfile_we = 1'b0;
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
                            decode_instr_int.instr_type = XOR_INST;
                        end
                        F3_ORI: begin
                            decode_instr_int.instr_type = OR_INST;
                        end
                        F3_ANDI: begin
                            decode_instr_int.instr_type = AND_INST;
                        end
                        F3_SLLI: begin
                            // check for illegal instruction
                            if (decode_i.inst.rtype.func7[31:26] == F7_NORMAL_AUX) begin
                                decode_instr_int.instr_type = SLL;
                            end
                            else if (decode_i.inst.rtype.func7[31:26] == F7_BINV[6:1]) begin
                                decode_instr_int.instr_type = BINV;
                            end
                            else if (decode_i.inst.rtype.func7 == F7_ROL_ROR_CLZ_CTZ_CPOP_SEXT) begin
                                case (decode_i.inst.rtype.rs2)
                                    RS2_CLZ: begin
                                        decode_instr_int.instr_type = CLZ;
                                    end
                                    RS2_CTZ: begin
                                        decode_instr_int.instr_type = CTZ;
                                    end
                                    RS2_SEXTB: begin
                                        decode_instr_int.instr_type = SEXTB;
                                    end
                                    RS2_SEXTH: begin
                                        decode_instr_int.instr_type = SEXTH;
                                    end
                                    RS2_CPOP: begin
                                        decode_instr_int.instr_type = CPOP;
                                    end
                                    default: begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                            else if (decode_i.inst.rtype.func7[31:26] == F7_BSET_ORCB[6:1]) begin
                                decode_instr_int.instr_type = BSET;
                            end
                            else if (decode_i.inst.rtype.func7[31:26] == F7_BCLR_BEXT[6:1]) begin
                                decode_instr_int.instr_type = BCLR;
                            end
                            else begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end
                        end
                        F3_SRLAI: begin // it is also for F3_RORI and F3_REV8
                            case (decode_i.inst.rtype.func7)
                                {F7_SRAI_SUB_SRA_NLOG[6:1], 1'b0}, {F7_SRAI_SUB_SRA_NLOG[6:1], 1'b1}: begin
                                    decode_instr_int.instr_type = SRA;
                                end
                                {F7_NORMAL[6:1], 1'b0}, {F7_NORMAL[6:1], 1'b1}: begin
                                    decode_instr_int.instr_type = SRL;
                                end
                                {F7_ROL_ROR_CLZ_CTZ_CPOP_SEXT[6:1], 1'b0}, {F7_ROL_ROR_CLZ_CTZ_CPOP_SEXT[6:1], 1'b1}: begin
                                    decode_instr_int.instr_type = ROR;
                                end
                                F7_REV8: begin
                                    if (decode_i.inst.rtype.rs2 == 5'b11000) begin
                                        decode_instr_int.instr_type = REV8;
                                    end else begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                end
                                F7_BSET_ORCB: begin
                                    if (decode_i.inst.rtype.rs2 == 5'b00111) begin
                                        decode_instr_int.instr_type = ORCB;
                                    end else begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                end
                                {F7_BCLR_BEXT[6:1], 1'b0}, {F7_BCLR_BEXT[6:1], 1'b1}: begin
                                    decode_instr_int.instr_type = BEXT;
                                end
                                default: begin
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
                        {F7_SRAI_SUB_SRA_NLOG,F3_ADD_SUB}: begin
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
                            decode_instr_int.instr_type = XOR_INST;
                        end
                        {F7_NORMAL,F3_SRL_SRA}: begin
                            decode_instr_int.instr_type = SRL;
                        end
                        {F7_SRAI_SUB_SRA_NLOG,F3_SRL_SRA}: begin
                            decode_instr_int.instr_type = SRA;
                        end
                        {F7_NORMAL,F3_OR}: begin
                            decode_instr_int.instr_type = OR_INST;
                        end
                        {F7_NORMAL,F3_AND}: begin
                            decode_instr_int.instr_type = AND_INST;
                        end
                        // Negated logic
                        {F7_SRAI_SUB_SRA_NLOG, F3_XNOR}: begin
                            decode_instr_int.instr_type = XNOR_INST;
                        end
                        {F7_SRAI_SUB_SRA_NLOG, F3_ORN}: begin
                            decode_instr_int.instr_type = ORN;
                        end
                        {F7_SRAI_SUB_SRA_NLOG, F3_ANDN}: begin
                            decode_instr_int.instr_type = ANDN;
                        end
                        // Rotation
                        {F7_ROL_ROR_CLZ_CTZ_CPOP_SEXT, F3_ROL}: begin
                            decode_instr_int.instr_type = ROL;
                        end
                        {F7_ROL_ROR_CLZ_CTZ_CPOP_SEXT, F3_ROR}: begin
                            decode_instr_int.instr_type = ROR;
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
                        {F7_SHADD, F3_SH1ADD}: begin
                            decode_instr_int.instr_type = SH1ADD;
                        end
                        {F7_SHADD, F3_SH2ADD}: begin
                            decode_instr_int.instr_type = SH2ADD;
                        end
                        {F7_SHADD, F3_SH3ADD}: begin
                            decode_instr_int.instr_type = SH3ADD;
                        end
                        {F7_CLMUL_MIN_MAX, F3_MIN}: begin
                            decode_instr_int.instr_type = MIN;
                        end
                        {F7_CLMUL_MIN_MAX, F3_MINU}: begin
                            decode_instr_int.instr_type = MINU;
                        end
                        {F7_CLMUL_MIN_MAX, F3_MAX}: begin
                            decode_instr_int.instr_type = MAX;
                        end
                        {F7_CLMUL_MIN_MAX, F3_MAXU}: begin
                            decode_instr_int.instr_type = MAXU;
                        end
                        {F7_BSET_ORCB, F3_BSET}: begin
                            decode_instr_int.instr_type = BSET;
                        end
                        {F7_BCLR_BEXT, F3_BCLR}: begin
                            decode_instr_int.instr_type = BCLR;
                        end
                        {F7_BCLR_BEXT, F3_BEXT}: begin
                            decode_instr_int.instr_type = BEXT;
                        end
                        {F7_BINV, F3_BINV}: begin
                            decode_instr_int.instr_type = BINV;
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
                        F3_64_SLLIW: begin // also F3_CLZW_CTZW_CPOPW
                            case (decode_i.inst.rtype.func7)
                                F7_64_NORMAL: begin
                                    decode_instr_int.instr_type = SLLW;
                                    xcpt_illegal_instruction_int = 1'b0;
                                end
                                {F7_64_ADDUW_ZEXTH_SLLIUW[6:1], 1'b0}, {F7_64_ADDUW_ZEXTH_SLLIUW[6:1], 1'b1}: begin
                                    decode_instr_int.instr_type = SLLIUW;
                                    xcpt_illegal_instruction_int = 1'b0;
                                end
                                F7_64_ROLW_RORW_CLZW_CTZW_CPOPW: begin
                                    case (decode_i.inst.rtype.rs2)
                                        RS2_CLZW: begin
                                            decode_instr_int.instr_type = CLZW;
                                        end
                                        RS2_CTZW: begin
                                            decode_instr_int.instr_type = CTZW;
                                        end
                                        RS2_CPOPW: begin
                                            decode_instr_int.instr_type = CPOPW;
                                        end
                                    endcase;
                                end
                                default: begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            endcase
                        end
                        F3_64_SRLIW_SRAIW: begin // It is also F3_RORIW
                            case (decode_i.inst.rtype.func7)
                                F7_64_SRAIW_SUBW_SRAW: begin
                                    decode_instr_int.instr_type = SRAW;
                                end
                                F7_64_NORMAL: begin
                                    decode_instr_int.instr_type = SRLW;
                                end
                                F7_64_ROLW_RORW_CLZW_CTZW_CPOPW: begin
                                    decode_instr_int.instr_type = RORW;
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
                        {F7_SRAI_SUB_SRA_NLOG,F3_64_ADDW_SUBW}: begin
                            decode_instr_int.instr_type = SUBW;
                        end
                        {F7_NORMAL,F3_64_SLLW}: begin
                            decode_instr_int.instr_type = SLLW;
                        end
                        {F7_NORMAL,F3_64_SRLW_SRAW}: begin
                            decode_instr_int.instr_type = SRLW;
                        end
                        {F7_SRAI_SUB_SRA_NLOG,F3_64_SRLW_SRAW}: begin
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
                        {F7_64_ADDUW_ZEXTH_SLLIUW, F3_ADDUW}: begin
                            decode_instr_int.instr_type = ADDUW;
                        end
                        {F7_64_SHADDUW, F3_SH1ADDUW}: begin
                            decode_instr_int.instr_type = SH1ADDUW;
                        end
                        {F7_64_SHADDUW, F3_SH2ADDUW}: begin
                            decode_instr_int.instr_type = SH2ADDUW;
                        end
                        {F7_64_SHADDUW, F3_SH3ADDUW}: begin
                            decode_instr_int.instr_type = SH3ADDUW;
                        end
                        {F7_64_ROLW_RORW_CLZW_CTZW_CPOPW, F3_ROLW}: begin
                            decode_instr_int.instr_type = ROLW;
                        end
                        {F7_64_ROLW_RORW_CLZW_CTZW_CPOPW, F3_RORW}: begin
                            decode_instr_int.instr_type = RORW;
                        end
                        {F7_64_ADDUW_ZEXTH_SLLIUW, F3_ZEXTH}: begin
                            if (decode_i.inst.rtype.rs2 == 0) begin
                                decode_instr_int.instr_type = ZEXTH;
                            end
                            else begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end
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
                        `ifndef DISABLE_SIMD
                        F3_V8B, F3_V16B, F3_V32B, F3_V64B: begin
                            decode_instr_int.use_mask = ~decode_i.inst.vltype.vm;
                            decode_instr_int.mem_size = {1'b0, decode_i.inst.vltype.width};
                            decode_instr_int.use_old_vd = ~vta_int;
                            if ((csr_vs_i == 2'b00) || (decode_i.inst.vltype.mew != 1'b0)) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                if (decode_i.inst.vltype.nf == 0) begin
                                    case (decode_i.inst.vltype.mop)
                                        MOP_UNIT_STRIDE: begin
                                            case (decode_i.inst.vltype.lumop)
                                                LUMOP_UNIT_STRIDE: begin
                                                    decode_instr_int.vregfile_we = ~vl_0;
                                                    decode_instr_int.instr_type = VLE;
                                                    xcpt_illegal_instruction_int = (vill || (vl > (VMAXELEM >> decode_i.inst.vltype.width[13:12])) || //LMUL > 1
                                                        ((decode_i.inst.vltype.width[13:12] > sew) && ((emul_mask & decode_instr_int.vs1) != 'h0))) ? 1'b1 : 1'b0;                                                 end
                                                LUMOP_UNIT_STRIDE_WREG: begin
                                                    decode_instr_int.vregfile_we = 1'b1;
                                                    decode_instr_int.instr_type = VL1R;
                                                    decode_instr_int.use_old_vd = 1'b0;
                                                end
                                                LUMOP_MASK: begin
                                                    decode_instr_int.vregfile_we = ~vl_0;
                                                    decode_instr_int.instr_type = VLM;
                                                    xcpt_illegal_instruction_int = vill;
                                                    decode_instr_int.use_old_vd = 1'b0;
                                                end
                                                LUMOP_FAULT_ONLY_FIRST: begin
                                                    decode_instr_int.vregfile_we = ~vl_0;
                                                    decode_instr_int.instr_type = VLEFF;
                                                    decode_instr_int.stall_csr_fence = ~vl_0;
                                                    xcpt_illegal_instruction_int = (vill || (vl > (VMAXELEM >> decode_i.inst.vltype.width[13:12])) || //LMUL > 1
                                                        ((decode_i.inst.vltype.width[13:12] > sew) && ((emul_mask & decode_instr_int.vs1) != 'h0))) ? 1'b1 : 1'b0;
                                                end
                                                default: begin
                                                    xcpt_illegal_instruction_int = 1'b1;
                                                end
                                            endcase
                                        end
                                        MOP_STRIDED: begin
                                            decode_instr_int.vregfile_we = ~vl_0;
                                            decode_instr_int.instr_type = VLSE;
                                            decode_instr_int.use_rs2 = 1'b1;
                                            xcpt_illegal_instruction_int = (vill || (vl > (VMAXELEM >> decode_i.inst.vltype.width[13:12])) || //LMUL > 1
                                                ((decode_i.inst.vltype.width[13:12] > sew) && ((emul_mask & decode_instr_int.vs1) != 'h0))) ? 1'b1 : 1'b0;
                                        end
                                        MOP_INDEXED_ORDERED, MOP_INDEXED_UNORDERED: begin
                                            decode_instr_int.vregfile_we = ~vl_0;
                                            decode_instr_int.instr_type = VLXE;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            xcpt_illegal_instruction_int = (vill || (vl > (VMAXELEM >> decode_i.inst.vltype.width[13:12])) || //LMUL > 1
                                                ((decode_i.inst.vltype.width[13:12] > sew) && ((emul_mask & decode_instr_int.vs1) != 'h0))) ? 1'b1 : 1'b0;
                                        end
                                        default: begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                    endcase
                                end else begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            end
                        end
                        `endif // `ifndef DISABLE_SIMD
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
                        `ifndef DISABLE_SIMD
                        F3_V8B, F3_V16B, F3_V32B, F3_V64B: begin
                            decode_instr_int.use_mask = ~decode_i.inst.vstype.vm;
                            decode_instr_int.mem_size = {1'b0, decode_i.inst.vstype.width};
                            decode_instr_int.use_old_vd = ~vta_int;
                            if ((csr_vs_i == 2'b00) || (decode_i.inst.vstype.mew != 1'b0)) begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end else begin
                                if (decode_i.inst.vstype.nf == 0) begin
                                    case (decode_i.inst.vstype.mop)
                                        MOP_UNIT_STRIDE: begin
                                            case (decode_i.inst.vstype.sumop)
                                                SUMOP_UNIT_STRIDE: begin
                                                    decode_instr_int.use_vs2 = 1'b1;
                                                    decode_instr_int.instr_type = VSE;
                                                    decode_instr_int.vs2 = decode_i.inst.vstype.vs3;
                                                    xcpt_illegal_instruction_int = (vill || (vl > (VMAXELEM >> decode_i.inst.vltype.width[13:12])) || //LMUL > 1
                                                        ((decode_i.inst.vltype.width[13:12] > sew) && ((emul_mask & decode_instr_int.vs1) != 'h0))) ? 1'b1 : 1'b0;
                                                end
                                                SUMOP_UNIT_STRIDE_WREG: begin
                                                    decode_instr_int.use_vs2 = 1'b1;
                                                    decode_instr_int.instr_type = VS1R;
                                                    decode_instr_int.vs2 = decode_i.inst.vstype.vs3;
                                                    decode_instr_int.use_old_vd = 1'b0;
                                                end
                                                SUMOP_MASK: begin
                                                    decode_instr_int.use_vs2 = 1'b1;
                                                    decode_instr_int.instr_type = VSM;
                                                    decode_instr_int.vs2 = decode_i.inst.vstype.vs3;
                                                    xcpt_illegal_instruction_int = vill;
                                                    decode_instr_int.use_old_vd = 1'b0;
                                                end
                                                default: begin
                                                    xcpt_illegal_instruction_int = 1'b1;
                                                end
                                            endcase
                                        end
                                        MOP_STRIDED: begin
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VSSE;
                                            decode_instr_int.vs2 = decode_i.inst.vstype.vs3;
                                            decode_instr_int.use_rs2 = 1'b1;
                                            xcpt_illegal_instruction_int = (vill || (vl > (VMAXELEM >> decode_i.inst.vltype.width[13:12])) || //LMUL > 1
                                                ((decode_i.inst.vltype.width[13:12] > sew) && ((emul_mask & decode_instr_int.vs1) != 'h0))) ? 1'b1 : 1'b0;
                                        end
                                        MOP_INDEXED_ORDERED, MOP_INDEXED_UNORDERED: begin
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VSXE;
                                            decode_instr_int.vs2 = decode_i.inst.vstype.vs3;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.vs1 = decode_i.inst.vstype.sumop;
                                            xcpt_illegal_instruction_int = (vill || (vl > (VMAXELEM >> decode_i.inst.vltype.width[13:12])) || //LMUL > 1
                                                ((decode_i.inst.vltype.width[13:12] > sew) && ((emul_mask & decode_instr_int.vs1) != 'h0))) ? 1'b1 : 1'b0;
                                        end
                                        default: begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                    endcase
                                end else begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            end
                        end
                        `endif // `ifndef DISABLE_SIMD
                        default: begin
                            xcpt_illegal_instruction_int = 1'b1;
                        end
                    endcase
                end
                `ifndef DISABLE_SIMD
                OP_V: begin
                    decode_instr_int.vregfile_we = ~vl_0;
                    decode_instr_int.unit = UNIT_SIMD;
                    decode_instr_int.use_mask = ~decode_i.inst.vtype.vm;
                    decode_instr_int.use_old_vd = ~vta_int;
                    if ((csr_vs_i == 2'b00) || ((vill == 1'b1) && (decode_i.inst.vtype.func3 != F3_OPCFG))) begin
                        xcpt_illegal_instruction_int = 1'b1;
                    end else begin
                        case (decode_i.inst.vtype.func3)
                            F3_OPIVV: begin
                                decode_instr_int.use_vs1     = 1'b1;
                                decode_instr_int.use_vs2     = 1'b1;
                                case (decode_i.inst.vtype.func6)
                                    F6_VADD: begin
                                        decode_instr_int.instr_type = VADD;
                                    end
                                    F6_VSUB: begin
                                        decode_instr_int.instr_type = VSUB;
                                    end
                                    F6_VADC: begin
                                        decode_instr_int.instr_type = VADC;
                                        if (decode_instr_int.use_mask == 0) begin
                                            //$warning("Espec: Encodings corresponding to the unmasked versions (vm=1) are reserved.");
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                    end
                                    F6_VSBC: begin
                                        decode_instr_int.instr_type = VSBC;
                                    end
                                    F6_VMADC: begin
                                        decode_instr_int.instr_type = VMADC;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSBC: begin
                                        decode_instr_int.instr_type = VMSBC;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end                                                                                   
                                    F6_VMIN: begin
                                        decode_instr_int.instr_type = VMIN;
                                    end
                                    F6_VMINU: begin
                                        decode_instr_int.instr_type = VMINU;
                                    end
                                    F6_VMAX: begin
                                        decode_instr_int.instr_type = VMAX;
                                    end
                                    F6_VMAXU: begin
                                        decode_instr_int.instr_type = VMAXU;
                                    end
                                    F6_VAND: begin
                                        decode_instr_int.instr_type = VAND;
                                    end
                                    F6_VOR: begin
                                        decode_instr_int.instr_type = VOR;
                                    end
                                    F6_VXOR: begin
                                        decode_instr_int.instr_type = VXOR;
                                    end
                                    F6_VMSEQ: begin
                                        decode_instr_int.instr_type = VMSEQ;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSNE: begin
                                        decode_instr_int.instr_type = VMSNE;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLTU: begin
                                        decode_instr_int.instr_type = VMSLTU;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLT: begin
                                        decode_instr_int.instr_type = VMSLT;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLEU: begin
                                        decode_instr_int.instr_type = VMSLEU;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLE: begin
                                        decode_instr_int.instr_type = VMSLE;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VSADDU: begin
                                        decode_instr_int.instr_type = VSADDU;
                                    end
                                    F6_VSADD: begin
                                        decode_instr_int.instr_type = VSADD;
                                    end
                                    F6_VSSUBU: begin
                                        decode_instr_int.instr_type = VSSUBU;
                                    end
                                    F6_VSSUB: begin
                                        decode_instr_int.instr_type = VSSUB;
                                    end
                                    F6_VSLL: begin
                                        decode_instr_int.instr_type = VSLL;
                                    end
                                    F6_VSRL: begin
                                        decode_instr_int.instr_type = VSRL;
                                    end
                                    F6_VSRA: begin
                                        decode_instr_int.instr_type = VSRA;
                                    end
                                    F6_VSSRL: begin
                                        decode_instr_int.instr_type = VSSRL;
                                    end
                                    F6_VSSRA: begin
                                        decode_instr_int.instr_type = VSSRA;
                                    end
                                    F6_VNCLIPU: begin
                                        if (!v_2sew_en_int) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNCLIPU;
                                        end
                                    end
                                    F6_VNCLIP: begin
                                        if (!v_2sew_en_int) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNCLIP;
                                        end
                                    end                                    
                                    F6_VNSRL: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vs2[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNSRL;
                                        end
                                    end
                                    F6_VNSRA: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vs2[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNSRA;
                                        end
                                    end
                                    F6_VMERGE_VMV: begin
                                        decode_instr_int.use_vs2 = (~decode_i.inst.vtype.vm) ? 1'b1 : 1'b0;
                                        decode_instr_int.instr_type = (~decode_i.inst.vtype.vm) ? VMERGE : VMV;
                                    end
                                    F6_VRGATHER: begin
                                        decode_instr_int.instr_type = VRGATHER;
                                    end
                                    F6_VSLIDEUP: begin
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VRGATHEREI16;
                                        if((vl > 'h08) || ((sew == SEW_8) && (decode_instr_int.vs1[0]))) begin // vs1 can not be odd with SEW8 due to EMUL>1
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                        else begin
                                            xcpt_illegal_instruction_int = 1'b0;
                                        end
                                    end
                                    F6_VMV1R_VSMUL: begin
                                        decode_instr_int.instr_type = VSMUL;
                                    end
                                    default: begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                            F3_OPIVX: begin
                                decode_instr_int.is_opvx     = 1'b1;
                                decode_instr_int.use_rs1     = 1'b1;
                                decode_instr_int.use_vs2     = 1'b1;
                                case (decode_i.inst.vtype.func6)
                                    F6_VADD: begin
                                        decode_instr_int.instr_type = VADD;
                                    end
                                    F6_VSUB: begin
                                        decode_instr_int.instr_type = VSUB;
                                    end
                                    F6_VRSUB: begin
                                        decode_instr_int.instr_type = VRSUB;
                                    end
                                    F6_VADC: begin
                                        decode_instr_int.instr_type = VADC;
                                        if (decode_instr_int.use_mask == 0) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                    end
                                    F6_VSBC: begin
                                        decode_instr_int.instr_type = VSBC;
                                    end
                                    F6_VMADC: begin
                                        decode_instr_int.instr_type = VMADC;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSBC: begin
                                        decode_instr_int.instr_type = VMSBC;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end                                                                                                                
                                    F6_VMIN: begin
                                        decode_instr_int.instr_type = VMIN;
                                    end
                                    F6_VMINU: begin
                                        decode_instr_int.instr_type = VMINU;
                                    end
                                    F6_VMAX: begin
                                        decode_instr_int.instr_type = VMAX;
                                    end
                                    F6_VMAXU: begin
                                        decode_instr_int.instr_type = VMAXU;
                                    end
                                    F6_VAND: begin
                                        decode_instr_int.instr_type = VAND;
                                    end
                                    F6_VOR: begin
                                        decode_instr_int.instr_type = VOR;
                                    end
                                    F6_VXOR: begin
                                        decode_instr_int.instr_type = VXOR;
                                    end
                                    F6_VMSEQ: begin
                                        decode_instr_int.instr_type = VMSEQ;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSNE: begin
                                        decode_instr_int.instr_type = VMSNE;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLTU: begin
                                        decode_instr_int.instr_type = VMSLTU;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLT: begin
                                        decode_instr_int.instr_type = VMSLT;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLEU: begin
                                        decode_instr_int.instr_type = VMSLEU;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLE: begin
                                        decode_instr_int.instr_type = VMSLE;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSGTU: begin
                                        decode_instr_int.instr_type = VMSGTU;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSGT: begin
                                        decode_instr_int.instr_type = VMSGT;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VSADDU: begin
                                        decode_instr_int.instr_type = VSADDU;
                                    end
                                    F6_VSADD: begin
                                        decode_instr_int.instr_type = VSADD;
                                    end
                                    F6_VSSUBU: begin
                                        decode_instr_int.instr_type = VSSUBU;
                                    end
                                    F6_VSSUB: begin
                                        decode_instr_int.instr_type = VSSUB;
                                    end
                                    F6_VSLL: begin
                                        decode_instr_int.instr_type = VSLL;
                                    end
                                    F6_VSRL: begin
                                        decode_instr_int.instr_type = VSRL;
                                    end
                                    F6_VSRA: begin
                                        decode_instr_int.instr_type = VSRA;
                                    end
                                    F6_VSSRL: begin
                                        decode_instr_int.instr_type = VSSRL;
                                    end
                                    F6_VSSRA: begin
                                        decode_instr_int.instr_type = VSSRA;
                                    end
                                    F6_VNCLIPU: begin
                                        if (!v_2sew_en_int) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNCLIPU;
                                        end
                                    end
                                    F6_VNCLIP: begin
                                        if (!v_2sew_en_int) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNCLIP;
                                        end
                                    end                                    
                                    F6_VNSRL: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vs2[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNSRL;
                                        end
                                    end
                                    F6_VNSRA: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vs2[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNSRA;
                                        end
                                    end
                                    F6_VMERGE_VMV: begin
                                        decode_instr_int.use_vs1 = 1'b0;
                                        decode_instr_int.use_vs2 = (~decode_i.inst.vtype.vm) ? 1'b1 : 1'b0;
                                        decode_instr_int.instr_type = (~decode_i.inst.vtype.vm) ? VMERGE : VMV;
                                    end
                                    F6_VSLIDEUP: begin
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VSLIDEUP;
                                    end
                                    F6_VSLIDEDOWN: begin
                                        decode_instr_int.instr_type = VSLIDEDOWN;
                                    end
                                    F6_VRGATHER: begin
                                        decode_instr_int.instr_type = VRGATHER;
                                    end
                                    F6_VMV1R_VSMUL: begin
                                        decode_instr_int.instr_type = VSMUL;
                                    end
                                    default: begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                            F3_OPIVI: begin
                                decode_instr_int.is_opvi     = 1'b1;
                                decode_instr_int.use_imm     = 1'b1;
                                decode_instr_int.use_vs2     = 1'b1;
                                case (decode_i.inst.vtype.func6)
                                    F6_VADD: begin
                                        decode_instr_int.instr_type = VADD;
                                    end
                                    F6_VRSUB: begin
                                        decode_instr_int.instr_type = VRSUB;
                                    end
                                    F6_VADC: begin
                                        decode_instr_int.instr_type = VADC;
                                        if (decode_instr_int.use_mask == 0) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                    end
                                    F6_VMADC: begin
                                        decode_instr_int.instr_type = VMADC;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end                                        
                                    F6_VAND: begin
                                        decode_instr_int.instr_type = VAND;
                                    end
                                    F6_VOR: begin
                                        decode_instr_int.instr_type = VOR;
                                    end
                                    F6_VXOR: begin
                                        decode_instr_int.instr_type = VXOR;
                                    end
                                    F6_VMSEQ: begin
                                        decode_instr_int.instr_type = VMSEQ;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSNE: begin
                                        decode_instr_int.instr_type = VMSNE;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLEU: begin
                                        decode_instr_int.instr_type = VMSLEU;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSLE: begin
                                        decode_instr_int.instr_type = VMSLE;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSGTU: begin
                                        decode_instr_int.instr_type = VMSGTU;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VMSGT: begin
                                        decode_instr_int.instr_type = VMSGT;
                                        decode_instr_int.use_old_vd = 1'b0;
                                    end
                                    F6_VSADDU: begin
                                        decode_instr_int.instr_type = VSADDU;
                                    end
                                    F6_VSADD: begin
                                        decode_instr_int.instr_type = VSADD;
                                    end
                                    F6_VSLL: begin
                                        decode_instr_int.instr_type = VSLL;
                                    end
                                    F6_VSRL: begin
                                        decode_instr_int.instr_type = VSRL;
                                    end
                                    F6_VSRA: begin
                                        decode_instr_int.instr_type = VSRA;
                                    end
                                    F6_VSSRL: begin
                                        decode_instr_int.instr_type = VSSRL;
                                    end
                                    F6_VSSRA: begin
                                        decode_instr_int.instr_type = VSSRA;
                                    end
                                    F6_VNCLIPU: begin
                                       if (!v_2sew_en_int) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            if (decode_instr_int.imm > ((2**5)-1)) begin
                                                xcpt_illegal_instruction_int = 1'b1;
                                            end else begin
                                                decode_instr_int.instr_type = VNCLIPU;
                                            end
                                        end
                                    end
                                    F6_VNCLIP: begin
                                        if (!v_2sew_en_int) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            if (decode_instr_int.imm > ((2**5)-1)) begin
                                                xcpt_illegal_instruction_int = 1'b1;
                                            end else begin
                                                decode_instr_int.instr_type = VNCLIP;
                                            end
                                        end
                                    end                                    
                                    F6_VNSRL: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vs2[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNSRL;
                                        end
                                    end
                                    F6_VNSRA: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vs2[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.instr_type = VNSRA;
                                        end
                                    end
                                    F6_VMERGE_VMV: begin
                                        decode_instr_int.use_vs1 = 1'b0;
                                        decode_instr_int.use_vs2 = (~decode_i.inst.vtype.vm) ? 1'b1 : 1'b0;
                                        decode_instr_int.instr_type = (~decode_i.inst.vtype.vm) ? VMERGE : VMV;
                                    end
                                    F6_VMV1R_VSMUL: begin
                                        if (imm_value != 'b0) begin // Do not allow VMV<nr>R with nr>1
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.vregfile_we = 1'b1; // Write result even if vl=0
                                            decode_instr_int.use_vs1 = 1'b0;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VMV1R;
                                        end
                                    end
                                    F6_VSLIDEUP: begin
                                        decode_instr_int.use_vs1 = 1'b0;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VSLIDEUP;
                                    end
                                    F6_VSLIDEDOWN: begin
                                        decode_instr_int.instr_type = VSLIDEDOWN;
                                    end
                                    F6_VRGATHER: begin
                                        decode_instr_int.instr_type = VRGATHER;
                                    end
                                    default: begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                            F3_OPMVV: begin
                                case (decode_i.inst.vtype.func6)
                                    F6_VREDSUM: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREDSUM;
                                    end
                                    F6_VREDAND: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREDAND;
                                    end
                                    F6_VREDOR: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREDOR;
                                    end
                                    F6_VREDXOR: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREDXOR;
                                    end
                                    F6_VREDMINU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREDMINU;
                                    end
                                    F6_VREDMIN: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREDMIN;
                                    end
                                    F6_VREDMAXU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREDMAXU;
                                    end
                                    F6_VREDMAX: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREDMAX;
                                    end
                                    F6_VMAND: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b0;
                                        decode_instr_int.instr_type = VMAND;
                                    end
                                    F6_VMNAND: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b0;
                                        decode_instr_int.instr_type = VMNAND;
                                    end
                                    F6_VMANDNOT: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b0;
                                        decode_instr_int.instr_type = VMANDN;
                                    end
                                    F6_VMNOR: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b0;
                                        decode_instr_int.instr_type = VMNOR;
                                    end                                                                            
                                    F6_VMORNOT: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b0;
                                        decode_instr_int.instr_type = VMORN;
                                    end  
                                    F6_VMOR: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b0;
                                        decode_instr_int.instr_type = VMOR;
                                    end
                                    F6_VMXOR: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b0;
                                        decode_instr_int.instr_type = VMXOR;
                                    end
                                    F6_VMXNOR: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b0;
                                        decode_instr_int.instr_type = VMXNOR;
                                    end
                                    F6_VWADDU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWADDU;
                                        end 
                                    end
                                    F6_VWADD: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWADD;
                                        end
                                    end
                                    F6_VWSUBU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWSUBU;
                                        end
                                    end
                                    F6_VWSUB: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWSUB;
                                        end
                                    end
                                    F6_VWADDUW: begin
                                        if ((!v_2sew_en_int) || ((decode_instr_int.vd[0] | decode_instr_int.vs2[0]) && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWADDUW;
                                        end
                                    end
                                    F6_VWADDW: begin
                                        if ((!v_2sew_en_int) || ((decode_instr_int.vd[0] | decode_instr_int.vs2[0]) && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWADDW;
                                        end
                                    end
                                    F6_VWSUBUW: begin
                                        if ((!v_2sew_en_int) || ((decode_instr_int.vd[0] | decode_instr_int.vs2[0]) && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWSUBUW;
                                        end
                                    end
                                    F6_VWSUBW: begin
                                        if ((!v_2sew_en_int) || ((decode_instr_int.vd[0] | decode_instr_int.vs2[0]) && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWSUBW;
                                        end
                                    end
                                    F6_VCNT: begin
                                        decode_instr_int.vregfile_we = 1'b0;
                                        decode_instr_int.regfile_we = 1'b1;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VCNT;
                                    end
                                    F6_VMUNARY0: begin
                                        if (decode_i.inst.vtype.vs1 == VS1_VID) begin
                                            decode_instr_int.instr_type = VID;
                                        end else if (decode_i.inst.vtype.vs1 == VS1_VIOTA) begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs2 = 1'b1; 
                                            decode_instr_int.instr_type = VIOTA;
                                        end else if (decode_i.inst.vtype.vs1 == VS1_VMSBF) begin
                                            decode_instr_int.instr_type = VMSBF;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.use_vs1 = 1'b0;
                                            decode_instr_int.use_old_vd = 1'b0;
                                        end else if (decode_i.inst.vtype.vs1 == VS1_VMSIF) begin
                                            decode_instr_int.instr_type = VMSIF;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.use_vs1 = 1'b0;
                                            decode_instr_int.use_old_vd = 1'b0;
                                        end else if (decode_i.inst.vtype.vs1 == VS1_VMSOF) begin
                                            decode_instr_int.instr_type = VMSOF;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.use_vs1 = 1'b0;
                                            decode_instr_int.use_old_vd = 1'b0;
                                        end else begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                    end
                                    F6_VRWXUNARY0: begin
                                        if (decode_i.inst.vtype.vs1 == VS1_VMV_X_S) begin
                                            decode_instr_int.vregfile_we = 1'b0;
                                            decode_instr_int.regfile_we = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VMV_X_S;
                                        end else if (decode_i.inst.vtype.vs1 == VS1_VPOPC) begin
                                            decode_instr_int.vregfile_we = 1'b0;
                                            decode_instr_int.regfile_we = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VPOPC;
                                        end else if (decode_i.inst.vtype.vs1 == VS1_VFIRST) begin
                                            decode_instr_int.vregfile_we = 1'b0;
                                            decode_instr_int.regfile_we  = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.use_vs1 = 1'b0;
                                            decode_instr_int.instr_type = VFIRST;
                                        end else begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                    end
                                    F6_VXUNARY0: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        if (decode_i.inst.vtype.vs1 == VS1_ZEXT_VF8) begin
                                            if (sew != SEW_64) begin
                                                xcpt_illegal_instruction_int = 1'b1;
                                            end else begin
                                                decode_instr_int.instr_type = VZEXT_VF8;
                                            end
                                        end else if (decode_i.inst.vtype.vs1 == VS1_SEXT_VF8) begin
                                            if (sew != SEW_64) begin
                                                xcpt_illegal_instruction_int = 1'b1;
                                            end else begin
                                                decode_instr_int.instr_type = VSEXT_VF8;
                                            end
                                        end else if (decode_i.inst.vtype.vs1 == VS1_ZEXT_VF4) begin
                                            if ((sew == SEW_16) || (sew == SEW_8)) begin
                                                xcpt_illegal_instruction_int = 1'b1;
                                            end else begin
                                                decode_instr_int.instr_type = VZEXT_VF4;
                                            end
                                        end else if (decode_i.inst.vtype.vs1 == VS1_SEXT_VF4) begin
                                            if ((sew == SEW_16) || (sew == SEW_8)) begin
                                                xcpt_illegal_instruction_int = 1'b1;
                                            end else begin
                                                decode_instr_int.instr_type = VSEXT_VF4;   
                                            end
                                        end else if (decode_i.inst.vtype.vs1 == VS1_ZEXT_VF2) begin
                                            if (sew == SEW_8) begin
                                                xcpt_illegal_instruction_int = 1'b1;
                                            end else begin
                                                decode_instr_int.instr_type = VZEXT_VF2;
                                            end
                                        end else if (decode_i.inst.vtype.vs1 == VS1_SEXT_VF2) begin
                                            if (sew == SEW_8) begin
                                                xcpt_illegal_instruction_int = 1'b1;
                                            end else begin
                                                decode_instr_int.instr_type = VSEXT_VF2;     
                                            end
                                        end else begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end
                                    end                                    
                                    F6_VMULHU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VMULHU;
                                    end
                                    F6_VMUL: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VMUL;
                                    end
                                    F6_VMULHSU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VMULHSU;
                                    end
                                    F6_VMULH: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VMULH;
                                    end
                                    F6_VMADD: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VMADD;
                                    end
                                    F6_VNMSUB: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VNMSUB;
                                    end
                                    F6_VMACC: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VMACC;
                                    end
                                    F6_VNMSAC: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VNMSAC;
                                    end
                                    F6_VWMACC: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.use_old_vd = 1'b1;
                                            decode_instr_int.instr_type = VWMACC;                                        
                                        end                                    
                                    end
                                    F6_VWMACCU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                           decode_instr_int.use_old_vd = 1'b1;
                                            decode_instr_int.instr_type = VWMACCU;                                        
                                        end                                    
                                    end
                                    F6_VWMACCSU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.use_old_vd = 1'b1;
                                            decode_instr_int.instr_type = VWMACCSU;                                        
                                        end
                                    end                                    
                                    F6_VWMULU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWMULU;
                                        end
                                    end
                                    F6_VWMULSU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWMULSU;
                                        end
                                    end
                                    F6_VWMUL: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_vs1 = 1'b1;
                                            decode_instr_int.use_vs2 = 1'b1;
                                            decode_instr_int.instr_type = VWMUL;
                                        end
                                    end
                                    F6_VCOMPRESS: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VCOMPRESS;
                                    end
                                    F6_VAADDU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VAADDU;
                                    end
                                    F6_VAADD: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VAADD;
                                    end
                                    F6_VASUBU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VASUBU;
                                    end
                                    F6_VASUB: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VASUB;
                                    end
                                    F6_VDIVU: begin
                                        decode_instr_int.vregfile_we = 1'b1;
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VDIVU;
                                    end
                                    F6_VDIV: begin
                                        decode_instr_int.vregfile_we = 1'b1;
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VDIV;
                                    end
                                    F6_VREMU: begin
                                        decode_instr_int.vregfile_we = 1'b1;
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREMU;
                                    end
                                    F6_VREM: begin
                                        decode_instr_int.vregfile_we = 1'b1;
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs1 = 1'b1;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VREM;
                                    end


                                    default: begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                            F3_OPMVX: begin
                                decode_instr_int.is_opvx = 1'b1;
                                decode_instr_int.use_vs1 = 1'b0;
                                decode_instr_int.use_vs2 = 1'b1;
                                decode_instr_int.use_rs1 = 1'b1;
                                case (decode_i.inst.vtype.func6)
                                    F6_VMULHU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VMULHU;
                                    end
                                    F6_VMUL: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VMUL;
                                    end
                                    F6_VMULHSU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VMULHSU;
                                    end
                                    F6_VMULH: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VMULH;
                                    end
                                    F6_VDIVU: begin
                                        decode_instr_int.vregfile_we = 1'b1;
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VDIVU;
                                    end
                                    F6_VDIV: begin
                                        decode_instr_int.vregfile_we = 1'b1;
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VDIV;
                                    end
                                    F6_VREMU: begin
                                        decode_instr_int.vregfile_we = 1'b1;
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VREMU;
                                    end
                                    F6_VREM: begin
                                        decode_instr_int.vregfile_we = 1'b1;
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VREM;
                                    end
                                    F6_VMADD: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VMADD;
                                    end
                                    F6_VNMSUB: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VNMSUB;
                                    end
                                    F6_VMACC: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VMACC;                                        
                                    end                                    
                                    F6_VNMSAC: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_old_vd = 1'b1;
                                        decode_instr_int.instr_type = VNMSAC;
                                    end
                                    F6_VWMACC: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_old_vd = 1'b1;
                                            decode_instr_int.instr_type = VWMACC;                                        
                                        end                                    
                                    end
                                    F6_VWMACCU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_old_vd = 1'b1;
                                            decode_instr_int.instr_type = VWMACCU;                                        
                                        end                                    
                                    end
                                    F6_VWMACCSU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_old_vd = 1'b1;
                                            decode_instr_int.instr_type = VWMACCSU;                                        
                                        end
                                    end                                    
                                    F6_VWMACCUS: begin
                                         if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.use_old_vd = 1'b1;
                                            decode_instr_int.instr_type = VWMACCUS;                                        
                                        end                                    
                                    end
                                    F6_VWMULU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWMULU;
                                        end
                                    end
                                    F6_VWMULSU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWMULSU;
                                        end
                                    end
                                    F6_VWMUL: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWMUL;
                                        end
                                    end
                                    F6_VWADDU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWADDU;
                                        end
                                    end
                                    F6_VWADD: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWADD;
                                        end
                                    end
                                    F6_VWSUBU: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWSUBU;
                                        end
                                    end
                                    F6_VWSUB: begin
                                        if ((!v_2sew_en_int) || (decode_instr_int.vd[0] && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWSUB;
                                        end
                                    end
                                    F6_VWADDUW: begin
                                        if ((!v_2sew_en_int) || ((decode_instr_int.vd[0] | decode_instr_int.vs2[0]) && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWADDUW;
                                        end
                                    end
                                    F6_VWADDW: begin
                                        if ((!v_2sew_en_int) || ((decode_instr_int.vd[0] | decode_instr_int.vs2[0]) && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWADDW;
                                        end
                                    end
                                    F6_VWSUBUW: begin
                                        if ((!v_2sew_en_int) || ((decode_instr_int.vd[0] | decode_instr_int.vs2[0]) && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWSUBUW;
                                        end
                                    end
                                    F6_VWSUBW: begin
                                        if ((!v_2sew_en_int) || ((decode_instr_int.vd[0] | decode_instr_int.vs2[0]) && (~vlmul_int[2]))) begin
                                            xcpt_illegal_instruction_int = 1'b1;
                                        end else begin
                                            decode_instr_int.regfile_we = 1'b0;
                                            decode_instr_int.instr_type = VWSUBW;
                                        end
                                    end
                                    F6_VRWXUNARY0: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VMV_S_X;
                                    end
                                    F6_VSLIDE1UP: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        // decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VSLIDE1UP;
                                    end
                                    F6_VSLIDE1DOWN: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        // decode_instr_int.use_vs2 = 1'b1;
                                        decode_instr_int.instr_type = VSLIDE1DOWN;
                                    end
                                    F6_VAADDU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VAADDU;
                                    end
                                    F6_VAADD: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VAADD;
                                    end
                                    F6_VASUBU: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VASUBU;
                                    end
                                    F6_VASUB: begin
                                        decode_instr_int.regfile_we = 1'b0;
                                        decode_instr_int.instr_type = VASUB;
                                    end
                                    default: begin
                                        xcpt_illegal_instruction_int = 1'b1;
                                    end
                                endcase
                            end
                            F3_OPCFG: begin
                                decode_instr_int.regfile_we = 1'b1;
                                decode_instr_int.vregfile_we = 1'b0;
                                decode_instr_int.unit = UNIT_SYSTEM;
                                decode_instr_int.use_mask = 1'b0;
                                decode_instr_int.use_rs1 = 1'b1;
                                decode_instr_int.use_old_vd = 1'b0;
                                if (decode_i.inst[31] && (decode_i.inst[30:25] == 6'd0)) begin
                                    decode_instr_int.instr_type = VSETVL;
                                    decode_instr_int.use_rs2 = 1'b1;
                                    decode_instr_int.stall_vset_fence = 1'b1;
                                end else if (!decode_i.inst[31]) begin
                                    decode_instr_int.instr_type = VSETVLI;
                                    decode_instr_int.use_imm = 1'b1;
                                    if((decode_instr_int.rs1 == 'h0) && (decode_instr_int.rd == 'h0)) begin
                                        decode_instr_int.stall_vset_fence = 1'b0;
                                    end else begin
                                        decode_instr_int.stall_vset_fence = 1'b1;
                                    end
                                end else if (decode_i.inst[31] && decode_i.inst[30]) begin
                                    decode_instr_int.instr_type = VSETIVLI;
                                    decode_instr_int.vl = vl_short;
                                    decode_instr_int.use_imm = 1'b1;
                                end else begin
                                    xcpt_illegal_instruction_int = 1'b1;
                                end
                            end
                            default: begin
                                xcpt_illegal_instruction_int = 1'b1;
                            end
                        endcase
                    end
                end
                `endif // `ifndef DISABLE_SIMD
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
                            if (debug_mode_en_i) begin
                                if((decode_i.inst.rtype.func7 == F7_ECALL_EBREAK_URET) &&
                                   (decode_i.inst.rtype.rs2 == RS2_EBREAK_SFENCEVM)) begin
                                    // stops the probram buffer execution
                                    decode_instr_int.instr_type = EBREAK;
                                end else begin
                                    decode_instr_int.use_imm = 1'b0;
                                    decode_instr_int.unit = UNIT_ALU;
                                    decode_instr_int.stall_csr_fence = 1'b0;
                                end
                            end else begin
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
                                                        // TODO (guillemlp): check and delete this option 
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
                                    decode_instr_int.frm = op_frm_fp_t'(decode_i.inst.fprtype.rm);
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
                                // TODO (guillemlp) not sure if the following is required
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
                                    decode_instr_int.frm = op_frm_fp_t'(decode_i.inst.fprtype.rm);
                                end
                            endcase
                        end
                    end
                end
                default: begin
                    // By default this is not a valid instruction
                    xcpt_illegal_instruction_int = 1'b1;
                end
            endcase
        end
    end
    
    assign is_vset_instr = (((decode_instr_int.instr_type == VSETIVLI) ||
                             (decode_instr_int.instr_type == VSETVL) ||
                             (decode_instr_int.instr_type == VSETVLI)
                            ) &&
                              decode_instr_int.valid) ? 1'b1 : 1'b0;

    //AVL
    assign rw_cmd_int = (((decode_instr_int.instr_type == VSETVL) || (decode_instr_int.instr_type == VSETVLI)
                       ) && (decode_instr_int.rs1 == 'h0)) ? CSR_CMD_VSETVLMAX : CSR_CMD_VSETVL;

    assign avl_value_int = (decode_instr_int.instr_type == VSETIVLI) ? {32'b0, decode_instr_int.imm[63:32]} : vset_rs1_i;

    assign avl_value_if_zero_int = (((decode_instr_int.instr_type == VSETVL) || (decode_instr_int.instr_type == VSETVLI)) &&
                                    ((decode_instr_int.rs1 == 'h0) && (decode_instr_int.rd == 'h0))
                                   ) ? 64'b1 : avl_value_int;                        

    //vtype
    assign vtype_int = ((decode_instr_int.instr_type == VSETIVLI) || (decode_instr_int.instr_type == VSETVLI)) ?
                            decode_instr_int.imm[CSR_ADDR_SIZE-1:0] : {{(CSR_ADDR_SIZE-9){1'b0}}, (|vset_rs2_i[63:8]), vset_rs2_i[7:0]};

    assign is_cycle_vset = ((decode_instr_int.instr_type == VSETIVLI) || 
                            ((decode_instr_int.instr_type == VSETVLI) &&
                             (decode_instr_int.rs1 == 'h0) && (decode_instr_int.rd == 'h0)
                            )) ? 1'b1 : 1'b0;
    assign write_vset_int = (is_cycle_vset && ~stall_i) || write_vset_i;                             

    vset_module vset_module_inst(
        .rstn_i(rstn_i),
        .clk_i(clk_i),

        .vtype_i(vtype_int),
        .is_vset_i(is_vset_instr),
        .rw_cmd_i(rw_cmd_int),
        .avl_value_i(avl_value_if_zero_int),
        .write_vset_i(write_vset_int),
        .vset_commited_i(commit_vset_i),
        .recover_commit_exception_i(recover_commit_exception_i),
        .recover_last_misspredict_i(recover_last_misspredict_i),
        .vset_index_misspredict_i(vset_index_misspredict_i),
        
        .vl_o(vl),
        .vl_short_o(vl_short),
        .sew_o(sew),
        .vill_o(vill),
        .vnarrow_wide_o(v_2sew_en_int),
        .vta_o(vta_int),
        .vma_o(vma_int),
        .vlmul_o(vlmul_int),
        .vlmax_o(vlmax_int),
        .prev_vtype_o(prev_vtype_o),
        .vset_index_o(vset_index_int),
        .full_vset_queue_o(full_vset_queue_o)
    );

    assign vl_short_o =  vl_short;
    assign vl_0 = (vl == 'h0) ? 1'b1 : 1'b0;
    

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
