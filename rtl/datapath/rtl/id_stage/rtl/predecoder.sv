module predecoder
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input   if_id_stage_t fetched_i,
    output  if_id_stage_t predecoded_o,
    output  logic         is_compressed_o
);

    instruction_t predecoded_inst;

    instruction_crtype_t instr_crtype;
    assign instr_crtype = fetched_i.inst;

    instruction_citype_t instr_citype;
    assign instr_citype = fetched_i.inst;

    instruction_csstype_t instr_csstype;
    assign instr_csstype = fetched_i.inst;

    instruction_ciwtype_t instr_ciwtype;
    assign instr_ciwtype = fetched_i.inst;

    instruction_cltype_t instr_cltype;
    assign instr_cltype = fetched_i.inst;

    instruction_cstype_t instr_cstype;
    assign instr_cstype = fetched_i.inst;

    instruction_catype_t instr_catype;
    assign instr_catype = fetched_i.inst;

    instruction_cbtype_t instr_cbtype;
    assign instr_cbtype = fetched_i.inst;

    instruction_cjtype_t instr_cjtype;
    assign instr_cjtype = fetched_i.inst;

    assign is_compressed_o = fetched_i.inst[1:0] != 2'b11;

    always_comb begin
        case (fetched_i.inst.bits[1:0])
            C0: begin
                case (instr_citype.func3)
                    F3_CADDI4SPN: begin
                        if (instr_ciwtype.imm12 == 8'b0) begin
                            // Applies both illegal instruction and reserved
                            // encoding with imm == 0
                            predecoded_inst = fetched_i.inst;
                        end else begin
                            predecoded_inst.itype.opcode = OP_ALU_I;
                            predecoded_inst.itype.rd = {2'b01, instr_ciwtype.rd};
                            predecoded_inst.itype.func3 = F3_ADDI;
                            predecoded_inst.itype.rs1 = 5'b00010;
                            predecoded_inst.itype.imm = {2'b00, instr_ciwtype.imm12[10:7], instr_ciwtype.imm12[12:11], instr_ciwtype.imm12[5], instr_ciwtype.imm12[6], 2'b00};
                        end
                    end
                    F3_CFLD: begin
                        predecoded_inst.itype.opcode = OP_LOAD_FP;
                        predecoded_inst.itype.rd = {2'b01, instr_cltype.rd};
                        predecoded_inst.itype.func3 = F3_LD;
                        predecoded_inst.itype.rs1 = {2'b1, instr_cltype.rs1};
                        predecoded_inst.itype.imm = {4'b0000, instr_cltype.imm6, instr_cltype.imm12, 3'b000};
                    end
                    F3_CLW: begin
                        predecoded_inst.itype.opcode = OP_LOAD;
                        predecoded_inst.itype.rd = {2'b01, instr_cltype.rd};
                        predecoded_inst.itype.func3 = F3_LW;
                        predecoded_inst.itype.rs1 = {2'b1, instr_cltype.rs1};
                        predecoded_inst.itype.imm = {5'b00000, instr_cltype.imm6[5], instr_cltype.imm12, instr_cltype.imm6[6], 2'b00};
                    end
                    F3_CLD: begin
                        predecoded_inst.itype.opcode = OP_LOAD;
                        predecoded_inst.itype.rd = {2'b01, instr_cltype.rd};
                        predecoded_inst.itype.func3 = F3_LD;
                        predecoded_inst.itype.rs1 = {2'b1, instr_cltype.rs1};
                        predecoded_inst.itype.imm = {4'b0000, instr_cltype.imm6, instr_cltype.imm12, 3'b000};
                    end
                    F3_ZCB_MEM: begin
                        case (instr_cltype.imm12)
                            F12_LBU: begin
                                predecoded_inst.itype.opcode = OP_LOAD;
                                predecoded_inst.itype.rd = {2'b01, instr_cltype.rd};
                                predecoded_inst.itype.func3 = F3_LBU;
                                predecoded_inst.itype.rs1 = {2'b1, instr_cltype.rs1};
                                predecoded_inst.itype.imm = {10'b0, instr_cltype.imm6[5], instr_cltype.imm6[6]};
                            end
                            F12_LH: begin
                                case (instr_cltype.imm6[6])
                                    1'b0: begin
                                        predecoded_inst.itype.opcode = OP_LOAD;
                                        predecoded_inst.itype.rd = {2'b01, instr_cltype.rd};
                                        predecoded_inst.itype.func3 = F3_LHU;
                                        predecoded_inst.itype.rs1 = {2'b1, instr_cltype.rs1};
                                        predecoded_inst.itype.imm = {10'b0, instr_cltype.imm6[5], 1'b0};
                                    end
                                    1'b1: begin
                                        predecoded_inst.itype.opcode = OP_LOAD;
                                        predecoded_inst.itype.rd = {2'b01, instr_cltype.rd};
                                        predecoded_inst.itype.func3 = F3_LH;
                                        predecoded_inst.itype.rs1 = {2'b1, instr_cltype.rs1};
                                        predecoded_inst.itype.imm = {10'b0, instr_cltype.imm6[5], 1'b0};
                                    end
                                endcase
                            end
                            F12_SB: begin
                                predecoded_inst.stype.opcode = OP_STORE;
                                predecoded_inst.stype.func3 = F3_SB;
                                predecoded_inst.stype.rs1 = {2'b01, instr_cstype.rs1};
                                predecoded_inst.stype.rs2 = {2'b01, instr_cstype.rs2};
                                predecoded_inst.stype.imm0 = {3'b000, instr_cstype.imm6[5], instr_cstype.imm6[6]};
                                predecoded_inst.stype.imm5 = {7'b0};
                            end
                            F12_SH: begin
                                case (instr_cltype.imm6[6])
                                    1'b0: begin
                                        predecoded_inst.stype.opcode = OP_STORE;
                                        predecoded_inst.stype.func3 = F3_SH;
                                        predecoded_inst.stype.rs1 = {2'b01, instr_cstype.rs1};
                                        predecoded_inst.stype.rs2 = {2'b01, instr_cstype.rs2};
                                        predecoded_inst.stype.imm0 = {3'b000, instr_cstype.imm6[5], 1'b0};
                                        predecoded_inst.stype.imm5 = {7'b0};
                                    end
                                    1'b1: begin
                                        predecoded_inst = fetched_i.inst;
                                    end
                                endcase
                            end
                            default:
                                predecoded_inst = fetched_i.inst;
                        endcase
                    end
                    F3_CFSD: begin
                        predecoded_inst.stype.opcode = OP_STORE_FP;
                        predecoded_inst.stype.func3 = F3_SD;
                        predecoded_inst.stype.rs1 = {2'b01, instr_cstype.rs1};
                        predecoded_inst.stype.rs2 = {2'b01, instr_cstype.rs2};
                        predecoded_inst.stype.imm0 = {instr_cstype.imm12[11:10], 3'b000};
                        predecoded_inst.stype.imm5 = {4'b0000, instr_cstype.imm6, instr_cstype.imm12[12]};
                    end
                    F3_CSW: begin
                        predecoded_inst.stype.opcode = OP_STORE;
                        predecoded_inst.stype.func3 = F3_SW;
                        predecoded_inst.stype.rs1 = {2'b01, instr_cstype.rs1};
                        predecoded_inst.stype.rs2 = {2'b01, instr_cstype.rs2};
                        predecoded_inst.stype.imm0 = {instr_cstype.imm12[11:10], instr_cstype.imm6[6], 2'b00};
                        predecoded_inst.stype.imm5 = {5'b00000, instr_cstype.imm6[5], instr_cstype.imm12[12]};
                    end
                    F3_CSD: begin
                        predecoded_inst.stype.opcode = OP_STORE;
                        predecoded_inst.stype.func3 = F3_SD;
                        predecoded_inst.stype.rs1 = {2'b01, instr_cstype.rs1};
                        predecoded_inst.stype.rs2 = {2'b01, instr_cstype.rs2};
                        predecoded_inst.stype.imm0 = {instr_cstype.imm12[11:10], 3'b000};
                        predecoded_inst.stype.imm5 = {4'b0000, instr_cstype.imm6, instr_cstype.imm12[12]};
                    end
                    default: begin
                        predecoded_inst = fetched_i.inst;
                    end
                endcase
            end
            C1: begin
                case (instr_citype.func3)
                    F3_CNOP_CADDI: begin
                        if (instr_citype.rd_rs1 == 5'b0) begin
                            predecoded_inst.itype.opcode = OP_ALU_I;
                            predecoded_inst.itype.rd = '0;
                    predecoded_inst.itype.func3 = F3_ADDI;
                            predecoded_inst.itype.rs1 = '0;
                            predecoded_inst.itype.imm = '0;
                        end else begin
                            predecoded_inst.itype.opcode = OP_ALU_I;
                            predecoded_inst.itype.rd = instr_citype.rd_rs1;
                            predecoded_inst.itype.func3 = F3_ADDI;
                            predecoded_inst.itype.rs1 = instr_citype.rd_rs1;
                            predecoded_inst.itype.imm = {{7{instr_citype.imm12}}, instr_citype.imm6};
                        end
                    end
                    F3_CADDIW: begin
                        if (instr_citype.rd_rs1 == 5'b0) begin
                            predecoded_inst = fetched_i.inst;
                        end else begin
                            predecoded_inst.itype.opcode = OP_ALU_I_W;
                            predecoded_inst.itype.rd = instr_citype.rd_rs1;
                            predecoded_inst.itype.func3 = F3_ADDI;
                            predecoded_inst.itype.rs1 = instr_citype.rd_rs1;
                            predecoded_inst.itype.imm = {{7{instr_citype.imm12}}, instr_citype.imm6};
                        end
                    end
                    F3_CLI: begin
                        predecoded_inst.itype.opcode = OP_ALU_I;
                        predecoded_inst.itype.rd = instr_citype.rd_rs1;
                        predecoded_inst.itype.func3 = F3_ADDI;
                        predecoded_inst.itype.rs1 = '0;
                        predecoded_inst.itype.imm = {{7{instr_citype.imm12}}, instr_citype.imm6};
                    end
                    F3_CADDI16SP_CLUI: begin
                        if (instr_citype.imm12 == 1'b0 && instr_citype.imm6 == '0) begin
                            predecoded_inst = fetched_i.inst;
                        end else begin
                            if (instr_citype.rd_rs1 == 5'b00010) begin // C.ADDI16SP
                                predecoded_inst.itype.opcode = OP_ALU_I;
                                predecoded_inst.itype.rd = instr_citype.rd_rs1;
                                predecoded_inst.itype.func3 = F3_ADDI;
                                predecoded_inst.itype.rs1 = instr_citype.rd_rs1;
                                predecoded_inst.itype.imm = {{3{instr_citype.imm12}}, instr_citype.imm6[4:3], instr_citype.imm6[5], instr_citype.imm6[2], instr_citype.imm6[6], 4'b0000};
                            end else begin
                                predecoded_inst.utype.opcode = OP_LUI;
                                predecoded_inst.utype.rd = instr_citype.rd_rs1;
                                predecoded_inst.utype.imm = {{15{instr_citype.imm12}}, instr_citype.imm6};
                            end
                        end
                    end
                    F3_CARITHMETIC: begin
                        case (instr_cbtype.offset12[11:10])
                            F2_CSRLI: begin
                                predecoded_inst.itype.opcode = OP_ALU_I;
                                predecoded_inst.itype.rd = {2'b01, instr_cbtype.rd_rs1};
                                predecoded_inst.itype.func3 = F3_SRLAI;
                                predecoded_inst.itype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                                predecoded_inst.itype.imm = {6'b000000, instr_cbtype.offset12[12], instr_cbtype.offset6};
                            end
                            F2_CSRAI: begin
                                predecoded_inst.itype.opcode = OP_ALU_I;
                                predecoded_inst.itype.rd = {2'b01, instr_cbtype.rd_rs1};
                                predecoded_inst.itype.func3 = F3_SRLAI;
                                predecoded_inst.itype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                                predecoded_inst.itype.imm = {6'b010000, instr_cbtype.offset12[12], instr_cbtype.offset6};
                            end
                            F2_CANDI: begin
                                predecoded_inst.itype.opcode = OP_ALU_I;
                                predecoded_inst.itype.rd = {2'b01, instr_cbtype.rd_rs1};
                                predecoded_inst.itype.func3 = F3_AND;
                                predecoded_inst.itype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                                predecoded_inst.itype.imm = {{7{instr_cbtype.offset12[12]}}, instr_cbtype.offset6};                               
                            end
                            F2_CALU: begin
                                case (instr_catype.func6[12])
                                    BIT_CALU_64: begin
                                        case (instr_catype.imm6)
                                            CALU_64_CSUB: begin
                                                predecoded_inst.rtype.opcode = OP_ALU;
                                                predecoded_inst.rtype.rd = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.func3 = F3_ADD_SUB;
                                                predecoded_inst.rtype.rs1 = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.rs2 = {2'b01, instr_catype.rs2};
                                                predecoded_inst.rtype.func7 = 7'b0100000;
                                            end
                                            CALU_64_CXOR: begin
                                                predecoded_inst.rtype.opcode = OP_ALU;
                                                predecoded_inst.rtype.rd = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.func3 = F3_XOR;
                                                predecoded_inst.rtype.rs1 = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.rs2 = {2'b01, instr_catype.rs2};
                                                predecoded_inst.rtype.func7 = 7'b0000000;
                                            end
                                            CALU_64_COR: begin
                                                predecoded_inst.rtype.opcode = OP_ALU;
                                                predecoded_inst.rtype.rd = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.func3 = F3_OR;
                                                predecoded_inst.rtype.rs1 = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.rs2 = {2'b01, instr_catype.rs2};
                                                predecoded_inst.rtype.func7 = 7'b0000000;
                                            end
                                            CALU_64_CAND: begin
                                                predecoded_inst.rtype.opcode = OP_ALU;
                                                predecoded_inst.rtype.rd = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.func3 = F3_AND;
                                                predecoded_inst.rtype.rs1 = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.rs2 = {2'b01, instr_catype.rs2};
                                                predecoded_inst.rtype.func7 = 7'b0000000;
                                            end
                                            default: begin
                                                // Should never enter here
                                                predecoded_inst = fetched_i.inst;
                                            end
                                        endcase
                                    end
                                    BIT_CALU_32: begin
                                         case (instr_catype.imm6)
                                            CALU_32_CSUBW: begin
                                                predecoded_inst.rtype.opcode = OP_ALU_W;
                                                predecoded_inst.rtype.rd = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.func3 = F3_ADD_SUB;
                                                predecoded_inst.rtype.rs1 = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.rs2 = {2'b01, instr_catype.rs2};
                                                predecoded_inst.rtype.func7 = 7'b0100000;
                                            end
                                            CALU_32_CADDW: begin
                                                predecoded_inst.rtype.opcode = OP_ALU_W;
                                                predecoded_inst.rtype.rd = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.func3 = F3_ADD_SUB;
                                                predecoded_inst.rtype.rs1 = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.rs2 = {2'b01, instr_catype.rs2};
                                                predecoded_inst.rtype.func7 = 7'b0000000;
                                            end
                                            CALU_MUL: begin
                                                predecoded_inst.rtype.opcode = OP_ALU;
                                                predecoded_inst.rtype.rd = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.func3 = F3_MUL;
                                                predecoded_inst.rtype.rs1 = {2'b01, instr_catype.rd_rs1};
                                                predecoded_inst.rtype.rs2 = {2'b01, instr_catype.rs2};
                                                predecoded_inst.rtype.func7 = F7_MUL_DIV;
                                            end
                                            CALU_Z_SEXT: begin
                                                 case (instr_catype.rs2)
                                                    CZEXTB: begin // Equivalent to an ANDI operation with 0xFF
                                                        predecoded_inst.itype.opcode = OP_ALU_I;
                                                        predecoded_inst.itype.rd = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.func3 = F3_AND;
                                                        predecoded_inst.itype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.imm = {4'b0, 8'b11111111};
                                                    end
                                                    CSEXTB: begin
                                                        predecoded_inst.itype.opcode = OP_ALU_I;
                                                        predecoded_inst.itype.rd = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.func3 = F3_CLZ_CTZ_CPOP_SEXTB_SEXTH;
                                                        predecoded_inst.itype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.imm = {12'b011000000100};
                                                    end
                                                    CZEXTH: begin
                                                        predecoded_inst.itype.opcode = OP_ALU_W;
                                                        predecoded_inst.itype.rd = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.func3 = F3_ZEXTH;
                                                        predecoded_inst.itype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.imm = {12'b000010000000};
                                                    end
                                                    CSEXTH: begin
                                                        predecoded_inst.itype.opcode = OP_ALU_I;
                                                        predecoded_inst.itype.rd = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.func3 = F3_CLZ_CTZ_CPOP_SEXTB_SEXTH;
                                                        predecoded_inst.itype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.imm = {12'b011000000101};
                                                    end
                                                    CZEXTW: begin
                                                        predecoded_inst.rtype.opcode = OP_ALU_W;
                                                        predecoded_inst.rtype.rd = {2'b01, instr_catype.rd_rs1};
                                                        predecoded_inst.rtype.func3 = F3_ADD_SUB;
                                                        predecoded_inst.rtype.rs1 = {2'b01, instr_catype.rd_rs1};
                                                        predecoded_inst.rtype.rs2 = 5'b00000;
                                                        predecoded_inst.rtype.func7 = 7'b0000100;
                                                    end
                                                    CNOT: begin
                                                        predecoded_inst.itype.opcode = OP_ALU_I;
                                                        predecoded_inst.itype.rd = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.func3 = F3_XORI;
                                                        predecoded_inst.itype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                                                        predecoded_inst.itype.imm = {12'b111111111111};
                                                    end
                                                    default: begin
                                                        predecoded_inst = fetched_i.inst;
                                                    end
                                                 endcase
                                            end
                                            default: begin
                                                // Reserved
                                                predecoded_inst = fetched_i.inst;
                                            end
                                        endcase
                                    end
                                    default: begin
                                        // Should never enter here
                                        predecoded_inst = fetched_i.inst;
                                    end
                                endcase
                            end
                        endcase
                    end
                    F3_CJ: begin
                        predecoded_inst.jtype.opcode = OP_JAL;
                        predecoded_inst.jtype.rd = 5'b00000;
                        predecoded_inst.jtype.imm20 = instr_cjtype.jump_target[12]; // part of sign-extension
                        predecoded_inst.jtype.imm12 = {8{instr_cjtype.jump_target[12]}}; // part of sign-extension
                        predecoded_inst.jtype.imm11 = instr_cjtype.jump_target[12]; // part of sign-extension
                        predecoded_inst.jtype.imm1 = {instr_cjtype.jump_target[8], instr_cjtype.jump_target[10:9], instr_cjtype.jump_target[6], instr_cjtype.jump_target[7], instr_cjtype.jump_target[2], instr_cjtype.jump_target[11], instr_cjtype.jump_target[5:3]};
                    end
                    F3_CBEQZ: begin
                        predecoded_inst.btype.opcode = OP_BRANCH;
                        predecoded_inst.btype.func3 = F3_BEQ;
                        predecoded_inst.btype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                        predecoded_inst.btype.rs2 = '0;
                        predecoded_inst.btype.imm12 = instr_cbtype.offset12[12];
                        predecoded_inst.btype.imm11 = instr_cbtype.offset12[12];
                        predecoded_inst.btype.imm5 = {{3{instr_cbtype.offset12[12]}}, instr_cbtype.offset6[6:5], instr_cbtype.offset6[2]};
                        predecoded_inst.btype.imm1 = {instr_cbtype.offset12[11:10], instr_cbtype.offset6[4:3]};
                    end
                    F3_CBNEZ: begin
                        predecoded_inst.btype.opcode = OP_BRANCH;
                        predecoded_inst.btype.func3 = F3_BNE;
                        predecoded_inst.btype.rs1 = {2'b01, instr_cbtype.rd_rs1};
                        predecoded_inst.btype.rs2 = '0;
                        predecoded_inst.btype.imm12 = instr_cbtype.offset12[12];
                        predecoded_inst.btype.imm11 = instr_cbtype.offset12[12];
                        predecoded_inst.btype.imm5 = {{3{instr_cbtype.offset12[12]}}, instr_cbtype.offset6[6:5], instr_cbtype.offset6[2]};
                        predecoded_inst.btype.imm1 = {instr_cbtype.offset12[11:10], instr_cbtype.offset6[4:3]};
                    end
                    default: begin
                        predecoded_inst = fetched_i.inst;
                    end
                endcase
            end

            C2: begin
                case (instr_citype.func3)
                    F3_CSLLI: begin
                        predecoded_inst.itype.opcode = OP_ALU_I;
                        predecoded_inst.itype.rd = instr_citype.rd_rs1;
                        predecoded_inst.itype.func3 = F3_SLLI;
                        predecoded_inst.itype.rs1 = instr_citype.rd_rs1;
                        predecoded_inst.itype.imm = {6'b000000, instr_citype.imm12[12], instr_citype.imm6};
                    end
                    F3_CFLDSP: begin
                        predecoded_inst.itype.opcode = OP_LOAD_FP;
                        predecoded_inst.itype.rd = instr_citype.rd_rs1;
                        predecoded_inst.itype.func3 = F3_LD;
                        predecoded_inst.itype.rs1 = 5'b00010;
                        predecoded_inst.itype.imm = {3'b000, instr_citype.imm6[4:2], instr_citype.imm12, instr_citype[6:5], 3'b000};
                    end
                    F3_CLWSP: begin
                        if (instr_citype.rd_rs1 == 5'b00000) begin
                            // reserved
                            predecoded_inst = fetched_i.inst;
                        end else begin
                            predecoded_inst.itype.opcode = OP_LOAD;
                            predecoded_inst.itype.rd = instr_citype.rd_rs1;
                            predecoded_inst.itype.func3 = F3_LW;
                            predecoded_inst.itype.rs1 = 5'b00010;
                            predecoded_inst.itype.imm = {4'b0000, instr_citype.imm6[3:2], instr_citype.imm12, instr_citype[6:4], 2'b00};
                        end
                    end
                    F3_CLDSP: begin
                         if (instr_citype.rd_rs1 == 5'b00000) begin
                            // reserved
                            predecoded_inst = fetched_i.inst;
                        end else begin
                            predecoded_inst.itype.opcode = OP_LOAD;
                            predecoded_inst.itype.rd = instr_citype.rd_rs1;
                            predecoded_inst.itype.func3 = F3_LD;
                            predecoded_inst.itype.rs1 = 5'b00010;
                            predecoded_inst.itype.imm = {3'b000, instr_citype.imm6[4:2], instr_citype.imm12, instr_citype[6:5], 3'b000};
                        end
                    end
                    F3_CJR_CMV_CEBREAK_CJALR_CADD: begin
                        case (instr_citype.imm12)
                            BIT_CJR_CMV: begin
                                if (instr_crtype.rs2 == 5'b00000) begin
                                    if (instr_crtype.rd_rs1 == 5'b00000) begin
                                        // reserved
                                        predecoded_inst = fetched_i.inst;
                                    end else begin
                                        predecoded_inst.itype.opcode = OP_JALR;
                                        predecoded_inst.itype.rd = 5'b00000;
                                        predecoded_inst.itype.func3 = 3'b000;
                                        predecoded_inst.itype.rs1 = instr_citype.rd_rs1;
                                        predecoded_inst.itype.imm = 12'b000000000000;
                                    end
                                end else begin
                                    predecoded_inst.rtype.opcode = OP_ALU;
                                    predecoded_inst.rtype.rd = instr_crtype.rd_rs1;
                                    predecoded_inst.rtype.func3 = F3_ADD_SUB;
                                    predecoded_inst.rtype.rs1 = 5'b00000;
                                    predecoded_inst.rtype.rs2 = instr_crtype.rs2;
                                    predecoded_inst.rtype.func7 = 7'b0000000;
                                end
                            end
                            BIT_CEBREAK_CJALR_CADD: begin
                                if (instr_crtype.rs2 == 5'b00000) begin
                                    if (instr_crtype.rd_rs1 == 5'b00000) begin
                                        predecoded_inst.itype.opcode = OP_SYSTEM;
                                        predecoded_inst.itype.rd = 5'b00000;
                                        predecoded_inst.itype.func3 = F3_ECALL_EBREAK_ERET;
                                        predecoded_inst.itype.rs1 = 5'b00000;
                                        predecoded_inst.itype.imm = {F7_ECALL_EBREAK_URET, RS2_EBREAK_SFENCEVM};
                                    end else begin
                                        predecoded_inst.itype.opcode = OP_JALR;
                                        predecoded_inst.itype.rd = 5'b00001;
                                        predecoded_inst.itype.func3 = 3'b000;
                                        predecoded_inst.itype.rs1 = instr_citype.rd_rs1;
                                        predecoded_inst.itype.imm = 12'b000000000000;
                                    end
                                end else begin
                                    predecoded_inst.rtype.opcode = OP_ALU;
                                    predecoded_inst.rtype.rd = instr_crtype.rd_rs1;
                                    predecoded_inst.rtype.func3 = F3_ADD_SUB;
                                    predecoded_inst.rtype.rs1 = instr_crtype.rd_rs1;
                                    predecoded_inst.rtype.rs2 = instr_crtype.rs2;
                                    predecoded_inst.rtype.func7 = 7'b0000000;
                                end
                            end
                        endcase
                    end
                    F3_CFSDSP: begin
                        predecoded_inst.stype.opcode = OP_STORE_FP;
                        predecoded_inst.stype.func3 = F3_SD;
                        predecoded_inst.stype.rs1 = 5'b00010;
                        predecoded_inst.stype.rs2 = instr_csstype.rs2;
                        predecoded_inst.stype.imm0 = {instr_csstype.imm12[11:10], 3'b000};
                        predecoded_inst.stype.imm5 = {3'b000, instr_csstype.imm12[9:7], instr_csstype.imm12[12]};
                    end
                    F3_CSWSP: begin
                        predecoded_inst.stype.opcode = OP_STORE;
                        predecoded_inst.stype.func3 = F3_SW;
                        predecoded_inst.stype.rs1 = 5'b00010;
                        predecoded_inst.stype.rs2 = instr_csstype.rs2;
                        predecoded_inst.stype.imm0 = {instr_csstype.imm12[11:9], 2'b00};
                        predecoded_inst.stype.imm5 = {4'b0000, instr_csstype.imm12[8:7], instr_csstype.imm12[12]};
                    end
                    F3_CSDSP: begin
                        predecoded_inst.stype.opcode = OP_STORE;
                        predecoded_inst.stype.func3 = F3_SD;
                        predecoded_inst.stype.rs1 = 5'b00010;
                        predecoded_inst.stype.rs2 = instr_csstype.rs2;
                        predecoded_inst.stype.imm0 = {instr_csstype.imm12[11:10], 3'b000};
                        predecoded_inst.stype.imm5 = {3'b000, instr_csstype.imm12[9:7], instr_csstype.imm12[12]};
                    end
                    default: begin
                        predecoded_inst = fetched_i.inst;
                    end
                endcase
            end

             default: begin
                predecoded_inst = fetched_i.inst;
            end
        endcase        
    end

    assign predecoded_o.pc_inst = fetched_i.pc_inst;
    assign predecoded_o.inst = predecoded_inst;
    assign predecoded_o.valid = fetched_i.valid;
    assign predecoded_o.bpred = fetched_i.bpred;
    assign predecoded_o.ex = fetched_i.ex;

    `ifdef SIM_KONATA_DUMP
    assign predecoded_o.id = fetched_i.id;
    `endif


endmodule

