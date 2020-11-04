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
    input  logic          wb_csr_ena_int_i,
    input  exe_wb_instr_t exe_to_wb_wb_i,
    input  csr_cmd_t      wb_csr_cmd_int_i,
    input  bus64_t        wb_csr_rw_data_int_i,
    input  logic          wb_xcpt_i,

    // Request to CSR
    output req_cpu_csr_t  req_cpu_csr_o
);

// CSR and Exceptions
assign req_cpu_csr_o.csr_rw_addr = (wb_csr_ena_int_i) ? exe_to_wb_wb_i.csr_addr : {CSR_ADDR_SIZE{1'b0}};
// if csr not enabled send command NOP
assign req_cpu_csr_o.csr_rw_cmd = (wb_csr_ena_int_i) ? wb_csr_cmd_int_i : CSR_CMD_NOPE;
// if csr not enabled send the interesting addr that you are accesing, exception help
assign req_cpu_csr_o.csr_rw_data = (wb_csr_ena_int_i) ? wb_csr_rw_data_int_i : exe_to_wb_wb_i.ex.origin;

assign req_cpu_csr_o.csr_exception = wb_xcpt_i;

// if we can retire an instruction
assign req_cpu_csr_o.csr_retire = exe_to_wb_wb_i.valid && !wb_xcpt_i;
// if there is a csr interrupt we take the interrupt?
assign req_cpu_csr_o.csr_xcpt_cause = exe_to_wb_wb_i.ex.cause;
assign req_cpu_csr_o.csr_pc = exe_to_wb_wb_i.pc;

endmodule
//`default_nettype wire

