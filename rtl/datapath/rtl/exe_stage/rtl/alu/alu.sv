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

module alu 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input rr_exe_arith_instr_t     instruction_i,       // In instruction
    output exe_wb_scalar_instr_t   instruction_o        // Out instruction
);

bus64_t data_rs1, data_rs2;

reg_csr_addr_t vsetvl_csr_addr_int;

assign data_rs1 = instruction_i.data_rs1;
assign data_rs2 = instruction_i.data_rs2;

assign vsetvl_csr_addr_int = {{(CSR_ADDR_SIZE-9){1'b0}}, (|data_rs2[63:8]), data_rs2[7:0]}; // vtype bits [62:8] are reserved, we can OR them

// Truncate Function
function [31:0] trunc_33_32(input [32:0] val_in);
  trunc_33_32 = val_in[31:0];
endfunction

function [31:0] trunc_63_32(input [62:0] val_in);
  trunc_63_32 = val_in[31:0];
endfunction

function [63:0] trunc_65_64(input [64:0] val_in);
  trunc_65_64 = val_in[63:0];
endfunction

function [63:0] trunc_66_64(input [65:0] val_in);
  trunc_66_64 = val_in[63:0];
endfunction

function [63:0] trunc_67_64(input [66:0] val_in);
  trunc_67_64 = val_in[63:0];
endfunction

function [31:0] trunc_65_32(input [64:0] val_in);
  trunc_65_32 = val_in[31:0];
endfunction

function [63:0] trunc_127_64(input [126:0] val_in);
  trunc_127_64 = val_in[63:0];
endfunction

bus64_t data_rs1_extended;

// Sign/Zero extension
always_comb begin
    case (instruction_i.instr.instr_type)
        ADDUW, SH1ADDUW, SH2ADDUW, SH3ADDUW, ZEXTW, SLLIUW, SLLW, SRLW, CPOPW: begin
            data_rs1_extended[63:32] = 32'b0;
            data_rs1_extended[31:0] = data_rs1[31:0];
        end
        ZEXTH: begin
            data_rs1_extended[63:16] = 48'b0;
            data_rs1_extended[15:0] = data_rs1[15:0];
        end
        SRAW: begin
            data_rs1_extended[63:32] = {32{data_rs1[31]}};
            data_rs1_extended[31:0] = data_rs1[31:0];
        end
        SEXTH: begin
            data_rs1_extended[63:16] = {48{data_rs1[15]}};
            data_rs1_extended[15:0] = data_rs1[15:0];
        end
        SEXTB: begin
            data_rs1_extended[63:8] = {56{data_rs1[7]}};
            data_rs1_extended[7:0] = data_rs1[7:0];
        end
        RORW, ROLW: begin
            data_rs1_extended[63:32] = data_rs1[31:0];
            data_rs1_extended[31:0] = data_rs1[31:0];
        end
        default: begin
            data_rs1_extended = data_rs1;
        end
    endcase
end

bus64_t data_rs1_shifted;

// Pre-shift
/*
 * Check possibility of using the shift module instead of this
 */
always_comb begin
    case (instruction_i.instr.instr_type)
        SH1ADD, SH1ADDUW: begin
            data_rs1_shifted = trunc_65_64(data_rs1_extended << 1);
        end
        SH2ADD, SH2ADDUW: begin
            data_rs1_shifted = trunc_66_64(data_rs1_extended << 2);
        end
        SH3ADD, SH3ADDUW: begin
            data_rs1_shifted = trunc_67_64(data_rs1_extended << 3);
        end
        default: begin
            data_rs1_shifted = data_rs1_extended;
        end
    endcase
end

bus64_t logic_rs1_i;
bus64_t logic_rs2_i;

bus64_t alu_add_result;
bus64_t alu_shift_result;
bus64_t alu_cmp_result;
bus64_t alu_logic_result;
bus64_t alu_count_zeros_result;
bus64_t alu_count_pop_result;

alu_add alu_add_inst (
    .data_rs1_i(data_rs1_shifted),
    .data_rs2_i(data_rs2),
    .instr_type_i(instruction_i.instr.instr_type),
    .result_o(alu_add_result)
);

alu_shift alu_shift_inst (
    .data_rs1_i(data_rs1_extended),
    .data_rs2_i(data_rs2),
    .instr_type_i(instruction_i.instr.instr_type),
    .result_o(alu_shift_result)
);

alu_cmp alu_cmp_inst (
    .data_rs1_i(data_rs1),
    .data_rs2_i(data_rs2),
    .instr_type_i(instruction_i.instr.instr_type),
    .result_o(alu_cmp_result)
);

alu_logic alu_logic_inst (
    .data_rs1_i(logic_rs1_i),
    .data_rs2_i(logic_rs2_i),
    .instr_type_i(instruction_i.instr.instr_type),
    .result_o(alu_logic_result)
);

alu_count_zeros alu_count_zeros_inst (
    .data_rs1_i(data_rs1),
    .instr_type_i(instruction_i.instr.instr_type),
    .result_o(alu_count_zeros_result)
);

alu_count_pop alu_count_pop_inst (
    .data_rs1_i(data_rs1_extended),
    .result_o(alu_count_pop_result)
);


/* For Zbs extension the output from the shift module needs to be connected to
 * the input of the logic module
 */

always_comb begin
    case (instruction_i.instr.instr_type)
        BSET, BEXT, BINV: begin
            logic_rs2_i = alu_shift_result;
        end
        BCLR: begin
            logic_rs2_i = ~alu_shift_result;
        end
        XNOR_INST, ORN, ANDN: begin
            logic_rs2_i = ~data_rs2;
        end
        default: begin
            logic_rs2_i = data_rs2;
        end
    endcase
end

always_comb begin
    case (instruction_i.instr.instr_type)
        BEXT: begin
            logic_rs1_i = 64'b1;
        end
        default: begin
            logic_rs1_i = data_rs1;
        end
    endcase
end


bus64_t result_modules;
always_comb begin
    case (instruction_i.instr.instr_type)
        ADD, SUB, ADDW, SUBW, ADDUW, SH1ADD, SH1ADDUW, SH2ADD, SH2ADDUW, SH3ADD, SH3ADDUW: begin
            result_modules = alu_add_result;
        end
        SLL, SLLW, SRL, SRLW, SRA, SRAW, SLLIUW, ROR, ROL, RORW, ROLW: begin
            result_modules = alu_shift_result;
        end
        SLT, SLTU, MIN, MINU, MAX, MAXU: begin
            result_modules = alu_cmp_result;
        end
        AND_INST, OR_INST, XOR_INST, XNOR_INST, ORN, ANDN, ORCB, BSET, BCLR, BEXT, BINV: begin
            result_modules = alu_logic_result;
        end
        CLZ, CLZW, CTZ, CTZW: begin
            result_modules = alu_count_zeros_result;
        end
        CPOP, CPOPW: begin
            result_modules = alu_count_pop_result;
        end
        default: begin
            result_modules = 64'b0;
        end
    endcase
end


// Result
always_comb begin
    case (instruction_i.instr.instr_type)
        ADD, SUB, SLL, SRL, SRA, SLT, SLTU, AND_INST, OR_INST, XOR_INST, ADDUW, SLLIUW, SH1ADD, SH1ADDUW, SH2ADD, SH2ADDUW, SH3ADD, SH3ADDUW, XNOR_INST, ORN, ANDN, ROR, ROL, MIN, MINU, MAX, MAXU, ORCB, CLZ, CTZ, CPOP, BSET, BCLR, BEXT, BINV: begin
            instruction_o.result = result_modules;
        end
        ADDW, SUBW, SLLW, SRLW, SRAW, RORW, ROLW, CLZW, CTZW, CPOPW: begin
            instruction_o.result[63:32] = {32{result_modules[31]}};
            instruction_o.result[31:0] = result_modules[31:0];
        end
        ZEXTW, ZEXTH, SEXTH, SEXTB: begin
            instruction_o.result = data_rs1_extended;
        end
        REV8: begin
            instruction_o.result[63:56] = data_rs1[7:0];
            instruction_o.result[55:48] = data_rs1[15:8];
            instruction_o.result[47:40] = data_rs1[23:16];
            instruction_o.result[39:32] = data_rs1[31:24];
            instruction_o.result[31:24] = data_rs1[39:32];
            instruction_o.result[23:16] = data_rs1[47:40];
            instruction_o.result[15:8] = data_rs1[55:48];
            instruction_o.result[7:0] = data_rs1[63:56];
        end
        VSETVL, VSETVLI, VSETIVLI: begin
            instruction_o.result = {{(64-VMAXELEM_LOG-1){1'b0}}, instruction_i.instr.vl};
        end
        default: begin
            if (instruction_i.instr.unit == UNIT_SYSTEM)
                instruction_o.result = data_rs1;
            else
                instruction_o.result = 0;
        end
    endcase
end

//------------------------------------------------------------------------------
// METADATA TO WRITE_BACK
//------------------------------------------------------------------------------

assign instruction_o.valid           = instruction_i.instr.valid & ((instruction_i.instr.unit == UNIT_ALU) | (instruction_i.instr.unit == UNIT_SYSTEM));
assign instruction_o.pc              = instruction_i.instr.pc;
assign instruction_o.bpred           = instruction_i.instr.bpred;
assign instruction_o.rs1             = instruction_i.instr.rs1;
assign instruction_o.rd              = instruction_i.instr.rd;
assign instruction_o.regfile_we      = instruction_i.instr.regfile_we;
assign instruction_o.instr_type      = instruction_i.instr.instr_type;
assign instruction_o.stall_csr_fence = instruction_i.instr.stall_csr_fence;
assign instruction_o.csr_addr        = (instruction_i.instr.instr_type == VSETVL) ? vsetvl_csr_addr_int : instruction_i.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_o.prd             = instruction_i.prd;
assign instruction_o.checkpoint_done = instruction_i.checkpoint_done;
assign instruction_o.chkp            = instruction_i.chkp;
assign instruction_o.gl_index        = instruction_i.gl_index;
assign instruction_o.mem_type        = instruction_i.instr.mem_type;
assign instruction_o.branch_taken    = 1'b0;
assign instruction_o.result_pc       = 0;
assign instruction_o.vl              = instruction_i.vl;
assign instruction_o.sew             = instruction_i.instr.sew;
`ifdef SIM_KONATA_DUMP
assign instruction_o.id              = instruction_i.instr.id;
`endif
assign instruction_o.fp_status     = 'h0;
// Exceptions

always_comb begin
    instruction_o.ex.cause  = INSTR_ADDR_MISALIGNED;
    instruction_o.ex.origin = 0;
    instruction_o.ex.valid  = 0;
end

endmodule
//`default_nettype wire

