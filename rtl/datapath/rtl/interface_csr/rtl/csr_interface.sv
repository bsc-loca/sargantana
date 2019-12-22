//`default_nettype none
//`include "drac_pkg.sv"
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
    input  logic          wb_xcpt_i,
    input exe_wb_instr_t  instruction_gl_commit,
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
    if (instruction_gl_commit.valid) begin
        case (instruction_gl_commit.instr_type)
            CSRRW: begin
                csr_cmd_int = CSR_CMD_WRITE;
                csr_rw_data_int = instruction_gl_commit.result;
                csr_ena_int = 1'b1;
            end
            CSRRS: begin
                csr_cmd_int = (instruction_gl_commit.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                csr_rw_data_int = instruction_gl_commit.result;
                csr_ena_int = 1'b1;
            end
            CSRRC: begin
                csr_cmd_int = (instruction_gl_commit.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                csr_rw_data_int = instruction_gl_commit.result;
                csr_ena_int = 1'b1;
            end
            CSRRWI: begin
                csr_cmd_int = CSR_CMD_WRITE;
                csr_rw_data_int = {59'b0,instruction_gl_commit.rs1};
                csr_ena_int = 1'b1;
            end
            CSRRSI: begin
                csr_cmd_int = (instruction_gl_commit.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                csr_rw_data_int = {59'b0,instruction_gl_commit.rs1};
                csr_ena_int = 1'b1;
            end
            CSRRCI: begin
                csr_cmd_int = (instruction_gl_commit.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                csr_rw_data_int = {59'b0,instruction_gl_commit.rs1};
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
assign req_cpu_csr_o.csr_rw_addr = (csr_ena_int) ? instruction_gl_commit.csr_addr : {CSR_ADDR_SIZE{1'b0}};
// if csr not enabled send command NOP
assign req_cpu_csr_o.csr_rw_cmd = (csr_ena_int) ? csr_cmd_int : CSR_CMD_NOPE;
// if csr not enabled send the interesting addr that you are accesing, exception help
assign req_cpu_csr_o.csr_rw_data = (csr_ena_int) ? csr_rw_data_int : instruction_gl_commit.ex.origin;

assign req_cpu_csr_o.csr_exception = wb_xcpt_i;

// if we can retire an instruction
//assign req_cpu_csr_o.csr_retire = exe_to_wb_wb_i.valid && !wb_xcpt_i;
assign req_cpu_csr_o.csr_retire = instruction_gl_commit.valid && !wb_xcpt_i && !stall_exe_i;
// if there is a csr interrupt we take the interrupt?
assign req_cpu_csr_o.csr_xcpt_cause = instruction_gl_commit.ex.cause;
assign req_cpu_csr_o.csr_pc = instruction_gl_commit.pc;
// CSR interruption
assign csr_ena_int_o = csr_ena_int;

endmodule

