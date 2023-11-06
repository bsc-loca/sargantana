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

// Interface of Data Path with CSR

module csr_interface
    import drac_pkg::*;
(
    // Datapath signals
    input  logic            commit_xcpt_i,            // Exception at Commit
    input  bus64_t          result_gl_i,
    input  reg_csr_addr_t   csr_addr_gl_i,
    input  gl_instruction_t [1:0] instruction_to_commit_i,  // Instruction to be Committed
    input  logic            stall_exe_i,              // Exe Stage is Stalled
    input  logic            commit_store_or_amo_i,    // The Commit Instruction is AMO or STORE
    input  logic            mem_commit_stall_i,       // The Commit Instruction is Stalled at Mem Stage
    input  exception_t      exception_mem_commit_i,   // The Exception comming from AMO or STORE
    input  exception_t      exception_gl_i,
    // CSR interruption
    output logic            csr_ena_int_o,            // Enable CSR petition
    // Request to CSR
    output req_cpu_csr_t    req_cpu_csr_o,             // Request to the CSRs
    output logic [1:0]      retire_inst_o
);

bus64_t csr_rw_data_int;
logic   csr_ena_int;
csr_cmd_t csr_cmd_int;


always_comb begin
    csr_cmd_int = CSR_CMD_NOPE;
    csr_rw_data_int = 64'b0;
    csr_ena_int = 1'b0;
    if (instruction_to_commit_i[0].valid && !instruction_to_commit_i[0].ex_valid) begin
        case (instruction_to_commit_i[0].instr_type)
            CSRRW: begin
                csr_cmd_int = CSR_CMD_WRITE;
                csr_rw_data_int = result_gl_i;
                csr_ena_int = 1'b1;
            end
            CSRRS: begin
                csr_cmd_int = (instruction_to_commit_i[0].rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                csr_rw_data_int = result_gl_i;
                csr_ena_int = 1'b1;
            end
            CSRRC: begin
                csr_cmd_int = (instruction_to_commit_i[0].rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                csr_rw_data_int = result_gl_i;
                csr_ena_int = 1'b1;
            end
            CSRRWI: begin
                csr_cmd_int = CSR_CMD_WRITE;
                csr_rw_data_int = {59'b0,instruction_to_commit_i[0].rs1};
                csr_ena_int = 1'b1;
            end
            CSRRSI: begin
                csr_cmd_int = (instruction_to_commit_i[0].rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                csr_rw_data_int = {59'b0,instruction_to_commit_i[0].rs1};
                csr_ena_int = 1'b1;
            end
            CSRRCI: begin
                csr_cmd_int = (instruction_to_commit_i[0].rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                csr_rw_data_int = {59'b0,instruction_to_commit_i[0].rs1};
                csr_ena_int = 1'b1;
            end
            ECALL,
            EBREAK,
            URET,
            SRET,
            MRET,
            WFI,
            SFENCE_VMA,
            MRTS: begin
                csr_cmd_int = CSR_CMD_SYS;
                csr_rw_data_int = 64'b0;
                csr_ena_int = 1'b1;
            end
            VSETVLI,
            VSETVL: begin
                csr_cmd_int = (instruction_to_commit_i[0].rs1 == 'h0) ? CSR_CMD_N2 : CSR_CMD_VSELVL;
                csr_rw_data_int = (instruction_to_commit_i[0].rs1 == 'h0 && instruction_to_commit_i[0].rd == 'h0) ? 64'b1 : result_gl_i;
                csr_ena_int = 1'b1;
            end
            default: begin
                `ifdef ASSERTIONS
                   assert (1 == 0);
                `endif
                 csr_ena_int = 1'b0;
            end
        endcase
    end
end

// tell cu that ecall was taken
    assign commit_2_blocked = !instruction_to_commit_i[0].valid || 
                                instruction_to_commit_i[0].ex_valid || 
                                csr_ena_int || !instruction_to_commit_i[1].valid ||
                                instruction_to_commit_i[1].valid &
                                (instruction_to_commit_i[1].instr_type == ECALL ||
                                instruction_to_commit_i[1].instr_type == SRET   ||
                                instruction_to_commit_i[1].instr_type == MRET   ||
                                instruction_to_commit_i[1].instr_type == URET   ||
                                instruction_to_commit_i[1].instr_type == WFI    ||
                                instruction_to_commit_i[1].instr_type == EBREAK ||
                                instruction_to_commit_i[1].instr_type == FENCE  || 
                                instruction_to_commit_i[1].instr_type == SFENCE_VMA || 
                                instruction_to_commit_i[1].instr_type == FENCE_I|| 
                                instruction_to_commit_i[1].instr_type == CSRRW  ||
                                instruction_to_commit_i[1].instr_type == CSRRS  ||
                                instruction_to_commit_i[1].instr_type == CSRRC  ||
                                instruction_to_commit_i[1].instr_type == CSRRWI ||
                                instruction_to_commit_i[1].instr_type == CSRRSI ||
                                instruction_to_commit_i[1].instr_type == CSRRCI ||
                                instruction_to_commit_i[1].instr_type == VSETVL ||
                                instruction_to_commit_i[1].instr_type == VSETVLI|| 
                                instruction_to_commit_i[1].mem_type == STORE    || 
                                instruction_to_commit_i[1].mem_type == AMO)     ||
                                instruction_to_commit_i[1].valid & instruction_to_commit_i[1].ex_valid;

// CSR and Exceptions
assign req_cpu_csr_o.csr_rw_addr = (csr_ena_int) ? csr_addr_gl_i : {CSR_ADDR_SIZE{1'b0}};
// if csr not enabled send command NOP
assign req_cpu_csr_o.csr_rw_cmd = (csr_ena_int) ? csr_cmd_int : CSR_CMD_NOPE;
// if csr not enabled send the interesting addr that you are accesing, exception help
assign req_cpu_csr_o.csr_rw_data = (csr_ena_int) ? csr_rw_data_int : (~commit_store_or_amo_i)? exception_gl_i.origin : exception_mem_commit_i.origin;

assign req_cpu_csr_o.csr_exception = commit_xcpt_i;

assign req_cpu_csr_o.fp_status = {instruction_to_commit_i[0].fp_status.NV, 
                                  instruction_to_commit_i[0].fp_status.DZ, 
                                  instruction_to_commit_i[0].fp_status.OF,
                                  instruction_to_commit_i[0].fp_status.UF,
                                  instruction_to_commit_i[0].fp_status.NX} & {5{retire_inst_o[0]}} | 
                                  {instruction_to_commit_i[1].fp_status.NV, 
                                  instruction_to_commit_i[1].fp_status.DZ, 
                                  instruction_to_commit_i[1].fp_status.OF,
                                  instruction_to_commit_i[1].fp_status.UF,
                                  instruction_to_commit_i[1].fp_status.NX} & {5{retire_inst_o[1]}};

// if we can retire an instruction
//assign req_cpu_csr_o.csr_retire = instruction_to_commit_i[0].valid && !commit_xcpt_i && !mem_commit_stall_i; //!stall_exe_i;
always_comb begin
    req_cpu_csr_o.csr_retire = 2'b0;
    retire_inst_o = 2'b0;
    if (instruction_to_commit_i[0].valid && commit_xcpt_i) begin
        retire_inst_o = 2'h1;
    end else if (instruction_to_commit_i[0].valid && !commit_xcpt_i && !mem_commit_stall_i && commit_2_blocked) begin
        req_cpu_csr_o.csr_retire = 2'h1;
        retire_inst_o = 2'h1;
    end else if (instruction_to_commit_i[0].valid && !commit_xcpt_i && !mem_commit_stall_i && !commit_2_blocked) begin
        req_cpu_csr_o.csr_retire = 2'b11;
        retire_inst_o = 2'b11;
    end; 
end
// if there is a csr interrupt we take the interrupt?
assign req_cpu_csr_o.csr_xcpt_cause = (~commit_store_or_amo_i)? exception_gl_i.cause : exception_mem_commit_i.cause;
assign req_cpu_csr_o.csr_pc = instruction_to_commit_i[0].pc;
// CSR interruption
assign csr_ena_int_o = csr_ena_int;

endmodule
