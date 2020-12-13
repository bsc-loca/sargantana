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
    input exe_wb_instr_t  exe_to_wb_wb_i,
    input  logic          stall_exe_i,
    // CSR interruption
    output logic          wb_csr_ena_int_o,
    // Request to CSR
    output req_cpu_csr_t  req_cpu_csr_o
);

bus64_t wb_csr_rw_data_int;
logic   wb_csr_ena_int;
csr_cmd_t wb_csr_cmd_int;

always_comb begin
    wb_csr_cmd_int = CSR_CMD_NOPE;
    wb_csr_rw_data_int = 64'b0;
    wb_csr_ena_int = 1'b0;
    if (exe_to_wb_wb_i.valid) begin
        case (exe_to_wb_wb_i.instr_type)
            CSRRW: begin
                wb_csr_cmd_int = CSR_CMD_WRITE;
                wb_csr_rw_data_int = exe_to_wb_wb_i.result;
                wb_csr_ena_int = 1'b1;
            end
            CSRRS: begin
                wb_csr_cmd_int = (exe_to_wb_wb_i.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                wb_csr_rw_data_int = exe_to_wb_wb_i.result;
                wb_csr_ena_int = 1'b1;
            end
            CSRRC: begin
                wb_csr_cmd_int = (exe_to_wb_wb_i.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                wb_csr_rw_data_int = exe_to_wb_wb_i.result;
                wb_csr_ena_int = 1'b1;
            end
            CSRRWI: begin
                wb_csr_cmd_int = CSR_CMD_WRITE;
                wb_csr_rw_data_int = {59'b0,exe_to_wb_wb_i.rs1};
                wb_csr_ena_int = 1'b1;
            end
            CSRRSI: begin
                wb_csr_cmd_int = (exe_to_wb_wb_i.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                wb_csr_rw_data_int = {59'b0,exe_to_wb_wb_i.rs1};
                wb_csr_ena_int = 1'b1;
            end
            CSRRCI: begin
                wb_csr_cmd_int = (exe_to_wb_wb_i.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                wb_csr_rw_data_int = {59'b0,exe_to_wb_wb_i.rs1};
                wb_csr_ena_int = 1'b1;
            end
            ECALL,
            EBREAK,
            URET,
            SRET,
            MRET,
            WFI,
            SFENCE_VMA,
            MRTS: begin
                wb_csr_cmd_int = CSR_CMD_SYS;
                wb_csr_rw_data_int = 64'b0;
                wb_csr_ena_int = 1'b1;
            end
            default: begin
                `ifdef ASSERTIONS
                   assert (1 == 0);
                `endif
                 wb_csr_ena_int = 1'b0;
            end
        endcase
    end
end

// CSR and Exceptions
assign req_cpu_csr_o.csr_rw_addr = (wb_csr_ena_int) ? exe_to_wb_wb_i.csr_addr : {CSR_ADDR_SIZE{1'b0}};
// if csr not enabled send command NOP
assign req_cpu_csr_o.csr_rw_cmd = (wb_csr_ena_int) ? wb_csr_cmd_int : CSR_CMD_NOPE;
// if csr not enabled send the interesting addr that you are accesing, exception help
assign req_cpu_csr_o.csr_rw_data = (wb_csr_ena_int) ? wb_csr_rw_data_int : exe_to_wb_wb_i.ex.origin;

assign req_cpu_csr_o.csr_exception = wb_xcpt_i;

// if we can retire an instruction
//assign req_cpu_csr_o.csr_retire = exe_to_wb_wb_i.valid && !wb_xcpt_i;
assign req_cpu_csr_o.csr_retire = exe_to_wb_wb_i.valid && !wb_xcpt_i && !stall_exe_i;
// if there is a csr interrupt we take the interrupt?
assign req_cpu_csr_o.csr_xcpt_cause = exe_to_wb_wb_i.ex.cause;
assign req_cpu_csr_o.csr_pc = exe_to_wb_wb_i.pc;
// CSR interruption
assign wb_csr_ena_int_o = wb_csr_ena_int;

endmodule
//`default_nettype wire

