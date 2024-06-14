/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : csr_interface.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author     | Description
 *  0.1        | Ruben. L   |
 *  0.2        | V. Soria P.| Adapt to Sargantana 
 * -----------------------------------------------
 */
 
// Interface of Data Path with CSR

module csr_interface
    import drac_pkg::*;
(
    // Datapath signals
    input  logic            commit_xcpt_i,            // Exception at Commit
    input  bus64_t          result_gl_i,
    input  reg_csr_addr_t   csr_addr_gl_i,
    input  reg_csr_addr_t   vsetvl_vtype_i,
    input  logic [VMAXELEM_LOG:0] vleff_vl_i,
    input  gl_instruction_t [1:0] instruction_to_commit_i,  // Instruction to be Committed
    input  logic            stall_exe_i,              // Exe Stage is Stalled
    input  logic            commit_store_or_amo_i,    // The Commit Instruction is AMO or STORE
    input  logic            mem_commit_stall_i,       // The Commit Instruction is Stalled at Mem Stage
    input  exception_t      exception_mem_commit_i,   // The Exception comming from AMO or STORE
    input  exception_t      exception_gl_i,
    // CSR Debug
    input  logic            debug_pc_valid_i,         // PC to CSRs is set as next_PC for debugging porpuses
    input  bus64_t          debug_pc_i,
    input  logic            debug_mode_en_i,  
    // CSR interruption
    output logic            csr_ena_int_o,            // Enable CSR petition
    // Request to CSR
    output req_cpu_csr_t    req_cpu_csr_o,             // Request to the CSRs
    output logic [1:0]      retire_inst_o
);

bus64_t csr_rw_data_int;
logic   csr_ena_int;
csr_cmd_t csr_cmd_int;
csr_addr_t csr_addr_int;
logic commit_2_blocked;


