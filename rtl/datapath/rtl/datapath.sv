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


    // Stages: if -- id -- rr -- ex -- wb
    // Signals stalls to be coming from the control unit
    /*logic stall_if_int;
    logic stall_id_int;
    logic stall_rr_int;
    logic stall_exe_int;
    logic stall_wb_int;
    assign stall_if_int = '0;
    assign stall_id_int = '0;
    assign stall_rr_int = '0;
    assign stall_exe_int = '0;
    assign stall_wb_int = '0;*/

    bus64_t commit_pc, commit_data;
    logic commit_valid, commit_reg_we;
    logic [4:0] commit_addr_reg;
    logic commit_branch_taken;
    bus64_t pc_if, pc_id, pc_rr, pc_exe, pc_wb;
    logic valid_if, valid_id, valid_rr, valid_exe, valid_wb;

    pipeline_ctrl_t control_int;
    cu_if_t cu_if_int;
    // TODO: Remove Stage IF stub
    //next_pc_sel_t next_pc_sel_if_int;
    addrPC_t pc_jump_if_int;

    
    //assign next_pc_sel_if_int = NEXT_PC_SEL_PC_4;
    // Pipelines stages data
    // Fetch
    if_id_stage_t stage_if_id_d; // this is the saving in the current cycle
    if_id_stage_t stage_if_id_q; // this is the next or output of reg
    // Decode
    instr_entry_t stage_id_rr_d;
    instr_entry_t stage_id_rr_q;
    // RR
    rr_exe_instr_t stage_rr_exe_d;
    rr_exe_instr_t stage_rr_exe_q;
    // EXE
    //exe_wb_instr_t stage_exe_wb_d;
    //exe_wb_instr_t stage_exe_wb_q;
    // WB->Commit
    //exe_wb_instr_t stage_commit;
    wb_cu_t wb_cu_int;
    rr_cu_t rr_cu_int;
    cu_rr_t cu_rr_int;

    // Control Unit
    id_cu_t id_cu_int;
    jal_id_if_t jal_id_if_int;


    // Exe
    logic stall_exe_out;
    exe_cu_t exe_cu_int;
    exe_wb_instr_t exe_to_wb_exe;
    exe_wb_instr_t exe_to_wb_wb;
    // this can be inserted to rr_exe
    //dec_wb_instr_t dec_to_wb_exe;
    //dec_wb_instr_t dec_to_wb_wb;

    //rr_exe_instr_t stage_rr_exe_d;
    //rr_exe_instr_t stage_rr_exe_q;

    //dec_exe_instr_t dec_to_exe_exe;
    //rr_exe_instr_t rr_to_exe_exe;
    wb_exe_instr_t wb_to_exe_exe;
    logic wb_xcpt;

    reg_addr_t io_base_addr;

    // wb csr
    bus64_t wb_csr_rw_data_int;
    logic   wb_csr_ena_int;
    csr_cmd_t wb_csr_cmd_int;


    // data to write to RR from wb
    bus64_t data_wb_rr_int;


    // What is this????
    // TODO: Ruben
    always_ff @(posedge clk_i, negedge rstn_i, negedge soft_rstn_i) begin
        // What is that?????
        if(!soft_rstn_i) begin
            io_base_addr <=  40'h0080000000;
        end else if(~rstn_i) begin
            io_base_addr <=  40'h0040000000;
        end else begin 
            io_base_addr <= io_base_addr;
        end
    end

    // Control Unit
    control_unit control_unit_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .valid_fetch(resp_icache_cpu_i.valid),
        .rr_cu_i(rr_cu_int),
        .cu_rr_o(cu_rr_int),
        .wb_cu_i(wb_cu_int),
        .exe_cu_i(exe_cu_int),
        .csr_cu_i(resp_csr_cpu_i),
        .pipeline_ctrl_o(control_int),
        .cu_if_o(cu_if_int),
        .id_cu_i(id_cu_int)

    );

    // COmbinational logic select the jum addr
    // from decode, wb 
    always_comb begin
        if (control_int.sel_addr_if == SEL_JUMP_COMMIT) begin
            pc_jump_if_int = exe_to_wb_wb.result_pc;
        end else if (control_int.sel_addr_if == SEL_JUMP_CSR) begin
            pc_jump_if_int = resp_csr_cpu_i.csr_evec;
        end else begin
            pc_jump_if_int = jal_id_if_int.jump_addr;
        end
    end

    // Multiplexor select jump pc from decode or fetch
    //assign pc_jump_if_int = (control_int.sel_addr_if == SEL_JUMP_COMMIT) ? exe_to_wb_wb.result_pc : 
    //                                                    jal_id_if_int.jump_addr;

    // IF Stage
    if_stage if_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .stall_i(control_int.stall_if),
        .next_pc_sel_i(cu_if_int.next_pc),
        .pc_jump_i(pc_jump_if_int),
        .resp_icache_cpu_i(resp_icache_cpu_i),
        .req_cpu_icache_o(req_cpu_icache_o),
        .fetch_o(stage_if_id_d)
    );

    // Register IF to ID
    register #($bits(if_id_stage_t)) reg_if_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(control_int.flush_if),
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
    assign id_cu_int.stall_csr = stage_id_rr_d.stall_csr && stage_id_rr_d.valid;

    // Register ID to RR
    register #($bits(instr_entry_t)) reg_id_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(control_int.flush_id),
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

    //assign stage_rr_exe_d.rs1 = stage_id_rr_q.rs1;
    //assign stage_rr_exe_d.rs2 = stage_id_rr_q.rs2;
    assign stage_rr_exe_d.instr = stage_id_rr_q;

    assign rr_cu_int.stall_csr = stage_rr_exe_d.instr.stall_csr && stage_rr_exe_d.instr.valid;

    // Register RR to EXE
    register #($bits(stage_rr_exe_d)) reg_rr_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(control_int.flush_rr),
        .load_i(!control_int.stall_rr),
        .input_i(stage_rr_exe_d),
        .output_o(stage_rr_exe_q)
    );

    exe_top exe_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        // Not sure what they do
        .kill_i(1'b0),
        .csr_eret_i(1'b0),

        //.from_rr_i(dec_to_exe_exe),
        .from_rr_i(stage_rr_exe_q),
        .from_wb_i(wb_to_exe_exe),

        .resp_dcache_cpu_i(resp_dcache_cpu_i),
        .io_base_addr_i(io_base_addr),

        .to_wb_o(exe_to_wb_exe),
        .stall_o(exe_cu_int.stall),

        .req_cpu_dcache_o(req_cpu_dcache_o),
        .dmem_lock_o()
    );

    assign exe_cu_int.stall_csr = stage_rr_exe_q.instr.stall_csr && stage_rr_exe_q.instr.valid;

    register #($bits(exe_wb_instr_t)) reg_exe_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(control_int.flush_exe),
        .load_i(!control_int.stall_exe),
        .input_i(exe_to_wb_exe),
        .output_o(exe_to_wb_wb)
    );

    // WB
    // CSR
    //assign wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
    // TODO (guillemlp): add a module thatn handles this
    always_comb begin
        if (exe_to_wb_wb.instr.valid) begin
            case (exe_to_wb_wb.instr.instr_type)
                CSRRW: begin
                    wb_csr_cmd_int = CSR_CMD_WRITE;
                    wb_csr_rw_data_int = exe_to_wb_wb.result_rd;
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                CSRRS: begin
                    wb_csr_cmd_int = (exe_to_wb_wb.instr.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                    wb_csr_rw_data_int = exe_to_wb_wb.result_rd;
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                CSRRC: begin
                    wb_csr_cmd_int = (exe_to_wb_wb.instr.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                    wb_csr_rw_data_int = exe_to_wb_wb.result_rd;
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                CSRRWI: begin
                    wb_csr_cmd_int = CSR_CMD_WRITE;
                    wb_csr_rw_data_int = {59'b0,exe_to_wb_wb.instr.rs1};
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                CSRRSI: begin
                    wb_csr_cmd_int = (exe_to_wb_wb.instr.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                    wb_csr_rw_data_int = {59'b0,exe_to_wb_wb.instr.rs1};
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                CSRRCI: begin
                    // TODO (guillemlp) do we extend sign?
                    wb_csr_cmd_int = (exe_to_wb_wb.instr.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                    wb_csr_rw_data_int = {59'b0,exe_to_wb_wb.instr.rs1};  
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                ECALL: begin
                    // what happens if interrup and ecall?????
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    // TODO (guillemlp) check correctness
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                URET: begin
                    // what happens if interrup and ecall?????
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    // TODO (guillemlp) check correctness
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                SRET: begin
                    // what happens if interrup and ecall?????
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    // TODO (guillemlp) check correctness
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                MRET: begin
                    // what happens if interrup and ecall?????
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    // TODO (guillemlp) check correctness
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                ERET: begin
                    // what happens if interrup and ecall?????
                    wb_csr_cmd_int = CSR_CMD_SYS;
                    // TODO (guillemlp) check correctness
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = !resp_csr_cpu_i.csr_interrupt;
                end
                default: begin
                    wb_csr_cmd_int = CSR_CMD_NOPE;
                    wb_csr_rw_data_int = 64'b0;
                    wb_csr_ena_int = 1'b0;
                end
            endcase // exe_to_wb_wb.instr.instr_type
        end else begin
            wb_csr_cmd_int = CSR_CMD_NOPE;
            wb_csr_rw_data_int = 64'b0;
            wb_csr_ena_int = 1'b0;
        end
    end

    // CSR and Exceptions
    assign req_cpu_csr_o.csr_rw_addr = (wb_csr_ena_int) ? exe_to_wb_wb.instr.imm[CSR_ADDR_SIZE-1:0] : {CSR_ADDR_SIZE{1'b0}};
    // if csr not enabled send command NOP
    assign req_cpu_csr_o.csr_rw_cmd = (wb_csr_ena_int) ? CSR_CMD_NOPE : wb_csr_cmd_int;
    // if csr not enabled send the interesting addr that you are accesing, exception help
    assign req_cpu_csr_o.csr_rw_data = (wb_csr_ena_int) ? exe_to_wb_wb.instr.ex.origin : wb_csr_rw_data_int;
    // if there is an exception that can be from:
    // the instruction itself or the interrupt
    assign wb_xcpt = exe_to_wb_wb.instr.ex.valid | resp_csr_cpu_i.csr_interrupt;

    assign req_cpu_csr_o.csr_exception = wb_xcpt;

    // if we can retire an instruction
    assign req_cpu_csr_o.csr_retire = exe_to_wb_wb.instr.valid && !wb_xcpt;
    // if there is a csr interrupt we take the interrupt?
    assign req_cpu_csr_o.csr_xcpt_cause = (resp_csr_cpu_i.csr_interrupt) ?   resp_csr_cpu_i.csr_interrupt_cause : 
                                                                            exe_to_wb_wb.instr.ex.cause;
    assign req_cpu_csr_o.csr_pc = exe_to_wb_wb.instr.pc;
    
    
    // data to write to regfile at WB from CSR or exe stage
    assign data_wb_rr_int = (wb_csr_ena_int) ?  resp_csr_cpu_i.csr_rw_rdata : 
                                                exe_to_wb_wb.result_rd; 
     
    // For bypasses
    assign wb_to_exe_exe.valid  = exe_to_wb_wb.instr.regfile_we && exe_to_wb_wb.instr.valid;
    assign wb_to_exe_exe.rd     = exe_to_wb_wb.rd;
    assign wb_to_exe_exe.data   = data_wb_rr_int;

    // Control Unit
    assign wb_cu_int.valid = exe_to_wb_wb.instr.valid;//; & !control_int.stall_wb; // and not flush???
    assign wb_cu_int.change_pc_ena = exe_to_wb_wb.instr.change_pc_ena;
    assign wb_cu_int.branch_taken = exe_to_wb_wb.branch_taken;
    assign wb_cu_int.csr_enable_wb = wb_csr_ena_int;
    assign wb_cu_int.stall_csr = exe_to_wb_wb.instr.stall_csr && exe_to_wb_wb.instr.valid;
    assign wb_cu_int.xcpt = wb_xcpt;
    assign wb_cu_int.write_enable = exe_to_wb_wb.instr.regfile_we;
    //assign wb_cu_int.bpred = ;

    // Debug signals
    assign commit_valid     = exe_to_wb_wb.instr.valid;
    assign commit_pc        = (exe_to_wb_wb.instr.valid) ? exe_to_wb_wb.instr.pc : 64'b0;
    assign commit_data      = (exe_to_wb_wb.instr.valid) ? data_wb_rr_int  : 64'b0;
    assign commit_addr_reg  = exe_to_wb_wb.instr.rd;
    assign commit_reg_we    = exe_to_wb_wb.instr.regfile_we && exe_to_wb_wb.instr.valid;
    assign commit_branch_taken = exe_to_wb_wb.branch_taken;
    // PC
    assign pc_if = (valid_if) ? stage_if_id_d.pc_inst : 64'b0;
    assign pc_id = (valid_id) ? stage_id_rr_d.pc : 64'b0;
    assign pc_rr = (valid_rr) ? stage_rr_exe_d.instr.pc : 64'b0;
    assign pc_exe = (valid_exe) ? stage_rr_exe_q.instr.pc : 64'b0;
    assign pc_wb = (valid_wb) ? exe_to_wb_wb.instr.pc : 64'b0;
    // Valid
    assign valid_if = stage_if_id_d.valid;
    assign valid_id = stage_id_rr_d.valid;
    assign valid_rr = stage_rr_exe_d.instr.valid;
    assign valid_exe = stage_rr_exe_q.instr.valid;
    assign valid_wb = exe_to_wb_wb.instr.valid;

endmodule
