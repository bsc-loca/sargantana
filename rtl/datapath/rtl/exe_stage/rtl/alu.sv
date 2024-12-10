/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : execution.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
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

function [31:0] trunc_65_32(input [64:0] val_in);
  trunc_65_32 = val_in[31:0];
endfunction

function [63:0] trunc_127_64(input [126:0] val_in);
  trunc_127_64 = val_in[63:0];
endfunction

// Operation

always_comb begin
    case (instruction_i.instr.instr_type)
        ADD: begin
            instruction_o.result = trunc_65_64(data_rs1 + data_rs2);
        end
        ADDW: begin
            instruction_o.result[31:0] = trunc_33_32(data_rs1[31:0] + data_rs2[31:0]);
            instruction_o.result[63:32] = {32{instruction_o.result[31]}};
        end
        SUB: begin
            instruction_o.result = trunc_65_64(data_rs1 - data_rs2);
        end
        SUBW: begin
            instruction_o.result[31:0] = trunc_33_32(data_rs1[31:0] - data_rs2[31:0]);
            instruction_o.result[63:32] = {32{instruction_o.result[31]}};
        end
        SLL: begin
            instruction_o.result = (data_rs1 << data_rs2[5:0]);
        end
        SLLW: begin
            instruction_o.result[31:0] = (data_rs1[31:0] << data_rs2[4:0]);
            instruction_o.result[63:32] = {32{instruction_o.result[31]}};
        end
        SLT: begin
            instruction_o.result = {63'b0, $signed(data_rs1) < $signed(data_rs2)};
        end
        SLTU: begin
            instruction_o.result = {63'b0, data_rs1 < data_rs2};
        end
        XOR_INST: begin
            instruction_o.result = data_rs1 ^ data_rs2;
        end
        SRL: begin
            instruction_o.result = data_rs1 >> data_rs2[5:0];
        end
        SRLW: begin
            instruction_o.result[31:0] = data_rs1[31:0] >> data_rs2[4:0];
            instruction_o.result[63:32] = {32{instruction_o.result[31]}};
        end
        SRA: begin
            instruction_o.result = $signed(data_rs1) >>> data_rs2[5:0];
        end
        SRAW: begin
            instruction_o.result[31:0] = $signed(data_rs1[31:0]) >>> data_rs2[4:0];
            instruction_o.result[63:32] = {32{instruction_o.result[31]}};
        end
        OR_INST: begin
            instruction_o.result = data_rs1 | data_rs2;
        end
        AND_INST: begin
            instruction_o.result = data_rs1 & data_rs2;
        end
        VSETIVLI: begin
            instruction_o.result = {32'b0, instruction_i.instr.imm[63:32]};
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

