import drac_pkg::*;

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
 * -----------------------------------------------
 */
 
// Interface with CSR

module csr_interface (
    // Datapath signals
    input  logic          commit_xcpt_i,
    input exe_wb_instr_t  instruction_to_commit_i,
    input  logic          stall_exe_i,
    // CSR interruption
    output logic          csr_ena_int_o,
    // Request to CSR
    output req_cpu_csr_t  req_cpu_csr_o
);

bus64_t csr_rw_data_int;
logic   csr_ena_int;
csr_cmd_t csr_cmd_int;


always_comb begin
    csr_cmd_int = CSR_CMD_NOPE;
    csr_rw_data_int = 64'b0;
    csr_ena_int = 1'b0;
    if (instruction_to_commit_i.valid) begin
        case (instruction_to_commit_i.instr_type)
            CSRRW: begin
                csr_cmd_int = CSR_CMD_WRITE;
                csr_rw_data_int = instruction_to_commit_i.result;
                csr_ena_int = 1'b1;
            end
            CSRRS: begin
                csr_cmd_int = (instruction_to_commit_i.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                csr_rw_data_int = instruction_to_commit_i.result;
                csr_ena_int = 1'b1;
            end
            CSRRC: begin
                csr_cmd_int = (instruction_to_commit_i.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                csr_rw_data_int = instruction_to_commit_i.result;
                csr_ena_int = 1'b1;
            end
            CSRRWI: begin
                csr_cmd_int = CSR_CMD_WRITE;
                csr_rw_data_int = {59'b0,instruction_to_commit_i.rs1};
                csr_ena_int = 1'b1;
            end
            CSRRSI: begin
                csr_cmd_int = (instruction_to_commit_i.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                csr_rw_data_int = {59'b0,instruction_to_commit_i.rs1};
                csr_ena_int = 1'b1;
            end
            CSRRCI: begin
                csr_cmd_int = (instruction_to_commit_i.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                csr_rw_data_int = {59'b0,instruction_to_commit_i.rs1};
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
            default: begin
                `ifdef ASSERTIONS
                   assert (1 == 0);
                `endif
                 csr_ena_int = 1'b0;
            end
        endcase
    end
end

// CSR and Exceptions
assign req_cpu_csr_o.csr_rw_addr = (csr_ena_int) ? instruction_to_commit_i.csr_addr : {CSR_ADDR_SIZE{1'b0}};
// if csr not enabled send command NOP
assign req_cpu_csr_o.csr_rw_cmd = (csr_ena_int) ? csr_cmd_int : CSR_CMD_NOPE;
// if csr not enabled send the interesting addr that you are accesing, exception help
assign req_cpu_csr_o.csr_rw_data = (csr_ena_int) ? csr_rw_data_int : : (~commit_store_or_amo_int)? instruction_to_commit_i.exception.origin : exception_mem_commit_int.origin;

assign req_cpu_csr_o.csr_exception = commit_xcpt_i;

// if we can retire an instruction
assign req_cpu_csr_o.csr_retire = instruction_to_commit_i.valid && !commit_xcpt_i && && (!commit_store_or_amo_int | !mem_commit_stall_int); //!stall_exe_i;
// if there is a csr interrupt we take the interrupt?
assign req_cpu_csr_o.csr_xcpt_cause = (~commit_store_or_amo_int)? instruction_to_commit_i.exception.cause : exception_mem_commit_int.cause;
assign req_cpu_csr_o.csr_pc = instruction_to_commit_i.pc;
// CSR interruption
assign csr_ena_int_o = csr_ena_int;

endmodule
