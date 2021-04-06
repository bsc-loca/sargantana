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
    // icache/dcache/CSR interface input
    input resp_icache_cpu_t resp_icache_cpu_i,
    input resp_dcache_cpu_t resp_dcache_cpu_i,
    input resp_csr_cpu_t    resp_csr_cpu_i,
    input debug_in_t        debug_i,
    input [1:0]             csr_priv_lvl_i,
    input logic             req_icache_ready_i,
    // icache/dcache/CSR interface output
    output req_cpu_dcache_t req_cpu_dcache_o, 
    output req_cpu_icache_t req_cpu_icache_o,
    output req_cpu_csr_t    req_cpu_csr_o,
    output debug_out_t      debug_o ,
    //--PMU   
    output to_PMU_t         pmu_flags_o
);

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// SIGNAL DECLARATION                                                                           /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef VERILATOR
    // Stages: if -- id -- rr -- ex -- wb
    bus64_t commit_pc, commit_data;
    logic commit_valid, commit_reg_we;
    logic [4:0] commit_addr_reg;
`endif

    bus64_t pc_if1, pc_if2, pc_id, pc_rr, pc_exe, pc_wb;
    logic valid_if1, valid_if2, valid_id, valid_rr, valid_exe, valid_wb;

    pipeline_ctrl_t control_int;
    pipeline_flush_t flush_int;
    cu_if_t cu_if_int;
    addrPC_t pc_jump_if_int;
    addrPC_t pc_evec_q;
    addrPC_t pc_next_csr_q;

    
    // Pipelines stages data
    // Fetch
    if_1_if_2_stage_t stage_if_1_if_2_d;
    if_1_if_2_stage_t stage_if_1_if_2_q;
    if_id_stage_t stage_if_2_id_d; // this is the saving in the current cycle
    if_id_stage_t stage_if_2_id_q; // this is the next or output of reg
    logic invalidate_icache_int;
    logic invalidate_buffer_int;
    logic retry_fetch;
    
    // Decode
    instr_entry_t decoded_instr;
    instr_entry_t stored_instr_id_d;
    instr_entry_t stored_instr_id_q;
    instr_entry_t selection_id_ir;

    id_cu_t id_cu_int;
    jal_id_if_t jal_id_if_int;
    
    logic src_select_id_ir_q;
    
    // Rename and free list
    ir_rr_stage_t stage_ir_rr_d;
    ir_rr_stage_t stage_ir_rr_q;
    ir_rr_stage_t stage_stall_rr_q;
    ir_rr_stage_t stage_no_stall_rr_q;

    logic do_checkpoint;
    logic do_recover;
    logic delete_checkpoint;
    logic out_of_checkpoints_rename;
    logic out_of_checkpoints_free_list;

    logic free_a_register;
    phreg_t freed_register;

    logic free_list_empty;

    phreg_t free_register_to_rename;

    checkpoint_ptr recover_checkpoint;
    checkpoint_ptr checkpoint_free_list;
    checkpoint_ptr checkpoint_rename;

    logic src_select_ir_rr_q;

    ir_cu_t ir_cu_int;
    cu_ir_t cu_ir_int;

    // Read Registers
    rr_exe_instr_t stage_rr_exe_d;
    rr_exe_instr_t stage_rr_exe_q;

    logic [drac_pkg::NUM_SCALAR_WB-1:0] snoop_rr_rs1;
    logic [drac_pkg::NUM_SCALAR_WB-1:0] snoop_rr_rs2;
    logic snoop_rr_rdy1;
    logic snoop_rr_rdy2;

    rr_cu_t rr_cu_int;
    cu_rr_t cu_rr_int;
    
    // Graduation List

    gl_instruction_t instruction_decode_gl;
    gl_instruction_t [drac_pkg::NUM_SCALAR_WB-1:0] instruction_writeback_gl;
    gl_index_t       [drac_pkg::NUM_SCALAR_WB-1:0] gl_index;
    logic            [drac_pkg::NUM_SCALAR_WB-1:0] gl_valid;
    gl_instruction_t instruction_gl_commit; 
    
    // Exe
    rr_exe_instr_t selection_rr_exe_d;

    exe_cu_t exe_cu_int;
    exe_wb_scalar_instr_t [drac_pkg::NUM_SCALAR_WB-1:0] exe_to_wb_scalar;
    exe_wb_scalar_instr_t [drac_pkg::NUM_SCALAR_WB-1:0] wb_scalar;

    bus64_t snoop_exe_data_rs1;
    bus64_t snoop_exe_data_rs2;
    logic   [drac_pkg::NUM_SCALAR_WB-1:0] snoop_exe_rs1;
    logic   [drac_pkg::NUM_SCALAR_WB-1:0] snoop_exe_rs2;
    logic snoop_exe_rdy1;
    logic snoop_exe_rdy2;
    logic pmu_exe_ready;

    bus64_t exe_data_rs1;
    bus64_t exe_data_rs2;
    rr_exe_instr_t reg_to_exe;

    // This addresses are fixed from lowrisc
    reg_addr_t io_base_addr;

    // codifies if the branch was correctly predicted 
    // this signal goes from exe stage to fetch stage
    logic correct_branch_pred;

    // WB->Commit
    wb_cu_t wb_cu_int;
    cu_wb_t cu_wb_int;
    
    exe_if_branch_pred_t exe_if_branch_pred_int;   

    // Commit signals
    commit_cu_t commit_cu_int;
    cu_commit_t cu_commit_int;
    logic commit_xcpt;
    logic commit_store_or_amo_int;
    
    gl_instruction_t instruction_gl_commit_old_q;
    gl_instruction_t instruction_to_commit;
    logic src_select_commit;
    exception_t exception_mem_commit_int;
    gl_index_t mem_gl_index_int;
    gl_index_t index_gl_commit;
    gl_index_t index_gl_commit_old_q;

    //Br at WB
    addrPC_t branch_addr_result_wb;
    logic correct_branch_pred_wb;

    // CSR signals
    logic   csr_ena_int;

    // Data to write to RR from WB or CSR
    bus64_t [drac_pkg::NUM_SCALAR_WB-1:0] data_wb_to_rr;
    bus64_t [drac_pkg::NUM_SCALAR_WB-1:0] data_wb_to_exe;
    phreg_t [drac_pkg::NUM_SCALAR_WB-1:0] write_paddr_rr;
    phreg_t [drac_pkg::NUM_SCALAR_WB-1:0] write_paddr_exe;
    reg_t   [drac_pkg::NUM_SCALAR_WB-1:0] write_vaddr;

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// IO ADDRESS SPACE                                                                             /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////


    // Debug signals
    bus64_t  reg_wr_data;
    phreg_t reg_wr_addr;
    phreg_t reg_prd1_addr;
    // stall IF
    logic stall_if;
    logic miss_icache;
    `ifdef VERILATOR
        bus64_t id_fetch;
    `endif

    // This addresses are fixed from lowrisc
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            io_base_addr <=  40'h0040000000;
        end else if(!soft_rstn_i) begin
            io_base_addr <=  40'h0040000000;
        end else begin 
            io_base_addr <= io_base_addr;
        end
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// CONTROL UNIT                                                                                 /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Control Unit
    control_unit control_unit_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .miss_icache_i(miss_icache),
        .ready_icache_i(req_icache_ready_i),
        .id_cu_i(id_cu_int),
        .ir_cu_i(ir_cu_int),
        .cu_ir_o(cu_ir_int),
        .rr_cu_i(rr_cu_int),
        .cu_rr_o(cu_rr_int),
        .wb_cu_i(wb_cu_int),
        .cu_wb_o(cu_wb_int),
        .exe_cu_i(exe_cu_int),
        .csr_cu_i(resp_csr_cpu_i),
        .pipeline_ctrl_o(control_int),
        .pipeline_flush_o(flush_int),
        .cu_if_o(cu_if_int),
        .invalidate_icache_o(invalidate_icache_int),
        .invalidate_buffer_o(invalidate_buffer_int),
        .correct_branch_pred_exe_i(correct_branch_pred),
        .correct_branch_pred_wb_i(correct_branch_pred_wb),
        .debug_halt_i(debug_i.halt_valid),
        .debug_change_pc_i(debug_i.change_pc_valid),
        .debug_wr_valid_i(debug_i.reg_write_valid),
        .commit_cu_i(commit_cu_int),
        .cu_commit_o(cu_commit_int),
        .pmu_jump_misspred_o(pmu_flags_o.branch_miss)
    );

    // Combinational logic select the jump addr
    // from decode or wb 
    always_comb begin
        retry_fetch = 1'b0;
        // TODO (guillemlp) highest priority?
        if (control_int.sel_addr_if == SEL_JUMP_DEBUG) begin
            pc_jump_if_int = debug_i.change_pc_addr;
        end else if (control_int.sel_addr_if == SEL_JUMP_EXECUTION) begin
            pc_jump_if_int = branch_addr_result_wb;
        end else if (control_int.sel_addr_if == SEL_JUMP_CSR) begin
            pc_jump_if_int = pc_evec_q;
            retry_fetch = 1'b1;
        end else if (control_int.sel_addr_if == SEL_JUMP_CSR_RW) begin
            pc_jump_if_int = pc_next_csr_q;
            retry_fetch = 1'b1;   
        end else if (control_int.sel_addr_if == SEL_JUMP_DECODE) begin
            pc_jump_if_int = jal_id_if_int.jump_addr;
        end else begin
            pc_jump_if_int = 64'h0;
            `ifdef ASSERTIONS
                assert (1 == 0);
            `endif
        end
    end

    assign stall_if_1 = control_int.stall_if_1 || debug_i.halt_valid;

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// FETCH                  STAGE                                                                 /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // IF Stage
    if_stage_1 if_stage_1_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .reset_addr_i(reset_addr_i),
        .stall_debug_i(debug_i.halt_valid),
        .stall_i(stall_if_1),
        .cu_if_i(cu_if_int),
        .invalidate_icache_i(invalidate_icache_int),
        .invalidate_buffer_i(invalidate_buffer_int),
        .pc_jump_i(pc_jump_if_int),
        .retry_fetch_i(retry_fetch),
        .req_cpu_icache_o(req_cpu_icache_o),
        .fetch_o(stage_if_1_if_2_d),
        `ifdef VERILATOR
        .id_o(id_fetch),
        `endif
        .exe_if_branch_pred_i(exe_if_branch_pred_int)
    );

    // Register IF1 to IF2
    register #($bits(if_1_if_2_stage_t)) reg_if_1_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_if),
        .load_i(!control_int.stall_if_1),
        .input_i(stage_if_1_if_2_d),
        .output_o(stage_if_1_if_2_q)
    );

    if_stage_2 if_stage_2_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .fetch_i(stage_if_1_if_2_q),
        .stall_i(control_int.stall_if_2),
        .flush_i(flush_int.flush_if),
        .resp_icache_cpu_i(resp_icache_cpu_i),
        .fetch_o(stage_if_2_id_d),
        .stall_o(miss_icache)
    );

    // Register IF to ID
    register #($bits(if_id_stage_t)) reg_if_2_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_if),
        .load_i(!control_int.stall_if_2),
        .input_i(stage_if_2_id_d),
        .output_o(stage_if_2_id_q)
    );

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// DECODER                           STAGE                                                      /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // ID Stage
    decoder id_decode_inst(
        .clk_i          (clk_i),
        .rstn_i         (rstn_i),
        .stall_i        (control_int.stall_id),
        .flush_i        (flush_int.flush_id),
        .decode_i       (stage_if_2_id_q),
        .decode_instr_o (decoded_instr),
        .jal_id_if_o    (jal_id_if_int)
    );

    // valid jal in decode
    assign id_cu_int.valid               = decoded_instr.valid;
    assign id_cu_int.valid_jal           = jal_id_if_int.valid;
    assign id_cu_int.stall_csr_fence     = decoded_instr.stall_csr_fence && decoded_instr.valid;
    assign id_cu_int.predicted_as_branch = decoded_instr.bpred.is_branch;
    assign id_cu_int.is_branch           = (decoded_instr.instr_type == BLT)  ||
                                           (decoded_instr.instr_type == BLTU) ||
                                           (decoded_instr.instr_type == BGE)  ||
                                           (decoded_instr.instr_type == BGEU) ||
                                           (decoded_instr.instr_type == BEQ)  ||
                                           (decoded_instr.instr_type == BNE)  ||
                                           (decoded_instr.instr_type == JAL) ||
                                           (decoded_instr.instr_type == JALR);


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// INSTRUCTION QUEUE, FREE LIST AND RENAME               STAGE                                  /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign stored_instr_id_d = (src_select_id_ir_q) ? decoded_instr : stored_instr_id_q;

    // Register ID to IR when stall
    register #($bits(instr_entry_t)) reg_id_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_id),
        .load_i(1'b1),
        .input_i(stored_instr_id_d),
        .output_o(stored_instr_id_q)
    );

    // Syncronus Mux to decide between actual decode or one cycle before
    always @(posedge clk_i) begin
        src_select_id_ir_q <= !control_int.stall_id;
    end
    
    assign selection_id_ir = (src_select_id_ir_q) ? decoded_instr : stored_instr_id_q;

    // Instruction Queue 
    instruction_queue instruction_queue_inst(
        .clk_i          (clk_i),
        .rstn_i         (rstn_i),  
        .flush_i        (flush_int.flush_ir),  
        .instruction_i  (selection_id_ir), 
        .read_head_i    (~control_int.stall_iq),
        .instruction_o  (stage_ir_rr_d.instr),
        .full_o         (ir_cu_int.full_iq),
        .empty_o        ()
    );

    // Free List
    free_list free_list_inst(
        .clk_i                  (clk_i),
        .rstn_i                 (rstn_i),
        .read_head_i            (stage_ir_rr_d.instr.regfile_we & stage_ir_rr_d.instr.valid & (stage_ir_rr_d.instr.rd != 'h0) & (~control_int.stall_ir)),
        .add_free_register_i    (cu_ir_int.enable_commit_update),
        .free_register_i        (instruction_to_commit.old_prd),
        .do_checkpoint_i        (cu_ir_int.do_checkpoint),
        .do_recover_i           (cu_ir_int.do_recover),
        .delete_checkpoint_i    (cu_ir_int.delete_checkpoint),
        .recover_checkpoint_i   (cu_ir_int.recover_checkpoint),
        .commit_roll_back_i     (cu_ir_int.recover_commit),
        .new_register_o         (free_register_to_rename),
        .checkpoint_o           (checkpoint_free_list),
        .out_of_checkpoints_o   (out_of_checkpoints_free_list),
        .empty_o                (free_list_empty)
    );

    // Rename Table
    rename_table rename_table_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .read_src1_i(stage_ir_rr_d.instr.rs1),
        .read_src2_i(stage_ir_rr_d.instr.rs2),
        .old_dst_i(stage_ir_rr_d.instr.rd),
        .write_dst_i(stage_ir_rr_d.instr.regfile_we & stage_ir_rr_d.instr.valid & (~control_int.stall_ir)),
        .new_dst_i(free_register_to_rename),
        .ready_i(cu_rr_int.write_enable),
        .vaddr_i(write_vaddr),
        .paddr_i(write_paddr_rr),
        .do_checkpoint_i(cu_ir_int.do_checkpoint),
        .do_recover_i(cu_ir_int.do_recover),
        .delete_checkpoint_i(cu_ir_int.delete_checkpoint),
        .recover_checkpoint_i(cu_ir_int.recover_checkpoint),
        .recover_commit_i(cu_ir_int.recover_commit), 
        .commit_old_dst_i(instruction_to_commit.rd),    
        .commit_write_dst_i(cu_ir_int.enable_commit_update),  
        .commit_new_dst_i(instruction_to_commit.prd),
        .src1_o(stage_no_stall_rr_q.prs1),
        .rdy1_o(stage_no_stall_rr_q.rdy1),
        .src2_o(stage_no_stall_rr_q.prs2),
        .rdy2_o(stage_no_stall_rr_q.rdy2),
        .old_dst_o(stage_no_stall_rr_q.old_prd),
        .checkpoint_o(checkpoint_rename),
        .out_of_checkpoints_o(out_of_checkpoints_rename)
    );

    // Check two structures output the same
    always @(posedge clk_i) assert (out_of_checkpoints_rename == out_of_checkpoints_free_list);
    always @(posedge clk_i) assert (checkpoint_rename == checkpoint_free_list);

    assign stage_no_stall_rr_q.chkp = checkpoint_rename;

    // Signals for Control Unit
    assign ir_cu_int.valid              = stage_ir_rr_d.instr.valid;
    assign ir_cu_int.empty_free_list    = free_list_empty;
    assign ir_cu_int.out_of_checkpoints = out_of_checkpoints_rename;
    assign ir_cu_int.is_branch          = (stage_ir_rr_d.instr.instr_type == BLT)  ||
                                          (stage_ir_rr_d.instr.instr_type == BLTU) ||
                                          (stage_ir_rr_d.instr.instr_type == BGE)  ||
                                          (stage_ir_rr_d.instr.instr_type == BGEU) ||
                                          (stage_ir_rr_d.instr.instr_type == BEQ)  ||
                                          (stage_ir_rr_d.instr.instr_type == BNE)  ||
                                          (stage_ir_rr_d.instr.instr_type == JALR);


    // Register IR to RR
    register #($bits(instr_entry_t) + $bits(phreg_t) + $bits(logic)) reg_ir_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_ir),
        .load_i(!control_int.stall_ir),
        .input_i({stage_ir_rr_d.instr,free_register_to_rename,cu_ir_int.do_checkpoint}),
        .output_o({stage_no_stall_rr_q.instr,stage_no_stall_rr_q.prd,stage_no_stall_rr_q.checkpoint_done})
    );

    // Second IR to RR. To store rename in case of stall
    register #($bits(ir_rr_stage_t)) reg_rename_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_ir),
        .load_i(1'b1), // This register is always storing a one cycle old copy of reg_ir_inst and the renaming.
        .input_i(stage_ir_rr_q),
        .output_o(stage_stall_rr_q)
    );

    // Syncronus Mux to decide between actual Rename or one cycle before Rename
    always @(posedge clk_i) begin
        src_select_ir_rr_q <= !control_int.stall_ir;
    end

    always_comb begin
        if (src_select_ir_rr_q) begin
            stage_ir_rr_q.instr = stage_no_stall_rr_q.instr;
            stage_ir_rr_q.prd = stage_no_stall_rr_q.prd;
            stage_ir_rr_q.prs1 = stage_no_stall_rr_q.prs1;
            stage_ir_rr_q.prs2 = stage_no_stall_rr_q.prs2;
            stage_ir_rr_q.rdy1 = stage_no_stall_rr_q.rdy1 | snoop_rr_rdy1;
            stage_ir_rr_q.rdy2 = stage_no_stall_rr_q.rdy2 | snoop_rr_rdy2;
            stage_ir_rr_q.old_prd = stage_no_stall_rr_q.old_prd;
            stage_ir_rr_q.chkp = stage_no_stall_rr_q.chkp;
            stage_ir_rr_q.checkpoint_done = stage_no_stall_rr_q.checkpoint_done;
        end else begin
            stage_ir_rr_q.instr = stage_stall_rr_q.instr;
            stage_ir_rr_q.prd = stage_stall_rr_q.prd;
            stage_ir_rr_q.prs1 = stage_stall_rr_q.prs1;
            stage_ir_rr_q.prs2 = stage_stall_rr_q.prs2;
            stage_ir_rr_q.rdy1 = stage_stall_rr_q.rdy1 | snoop_rr_rdy1;
            stage_ir_rr_q.rdy2 = stage_stall_rr_q.rdy2 | snoop_rr_rdy2;
            stage_ir_rr_q.old_prd = stage_stall_rr_q.old_prd;
            stage_ir_rr_q.chkp = stage_stall_rr_q.chkp;
            stage_ir_rr_q.checkpoint_done = stage_stall_rr_q.checkpoint_done;
        end
    end

    always_comb begin
        for (int i = 0; i<drac_pkg::NUM_SCALAR_WB; ++i) begin
            snoop_rr_rs1[i] = cu_rr_int.snoop_enable[i] & (write_paddr_exe[i] == stage_ir_rr_q.prs1) & (stage_ir_rr_q.instr.rs1!= 0);
            snoop_rr_rs2[i] = cu_rr_int.snoop_enable[i] & (write_paddr_exe[i] == stage_ir_rr_q.prs2) & (stage_ir_rr_q.instr.rs2!= 0);
        end
        snoop_rr_rdy1 = |snoop_rr_rs1;
        snoop_rr_rdy2 = |snoop_rr_rs2;
    end
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// GRADUATION LIST AND READ REGISTER  STAGE                                                     /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign instruction_decode_gl.valid                  = stage_ir_rr_q.instr.valid & (~control_int.stall_rr);
    assign instruction_decode_gl.instr_type             = stage_ir_rr_q.instr.instr_type;
    assign instruction_decode_gl.rd                     = stage_ir_rr_q.instr.rd;
    assign instruction_decode_gl.rs1                    = stage_ir_rr_q.instr.rs1;
    assign instruction_decode_gl.pc                     = stage_ir_rr_q.instr.pc;
    assign instruction_decode_gl.exception              = stage_ir_rr_q.instr.ex;
    assign instruction_decode_gl.stall_csr_fence        = stage_ir_rr_q.instr.stall_csr_fence;
    assign instruction_decode_gl.old_prd                = stage_ir_rr_q.old_prd;
    assign instruction_decode_gl.prd                    = stage_ir_rr_q.prd;
    assign instruction_decode_gl.regfile_we             = stage_ir_rr_q.instr.regfile_we;
    `ifdef VERILATOR
        assign instruction_decode_gl.inst               = stage_ir_rr_q.instr.inst;
    `endif

    graduation_list graduation_list_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .instruction_i(instruction_decode_gl),
        .read_head_i(cu_commit_int.enable_commit),
        .instruction_writeback_i(gl_index),
        .instruction_writeback_enable_i(gl_valid),
        .instruction_writeback_data_i(instruction_writeback_gl),
        .flush_i(cu_wb_int.flush_gl),
        .flush_index_i(cu_wb_int.flush_gl_index),
        .flush_commit_i(cu_commit_int.flush_gl_commit),
        .assigned_gl_entry_o(stage_rr_exe_d.gl_index),
        .instruction_o(instruction_gl_commit),
        .commit_gl_entry_o(index_gl_commit),
        .full_o(rr_cu_int.gl_full),
        .empty_o()
    );

    assign reg_prd1_addr  = (debug_i.reg_read_valid  && debug_i.halt_valid)  ? debug_i.reg_read_write_addr : stage_ir_rr_q.prs1;
    
    // RR Stage
    regfile regfile(
        .clk_i(clk_i),

        .write_enable_i(cu_rr_int.write_enable),
        .write_addr_i(write_paddr_rr),
        .write_data_i(data_wb_to_rr),
        
        .read_addr1_i(reg_prd1_addr),
        .read_addr2_i(stage_ir_rr_q.prs2),
        .read_data1_o(stage_rr_exe_d.data_rs1),
        .read_data2_o(stage_rr_exe_d.data_rs2)
    );

    assign stage_rr_exe_d.instr = stage_ir_rr_q.instr;
    assign stage_rr_exe_d.csr_interrupt_cause = resp_csr_cpu_i.csr_interrupt_cause;
    assign stage_rr_exe_d.csr_interrupt = resp_csr_cpu_i.csr_interrupt;
    assign stage_rr_exe_d.prd = stage_ir_rr_q.prd;
    assign stage_rr_exe_d.prs1 = stage_ir_rr_q.prs1;
    assign stage_rr_exe_d.prs2 = stage_ir_rr_q.prs2;
    assign stage_rr_exe_d.rdy1 = stage_ir_rr_q.rdy1;
    assign stage_rr_exe_d.rdy2 = stage_ir_rr_q.rdy2;
    assign stage_rr_exe_d.old_prd = stage_ir_rr_q.old_prd;
    assign stage_rr_exe_d.chkp = stage_ir_rr_q.chkp;
    assign stage_rr_exe_d.checkpoint_done = stage_ir_rr_q.checkpoint_done;

    assign selection_rr_exe_d = (control_int.stall_rr) ? reg_to_exe : stage_rr_exe_d;

    // Register RR to EXE
    register #($bits(stage_rr_exe_d)) reg_rr_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_rr),
        .load_i(1'b1),
        .input_i(selection_rr_exe_d),
        .output_o(stage_rr_exe_q)
    );

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// EXECUTION STAGE                                                                              /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always_comb begin
        snoop_exe_data_rs1 = 64'b0;
        snoop_exe_data_rs2 = 64'b0;

        for (int i = 0; i<drac_pkg::NUM_SCALAR_WB; ++i) begin
            snoop_exe_rs1[i] = cu_rr_int.snoop_enable[i] & (write_paddr_exe[i] == stage_rr_exe_q.prs1) & (stage_rr_exe_q.instr.rs1 != 0);
            snoop_exe_rs2[i] = cu_rr_int.snoop_enable[i] & (write_paddr_exe[i] == stage_rr_exe_q.prs2) & (stage_rr_exe_q.instr.rs2 != 0);
            snoop_exe_data_rs1 |= snoop_exe_rs1[i] ? data_wb_to_exe[i] : 64'b0;
            snoop_exe_data_rs2 |= snoop_exe_rs2[i] ? data_wb_to_exe[i] : 64'b0;
        end

        snoop_exe_rdy1 = |snoop_exe_rs1;
        snoop_exe_rdy2 = |snoop_exe_rs2;
        exe_data_rs1 = snoop_exe_rdy1 ? (snoop_exe_data_rs1) : stage_rr_exe_q.data_rs1;
        exe_data_rs2 = snoop_exe_rdy2 ? (snoop_exe_data_rs2) : stage_rr_exe_q.data_rs2;
    end
    assign reg_to_exe.instr = stage_rr_exe_q.instr;
    assign reg_to_exe.data_rs1 = exe_data_rs1;
    assign reg_to_exe.data_rs2 = exe_data_rs2;
    assign reg_to_exe.csr_interrupt = stage_rr_exe_q.csr_interrupt;
    assign reg_to_exe.csr_interrupt_cause = stage_rr_exe_q.csr_interrupt_cause;
    assign reg_to_exe.prs1 = stage_rr_exe_q.prs1;
    assign reg_to_exe.rdy1 = snoop_exe_rdy1 | stage_rr_exe_q.rdy1;
    assign reg_to_exe.prs2 = stage_rr_exe_q.prs2;
    assign reg_to_exe.rdy2 = snoop_exe_rdy2 | stage_rr_exe_q.rdy2;
    assign reg_to_exe.prd = stage_rr_exe_q.prd;
    assign reg_to_exe.old_prd = stage_rr_exe_q.old_prd;
    assign reg_to_exe.checkpoint_done = stage_rr_exe_q.checkpoint_done;
    assign reg_to_exe.chkp = stage_rr_exe_q.chkp;
    assign reg_to_exe.gl_index = stage_rr_exe_q.gl_index;

    exe_stage exe_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .kill_i(flush_int.flush_exe),
        .csr_interrupt_i(resp_csr_cpu_i.csr_interrupt),
        .csr_interrupt_cause_i(resp_csr_cpu_i.csr_interrupt_cause),

        .from_rr_i(reg_to_exe),

        .resp_dcache_cpu_i(resp_dcache_cpu_i),
        .io_base_addr_i(io_base_addr),
        .flush_i(flush_int.flush_exe),
        .commit_store_or_amo_i(commit_store_or_amo_int),

        .exe_if_branch_pred_o(exe_if_branch_pred_int),
        .correct_branch_pred_o(correct_branch_pred),

        .arith_to_wb_o(exe_to_wb_scalar[0]),
        .mem_to_wb_o(exe_to_wb_scalar[1]),
        .exe_cu_o(exe_cu_int),

        .mem_commit_stall_o(mem_commit_stall_int),
        .mem_gl_index_o(mem_gl_index_int),
        .exception_mem_commit_o(exception_mem_commit_int),

        .req_cpu_dcache_o(req_cpu_dcache_o),

        //PMU Neiel-Leyva
        .pmu_is_branch_o          (pmu_flags_o.is_branch),      
        .pmu_branch_taken_o       (pmu_flags_o.branch_taken),   
        .pmu_stall_mul_o          (pmu_flags_o.stall_rr),
        .pmu_stall_mem_o          (pmu_flags_o.stall_wb),
        .pmu_exe_ready_o          (pmu_exe_ready),
        .pmu_struct_depend_stall_o(pmu_flags_o.struct_depend)
    );

    register #($bits(exe_wb_scalar_instr_t) + $bits(exe_wb_scalar_instr_t)) reg_exe_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_exe),
        .load_i(!control_int.stall_exe),
        .input_i(exe_to_wb_scalar),
        .output_o(wb_scalar)
    );

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            branch_addr_result_wb <=  40'h0040000000;
            correct_branch_pred_wb <=  1'b1;
        end else if(!control_int.stall_exe) begin
            branch_addr_result_wb <=  exe_if_branch_pred_int.branch_addr_result_exe;
            correct_branch_pred_wb <=  correct_branch_pred;
        end else begin 
            branch_addr_result_wb <= branch_addr_result_wb;
            correct_branch_pred_wb <= correct_branch_pred_wb;
        end
    end 

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// WRITE BACK STAGE                                                                             /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //WB data for the bypasses (the CSRs should not be bypassed)
    always_comb begin
        for (int i = 0; i<drac_pkg::NUM_SCALAR_WB; ++i) begin
            //Graduation list writeback arrays
            gl_valid[i] = wb_scalar[i].valid;
            gl_index[i] = wb_scalar[i].gl_index;
            instruction_writeback_gl[i].csr_addr = wb_scalar[i].csr_addr;
            instruction_writeback_gl[i].exception = wb_scalar[i].ex;
            instruction_writeback_gl[i].result   = wb_scalar[i].result;

            // Write data regfile from WB or from Commit (CSR)
            // CSR are exclusive with the rest of instrucitons. Therefor, there are no conflicts
            if (i == 0) begin
                // Change the data of write port 0 with dbg ring data
                if (debug_i.reg_write_valid && debug_i.halt_valid) begin
                    wb_cu_int.write_enable[i] = cu_rr_int.write_enable_dbg; //TODO: Check if this creates comb loops in cu
                end else begin
                    wb_cu_int.write_enable[i] = wb_scalar[i].regfile_we;
                end
                data_wb_to_exe[i] = wb_scalar[i].result;
                write_paddr_exe[i] = wb_scalar[i].prd;
                write_vaddr[i] = (commit_cu_int.write_enable) ? instruction_to_commit.rd :
                                  wb_scalar[i].rd;
                wb_cu_int.snoop_enable[i] = wb_scalar[i].regfile_we;
            end else begin
                data_wb_to_exe[i] = wb_scalar[i].result;
                write_paddr_exe[i]   = wb_scalar[i].prd;
                write_vaddr[i]   = wb_scalar[i].rd;
                wb_cu_int.write_enable[i] = wb_scalar[i].regfile_we;
                wb_cu_int.snoop_enable[i] = wb_scalar[i].regfile_we;
            end
            wb_cu_int.valid[i]        = wb_scalar[i].valid;
        end
        wb_cu_int.change_pc_ena = wb_scalar[0].change_pc_ena;
        wb_cu_int.checkpoint_done = wb_scalar[0].checkpoint_done;
        wb_cu_int.chkp = wb_scalar[0].chkp;
        wb_cu_int.gl_index = wb_scalar[0].gl_index;
    end

    // WB data to RR
    always_comb begin
        for (int i = 0; i<drac_pkg::NUM_SCALAR_WB; ++i) begin
            if (i == 0) begin
                // Change the data of write port 0 with dbg ring data
                if (debug_i.reg_write_valid && debug_i.halt_valid) begin
                    data_wb_to_rr[i] = debug_i.reg_write_data;
                    write_paddr_rr[i] = debug_i.reg_read_write_addr;
                end else begin
                    data_wb_to_rr[i] = (commit_cu_int.write_enable) ? resp_csr_cpu_i.csr_rw_rdata : data_wb_to_exe[i];
                    write_paddr_rr[i] = (commit_cu_int.write_enable) ? instruction_to_commit.prd : write_paddr_exe[i];
                end
            end else begin
                data_wb_to_rr[i] = data_wb_to_exe[i];
                write_paddr_rr[i] = write_paddr_exe[i];
            end
        end
    end
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// COMMIT STAGE                                                                                 /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    register #($bits(gl_instruction_t)+$bits(gl_index_t)) commit_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_commit),
        .load_i(src_select_commit),
        .input_i({instruction_gl_commit,index_gl_commit}),
        .output_o({instruction_gl_commit_old_q,index_gl_commit_old_q})
    );

    // Syncronus Mux to decide between actual (decode + rename) or one cycle before (decode + rename)
    always @(posedge clk_i) begin
        src_select_commit <= !control_int.stall_commit;
    end

    assign instruction_to_commit = (src_select_commit)? instruction_gl_commit : instruction_gl_commit_old_q;
    assign commit_cu_int.gl_index = (src_select_commit)? index_gl_commit : index_gl_commit_old_q;

    csr_interface csr_interface_inst
    (
        .commit_xcpt_i              (commit_xcpt),
        .instruction_to_commit_i    (instruction_to_commit),
        .stall_exe_i                (control_int.stall_exe),
        .commit_store_or_amo_i      (commit_store_or_amo_int),
        .mem_commit_stall_i         (mem_commit_stall_int),
        .exception_mem_commit_i     (exception_mem_commit_int),
        .csr_ena_int_o              (csr_ena_int),
        .req_cpu_csr_o              (req_cpu_csr_o)
    );

    // Delay the PC_EVEC treatment one cycle
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            pc_evec_q <= 'b0;
            pc_next_csr_q <= 'b0;
        end else begin 
            pc_evec_q <= resp_csr_cpu_i.csr_evec;
            pc_next_csr_q <= instruction_to_commit.pc + 64'h4;
        end
    end

    // if there is an exception that can be from:
    // the instruction itself or the interrupt
    assign commit_xcpt = (~commit_store_or_amo_int)? instruction_to_commit.exception.valid : exception_mem_commit_int.valid;

    // Control Unit From Commit
    assign commit_cu_int.valid = instruction_to_commit.valid;
    assign commit_cu_int.regfile_we = instruction_to_commit.regfile_we;
    assign commit_cu_int.csr_enable = csr_ena_int;
    assign commit_cu_int.stall_csr_fence = instruction_to_commit.stall_csr_fence && instruction_to_commit.valid;
    assign commit_cu_int.xcpt = commit_xcpt;

    // tell cu that ecall was taken
    assign commit_cu_int.ecall_taken = (instruction_to_commit.instr_type == ECALL  ||
                                        instruction_to_commit.instr_type == MRTS   ||
                                        instruction_to_commit.instr_type == EBREAK );

    // tell cu that there is a fence or fence_i
    assign commit_cu_int.fence = (instruction_to_commit.instr_type == FENCE_I || 
                                  instruction_to_commit.instr_type == FENCE || 
                                  instruction_to_commit.instr_type == SFENCE_VMA);
    // tell cu there is a fence i to flush the icache
    assign commit_cu_int.fence_i = (instruction_to_commit.instr_type == FENCE_I || 
                                    instruction_to_commit.instr_type == SFENCE_VMA);

    // tell cu that commit needs to write there is a fence
    assign commit_cu_int.write_enable = instruction_to_commit.valid &
                                        (instruction_to_commit.instr_type == CSRRW  ||
                                         instruction_to_commit.instr_type == CSRRS  ||
                                         instruction_to_commit.instr_type == CSRRC  ||
                                         instruction_to_commit.instr_type == CSRRWI ||
                                         instruction_to_commit.instr_type == CSRRSI ||
                                         instruction_to_commit.instr_type == CSRRCI );

    assign commit_store_or_amo_int = (instruction_to_commit.instr_type == SD)          || 
                                     (instruction_to_commit.instr_type == SW)          ||
                                     (instruction_to_commit.instr_type == SH)          ||
                                     (instruction_to_commit.instr_type == SB)          ||
                                     (instruction_to_commit.instr_type == AMO_MAXWU)   ||
                                     (instruction_to_commit.instr_type == AMO_MAXDU)   ||
                                     (instruction_to_commit.instr_type == AMO_MINWU)   ||
                                     (instruction_to_commit.instr_type == AMO_MINDU)   ||
                                     (instruction_to_commit.instr_type == AMO_MAXW)    ||
                                     (instruction_to_commit.instr_type == AMO_MAXD)    ||
                                     (instruction_to_commit.instr_type == AMO_MINW)    ||
                                     (instruction_to_commit.instr_type == AMO_MIND)    ||
                                     (instruction_to_commit.instr_type == AMO_ORW)     ||
                                     (instruction_to_commit.instr_type == AMO_ORD)     ||
                                     (instruction_to_commit.instr_type == AMO_ANDW)    ||
                                     (instruction_to_commit.instr_type == AMO_ANDD)    ||
                                     (instruction_to_commit.instr_type == AMO_XORW)    ||
                                     (instruction_to_commit.instr_type == AMO_XORD)    ||
                                     (instruction_to_commit.instr_type == AMO_ADDW)    ||
                                     (instruction_to_commit.instr_type == AMO_ADDD)    ||
                                     (instruction_to_commit.instr_type == AMO_SWAPW)   ||
                                     (instruction_to_commit.instr_type == AMO_SWAPD)   ||
                                     (instruction_to_commit.instr_type == AMO_SCW)     ||
                                     (instruction_to_commit.instr_type == AMO_SCD)     ||
                                     (instruction_to_commit.instr_type == AMO_LRW)     ||
                                     (instruction_to_commit.instr_type == AMO_LRD)     ;

    assign commit_cu_int.stall_commit = mem_commit_stall_int | (commit_store_or_amo_int & (commit_cu_int.gl_index != mem_gl_index_int));

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// DEBUG SIGNALS                                                                                /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef VERILATOR
    // Debug signals
    assign commit_valid     = instruction_to_commit.valid && !commit_cu_int.stall_commit;
    assign commit_pc        = (instruction_to_commit.valid) ? instruction_to_commit.pc : 64'b0;

    always_comb begin 
        if(instruction_to_commit.valid) begin
            if (commit_cu_int.write_enable) begin
                commit_data = resp_csr_cpu_i.csr_rw_rdata;
            end else if (commit_store_or_amo_int & (commit_cu_int.gl_index == mem_gl_index_int)) begin
                commit_data = exe_to_wb_scalar[1].result;
            end else begin
                commit_data = instruction_to_commit.result;
            end
        end else begin
            commit_data = 64'b0;
        end
    end

    assign commit_addr_reg  = instruction_to_commit.rd;
    assign commit_reg_we    = instruction_to_commit.regfile_we && commit_valid;

    // PC
    assign pc_if1  = stage_if_1_if_2_d.pc_inst;
    assign pc_if2  = stage_if_2_id_d.pc_inst;
    assign pc_id  = (valid_id)  ? decoded_instr.pc : 64'b0;
    assign pc_rr  = (valid_rr)  ? stage_rr_exe_d.instr.pc : 64'b0;
    assign pc_exe = (valid_exe) ? stage_rr_exe_q.instr.pc : 64'b0;
    assign pc_wb = (valid_wb) ? wb_scalar[0].pc : 64'b0;

    // Valid
    assign valid_if1  = stage_if_1_if_2_d.valid;
    assign valid_if2  = stage_if_2_id_d.valid;
    assign valid_id  = decoded_instr.valid;
    assign valid_rr  = stage_rr_exe_d.instr.valid;
    assign valid_exe = stage_rr_exe_q.instr.valid;
    assign valid_wb = wb_scalar[0].valid;

    // Module that generates the signature of the core to compare with spike
    `ifdef VERILATOR_TORTURE_TESTS
        torture_dump_behav torture_dump
        (
            .clk(clk_i),
            .rst(rstn_i),
            .commit_valid(commit_valid),
            .reg_wr_valid(commit_reg_we && (commit_addr_reg != 5'b0)),
            .pc(commit_pc),
            .inst(instruction_to_commit.inst),
            .reg_dst(commit_addr_reg),
            .data(commit_data),
            .xcpt(commit_xcpt),
            .xcpt_cause(instruction_to_commit.exception.cause),
            .csr_priv_lvl(csr_priv_lvl_i),
            .csr_rw_data(req_cpu_csr_o.csr_rw_data),
            .csr_xcpt(resp_csr_cpu_i.csr_exception),
            .csr_xcpt_cause(resp_csr_cpu_i.csr_exception_cause),
            .csr_tval(resp_csr_cpu_i.csr_tval)
        );
        konata_dump_behav konata_dump
        (
            .clk(clk_i),
            .rst(rstn_i),
            .if1_valid(valid_if1),
            .if1_id(id_fetch), 
            .if1_stall(control_int.stall_if_1),
            .if1_flush(flush_int.flush_if),

            .if2_valid(valid_if2),
            .if2_id(stage_if_2_id_d.id),
            .if2_stall(control_int.stall_if_2),
            .if2_flush(flush_int.flush_if),

            .id_valid(valid_id),
            .id_inst(stage_if_2_id_q.inst),
            .id_pc(pc_id),
            .id_id(stage_if_2_id_q.id),
            .id_stall(control_int.stall_id),
            .id_flush(flush_int.flush_id),

            .ir_valid(stage_ir_rr_d.instr.valid),
            .ir_id(stage_ir_rr_d.instr.id),
            .ir_stall(control_int.stall_ir),
            .ir_flush(flush_int.flush_ir),

            .rr_valid(valid_rr),
            .rr_id(stage_ir_rr_q.instr.id),
            .rr_stall(control_int.stall_rr),
            .rr_flush(flush_int.flush_rr),

            .exe_valid(valid_exe),
            .exe_id(stage_rr_exe_q.instr.id),
            .exe_stall(control_int.stall_exe),
            .exe_flush(flush_int.flush_exe),

            .wb1_valid(wb_scalar[0].valid),
            .wb1_id(wb_scalar[0].id),

            .wb2_valid(wb_scalar[1].valid),
            .wb2_id(wb_scalar[1].id)
        );
    `endif
`endif

    // Debug Ring signals Output
    // PC
    assign debug_o.pc_fetch = pc_if2[39:0];
    assign debug_o.pc_dec   = pc_id[39:0];
    assign debug_o.pc_rr    = pc_rr[39:0];
    assign debug_o.pc_exe   = pc_exe[39:0];
    assign debug_o.pc_wb    = pc_wb[39:0];
    // Write-back signals
    assign debug_o.wb_valid_1 = wb_scalar[0].valid;
    assign debug_o.wb_reg_addr_1 = wb_scalar[0].rd;
    assign debug_o.wb_reg_we_1 = wb_scalar[0].regfile_we;
    assign debug_o.wb_valid_2 = wb_scalar[1].valid;
    assign debug_o.wb_reg_addr_2 = wb_scalar[1].rd;
    assign debug_o.wb_reg_we_2 = wb_scalar[1].regfile_we;
    // Register File read 
    assign debug_o.reg_read_data = stage_rr_exe_d.data_rs1;


    //PMU
    assign pmu_flags_o.stall_if        = resp_csr_cpu_i.csr_stall ;
    
    assign pmu_flags_o.stall_id        = control_int.stall_id || ~decoded_instr.valid;
    assign pmu_flags_o.stall_exe       = control_int.stall_exe || ~reg_to_exe.instr.valid;
    assign pmu_flags_o.load_store      = commit_store_or_amo_int || instruction_to_commit.instr_type == LB  || 
                                                                 instruction_to_commit.instr_type == LH  ||
                                                                 instruction_to_commit.instr_type == LW  ||
                                                                 instruction_to_commit.instr_type == LD  ||
                                                                 instruction_to_commit.instr_type == LBU ||
                                                                 instruction_to_commit.instr_type == LHU ||
                                                                 instruction_to_commit.instr_type == LWU;
    assign pmu_flags_o.data_depend     = ~pmu_exe_ready && ~pmu_flags_o.stall_exe;
    assign pmu_flags_o.grad_list_full  = rr_cu_int.gl_full && ~resp_csr_cpu_i.csr_stall && ~exe_cu_int.stall;
    assign pmu_flags_o.free_list_empty = free_list_empty && ~rr_cu_int.gl_full && ~resp_csr_cpu_i.csr_stall && ~exe_cu_int.stall;
endmodule
