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
    input req_icache_cpu_t  req_icache_cpu_i,
    input req_dcache_cpu_t  req_dcache_cpu_i,
    input req_csr_cpu_t     req_csr_cpu_i,

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
    instr_entry_t wb_instr_int;
    //exe_wb_instr_t stage_commit;
    wb_cu_t wb_cu_int;

    // Control Unit
    id_cu_t id_cu_int;
    jal_id_if_t jal_id_if_int;


    // Exe
    logic stall_exe_out;
    exe_cu_t exe_cu_i;
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

    reg_addr_t io_base_addr;

    // wb csr
    bus64_t wb_csr_rw_data_int;
    logic   wb_csr_ena_int;
    csr_cmd_t wb_csr_cmd_int;


    // data to write to RR from wb
    bus64_t data_wb_rr_int;


    // What is this????
    // TODO: Ruben
    always_ff @(posedge clk_i, negedge rstn_i) begin
        // What is that?????
        if(~rstn_i) begin
            io_base_addr <=  40'h0080000000;
        end else if(~soft_rstn_i) begin
            io_base_addr <=  40'h0040000000;
        end else begin 
            io_base_addr <= io_base_addr;
        end
    end

    // Control Unit
    control_unit control_unit_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .valid_fetch(req_icache_cpu_i.valid),
        .wb_cu_i(wb_cu_int),
        .exe_cu_i(exe_cu_i),
        .csr_cu_i(req_csr_cpu_i),
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
            pc_jump_if_int = req_csr_cpu_i.csr_evec;
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
        .req_icache_cpu_i(req_icache_cpu_i),
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

        .write_enable_i(wb_instr_int.regfile_we&wb_instr_int.valid),
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

        //.from_rr_i(dec_to_exe_exe),
        .from_rr_i(stage_rr_exe_q),
        .from_wb_i(wb_to_exe_exe),

        .io_base_addr_i(io_base_addr),
        .dmem_resp_replay_i(req_dcache_cpu_i.dmem_resp_replay_i),
        .dmem_resp_data_i(req_dcache_cpu_i.dmem_resp_data_i),
        .dmem_req_ready_i(req_dcache_cpu_i.dmem_req_ready_i),
        .dmem_resp_valid_i(req_dcache_cpu_i.dmem_resp_valid_i),
        .dmem_resp_nack_i(req_dcache_cpu_i.dmem_resp_nack_i),
        .dmem_xcpt_ma_st_i(req_dcache_cpu_i.dmem_xcpt_ma_st_i),
        .dmem_xcpt_ma_ld_i(req_dcache_cpu_i.dmem_xcpt_ma_ld_i),
        .dmem_xcpt_pf_st_i(req_dcache_cpu_i.dmem_xcpt_pf_st_i),
        .dmem_xcpt_pf_ld_i(req_dcache_cpu_i.dmem_xcpt_pf_ld_i),
        // Not sure what it does
        .kill_i(1'b0),
        .csr_eret_i(1'b0),

        .to_wb_o(exe_to_wb_exe),
        .stall_o(exe_cu_i.stall),

        .dmem_req_valid_o   (req_cpu_dcache_o.dmem_req_valid_o),
        .dmem_req_cmd_o     (req_cpu_dcache_o.dmem_req_cmd_o),
        .dmem_req_addr_o    (req_cpu_dcache_o.dmem_req_addr_o),
        .dmem_op_type_o     (req_cpu_dcache_o.dmem_op_type_o),
        .dmem_req_data_o    (req_cpu_dcache_o.dmem_req_data_o),
        .dmem_req_tag_o     (req_cpu_dcache_o.dmem_req_tag_o),
        .dmem_req_invalidate_lr_o(req_cpu_dcache_o.dmem_req_invalidate_lr_o),
        .dmem_req_kill_o(req_cpu_dcache_o.dmem_req_kill_o),
        .dmem_lock_o(req_cpu_dcache_o.dmem_lock_o)
    );

    register #($bits(instr_entry_t)+$bits(exe_wb_instr_t)) reg_exe_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(control_int.flush_exe),
        .load_i(!control_int.stall_exe),
        .input_i({stage_rr_exe_q.instr,exe_to_wb_exe}),
        .output_o({wb_instr_int,exe_to_wb_wb})
    );

    // WB
    // CSR
    //assign wb_csr_ena_int = !req_csr_cpu_i.csr_interrupt;
    // TODO (guillemlp): change that the enable is when puting any CSR
    always_comb begin
        case (wb_instr_int.instr_type)
            CSRRW: begin
                wb_csr_cmd_int = CSR_CMD_WRITE;
                wb_csr_rw_data_int = exe_to_wb_wb.result_rd;
                wb_csr_ena_int = !req_csr_cpu_i.csr_interrupt;
            end
            CSRRS: begin
                wb_csr_cmd_int = (wb_instr_int.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                wb_csr_rw_data_int = exe_to_wb_wb.result_rd;
                wb_csr_ena_int = !req_csr_cpu_i.csr_interrupt;
            end
            CSRRC: begin
                wb_csr_cmd_int = (wb_instr_int.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                wb_csr_rw_data_int = exe_to_wb_wb.result_rd;
                wb_csr_ena_int = !req_csr_cpu_i.csr_interrupt;
            end
            CSRRWI: begin
                wb_csr_cmd_int = CSR_CMD_WRITE;
                wb_csr_rw_data_int = {59'b0,wb_instr_int.rs1};
                wb_csr_ena_int = !req_csr_cpu_i.csr_interrupt;
            end
            CSRRSI: begin
                wb_csr_cmd_int = (wb_instr_int.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_SET;
                wb_csr_rw_data_int = {59'b0,wb_instr_int.rs1};
                wb_csr_ena_int = !req_csr_cpu_i.csr_interrupt;
            end
            CSRRCI: begin
                // do we extend sign?
                wb_csr_cmd_int = (wb_instr_int.rs1 == 'h0) ? CSR_CMD_READ : CSR_CMD_CLEAR;
                wb_csr_rw_data_int = {59'b0,wb_instr_int.rs1};  
                wb_csr_ena_int = !req_csr_cpu_i.csr_interrupt;
            end
            default: begin
                wb_csr_cmd_int = CSR_CMD_NOPE;
                wb_csr_rw_data_int = 64'b0;
                wb_csr_ena_int = 1'b0;
            end
        endcase // wb_instr_int.instr_type
    end

    assign req_cpu_csr_o.csr_rw_addr = (wb_csr_ena_int) ? wb_instr_int.imm[CSR_ADDR_SIZE-1:0] : {CSR_ADDR_SIZE{1'b0}};
    assign req_cpu_csr_o.csr_rw_cmd = (wb_csr_ena_int) ? CSR_CMD_NOPE : wb_csr_cmd_int;
    assign req_cpu_csr_o.csr_rw_data = (wb_csr_ena_int) ? 64'b0 : wb_csr_rw_data_int;
    assign req_cpu_csr_o.csr_exception =    wb_instr_int.ex.valid | 
                                            (req_csr_cpu_i.csr_interrupt) |
                                            (req_csr_cpu_i.csr_exception); 
    // if we can retire an instruction
    assign req_cpu_csr_o.csr_retire = wb_instr_int.valid;
    // TODO CHANGE it!
    assign req_cpu_csr_o.csr_xcpt_cause = (req_csr_cpu_i.csr_interrupt) ?   req_csr_cpu_i.csr_interrupt_cause : 
                                                                            wb_instr_int.ex.cause;
    assign req_cpu_csr_o.csr_pc = wb_instr_int.pc;
    
    
    // data to write to regfile at WB from CSR or exe stage
    assign data_wb_rr_int = (wb_csr_ena_int) ?  req_csr_cpu_i.csr_rw_rdata : 
                                                exe_to_wb_wb.result_rd; 
     
    // For bypasses
    //assign wb_to_exe_exe.valid  = !control_int.stall_wb & wb_instr_int.regfile_we && wb_instr_int.valid;
    assign wb_to_exe_exe.valid  = wb_instr_int.regfile_we && wb_instr_int.valid;
    assign wb_to_exe_exe.rd     = exe_to_wb_wb.rd;
    assign wb_to_exe_exe.data   = data_wb_rr_int;

    assign wb_cu_int.valid = wb_instr_int.valid;//; & !control_int.stall_wb; // and not flush???
    assign wb_cu_int.change_pc_ena = wb_instr_int.change_pc_ena;
    assign wb_cu_int.branch_taken = exe_to_wb_wb.branch_taken;
    assign wb_cu_int.csr_enable_wb = wb_csr_ena_int;
    //assign wb_cu_int.bpred = ;
    //assign wb_cu_int.ex = ;

    assign commit_valid     = wb_instr_int.valid;
    assign commit_pc        = (wb_instr_int.valid) ? wb_instr_int.pc : 64'b0;
    assign commit_data      = data_wb_rr_int;
    assign commit_addr_reg  = wb_instr_int.rd;
    assign commit_reg_we    = wb_instr_int.regfile_we && wb_instr_int.valid;
    assign commit_branch_taken = exe_to_wb_wb.branch_taken;
    assign pc_if = (valid_if) ? stage_if_id_d.pc_inst : 64'b0;
    assign pc_id = (valid_id) ? stage_id_rr_d.pc : 64'b0;
    assign pc_rr = (valid_rr) ? stage_rr_exe_d.instr.pc : 64'b0;
    assign pc_exe = (valid_exe) ? stage_rr_exe_q.instr.pc : 64'b0;
    assign pc_wb = (valid_wb) ? wb_instr_int.pc : 64'b0;
    assign valid_if = stage_if_id_d.valid;
    assign valid_id = stage_id_rr_d.valid;
    assign valid_rr = stage_rr_exe_d.instr.valid;
    assign valid_exe = stage_rr_exe_q.instr.valid;
    assign valid_wb = wb_instr_int.valid;

endmodule
