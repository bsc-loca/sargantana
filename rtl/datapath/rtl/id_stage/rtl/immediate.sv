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

module immediate
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instruction_t instr_i,
    output bus64_t imm_o
);
    bus32_t imm_itype;
    bus32_t imm_stype;
    bus32_t imm_btype;
    bus32_t imm_utype;
    bus32_t imm_jtype;
    bus64_t imm_uitype;
    bus64_t imm_vtype;
    bus64_t imm_shamt, imm_shamt_big;
    bus32_t sign_extended;

    assign imm_shamt_big = {{57{instr_i[26]}}, instr_i[26:20]};
    assign imm_shamt = {{58{instr_i[25]}}, instr_i[25:20]};

    assign imm_itype = {{20{instr_i[31]}}, instr_i.itype.imm};
    
    assign imm_stype = {{20{instr_i[31]}}, instr_i.stype.imm5, instr_i.stype.imm0};
    
    assign imm_btype = {{20{instr_i[31]}}, instr_i.btype.imm11, instr_i.btype.imm5, instr_i.btype.imm1, 1'b0};
    
    assign imm_utype = {instr_i.utype.imm, 12'b0};

    assign imm_jtype = {{11{instr_i[31]}}, instr_i.jtype.imm20,
                                         instr_i.jtype.imm12, 
                                         instr_i.jtype.imm11,
                                         instr_i.jtype.imm1, 1'b0};
    
    assign imm_vtype = {{58{instr_i[19]}}, instr_i.vtype.vs1};
    // No sign extended
    assign imm_uitype = {{59{1'b0}}, instr_i.common.rs1};
    assign sign_extended = {32{instr_i[31]}}; 

    always_comb begin
        case (instr_i.common.opcode)
            riscv_pkg::OP_LUI,
            riscv_pkg::OP_AUIPC: begin
                imm_o = {sign_extended,imm_utype};
            end
            riscv_pkg::OP_JAL: begin
                imm_o = {sign_extended,imm_jtype};
            end
            riscv_pkg::OP_LOAD_FP: begin
                case (instr_i.stype.func3)
                    F3_FLW,
                    F3_FLD: begin
                        imm_o = {sign_extended,imm_itype};
                    end
                    default: begin
                        imm_o = '0;
                    end
                endcase
            end
            riscv_pkg::OP_JALR,
            riscv_pkg::OP_LOAD: begin
                imm_o = {sign_extended,imm_itype};
            end
            riscv_pkg::OP_ALU_I: begin
                case (instr_i.common.func3)
                    F3_SLLI,
                    F3_SRLAI: begin
                        imm_o = imm_shamt_big;
                    end
                    default : begin
                        imm_o = {sign_extended,imm_itype};
                    end
                endcase
            end
            riscv_pkg::OP_ALU_I_W: begin
                case (instr_i.common.func3)
                    F3_64_SLLIW,
                    F3_64_SRLIW_SRAIW: begin
                        imm_o = imm_shamt;
                    end
                    default : begin
                        imm_o = {sign_extended,imm_itype};
                    end
                endcase
            end
            riscv_pkg::OP_BRANCH: begin
                imm_o = {sign_extended,imm_btype};
            end
            riscv_pkg::OP_STORE_FP: begin
                case (instr_i.stype.func3)
                    F3_FLW,
                    F3_FLD: begin
                        imm_o = {sign_extended,imm_stype};
                    end
                    default: begin
                        imm_o = '0;
                    end
                endcase
            end
            riscv_pkg::OP_STORE: begin
                imm_o = {sign_extended,imm_stype};
            end
            riscv_pkg::OP_SYSTEM: begin
                // we could filter here for only the important CSR
                case (instr_i.itype.func3)
                    F3_CSRRW,
                    F3_CSRRS,
                    F3_CSRRC,
                    F3_CSRRWI,
                    F3_CSRRSI,
                    F3_CSRRCI,
                    F3_ECALL_EBREAK_ERET : begin
                        imm_o = {sign_extended,imm_itype};
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
