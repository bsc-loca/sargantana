/*
 * Copyright 2025 BSC*
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

module branch_unit
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input rr_exe_arith_instr_t       instruction_i,       // In instruction
    output exe_wb_scalar_instr_t     instruction_o        // Out instruction
);

bus64_t data_rs1, data_rs2;

logic equal;
logic less;
logic less_u;

logic   branch_taken;
bus64_t target;
bus64_t result;

// Data source operands
assign data_rs1 = instruction_i.data_rs1;
assign data_rs2 = instruction_i.data_rs2;

// Calculate all posible conditions
assign equal = (data_rs1 == data_rs2);
assign less = $signed(data_rs1) < $signed(data_rs2);
assign less_u = data_rs1 < data_rs2;

// Truncate Function
function [63:0] trunc_65_64(input [64:0] val_in);
  trunc_65_64 = val_in[63:0];
endfunction

// Calculate target
always_comb begin
    case (instruction_i.instr.instr_type)
        JAL: begin
            // Jal always puts a zero in the lower bit. PC plus immediate
            target = trunc_65_64(instruction_i.instr.pc + instruction_i.instr.imm) & 64'hFFFFFFFFFFFFFFFE; 
        end
        JALR: begin
            // Jalr always puts a zero in the lower bit
            target = trunc_65_64(data_rs1 + instruction_i.instr.imm) & 64'hFFFFFFFFFFFFFFFE;
        end
        BLT, BLTU, BGE, BGEU, BEQ, BNE: begin
            target = trunc_65_64(instruction_i.instr.pc + instruction_i.instr.imm);
        end
        default: begin
            target = 0;
        end
    endcase
end

// Calculate taken
always_comb begin
    case (instruction_i.instr.instr_type)
        JAL: begin
            branch_taken = 1; // guillemlp this is done at decode stage
        end
        JALR: begin
            branch_taken = 1;
        end
        BEQ: begin   //branch on equal
            branch_taken = equal;
        end
        BNE: begin //branch on not equal
            branch_taken = ~equal;
        end
        BLT: begin //branch on less than
            branch_taken = less;
        end
        BGE: begin //branch on greater than or equal
            branch_taken = ~less;
        end
        BLTU: begin //branch if less than unsigned
            branch_taken = less_u;
        end
        BGEU: begin //branch if greater than or equal unsigned
            branch_taken = ~less_u;
        end
        default: begin
            branch_taken = 0;
        end
    endcase
end

//------------------------------------------------------------------------------
// METADATA TO WRITE_BACK
//------------------------------------------------------------------------------

assign instruction_o.valid           = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_BRANCH);
assign instruction_o.pc              = instruction_i.instr.pc;
assign instruction_o.bpred           = instruction_i.instr.bpred;
assign instruction_o.rs1             = instruction_i.instr.rs1;
assign instruction_o.rd              = instruction_i.instr.rd;
assign instruction_o.regfile_we      = instruction_i.instr.regfile_we;
assign instruction_o.instr_type      = instruction_i.instr.instr_type;
assign instruction_o.stall_csr_fence = instruction_i.instr.stall_csr_fence;
assign instruction_o.csr_addr        = instruction_i.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_o.prd             = instruction_i.prd;
assign instruction_o.checkpoint_done = instruction_i.checkpoint_done;
assign instruction_o.chkp            = instruction_i.chkp;
assign instruction_o.gl_index        = instruction_i.gl_index;
assign instruction_o.mem_type        = instruction_i.instr.mem_type;
assign instruction_o.vl              = instruction_i.instr.vl;
assign instruction_o.sew             = instruction_i.instr.sew;
`ifdef SIM_KONATA_DUMP
assign instruction_o.id            = instruction_i.instr.id;
`endif
assign instruction_o.branch_taken  = branch_taken;
assign instruction_o.fp_status     = 'h0;

// Target 

assign result = (branch_taken) ? target : trunc_65_64(instruction_i.instr.pc + 4);
assign instruction_o.result     = trunc_65_64(instruction_i.instr.pc + 4);
assign instruction_o.result_pc  = target;
        
// Exceptions

always_comb begin
    instruction_o.ex.cause  = INSTR_ADDR_MISALIGNED;
    instruction_o.ex.origin = 0;
    instruction_o.ex.valid  = 0;
    if(instruction_i.instr.valid) begin // Check exceptions in exe stage
        if ((result[1:0] != 0) && (instruction_i.instr.unit == UNIT_BRANCH) &&
             ((instruction_i.instr.instr_type == JALR) ||
               (((instruction_i.instr.instr_type == BLT)  || 
                 (instruction_i.instr.instr_type == BLTU) || 
                 (instruction_i.instr.instr_type == BGE)  ||
                 (instruction_i.instr.instr_type == BGEU) || 
                 (instruction_i.instr.instr_type == BEQ)  || 
                 (instruction_i.instr.instr_type == BNE) ) &&
                branch_taken ))) begin // invalid address
            instruction_o.ex.cause = INSTR_ADDR_MISALIGNED;
            instruction_o.ex.origin = result;
            instruction_o.ex.valid = 1;
        end
    end 
end

endmodule