always_comb begin
    csr_cmd_int = CSR_CMD_NOPE;
    csr_rw_data_int = 64'b0;
    csr_ena_int = 1'b0;
    csr_addr_int = csr_addr_gl_i;
    if (instruction_to_commit_i[0].valid && !instruction_to_commit_i[0].ex_valid) begin
        case (instruction_to_commit_i[0].instr_type)
            CSRRW: begin
                csr_cmd_int = (instruction_to_commit_i[0].rd == 'h0) ? CSR_CMD_WRITE : CSR_CMD_RW;
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
                csr_cmd_int = (instruction_to_commit_i[0].rd == 'h0) ? CSR_CMD_WRITE : CSR_CMD_RW;
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
            VSETVLI: begin
                csr_cmd_int = (instruction_to_commit_i[0].rs1 == 'h0) ? CSR_CMD_VSETVLMAX : CSR_CMD_VSETVL;
                csr_rw_data_int = result_gl_i; //(instruction_to_commit_i[0].rs1 == 'h0 && instruction_to_commit_i[0].rd == 'h0) ? 64'b1 : result_gl_i;
                csr_ena_int = 1'b1;
            end
            VSETVL: begin
                csr_cmd_int = (instruction_to_commit_i[0].rs1 == 'h0) ? CSR_CMD_VSETVLMAX : CSR_CMD_VSETVL;
                csr_rw_data_int = ((instruction_to_commit_i[0].rs1 == 'h0) && (instruction_to_commit_i[0].rd == 'h0)) ? 64'b1 : result_gl_i;
                csr_ena_int = 1'b1;
                csr_addr_int = vsetvl_vtype_i;
            end
            VSETIVLI: begin
                csr_cmd_int = CSR_CMD_VSETVL;
                csr_rw_data_int = result_gl_i;
                csr_ena_int = 1'b1;
            end
            VLEFF: begin
                csr_cmd_int = CSR_CMD_VLEFF;
                csr_rw_data_int = {{(64-VMAXELEM_LOG-1){1'b0}}, vleff_vl_i};
                csr_ena_int = (vleff_vl_i == 'h0) ? 1'b0 : 1'b1;
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
    assign commit_2_blocked = ((((((!instruction_to_commit_i[0].valid) ||
                                    instruction_to_commit_i[0].ex_valid) ||
                                    csr_ena_int) || (!instruction_to_commit_i[1].valid)) ||
                                    (instruction_to_commit_i[1].valid &
                                    ((((((((((((((((((((instruction_to_commit_i[1].instr_type == ECALL) ||
                                    (instruction_to_commit_i[1].instr_type == SRET)) ||
                                    (instruction_to_commit_i[1].instr_type == MRET)) ||
                                    (instruction_to_commit_i[1].instr_type == URET)) ||
                                    (instruction_to_commit_i[1].instr_type == WFI)) ||
                                    (instruction_to_commit_i[1].instr_type == EBREAK)) ||
                                    (instruction_to_commit_i[1].instr_type == FENCE)) ||
                                    (instruction_to_commit_i[1].instr_type == SFENCE_VMA)) ||
                                    (instruction_to_commit_i[1].instr_type == FENCE_I)) ||
                                    (instruction_to_commit_i[1].instr_type == CSRRW)) ||
                                    (instruction_to_commit_i[1].instr_type == CSRRS)) ||
                                    (instruction_to_commit_i[1].instr_type == CSRRC)) ||
                                    (instruction_to_commit_i[1].instr_type == CSRRWI)) ||
                                    (instruction_to_commit_i[1].instr_type == CSRRSI)) ||
                                    (instruction_to_commit_i[1].instr_type == CSRRCI)) ||
                                    (instruction_to_commit_i[1].instr_type == VSETVL)) ||
                                    (instruction_to_commit_i[1].instr_type == VSETVLI)) ||
                                    (instruction_to_commit_i[1].mem_type == STORE)) ||
                                    (instruction_to_commit_i[1].mem_type == AMO)) ||
                                    instruction_to_commit_i[1].stall_csr_fence))) ||
                                    (instruction_to_commit_i[1].valid & instruction_to_commit_i[1].ex_valid));

// CSR and Exceptions
assign req_cpu_csr_o.csr_rw_addr = (csr_ena_int) ? csr_addr_int : {CSR_ADDR_SIZE{1'b0}};
// if csr not enabled send command NOP
assign req_cpu_csr_o.csr_rw_cmd = (csr_ena_int) ? csr_cmd_int : CSR_CMD_NOPE;
// if csr not enabled send the interesting addr that you are accesing, exception help
assign req_cpu_csr_o.csr_rw_data = csr_rw_data_int;

assign req_cpu_csr_o.csr_exception = commit_xcpt_i && !debug_mode_en_i;

assign req_cpu_csr_o.fp_status = (({instruction_to_commit_i[0].fp_status.NV,
                                    instruction_to_commit_i[0].fp_status.DZ,
                                    instruction_to_commit_i[0].fp_status.OF,
                                    instruction_to_commit_i[0].fp_status.UF,
                                    instruction_to_commit_i[0].fp_status.NX} & {5 {retire_inst_o[0]}}) |
                                    ({instruction_to_commit_i[1].fp_status.NV,
                                    instruction_to_commit_i[1].fp_status.DZ,
                                    instruction_to_commit_i[1].fp_status.OF,
                                    instruction_to_commit_i[1].fp_status.UF,
                                    instruction_to_commit_i[1].fp_status.NX} & {5 {retire_inst_o[1]}}));

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
// Vector saturating instructions that overflow set the VXSAT CSR
assign req_cpu_csr_o.csr_vxsat = ((retire_inst_o[0] & instruction_to_commit_i[0].vs_ovf) | (retire_inst_o[1] & instruction_to_commit_i[1].vs_ovf));  
// if there is a csr interrupt we take the interrupt?
assign req_cpu_csr_o.csr_xcpt_cause = (~commit_store_or_amo_i)? exception_gl_i.cause : exception_mem_commit_i.cause;
assign req_cpu_csr_o.csr_xcpt_origin = (~commit_store_or_amo_i)? exception_gl_i.origin : exception_mem_commit_i.origin;
assign req_cpu_csr_o.csr_pc = (debug_pc_valid_i) ? debug_pc_i : instruction_to_commit_i[0].pc;
// CSR interruption
assign csr_ena_int_o = csr_ena_int;
// Notify the CSR if the retiring instructions modify the FP regfile
assign req_cpu_csr_o.freg_modified = ((retire_inst_o[0] & instruction_to_commit_i[0].fregfile_we) | (retire_inst_o[1] & instruction_to_commit_i[1].fregfile_we));

endmodule
