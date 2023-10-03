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

assign data_rs1 = instruction_i.data_rs1;
assign data_rs2 = instruction_i.data_rs2;

// Operation

always_comb begin
    case (instruction_i.instr.instr_type)
        ADD: begin
            instruction_o.result = data_rs1 + data_rs2;
        end
        ADDW: begin
            instruction_o.result[31:0] = data_rs1[31:0] + data_rs2[31:0];
            instruction_o.result[63:32] = {32{instruction_o.result[31]}};
        end
        SUB: begin
            instruction_o.result = data_rs1 - data_rs2;
        end
        SUBW: begin
            instruction_o.result[31:0] = data_rs1[31:0] - data_rs2[31:0];
            instruction_o.result[63:32] = {32{instruction_o.result[31]}};
        end
        SLL: begin
            instruction_o.result = data_rs1 << data_rs2[5:0];
        end
        SLLW: begin
            instruction_o.result[31:0] = data_rs1[31:0] << data_rs2[4:0];
            instruction_o.result[63:32] = {32{instruction_o.result[31]}};
        end
        SLT: begin
            instruction_o.result = {63'b0, $signed(data_rs1) < $signed(data_rs2)};
        end
        SLTU: begin
            instruction_o.result = {63'b0, data_rs1 < data_rs2};
        end
        XOR: begin
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
        OR: begin
            instruction_o.result = data_rs1 | data_rs2;
        end
        AND: begin
            instruction_o.result = data_rs1 & data_rs2;
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

assign instruction_o.valid           = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_ALU | instruction_i.instr.unit == UNIT_SYSTEM);
assign instruction_o.pc              = instruction_i.instr.pc;
assign instruction_o.bpred           = instruction_i.instr.bpred;
assign instruction_o.rs1             = instruction_i.instr.rs1;
assign instruction_o.rd              = instruction_i.instr.rd;
assign instruction_o.change_pc_ena   = instruction_i.instr.change_pc_ena;
assign instruction_o.regfile_we      = instruction_i.instr.regfile_we;
assign instruction_o.instr_type      = instruction_i.instr.instr_type;
assign instruction_o.stall_csr_fence = instruction_i.instr.stall_csr_fence;
assign instruction_o.csr_addr        = instruction_i.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_o.prd             = instruction_i.prd;
assign instruction_o.checkpoint_done = instruction_i.checkpoint_done;
assign instruction_o.chkp            = instruction_i.chkp;
assign instruction_o.gl_index        = instruction_i.gl_index;
assign instruction_o.mem_type        = instruction_i.instr.mem_type;
assign instruction_o.branch_taken    = 1'b0;
assign instruction_o.result_pc       = 0;
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

