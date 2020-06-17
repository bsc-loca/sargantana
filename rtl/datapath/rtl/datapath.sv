/* -----------------------------------------------
* Project Name   : DRAC
* File           : datapath.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

import drac_pkg::*;
import riscv_pkg::*;

module datapath(
    input logic             clk_i,
    input logic             rstn_i,
    input addr_t            reset_addr_i,
    input logic             soft_rstn_i,
    // icache/dcache interface
    // naming could be improved
    input resp_icache_cpu_t  resp_icache_cpu_i,
    input resp_dcache_cpu_t  resp_dcache_cpu_i,
    input resp_csr_cpu_t     resp_csr_cpu_i,

    output req_cpu_dcache_t req_cpu_dcache_o, 
    output req_cpu_icache_t req_cpu_icache_o,
    output req_cpu_csr_t    req_cpu_csr_o
);
// RISCV TESTS

`ifdef VERILATOR
    // Stages: if -- id -- rr -- ex -- wb
    bus64_t commit_pc, commit_data;
    logic commit_valid, commit_reg_we;
    logic [4:0] commit_addr_reg;
    logic commit_branch_taken;
`endif

    bus64_t pc_if, pc_id, pc_rr, pc_exe, pc_wb;
    logic valid_if, valid_id, valid_rr, valid_exe, valid_wb;

    pipeline_ctrl_t control_int;
    pipeline_flush_t flush_int;
    cu_if_t cu_if_int;
    addrPC_t pc_jump_if_int;

    
    // Pipelines stages data
    // Fetch
    if_id_stage_t stage_if_id_d; // this is the saving in the current cycle
    if_id_stage_t stage_if_id_q; // this is the next or output of reg
    logic invalidate_icache_int;
    logic invalidate_buffer_int;
    logic retry_fetch;
    // Decode
    instr_entry_t stage_id_rr_d;
    instr_entry_t stage_id_rr_q;
    // RR
    rr_exe_instr_t stage_rr_exe_d;
    rr_exe_instr_t stage_rr_exe_q;

    // Control Unit Decode
    id_cu_t id_cu_int;
    jal_id_if_t jal_id_if_int;

    // Exe
    logic stall_exe_out;
    /* verilator lint_off UNOPTFLAT */
    exe_cu_t exe_cu_int;
    /* verilator lint_on UNOPTFLAT */
    exe_wb_instr_t exe_to_wb_exe;
    exe_wb_instr_t exe_to_wb_wb;

    exe_if_branch_pred_t exe_if_branch_pred_int;   

    wb_exe_instr_t wb_to_exe_exe;
    logic wb_xcpt;

    reg_addr_t io_base_addr;

    // WB->Commit
    wb_cu_t wb_cu_int;
    rr_cu_t rr_cu_int;
    cu_rr_t cu_rr_int;

    // wb csr
    bus64_t wb_csr_rw_data_int;
    logic   wb_csr_ena_int;
    csr_cmd_t wb_csr_cmd_int;


    // data to write to RR from wb
    bus64_t data_wb_rr_int;

    // codifies if the branch was correctly predicted 
    // this signal goes from exe stage to fetch stage
    logic correct_branch_pred;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            io_base_addr <=  40'h0040000000;
        end else if(!soft_rstn_i) begin
            io_base_addr <=  40'h0080000000;
        end else begin 
            io_base_addr <= io_base_addr;
        end
    end

    // Control Unit
    control_unit control_unit_inst(
        .valid_fetch(resp_icache_cpu_i.valid),
        .rr_cu_i(rr_cu_int),
        .cu_rr_o(cu_rr_int),
        .wb_cu_i(wb_cu_int),
        .exe_cu_i(exe_cu_int),
        .csr_cu_i(resp_csr_cpu_i),
        .pipeline_ctrl_o(control_int),
        .pipeline_flush_o(flush_int),
        .cu_if_o(cu_if_int),
        .invalidate_icache_o(invalidate_icache_int),
        .invalidate_buffer_o(invalidate_buffer_int),
        .id_cu_i(id_cu_int),
        .correct_branch_pred_i(correct_branch_pred)
    );

    // Combinational logic select the jum addr
    // from decode, wb 
    always_comb begin
        retry_fetch = 1'b0;
        if (control_int.sel_addr_if == SEL_JUMP_EXECUTION) begin
            pc_jump_if_int = exe_to_wb_exe.result_pc;
        end else if (control_int.sel_addr_if == SEL_JUMP_CSR) begin
            pc_jump_if_int = resp_csr_cpu_i.csr_evec;
            retry_fetch = 1'b1;
        end else begin
            pc_jump_if_int = jal_id_if_int.jump_addr;
        end
    end

    // IF Stage
    if_stage if_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .reset_addr_i(reset_addr_i),
        .stall_i(control_int.stall_if),
        .cu_if_i(cu_if_int),
        .invalidate_icache_i(invalidate_icache_int),
        .invalidate_buffer_i(invalidate_buffer_int),
        .pc_jump_i(pc_jump_if_int),
        .resp_icache_cpu_i(resp_icache_cpu_i),
        .retry_fetch_i(retry_fetch),
        .req_cpu_icache_o(req_cpu_icache_o),
        .fetch_o(stage_if_id_d),
        .exe_if_branch_pred_i(exe_if_branch_pred_int)
    );

    // Register IF to ID
    register #($bits(if_id_stage_t)) reg_if_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_if),
        .load_i(!control_int.stall_if),
        .input_i(stage_if_id_d),
        .output_o(stage_if_id_q)
    );

    // ID Stage
    decoder id_decode_inst(
        .decode_i(stage_if_id_q),
        .decode_instr_o(stage_id_rr_d),
        .jal_id_if_o(jal_id_if_int)
    );
    // valid jal in decode
    assign id_cu_int.valid_jal = jal_id_if_int.valid;
    assign id_cu_int.stall_csr_fence = stage_id_rr_d.stall_csr_fence && stage_id_rr_d.valid;

    // Register ID to RR
    register #($bits(instr_entry_t)) reg_id_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_id),
        .load_i(!control_int.stall_id),
        .input_i(stage_id_rr_d),
        .output_o(stage_id_rr_q)
    );

    // RR Stage
    regfile rr_stage_inst(
        .clk_i(clk_i),

        .write_enable_i(cu_rr_int.write_enable),
        .write_addr_i(exe_to_wb_wb.rd),
        .write_data_i(data_wb_rr_int),
        .read_addr1_i(stage_id_rr_q.rs1),
        .read_addr2_i(stage_id_rr_q.rs2),
        .read_data1_o(stage_rr_exe_d.data_rs1),
        .read_data2_o(stage_rr_exe_d.data_rs2)
    );

    assign stage_rr_exe_d.instr = stage_id_rr_q;

    assign rr_cu_int.stall_csr_fence = stage_rr_exe_d.instr.stall_csr_fence && stage_rr_exe_d.instr.valid;

    // Register RR to EXE
    register #($bits(stage_rr_exe_d)) reg_rr_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_rr),
        .load_i(!control_int.stall_rr),
        .input_i(stage_rr_exe_d),
        .output_o(stage_rr_exe_q)
    );

    exe_stage exe_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .kill_i(flush_int.flush_exe),
        .csr_interrupt_i(resp_csr_cpu_i.csr_interrupt),
        .csr_interrupt_cause_i(resp_csr_cpu_i.csr_interrupt_cause),

        .from_rr_i(stage_rr_exe_q),
        .from_wb_i(wb_to_exe_exe),

        .resp_dcache_cpu_i(resp_dcache_cpu_i),
        .io_base_addr_i(io_base_addr),

        .to_wb_o(exe_to_wb_exe),
        .stall_o(exe_cu_int.stall),

        .req_cpu_dcache_o(req_cpu_dcache_o),
        .exe_if_branch_pred_o   (exe_if_branch_pred_int),
        .correct_branch_pred_o  (correct_branch_pred)
    );

    assign exe_cu_int.valid = stage_rr_exe_q.instr.valid;
    assign exe_cu_int.change_pc_ena = stage_rr_exe_q.instr.change_pc_ena;
    assign exe_cu_int.stall_csr_fence = stage_rr_exe_q.instr.stall_csr_fence && stage_rr_exe_q.instr.valid;

    register #($bits(exe_wb_instr_t)) reg_exe_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_exe),
        .load_i(!control_int.stall_exe),
        .input_i(exe_to_wb_exe),
        .output_o(exe_to_wb_wb)
    );

    // WB
    // CSR
    // This could be placed in an outsite module
    always_comb begin
        wb_csr_cmd_int = CSR_CMD_NOPE;
        wb_csr_rw_data_int = 64'b0;
        wb_csr_ena_int = 1'b0;
        if (exe_to_wb_wb.valid) begin
            case (exe_to_wb_wb.instr_type)
                CSRRW: begin
                    wb_csr_cmd_int = CSR_CMD_WRITE;
                    wb_csr_rw_data_int = exe_to_wb_wb.result;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                CSRRS: begin
                    wb_csr_cmd_int = (exe_to_wb_wb.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                    wb_csr_rw_data_int = exe_to_wb_wb.result;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                CSRRC: begin
                    wb_csr_cmd_int = (exe_to_wb_wb.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                    wb_csr_rw_data_int = exe_to_wb_wb.result;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                CSRRWI: begin
                    wb_csr_cmd_int = CSR_CMD_WRITE;
                    wb_csr_rw_data_int = {59'b0,exe_to_wb_wb.rs1};
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                CSRRSI: begin
                    wb_csr_cmd_int = (exe_to_wb_wb.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                    wb_csr_rw_data_int = {59'b0,exe_to_wb_wb.rs1};
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                CSRRCI: begin
                    wb_csr_cmd_int = (exe_to_wb_wb.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                    wb_csr_rw_data_int = {59'b0,exe_to_wb_wb.rs1};  
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                ECALL: begin
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                EBREAK: begin
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                URET: begin
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                SRET: begin
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                MRET: begin
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                ERET: begin // Old ISA
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                FENCE: begin
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
                end
                MRTS: begin // Old ISA
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b1;//!resp_csr_cpu_i.csr_interrupt;
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
    assign req_cpu_csr_o.csr_rw_addr = (wb_csr_ena_int) ? exe_to_wb_wb.csr_addr : {CSR_ADDR_SIZE{1'b0}};
    // if csr not enabled send command NOP
    assign req_cpu_csr_o.csr_rw_cmd = (wb_csr_ena_int) ? wb_csr_cmd_int : CSR_CMD_NOPE;
    // if csr not enabled send the interesting addr that you are accesing, exception help
    assign req_cpu_csr_o.csr_rw_data = (wb_csr_ena_int) ? wb_csr_rw_data_int : exe_to_wb_wb.ex.origin;

    // if there is an exception that can be from:
    // the instruction itself or the interrupt
    assign wb_xcpt = exe_to_wb_wb.ex.valid;

    assign req_cpu_csr_o.csr_exception = wb_xcpt;

    // if we can retire an instruction
    assign req_cpu_csr_o.csr_retire = exe_to_wb_wb.valid && !wb_xcpt;
    // if there is a csr interrupt we take the interrupt?
    assign req_cpu_csr_o.csr_xcpt_cause = exe_to_wb_wb.ex.cause;
    assign req_cpu_csr_o.csr_pc = exe_to_wb_wb.pc;
    
    
    // data to write to regfile at WB from CSR or exe stage
    assign data_wb_rr_int = (wb_csr_ena_int) ?  resp_csr_cpu_i.csr_rw_rdata : 
                                                exe_to_wb_wb.result; 
     
    // For bypasses
    assign wb_to_exe_exe.valid  = exe_to_wb_wb.regfile_we && exe_to_wb_wb.valid;
    assign wb_to_exe_exe.rd     = exe_to_wb_wb.rd;
    assign wb_to_exe_exe.data   = data_wb_rr_int;

    // Control Unit
    assign wb_cu_int.valid = exe_to_wb_wb.valid;//; & !control_int.stall_wb; // and not flush???
    assign wb_cu_int.change_pc_ena = exe_to_wb_wb.change_pc_ena;
    assign wb_cu_int.csr_enable_wb = wb_csr_ena_int;
    assign wb_cu_int.stall_csr_fence = exe_to_wb_wb.stall_csr_fence && exe_to_wb_wb.valid;
    assign wb_cu_int.xcpt = wb_xcpt;
    assign wb_cu_int.write_enable = exe_to_wb_wb.regfile_we;
    assign wb_cu_int.ecall_taken = (exe_to_wb_wb.instr_type == ECALL ||
                                    exe_to_wb_wb.instr_type == MRTS  ||
                                    exe_to_wb_wb.instr_type == EBREAK );
    // tell cu that there is a fence
    assign wb_cu_int.fence = (exe_to_wb_wb.instr_type == FENCE_I || 
                              exe_to_wb_wb.instr_type == FENCE);

`ifdef VERILATOR
    // Debug signals
    assign commit_valid     = exe_to_wb_wb.valid;
    assign commit_pc        = (exe_to_wb_wb.valid) ? exe_to_wb_wb.pc : 64'b0;
    assign commit_data      = (exe_to_wb_wb.valid) ? data_wb_rr_int  : 64'b0;
    assign commit_addr_reg  = exe_to_wb_wb.rd;
    assign commit_reg_we    = exe_to_wb_wb.regfile_we && exe_to_wb_wb.valid;
    assign commit_branch_taken = exe_to_wb_wb.branch_taken;
`endif

    // PC
    assign pc_if = (valid_if) ? stage_if_id_d.pc_inst : 64'b0;
    assign pc_id = (valid_id) ? stage_id_rr_d.pc : 64'b0;
    assign pc_rr = (valid_rr) ? stage_rr_exe_d.instr.pc : 64'b0;
    assign pc_exe = (valid_exe) ? stage_rr_exe_q.instr.pc : 64'b0;
    assign pc_wb = (valid_wb) ? exe_to_wb_wb.pc : 64'b0;
    // Valid
    assign valid_if = stage_if_id_d.valid;
    assign valid_id = stage_id_rr_d.valid;
    assign valid_rr = stage_rr_exe_d.instr.valid;
    assign valid_exe = stage_rr_exe_q.instr.valid;
    assign valid_wb = exe_to_wb_wb.valid;

    // Module that generates the signature of the core to compare with spike
    `ifdef VERILATOR_TORTURE_TESTS
    torture_dump_behav torture_dump
    (
        .clk(clk_i),
        .rst(rstn_i),
        .commit_valid(commit_valid),
        .reg_wr_valid(cu_rr_int.write_enable && (commit_addr_reg != 5'b0)),
        .pc(commit_pc),
        .inst(exe_to_wb_wb.inst),
        .reg_dst(commit_addr_reg),
        .data(commit_data)
    );
    `endif

endmodule
