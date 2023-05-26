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

module datapath
    import drac_pkg::*;
    import riscv_pkg::*;
    import mmu_pkg::*;
(
    input logic             clk_i,
    input logic             rstn_i,
    input addr_t            reset_addr_i,
    input logic             soft_rstn_i,
    // icache/dcache/CSR interface input
    input resp_icache_cpu_t resp_icache_cpu_i,
    input resp_dcache_cpu_t resp_dcache_cpu_i,
    input resp_csr_cpu_t    resp_csr_cpu_i,
    input [2:0]             csr_frm_i, 
    input [1:0]             csr_fs_i,  
    input logic             en_translation_i,
    input logic             en_ld_st_translation_i,
    input debug_in_t        debug_i,
    input [1:0]             csr_priv_lvl_i,
    input logic             req_icache_ready_i,
    input sew_t             sew_i,
    input tlb_cache_comm_t  dtlb_comm_i,
    // icache/dcache/CSR interface output
    output req_cpu_dcache_t req_cpu_dcache_o, 
    output req_cpu_icache_t req_cpu_icache_o,
    output req_cpu_csr_t    req_cpu_csr_o,
    output debug_out_t      debug_o,
    output cache_tlb_comm_t dtlb_comm_o,
    //--PMU   
    output to_PMU_t         pmu_flags_o
);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////// SIGNAL DECLARATION                                                                           /////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef VERILATOR
    // Stages: if -- id -- rr -- ex -- wb
    bus64_t [1:0] commit_pc;
    bus_simd_t [1:0] commit_data;
    logic [1:0] commit_valid;
    logic [1:0] commit_reg_we;
    logic [1:0] commit_vreg_we; 
    logic [1:0] commit_freg_we;
    reg_t [1:0] commit_addr_reg;
    reg_t [1:0] commit_addr_freg;
    reg_t [1:0] commit_addr_vreg;
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
    id_ir_stage_t decoded_instr;
    id_ir_stage_t stored_instr_id_d;
    id_ir_stage_t stored_instr_id_q;
    id_ir_stage_t selection_id_ir;

    id_cu_t id_cu_int;
    jal_id_if_t jal_id_if_int;
    
    logic src_select_id_ir_q;
    
    // Rename and free list
    id_ir_stage_t stage_iq_ir_q;
    id_ir_stage_t stage_ir_rr_d;
    ir_rr_stage_t stage_ir_rr_q;
    ir_rr_stage_t stage_stall_rr_q;
    ir_rr_stage_t stage_no_stall_rr_q;

    logic ir_scalar_rdy_src1_int;
    logic ir_scalar_rdy_src2_int;
    logic ir_fp_rdy_src1_int;
    logic ir_fp_rdy_src2_int;

    phreg_t ir_scalar_preg_src1_int;
    phreg_t ir_scalar_preg_src2_int;
    phreg_t ir_scalar_old_dst_int;
    phreg_t ir_fp_preg_src2_int;
    phreg_t ir_fp_preg_src1_int;
    phreg_t ir_fp_old_dst_int;

    logic do_checkpoint;
    logic do_recover;
    logic delete_checkpoint;
    logic out_of_checkpoints_rename;
    logic out_of_checkpoints_free_list;
    logic simd_out_of_checkpoints_rename;
    logic simd_out_of_checkpoints_free_list;
    logic fp_out_of_checkpoints_rename;
    logic fp_out_of_checkpoints_free_list;

    logic free_list_empty;
    logic simd_free_list_empty;
    logic fp_free_list_empty;

    phreg_t  free_register_to_rename;
    phvreg_t simd_free_register_to_rename;
    phfreg_t fp_free_register_to_rename;

    checkpoint_ptr checkpoint_free_list;
    checkpoint_ptr checkpoint_rename;
    checkpoint_ptr simd_checkpoint_free_list;
    checkpoint_ptr simd_checkpoint_rename;
    checkpoint_ptr fp_checkpoint_free_list;
    checkpoint_ptr fp_checkpoint_rename;

    logic src_select_ir_rr_q;

    ir_cu_t ir_cu_int;
    cu_ir_t cu_ir_int;

    reg_t free_list_read_src1_int;

    // Read Registers
    rr_exe_instr_t stage_rr_exe_d;
    rr_exe_instr_t stage_rr_exe_q;

    bus64_t rr_data_scalar_src1;
    bus64_t rr_data_scalar_src2;
    bus64_t rr_data_fp_src1;
    bus64_t rr_data_fp_src2;

    logic [drac_pkg::NUM_SCALAR_WB-1:0] snoop_rr_rs1;
    logic [drac_pkg::NUM_SCALAR_WB-1:0] snoop_rr_rs2;
    logic snoop_rr_rdy1;
    logic snoop_rr_rdy2;
    logic snoop_rr_vrdy1;
    logic snoop_rr_vrdy2;
    logic snoop_rr_vrdy_old_vd;
    logic snoop_rr_vrdym;

    logic [drac_pkg::NUM_FP_WB-1:0] snoop_rr_frs1;
    logic [drac_pkg::NUM_FP_WB-1:0] snoop_rr_frs2;
    logic [drac_pkg::NUM_FP_WB-1:0] snoop_rr_frs3;
    logic snoop_rr_frdy1;
    logic snoop_rr_frdy2;
    logic snoop_rr_frdy3;

    rr_cu_t rr_cu_int;
    cu_rr_t cu_rr_int;

    logic is_csr_int;
    reg_csr_addr_t csr_addr_int;
    exception_t ex_gl_in_int;

    bus64_t result_gl_out_int;
    reg_csr_addr_t csr_addr_gl_out_int;
    exception_t ex_gl_out_int;

    exception_t interrupt_ex;

    exception_t ex_from_exe_int;
    gl_index_t ex_from_exe_index_int;
    // Graduation List

    gl_instruction_t instruction_decode_gl;
    
    gl_wb_data_t [drac_pkg::NUM_SCALAR_WB-1:0] instruction_writeback_gl;
    gl_index_t       [drac_pkg::NUM_SCALAR_WB-1:0] gl_index;
    logic            [drac_pkg::NUM_SCALAR_WB-1:0] gl_valid;
    // FP
    gl_wb_data_t [drac_pkg::NUM_FP_WB-1:0] instruction_fp_writeback_gl;
    gl_index_t       [drac_pkg::NUM_FP_WB-1:0] gl_index_fp;
    logic            [drac_pkg::NUM_FP_WB-1:0] gl_valid_fp;
    // SIMD
    gl_wb_data_t [drac_pkg::NUM_SIMD_WB-1:0]   instruction_simd_writeback_gl;
    gl_index_t       [drac_pkg::NUM_SIMD_WB-1:0]   gl_index_simd;
    logic            [drac_pkg::NUM_SIMD_WB-1:0]   gl_valid_simd;

    gl_instruction_t [1:0] instruction_gl_commit; 
    
    // Exe
    rr_exe_instr_t selection_rr_exe_d;

    exe_cu_t exe_cu_int;
    exe_wb_scalar_instr_t [drac_pkg::NUM_SCALAR_WB-1:0] exe_to_wb_scalar;
    exe_wb_scalar_instr_t [1:0] exe_to_wb_scalar_simd_fp;
    exe_wb_scalar_instr_t [drac_pkg::NUM_SCALAR_WB-1:0] wb_scalar;
    exe_wb_simd_instr_t [drac_pkg::NUM_SIMD_WB-1:0] exe_to_wb_simd;
    exe_wb_simd_instr_t [drac_pkg::NUM_SIMD_WB-1:0] wb_simd;
    exe_wb_fp_instr_t [drac_pkg::NUM_FP_WB-1:0] exe_to_wb_fp;
    exe_wb_fp_instr_t [drac_pkg::NUM_FP_WB-1:0] wb_fp;

    bus64_t snoop_exe_data_rs1;
    bus64_t snoop_exe_data_rs2;
    logic   [NUM_SCALAR_WB-1:0] snoop_exe_rs1;
    logic   [NUM_SCALAR_WB-1:0] snoop_exe_rs2;
    logic snoop_exe_rdy1;
    logic snoop_exe_rdy2;
    bus_simd_t snoop_exe_data_vs1;
    bus_simd_t snoop_exe_data_vs2;
    bus_simd_t snoop_exe_data_old_vd;
    bus_mask_t snoop_exe_data_vm;
    logic   [NUM_SIMD_WB-1:0] snoop_exe_vs1;
    logic   [NUM_SIMD_WB-1:0] snoop_exe_vs2;
    logic   [NUM_SIMD_WB-1:0] snoop_exe_old_vd;
    logic   [NUM_SIMD_WB-1:0] snoop_exe_vm;
    logic snoop_exe_vrdy1;
    logic snoop_exe_vrdy2;
    logic snoop_exe_vrdy_old_vd;
    logic snoop_exe_vrdym;
    logic pmu_exe_ready;

    bus64_t snoop_exe_data_frs1;
    bus64_t snoop_exe_data_frs2;
    bus64_t snoop_exe_data_frs3;
    logic   [drac_pkg::NUM_FP_WB-1:0] snoop_exe_frs1;
    logic   [drac_pkg::NUM_FP_WB-1:0] snoop_exe_frs2;
    logic   [drac_pkg::NUM_FP_WB-1:0] snoop_exe_frs3;
    logic snoop_exe_frdy1;
    logic snoop_exe_frdy2;
    logic snoop_exe_frdy3;

    bus64_t exe_data_rs1;
    bus64_t exe_data_rs2;
    bus_simd_t exe_data_vs1;
    bus_simd_t exe_data_vs2;
    bus_simd_t exe_data_old_vd;
    bus_mask_t exe_data_vm;
    bus64_t exe_data_frs1;
    bus64_t exe_data_frs2;
    bus64_t exe_data_frs3;
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
    bus64_t commit_xcpt_cause;
    logic commit_store_or_amo_int;
    logic mem_commit_store_or_amo_int;
    
    //gl_instruction_t instruction_gl_commit_old_q;
    gl_instruction_t [1:0] instruction_to_commit;
    logic src_select_commit;
    exception_t exception_mem_commit_int;
    gl_index_t mem_gl_index_int;
    gl_index_t index_gl_commit;
    logic [1:0] retire_inst_gl;
    //gl_index_t index_gl_commit_old_q;

    //Br at WB
    addrPC_t branch_addr_result_wb;
    logic correct_branch_pred_wb;

    // CSR signals
    logic   csr_ena_int;

    // Data to write to RR from WB or CSR
    bus64_t [NUM_SCALAR_WB-1:0] data_wb_to_rr;
    bus64_t [NUM_SCALAR_WB-1:0] data_wb_to_exe;
    phreg_t [NUM_SCALAR_WB-1:0] write_paddr_rr;
    phreg_t [NUM_SCALAR_WB-1:0] write_paddr_exe;
    reg_t   [NUM_SCALAR_WB-1:0] write_vaddr;

    bus_simd_t [NUM_SIMD_WB-1:0] simd_data_wb_to_rr;
    bus_simd_t [NUM_SIMD_WB-1:0] simd_data_wb_to_exe;
    phvreg_t   [NUM_SIMD_WB-1:0] simd_write_paddr_rr;
    phvreg_t   [NUM_SIMD_WB-1:0] simd_write_paddr_exe;
    vreg_t     [NUM_SIMD_WB-1:0] simd_write_vaddr;

    // Data to write to RR from WB or CSR
    bus64_t [drac_pkg::NUM_FP_WB-1:0] fp_data_wb_to_rr;
    bus64_t [drac_pkg::NUM_FP_WB-1:0] fp_data_wb_to_exe;
    phreg_t [drac_pkg::NUM_FP_WB-1:0] fp_write_paddr_rr;
    phreg_t [drac_pkg::NUM_FP_WB-1:0] fp_write_paddr_exe;
    reg_t   [drac_pkg::NUM_FP_WB-1:0] fp_write_vaddr;

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// IO ADDRESS SPACE                                                                             /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////


    // Debug signals
    bus64_t    reg_wr_data;
    phreg_t    reg_wr_addr;
    bus_simd_t vreg_wr_data;
    phvreg_t   vreg_wr_addr;
    phreg_t    reg_prd1_addr;
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
        .en_translation_i(en_translation_i), 
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
        .frm_i          (csr_frm_i),
        .csr_fs_i       (csr_fs_i), 
        .decode_instr_o (decoded_instr),
        .jal_id_if_o    (jal_id_if_int)
    );

    // valid jal in decode
    assign id_cu_int.valid               = decoded_instr.instr.valid;
    assign id_cu_int.valid_jal           = jal_id_if_int.valid;
    assign id_cu_int.stall_csr_fence     = decoded_instr.instr.stall_csr_fence && decoded_instr.instr.valid;
    assign id_cu_int.predicted_as_branch = decoded_instr.instr.bpred.is_branch;
    assign id_cu_int.is_branch           = (decoded_instr.instr.instr_type == BLT)  ||
                                           (decoded_instr.instr.instr_type == BLTU) ||
                                           (decoded_instr.instr.instr_type == BGE)  ||
                                           (decoded_instr.instr.instr_type == BGEU) ||
                                           (decoded_instr.instr.instr_type == BEQ)  ||
                                           (decoded_instr.instr.instr_type == BNE)  ||
                                           (decoded_instr.instr.instr_type == JAL) ||
                                           (decoded_instr.instr.instr_type == JALR);


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// INSTRUCTION QUEUE, FREE LIST AND RENAME               STAGE                                  /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign stored_instr_id_d = (src_select_id_ir_q) ? decoded_instr : stored_instr_id_q;
assign free_list_read_src1_int = (debug_i.reg_read_valid  && debug_i.halt_valid)  ? debug_i.reg_read_write_addr : stage_iq_ir_q.instr.rs1;
assign debug_o.reg_list_paddr = stage_no_stall_rr_q.prs1;

    // Register ID to IR when stall
    register #($bits(id_ir_stage_t)) reg_id_inst(
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
        .instruction_o  (stage_iq_ir_q),
        .full_o         (ir_cu_int.full_iq),
        .empty_o        ()
    );

    // Free List
    free_list free_list_inst(
        .clk_i                  (clk_i),
        .rstn_i                 (rstn_i),
        .read_head_i            (stage_iq_ir_q.instr.regfile_we & stage_iq_ir_q.instr.valid & (stage_iq_ir_q.instr.rd != 'h0) & (~control_int.stall_ir) & (~control_int.stall_iq)),
        .add_free_register_i    (cu_ir_int.enable_commit_update),
        .free_register_i        ({instruction_to_commit[1].old_prd, instruction_to_commit[0].old_prd}),
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

    simd_free_list simd_free_list_inst(
        .clk_i                  (clk_i),
        .rstn_i                 (rstn_i),
        .read_head_i            (stage_iq_ir_q.instr.vregfile_we & stage_iq_ir_q.instr.valid & (~control_int.stall_ir) & (~control_int.stall_iq)),
        .add_free_register_i    (cu_ir_int.simd_enable_commit_update),
        .free_register_i        ({instruction_to_commit[1].old_pvd, instruction_to_commit[0].old_pvd}),
        .do_checkpoint_i        (cu_ir_int.do_checkpoint),
        .do_recover_i           (cu_ir_int.do_recover),
        .delete_checkpoint_i    (cu_ir_int.delete_checkpoint),
        .recover_checkpoint_i   (cu_ir_int.recover_checkpoint),
        .commit_roll_back_i     (cu_ir_int.recover_commit),
        .new_register_o         (simd_free_register_to_rename),
        .checkpoint_o           (simd_checkpoint_free_list),
        .out_of_checkpoints_o   (simd_out_of_checkpoints_free_list),
        .empty_o                (simd_free_list_empty) // TODO not connected
    );

    fp_free_list fp_free_list_inst(
        .clk_i                  (clk_i),
        .rstn_i                 (rstn_i),
        .read_head_i            (stage_iq_ir_q.instr.fregfile_we & stage_iq_ir_q.instr.valid & (~control_int.stall_ir) & (~control_int.stall_iq)),
        .add_free_register_i    (cu_ir_int.fp_enable_commit_update),
        .free_register_i        ({instruction_to_commit[1].old_fprd, instruction_to_commit[0].old_fprd}),
        .do_checkpoint_i        (cu_ir_int.do_checkpoint),
        .do_recover_i           (cu_ir_int.do_recover),
        .delete_checkpoint_i    (cu_ir_int.delete_checkpoint),
        .recover_checkpoint_i   (cu_ir_int.recover_checkpoint),
        .commit_roll_back_i     (cu_ir_int.recover_commit),
        .new_register_o         (fp_free_register_to_rename),
        .checkpoint_o           (fp_checkpoint_free_list),
        .out_of_checkpoints_o   (fp_out_of_checkpoints_free_list),
        .empty_o                (fp_free_list_empty) // TODO not connected
    );

    // Rename Table
    rename_table rename_table_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .read_src1_i( free_list_read_src1_int ),
        .read_src2_i(stage_iq_ir_q.instr.rs2),
        .old_dst_i(stage_iq_ir_q.instr.rd),
        .write_dst_i(stage_iq_ir_q.instr.regfile_we & stage_iq_ir_q.instr.valid & (~control_int.stall_ir) & (~control_int.stall_iq)),
        .new_dst_i(free_register_to_rename),
        .use_rs1_i(stage_iq_ir_q.instr.use_rs1 | (debug_i.reg_read_valid  && debug_i.halt_valid)),
        .use_rs2_i(stage_iq_ir_q.instr.use_rs2),
        .ready_i(cu_rr_int.write_enable),
        .vaddr_i(write_vaddr),
        .paddr_i(write_paddr_rr),
        .do_checkpoint_i(cu_ir_int.do_checkpoint),
        .do_recover_i(cu_ir_int.do_recover),
        .delete_checkpoint_i(cu_ir_int.delete_checkpoint),
        .recover_checkpoint_i(cu_ir_int.recover_checkpoint),
        .recover_commit_i(cu_ir_int.recover_commit), 
        .commit_old_dst_i({instruction_to_commit[1].rd, instruction_to_commit[0].rd}),    
        .commit_write_dst_i(cu_ir_int.enable_commit_update),  
        .commit_new_dst_i({instruction_to_commit[1].prd, instruction_to_commit[0].prd}),
        .src1_o(stage_no_stall_rr_q.prs1),
        .rdy1_o(stage_no_stall_rr_q.rdy1),
        .src2_o(stage_no_stall_rr_q.prs2),
        .rdy2_o(stage_no_stall_rr_q.rdy2),
        .old_dst_o(stage_no_stall_rr_q.old_prd),
        .checkpoint_o(checkpoint_rename),
        .out_of_checkpoints_o(out_of_checkpoints_rename)
    );

    simd_rename_table simd_rename_table_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .read_src1_i(stage_iq_ir_q.instr.vs1),
        .read_src2_i(stage_iq_ir_q.instr.vs2),
        .old_dst_i(stage_iq_ir_q.instr.vd),
        .write_dst_i(stage_iq_ir_q.instr.vregfile_we & stage_iq_ir_q.instr.valid & (~control_int.stall_ir) & (~control_int.stall_iq)),
        .new_dst_i(simd_free_register_to_rename),
        .use_vs1_i(stage_iq_ir_q.instr.use_vs1),
        .use_vs2_i(stage_iq_ir_q.instr.use_vs2),
        .use_mask_i(stage_iq_ir_q.instr.use_mask),
        .use_old_vd_i(stage_iq_ir_q.instr.vregfile_we & stage_iq_ir_q.instr.use_mask),
        .ready_i(cu_rr_int.vwrite_enable),
        .vaddr_i(simd_write_vaddr),
        .paddr_i(simd_write_paddr_rr),
        .do_checkpoint_i(cu_ir_int.do_checkpoint),
        .do_recover_i(cu_ir_int.do_recover),
        .delete_checkpoint_i(cu_ir_int.delete_checkpoint),
        .recover_checkpoint_i(cu_ir_int.recover_checkpoint),
        .recover_commit_i(cu_ir_int.recover_commit), 
        .commit_old_dst_i({instruction_to_commit[1].vd, instruction_to_commit[0].vd}),    
        .commit_write_dst_i(cu_ir_int.simd_enable_commit_update),  
        .commit_new_dst_i({instruction_to_commit[1].pvd, instruction_to_commit[0].pvd}),
        .src1_o(stage_no_stall_rr_q.pvs1),
        .rdy1_o(stage_no_stall_rr_q.vrdy1),
        .src2_o(stage_no_stall_rr_q.pvs2),
        .rdy2_o(stage_no_stall_rr_q.vrdy2),
        .srcm_o(stage_no_stall_rr_q.pvm),
        .rdym_o(stage_no_stall_rr_q.vrdym),
        .old_dst_o(stage_no_stall_rr_q.old_pvd),
        .rdy_old_dst_o(stage_no_stall_rr_q.vrdy_old_vd),
        .checkpoint_o(simd_checkpoint_rename),
        .out_of_checkpoints_o(simd_out_of_checkpoints_rename)
    );

    // FP Rename Table 
    fp_rename_table fp_rename_table_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .read_src1_i(stage_iq_ir_q.instr.rs1),
        .read_src2_i(stage_iq_ir_q.instr.rs2),
        .read_src3_i(stage_iq_ir_q.instr.rs3),
        .old_dst_i(stage_iq_ir_q.instr.rd),
        .write_dst_i(stage_iq_ir_q.instr.fregfile_we & stage_iq_ir_q.instr.valid & (~control_int.stall_ir) & (~control_int.stall_iq)),
        .new_dst_i(fp_free_register_to_rename),
        .use_fs1_i(stage_iq_ir_q.instr.use_fs1),
        .use_fs2_i(stage_iq_ir_q.instr.use_fs2),
        .use_fs3_i(stage_iq_ir_q.instr.use_fs3),
        .ready_i(cu_rr_int.fwrite_enable),
        .vaddr_i(fp_write_vaddr), // WB
        .paddr_i(fp_write_paddr_rr), // WB
        .do_checkpoint_i(cu_ir_int.do_checkpoint),
        .do_recover_i(cu_ir_int.do_recover),
        .delete_checkpoint_i(cu_ir_int.delete_checkpoint),
        .recover_checkpoint_i(cu_ir_int.recover_checkpoint),
        .recover_commit_i(cu_ir_int.recover_commit),
        .commit_old_dst_i({instruction_to_commit[1].rd, instruction_to_commit[0].rd}),
        .commit_write_dst_i(cu_ir_int.fp_enable_commit_update),
        .commit_new_dst_i({instruction_to_commit[1].fprd, instruction_to_commit[0].fprd}),
        .src1_o(stage_no_stall_rr_q.fprs1),
        .rdy1_o(stage_no_stall_rr_q.frdy1),
        .src2_o(stage_no_stall_rr_q.fprs2),
        .rdy2_o(stage_no_stall_rr_q.frdy2),
        .src3_o(stage_no_stall_rr_q.fprs3),
        .rdy3_o(stage_no_stall_rr_q.frdy3),
        .old_dst_o(stage_no_stall_rr_q.old_fprd),
        .checkpoint_o(fp_checkpoint_rename),
        .out_of_checkpoints_o(fp_out_of_checkpoints_rename)
    );
    
    // Check two structures output the same
    /*always @(posedge clk_i) assert (out_of_checkpoints_rename == out_of_checkpoints_free_list);
    always @(posedge clk_i) assert (checkpoint_rename == checkpoint_free_list);
    always @(posedge clk_i) assert (simd_out_of_checkpoints_rename == simd_out_of_checkpoints_free_list);
    always @(posedge clk_i) assert (simd_checkpoint_rename == simd_checkpoint_free_list);
    always @(posedge clk_i) assert (fp_out_of_checkpoints_rename == fp_out_of_checkpoints_free_list);
    always @(posedge clk_i) assert (fp_checkpoint_rename == fp_checkpoint_free_list); */

    assign stage_no_stall_rr_q.chkp = checkpoint_rename;

    // Signals for Control Unit
    assign ir_cu_int.valid                   = stage_iq_ir_q.instr.valid;
    assign ir_cu_int.empty_free_list         = free_list_empty;
    assign ir_cu_int.out_of_checkpoints      = out_of_checkpoints_rename;
    assign ir_cu_int.simd_out_of_checkpoints = simd_out_of_checkpoints_rename;
    assign ir_cu_int.fp_out_of_checkpoints   = fp_out_of_checkpoints_rename;
    assign ir_cu_int.is_branch               = (stage_iq_ir_q.instr.instr_type == BLT)  ||
                                               (stage_iq_ir_q.instr.instr_type == BLTU) ||
                                               (stage_iq_ir_q.instr.instr_type == BGE)  ||
                                               (stage_iq_ir_q.instr.instr_type == BGEU) ||
                                               (stage_iq_ir_q.instr.instr_type == BEQ)  ||
                                               (stage_iq_ir_q.instr.instr_type == BNE)  ||
                                               (stage_iq_ir_q.instr.instr_type == JALR);
    always_comb begin
        stage_ir_rr_d = stage_iq_ir_q;
        stage_ir_rr_d.instr.valid = stage_iq_ir_q.instr.valid & (~control_int.stall_iq); 
    end 
    // Register IR to RR
    register #($bits(id_ir_stage_t) + $bits(phreg_t) + $bits(phvreg_t) + $bits(phreg_t) + $bits(logic)) reg_ir_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_ir),
        .load_i(!control_int.stall_ir),
        .input_i({stage_ir_rr_d,free_register_to_rename, fp_free_register_to_rename, simd_free_register_to_rename,cu_ir_int.do_checkpoint}),
        .output_o({stage_no_stall_rr_q.instr,stage_no_stall_rr_q.ex,stage_no_stall_rr_q.prd,stage_no_stall_rr_q.fprd,stage_no_stall_rr_q.pvd,stage_no_stall_rr_q.checkpoint_done})
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
            stage_ir_rr_q.ex = stage_no_stall_rr_q.ex;
            stage_ir_rr_q.prd = stage_no_stall_rr_q.prd;
            stage_ir_rr_q.pvd = stage_no_stall_rr_q.pvd;
            stage_ir_rr_q.prs1 = stage_no_stall_rr_q.prs1;
            stage_ir_rr_q.pvs1 = stage_no_stall_rr_q.pvs1;
            stage_ir_rr_q.prs2 = stage_no_stall_rr_q.prs2;
            stage_ir_rr_q.pvs2 = stage_no_stall_rr_q.pvs2;
            stage_ir_rr_q.pvm  = stage_no_stall_rr_q.pvm;
            stage_ir_rr_q.rdy1 = stage_no_stall_rr_q.rdy1 | snoop_rr_rdy1;
            stage_ir_rr_q.vrdy1 = stage_no_stall_rr_q.vrdy1 | snoop_rr_vrdy1;
            stage_ir_rr_q.rdy2 = stage_no_stall_rr_q.rdy2 | snoop_rr_rdy2;
            stage_ir_rr_q.vrdy2 = stage_no_stall_rr_q.vrdy2 | snoop_rr_vrdy2;
            stage_ir_rr_q.vrdym = stage_no_stall_rr_q.vrdym | snoop_rr_vrdym;
            stage_ir_rr_q.old_prd = stage_no_stall_rr_q.old_prd;
            stage_ir_rr_q.old_pvd = stage_no_stall_rr_q.old_pvd;
            stage_ir_rr_q.vrdy_old_vd = stage_no_stall_rr_q.vrdy_old_vd | snoop_rr_vrdy_old_vd;
            stage_ir_rr_q.fprd = stage_no_stall_rr_q.fprd;
            stage_ir_rr_q.fprs1 = stage_no_stall_rr_q.fprs1;
            stage_ir_rr_q.fprs2 = stage_no_stall_rr_q.fprs2;
            stage_ir_rr_q.fprs3 = stage_no_stall_rr_q.fprs3;
            stage_ir_rr_q.frdy1 = stage_no_stall_rr_q.frdy1 | snoop_rr_frdy1;
            stage_ir_rr_q.frdy2 = stage_no_stall_rr_q.frdy2 | snoop_rr_frdy2;
            stage_ir_rr_q.frdy3 = stage_no_stall_rr_q.frdy3 | snoop_rr_frdy3;
            stage_ir_rr_q.old_fprd = stage_no_stall_rr_q.old_fprd;
            stage_ir_rr_q.chkp = stage_no_stall_rr_q.chkp;
            stage_ir_rr_q.checkpoint_done = stage_no_stall_rr_q.checkpoint_done;
        end else begin
            stage_ir_rr_q.instr = stage_stall_rr_q.instr;
            stage_ir_rr_q.ex = stage_stall_rr_q.ex;
            stage_ir_rr_q.prd = stage_stall_rr_q.prd;
            stage_ir_rr_q.pvd = stage_stall_rr_q.pvd;
            stage_ir_rr_q.prs1 = stage_stall_rr_q.prs1;
            stage_ir_rr_q.pvs1 = stage_stall_rr_q.pvs1;
            stage_ir_rr_q.prs2 = stage_stall_rr_q.prs2;
            stage_ir_rr_q.pvs2 = stage_stall_rr_q.pvs2;
            stage_ir_rr_q.pvm  = stage_stall_rr_q.pvm;
            stage_ir_rr_q.rdy1 = stage_stall_rr_q.rdy1 | snoop_rr_rdy1;
            stage_ir_rr_q.vrdy1 = stage_stall_rr_q.vrdy1 | snoop_rr_vrdy1;
            stage_ir_rr_q.rdy2 = stage_stall_rr_q.rdy2 | snoop_rr_rdy2;
            stage_ir_rr_q.vrdy2 = stage_stall_rr_q.vrdy2 | snoop_rr_vrdy2;
            stage_ir_rr_q.vrdym = stage_stall_rr_q.vrdym | snoop_rr_vrdym;
            stage_ir_rr_q.old_prd = stage_stall_rr_q.old_prd;
            stage_ir_rr_q.old_pvd = stage_stall_rr_q.old_pvd;
            stage_ir_rr_q.vrdy_old_vd = stage_stall_rr_q.vrdy_old_vd | snoop_rr_vrdy_old_vd;
            stage_ir_rr_q.fprd = stage_stall_rr_q.fprd;
            stage_ir_rr_q.fprs1 = stage_stall_rr_q.fprs1;
            stage_ir_rr_q.fprs2 = stage_stall_rr_q.fprs2;
            stage_ir_rr_q.fprs3 = stage_stall_rr_q.fprs3;
            stage_ir_rr_q.frdy1 = stage_stall_rr_q.frdy1 | snoop_rr_frdy1;
            stage_ir_rr_q.frdy2 = stage_stall_rr_q.frdy2 | snoop_rr_frdy2;
            stage_ir_rr_q.frdy3 = stage_stall_rr_q.frdy3 | snoop_rr_frdy3;
            stage_ir_rr_q.old_fprd = stage_stall_rr_q.old_fprd;
            stage_ir_rr_q.chkp = stage_stall_rr_q.chkp;
            stage_ir_rr_q.checkpoint_done = stage_stall_rr_q.checkpoint_done;
        end
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// GRADUATION LIST AND READ REGISTER  STAGE                                                     /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign instruction_decode_gl.valid                  = stage_ir_rr_q.instr.valid & (~control_int.stall_rr);
    assign instruction_decode_gl.instr_type             = stage_ir_rr_q.instr.instr_type;
    assign instruction_decode_gl.rd                     = stage_ir_rr_q.instr.rd;
    assign instruction_decode_gl.rs1                    = stage_ir_rr_q.instr.rs1;
    assign instruction_decode_gl.vd                     = stage_ir_rr_q.instr.vd;
    assign instruction_decode_gl.vs1                    = stage_ir_rr_q.instr.vs1;
    assign instruction_decode_gl.pc                     = stage_ir_rr_q.instr.pc;
    assign instruction_decode_gl.stall_csr_fence        = stage_ir_rr_q.instr.stall_csr_fence;
    assign instruction_decode_gl.old_prd                = stage_ir_rr_q.old_prd;
    assign instruction_decode_gl.old_fprd               = stage_ir_rr_q.old_fprd;
    assign instruction_decode_gl.old_pvd                = stage_ir_rr_q.old_pvd;
    assign instruction_decode_gl.prd                    = stage_ir_rr_q.prd;
    assign instruction_decode_gl.pvd                    = stage_ir_rr_q.pvd;
    assign instruction_decode_gl.fprd                   = stage_ir_rr_q.fprd;
    assign instruction_decode_gl.regfile_we             = stage_ir_rr_q.instr.regfile_we;
    assign instruction_decode_gl.vregfile_we            = stage_ir_rr_q.instr.vregfile_we;
    assign instruction_decode_gl.fregfile_we            = stage_ir_rr_q.instr.fregfile_we;
    `ifdef VERILATOR
        assign instruction_decode_gl.inst               = stage_ir_rr_q.instr.inst;
        assign instruction_decode_gl.id                 = stage_ir_rr_q.instr.id;
        assign instruction_decode_gl.exception = !stage_ir_rr_q.ex.valid && resp_csr_cpu_i.csr_interrupt ?  interrupt_ex : stage_ir_rr_q.ex;
    `endif
    assign instruction_decode_gl.fp_status              = '0;
    assign instruction_decode_gl.mem_type               = stage_ir_rr_q.instr.mem_type;

    // selecting the exception source, interrupt or exception from the front-end
    assign interrupt_ex.valid = resp_csr_cpu_i.csr_interrupt;
    assign interrupt_ex.cause = exception_cause_t'(resp_csr_cpu_i.csr_interrupt_cause);
    assign interrupt_ex.origin = 64'b0;
    assign instruction_decode_gl.ex_valid = stage_ir_rr_q.ex.valid | resp_csr_cpu_i.csr_interrupt;
    assign ex_gl_in_int = !stage_ir_rr_q.ex.valid && resp_csr_cpu_i.csr_interrupt ? interrupt_ex : stage_ir_rr_q.ex ;

    assign is_csr_int =(stage_ir_rr_q.instr.instr_type == ECALL ||
                        stage_ir_rr_q.instr.instr_type == SRET   ||
                        stage_ir_rr_q.instr.instr_type == MRET   ||
                        stage_ir_rr_q.instr.instr_type == URET   ||
                        stage_ir_rr_q.instr.instr_type == WFI    ||
                        stage_ir_rr_q.instr.instr_type == EBREAK ||
                        stage_ir_rr_q.instr.instr_type == FENCE  || 
                        stage_ir_rr_q.instr.instr_type == SFENCE_VMA || 
                        stage_ir_rr_q.instr.instr_type == FENCE_I|| 
                        stage_ir_rr_q.instr.instr_type == CSRRW  ||
                        stage_ir_rr_q.instr.instr_type == CSRRS  ||
                        stage_ir_rr_q.instr.instr_type == CSRRC  ||
                        stage_ir_rr_q.instr.instr_type == CSRRWI ||
                        stage_ir_rr_q.instr.instr_type == CSRRSI ||
                        stage_ir_rr_q.instr.instr_type == CSRRCI ||
                        stage_ir_rr_q.instr.instr_type == VSETVL ||
                        stage_ir_rr_q.instr.instr_type == VSETVLI);
    assign csr_addr_int = stage_ir_rr_q.instr.imm[CSR_ADDR_SIZE-1:0];
    

    graduation_list graduation_list_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .instruction_i(instruction_decode_gl),
        .is_csr_i(is_csr_int),
        .csr_addr_i(csr_addr_int),
        .ex_i(ex_gl_in_int),
        .read_head_i(retire_inst_gl),
        .instruction_writeback_i(gl_index),
        .instruction_writeback_enable_i(gl_valid),
        .instruction_writeback_data_i(instruction_writeback_gl),
        .instruction_simd_writeback_i(gl_index_simd),
        .instruction_simd_writeback_enable_i(gl_valid_simd),
        .instruction_simd_writeback_data_i(instruction_simd_writeback_gl),
        .instruction_fp_writeback_i(gl_index_fp),
        .instruction_fp_writeback_enable_i(gl_valid_fp),
        .instruction_fp_writeback_data_i(instruction_fp_writeback_gl),
        .ex_from_exe_index_i(ex_from_exe_index_int),
        .ex_from_exe_i(ex_from_exe_int),
        .flush_i(cu_wb_int.flush_gl),
        .flush_index_i(cu_wb_int.flush_gl_index),
        .flush_commit_i(cu_commit_int.flush_gl_commit),
        .assigned_gl_entry_o(stage_rr_exe_d.gl_index),
        .instruction_o(instruction_gl_commit),
        .commit_gl_entry_o(index_gl_commit),
        .full_o(rr_cu_int.gl_full),
        .empty_o(debug_o.reg_backend_empty),
        .csr_addr_o(csr_addr_gl_out_int),
        .result_o(result_gl_out_int),
        .exception_o(ex_gl_out_int)
    );

    always_comb begin
        snoop_rr_rdy1 = 1'b0;
        snoop_rr_rdy2 = 1'b0;
        snoop_rr_vrdy1 = 1'b0;
        snoop_rr_vrdy2 = 1'b0;
        snoop_rr_vrdy_old_vd = 1'b0;
        snoop_rr_vrdym = 1'b0;
        snoop_rr_frdy1 = 1'b0;
        snoop_rr_frdy2 = 1'b0;
        snoop_rr_frdy3 = 1'b0;

        for (int i = 0; i<NUM_SCALAR_WB; ++i) begin
            snoop_rr_rdy1 |= cu_rr_int.snoop_enable[i] & (write_paddr_exe[i] == stage_ir_rr_q.prs1) & (stage_ir_rr_q.instr.rs1!= 0);
            snoop_rr_rdy2 |= cu_rr_int.snoop_enable[i] & (write_paddr_exe[i] == stage_ir_rr_q.prs2) & (stage_ir_rr_q.instr.rs2!= 0);
        end

        for (int i = 0; i<NUM_SIMD_WB; ++i) begin
            snoop_rr_vrdy1 |= cu_rr_int.vsnoop_enable[i] & (simd_write_paddr_exe[i] == stage_ir_rr_q.pvs1);
            snoop_rr_vrdy2 |= cu_rr_int.vsnoop_enable[i] & (simd_write_paddr_exe[i] == stage_ir_rr_q.pvs2);
            snoop_rr_vrdy_old_vd |= cu_rr_int.vsnoop_enable[i] & (simd_write_paddr_exe[i] == stage_ir_rr_q.old_pvd);
            snoop_rr_vrdym |= cu_rr_int.vsnoop_enable[i] & (simd_write_paddr_exe[i] == stage_ir_rr_q.pvm) & stage_ir_rr_q.instr.use_mask;
        end

        for (int i = 0; i<drac_pkg::NUM_FP_WB; ++i) begin
            snoop_rr_frdy1 |= cu_rr_int.fwrite_enable[i] & (fp_write_paddr_exe[i] == stage_ir_rr_q.fprs1);
            snoop_rr_frdy2 |= cu_rr_int.fwrite_enable[i] & (fp_write_paddr_exe[i] == stage_ir_rr_q.fprs2);
            snoop_rr_frdy3 |= cu_rr_int.fwrite_enable[i] & (fp_write_paddr_exe[i] == stage_ir_rr_q.fprs3);
        end
    end

    assign reg_prd1_addr  = (debug_i.reg_p_read_valid  && debug_i.halt_valid)  ? debug_i.reg_read_write_paddr : stage_ir_rr_q.prs1;
    
    // RR Stage
    regfile regfile_inst(
        .clk_i (clk_i),

        .write_enable_i(cu_rr_int.write_enable),
        .write_addr_i(write_paddr_rr),
        .write_data_i(data_wb_to_rr),
        
        .read_addr1_i(reg_prd1_addr),
        .read_addr2_i(stage_ir_rr_q.prs2),
        .read_data1_o(rr_data_scalar_src1),
        .read_data2_o(rr_data_scalar_src2)
    );

    // RR Stage
    regfile_fp regfile_fp_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .write_enable_i(cu_rr_int.fwrite_enable),
        .write_addr_i(fp_write_paddr_rr),
        .write_data_i(fp_data_wb_to_rr),
        
        .read_addr1_i(stage_ir_rr_q.fprs1),
        .read_addr2_i(stage_ir_rr_q.fprs2),
        .read_addr3_i(stage_ir_rr_q.fprs3),
        .read_data1_o(rr_data_fp_src1),
        .read_data2_o(rr_data_fp_src2),
        .read_data3_o(stage_rr_exe_d.data_rs3)
    );

    vregfile vregfile(
        .clk_i (clk_i),
        .write_enable_i(cu_rr_int.vwrite_enable),
        .write_addr_i(simd_write_paddr_rr),
        .write_data_i(simd_data_wb_to_rr),
        .read_addr1_i(stage_ir_rr_q.pvs1),
        .read_addr2_i(stage_ir_rr_q.pvs2),
        .read_addr_old_vd_i(stage_ir_rr_q.old_pvd),
        .read_addrm_i(stage_ir_rr_q.pvm),
        .use_mask_i(stage_ir_rr_q.instr.use_mask),
        .read_data1_o(stage_rr_exe_d.data_vs1),
        .read_data2_o(stage_rr_exe_d.data_vs2),
        .read_data_old_vd_o(stage_rr_exe_d.data_old_vd),
        .read_mask_o(stage_rr_exe_d.data_vm)
    );
    // Decide from which Regfile to Read FP
    always_comb begin : read_src
        if (stage_ir_rr_q.instr.use_fs1) begin
            stage_rr_exe_d.data_rs1 = rr_data_fp_src1;
        end else begin // From Scalar
            stage_rr_exe_d.data_rs1 = rr_data_scalar_src1;
        end
        if (stage_ir_rr_q.instr.use_fs2) begin 
            stage_rr_exe_d.data_rs2 = rr_data_fp_src2;
        end else begin // From Scalar
            stage_rr_exe_d.data_rs2 = rr_data_scalar_src2;
        end
    end

    always_comb begin
        stage_rr_exe_d.instr = stage_ir_rr_q.instr;
        stage_rr_exe_d.instr.valid = stage_ir_rr_q.instr.valid && !(stage_ir_rr_q.instr.ex_valid | resp_csr_cpu_i.csr_interrupt);
        stage_rr_exe_d.instr.ex_valid = stage_ir_rr_q.instr.ex_valid | resp_csr_cpu_i.csr_interrupt;
    end
    assign stage_rr_exe_d.prd = stage_ir_rr_q.prd;
    assign stage_rr_exe_d.prs1 = stage_ir_rr_q.prs1;
    assign stage_rr_exe_d.prs2 = stage_ir_rr_q.prs2;
    assign stage_rr_exe_d.rdy1 = stage_ir_rr_q.rdy1;
    assign stage_rr_exe_d.rdy2 = stage_ir_rr_q.rdy2;
    assign stage_rr_exe_d.old_prd = stage_ir_rr_q.old_prd;
    assign stage_rr_exe_d.fprd = stage_ir_rr_q.fprd;
    assign stage_rr_exe_d.fprs1 = stage_ir_rr_q.fprs1;
    assign stage_rr_exe_d.fprs2 = stage_ir_rr_q.fprs2;
    assign stage_rr_exe_d.fprs3 = stage_ir_rr_q.fprs3;
    assign stage_rr_exe_d.frdy1 = stage_ir_rr_q.frdy1;
    assign stage_rr_exe_d.frdy2 = stage_ir_rr_q.frdy2;
    assign stage_rr_exe_d.frdy3 = stage_ir_rr_q.frdy3;
    assign stage_rr_exe_d.old_fprd = stage_ir_rr_q.old_fprd;
    assign stage_rr_exe_d.pvd = stage_ir_rr_q.pvd;
    assign stage_rr_exe_d.pvs1 = stage_ir_rr_q.pvs1;
    assign stage_rr_exe_d.pvs2 = stage_ir_rr_q.pvs2;
    assign stage_rr_exe_d.pvm  = stage_ir_rr_q.pvm;
    assign stage_rr_exe_d.vrdy1 = stage_ir_rr_q.vrdy1;
    assign stage_rr_exe_d.vrdy2 = stage_ir_rr_q.vrdy2;
    assign stage_rr_exe_d.vrdym = stage_ir_rr_q.vrdym;
    assign stage_rr_exe_d.old_pvd = stage_ir_rr_q.old_pvd;
    assign stage_rr_exe_d.vrdy_old_vd = stage_ir_rr_q.vrdy_old_vd;
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
        snoop_exe_data_vs1 = 'h0;
        snoop_exe_data_vs2 = 'h0;
        snoop_exe_data_old_vd = 'h0;
        snoop_exe_data_vm  = 'h0;
        snoop_exe_data_frs1 = 64'b0;
        snoop_exe_data_frs2 = 64'b0;
        snoop_exe_data_frs3 = 64'b0;

        for (int i = 0; i<drac_pkg::NUM_SCALAR_WB; ++i) begin
            snoop_exe_rs1[i] = cu_rr_int.snoop_enable[i] & (write_paddr_exe[i] == stage_rr_exe_q.prs1) & (stage_rr_exe_q.instr.rs1 != 0);
            snoop_exe_rs2[i] = cu_rr_int.snoop_enable[i] & (write_paddr_exe[i] == stage_rr_exe_q.prs2) & (stage_rr_exe_q.instr.rs2 != 0);
            snoop_exe_data_rs1 |= snoop_exe_rs1[i] ? data_wb_to_exe[i] : 64'b0;
            snoop_exe_data_rs2 |= snoop_exe_rs2[i] ? data_wb_to_exe[i] : 64'b0;
        end

        for (int i = 0; i<drac_pkg::NUM_SIMD_WB; ++i) begin
            snoop_exe_vs1[i] = cu_rr_int.vsnoop_enable[i] & (simd_write_paddr_exe[i] == stage_rr_exe_q.pvs1);
            snoop_exe_vs2[i] = cu_rr_int.vsnoop_enable[i] & (simd_write_paddr_exe[i] == stage_rr_exe_q.pvs2);
            snoop_exe_old_vd[i] = cu_rr_int.vsnoop_enable[i] & (simd_write_paddr_exe[i] == stage_rr_exe_q.old_pvd);
            snoop_exe_vm[i]  = cu_rr_int.vsnoop_enable[i] & (simd_write_paddr_exe[i] == stage_rr_exe_q.pvm) & stage_rr_exe_q.instr.use_mask;
            snoop_exe_data_vs1 |= snoop_exe_vs1[i] ? simd_data_wb_to_exe[i] : 'h0;
            snoop_exe_data_vs2 |= snoop_exe_vs2[i] ? simd_data_wb_to_exe[i] : 'h0;
            snoop_exe_data_old_vd |= snoop_exe_old_vd[i] ? simd_data_wb_to_exe[i] : 'h0;
            for (int j = 0; j<VLEN/8; ++j) begin
                snoop_exe_data_vm[j]  |= snoop_exe_vm[i]  ? simd_data_wb_to_exe[i][j*8] : 'h0; //LSB of every byte
            end
        end

        for (int i = 0; i<drac_pkg::NUM_FP_WB; ++i) begin
            snoop_exe_frs1[i] = cu_rr_int.fsnoop_enable[i] & (fp_write_paddr_exe[i] == stage_rr_exe_q.fprs1);
            snoop_exe_frs2[i] = cu_rr_int.fsnoop_enable[i] & (fp_write_paddr_exe[i] == stage_rr_exe_q.fprs2);
            snoop_exe_frs3[i] = cu_rr_int.fsnoop_enable[i] & (fp_write_paddr_exe[i] == stage_rr_exe_q.fprs3);
            snoop_exe_data_frs1 |= snoop_exe_frs1[i] ? fp_data_wb_to_exe[i] : 64'b0;
            snoop_exe_data_frs2 |= snoop_exe_frs2[i] ? fp_data_wb_to_exe[i] : 64'b0;
            snoop_exe_data_frs3 |= snoop_exe_frs3[i] ? fp_data_wb_to_exe[i] : 64'b0;
        end

        snoop_exe_rdy1 = |snoop_exe_rs1;
        snoop_exe_rdy2 = |snoop_exe_rs2;
        exe_data_rs1 = snoop_exe_rdy1 ? (snoop_exe_data_rs1) : stage_rr_exe_q.data_rs1;
        exe_data_rs2 = snoop_exe_rdy2 ? (snoop_exe_data_rs2) : stage_rr_exe_q.data_rs2;

        snoop_exe_vrdy1 = |snoop_exe_vs1;
        snoop_exe_vrdy2 = |snoop_exe_vs2;
        snoop_exe_vrdy_old_vd = |snoop_exe_old_vd;
        snoop_exe_vrdym = |snoop_exe_vm;

        exe_data_vs1 = snoop_exe_vrdy1 ? (snoop_exe_data_vs1) : stage_rr_exe_q.data_vs1;
        exe_data_vs2 = snoop_exe_vrdy2 ? (snoop_exe_data_vs2) : stage_rr_exe_q.data_vs2;
        exe_data_old_vd = snoop_exe_vrdy_old_vd ? (snoop_exe_data_old_vd) : stage_rr_exe_q.data_old_vd;
        exe_data_vm  = snoop_exe_vrdym ? (snoop_exe_data_vm)  : stage_rr_exe_q.data_vm;

        snoop_exe_frdy1 = |snoop_exe_frs1;
        snoop_exe_frdy2 = |snoop_exe_frs2;
        snoop_exe_frdy3 = |snoop_exe_frs3;

        exe_data_frs1 = snoop_exe_frdy1 ? (snoop_exe_data_frs1) : stage_rr_exe_q.data_rs1;
        exe_data_frs2 = snoop_exe_frdy2 ? (snoop_exe_data_frs2) : stage_rr_exe_q.data_rs2;
        exe_data_frs3 = snoop_exe_frdy3 ? (snoop_exe_data_frs3) : stage_rr_exe_q.data_rs3;
    end

    assign reg_to_exe.instr = stage_rr_exe_q.instr;
    assign reg_to_exe.data_vs1 = exe_data_vs1;
    assign reg_to_exe.data_vs2 = exe_data_vs2;
    assign reg_to_exe.data_old_vd = exe_data_old_vd;
    assign reg_to_exe.data_vm  = exe_data_vm;
    assign reg_to_exe.data_rs1 = (stage_rr_exe_q.instr.use_fs1) ? exe_data_frs1 : exe_data_rs1;
    assign reg_to_exe.data_rs2 = (stage_rr_exe_q.instr.use_fs2) ? exe_data_frs2 : exe_data_rs2;
    assign reg_to_exe.data_rs3 = exe_data_frs3;
    
    assign reg_to_exe.prs1 = stage_rr_exe_q.prs1;
    assign reg_to_exe.rdy1 = snoop_exe_rdy1 | stage_rr_exe_q.rdy1;
    assign reg_to_exe.prs2 = stage_rr_exe_q.prs2;
    assign reg_to_exe.rdy2 = snoop_exe_rdy2 | stage_rr_exe_q.rdy2;
    assign reg_to_exe.prd = stage_rr_exe_q.prd;
    assign reg_to_exe.old_prd = stage_rr_exe_q.old_prd;
    
    assign reg_to_exe.fprs1 = stage_rr_exe_q.fprs1;
    assign reg_to_exe.frdy1 = snoop_exe_frdy1 | stage_rr_exe_q.frdy1;
    assign reg_to_exe.fprs2 = stage_rr_exe_q.fprs2;
    assign reg_to_exe.frdy2 = snoop_exe_frdy2 | stage_rr_exe_q.frdy2;
    assign reg_to_exe.fprs3 = stage_rr_exe_q.fprs3;
    assign reg_to_exe.frdy3 = snoop_exe_frdy3 | stage_rr_exe_q.frdy3;
    assign reg_to_exe.fprd = stage_rr_exe_q.fprd;
    assign reg_to_exe.old_fprd = stage_rr_exe_q.old_fprd;

    assign reg_to_exe.pvs1 = stage_rr_exe_q.pvs1;
    assign reg_to_exe.vrdy1 = snoop_exe_vrdy1 | stage_rr_exe_q.vrdy1;
    assign reg_to_exe.pvs2 = stage_rr_exe_q.pvs2;
    assign reg_to_exe.vrdy2 = snoop_exe_vrdy2 | stage_rr_exe_q.vrdy2;
    assign reg_to_exe.pvm = stage_rr_exe_q.pvm;
    assign reg_to_exe.vrdym = snoop_exe_vrdym | stage_rr_exe_q.vrdym;
    assign reg_to_exe.pvd = stage_rr_exe_q.pvd;
    assign reg_to_exe.old_pvd = stage_rr_exe_q.old_pvd;
    assign reg_to_exe.vrdy_old_vd = snoop_exe_vrdy_old_vd | stage_rr_exe_q.vrdy_old_vd;

    assign reg_to_exe.checkpoint_done = stage_rr_exe_q.checkpoint_done;
    assign reg_to_exe.chkp = stage_rr_exe_q.chkp;
    assign reg_to_exe.gl_index = stage_rr_exe_q.gl_index;

    exe_stage exe_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .kill_i(flush_int.kill_exe),

        .en_ld_st_translation_i(en_ld_st_translation_i),

        .from_rr_i(reg_to_exe),
        .sew_i(sew_i),
        
        .resp_dcache_cpu_i(resp_dcache_cpu_i),
        .io_base_addr_i(io_base_addr),
        .flush_i(flush_int.flush_exe),
        .commit_store_or_amo_i(commit_store_or_amo_int),
        .commit_store_or_amo_gl_idx_i(commit_cu_int.gl_index),
        .dtlb_comm_i(dtlb_comm_i),
        .dtlb_comm_o(dtlb_comm_o),
        .priv_lvl_i(csr_priv_lvl_i),
    
        .exe_if_branch_pred_o(exe_if_branch_pred_int),
        .correct_branch_pred_o(correct_branch_pred),
    
        .arith_to_scalar_wb_o(exe_to_wb_scalar[0]),
        .mem_to_scalar_wb_o(wb_scalar[1]),
        .mul_div_to_scalar_wb_o(wb_scalar[3]),

        .simd_to_scalar_wb_o(exe_to_wb_scalar_simd_fp[0]),
        .fp_to_scalar_wb_o(exe_to_wb_scalar_simd_fp[1]),
        .simd_to_simd_wb_o(exe_to_wb_simd[0]),
        .mem_to_simd_wb_o(wb_simd[1]),

        .mem_to_fp_wb_o(wb_fp[1]),
        .fp_to_wb_o(exe_to_wb_fp[0]),
        .exe_cu_o(exe_cu_int),

        .mem_commit_stall_o(mem_commit_stall_int),
        .mem_store_or_amo_o(mem_commit_store_or_amo_int),
        .mem_gl_index_o(mem_gl_index_int),
        .exception_mem_commit_o(exception_mem_commit_int),
        .ex_gl_o(ex_from_exe_int),
        .ex_gl_index_o(ex_from_exe_index_int),

        .req_cpu_dcache_o(req_cpu_dcache_o),
    
        //PMU Neiel-Leyva
        .pmu_is_branch_o          (pmu_flags_o.is_branch),      
        .pmu_branch_taken_o       (pmu_flags_o.branch_taken),   
        .pmu_stall_mem_o          (pmu_flags_o.stall_wb),
        .pmu_exe_ready_o          (pmu_exe_ready),
        .pmu_struct_depend_stall_o(pmu_flags_o.struct_depend),
        .pmu_load_after_store_o   (pmu_flags_o.stall_rr)
    );
    always_comb begin 
        // We assign FP over SIMD by default if valid
        if (exe_to_wb_scalar_simd_fp[1].valid) begin
            exe_to_wb_scalar[2] = exe_to_wb_scalar_simd_fp[1];
        end else begin
            exe_to_wb_scalar[2] = exe_to_wb_scalar_simd_fp[0];
        end
    end

    always @(posedge clk_i)  assert (!(exe_to_wb_scalar_simd_fp[0].valid & exe_to_wb_scalar_simd_fp[1].valid));

    register #( (2) * $bits(exe_wb_scalar_instr_t) + (NUM_SIMD_WB - 1) * $bits(exe_wb_simd_instr_t) + (NUM_FP_WB - 1) * $bits(exe_wb_fp_instr_t)) reg_exe_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_exe),
        .load_i(!control_int.stall_exe),
        .input_i({exe_to_wb_scalar[0], exe_to_wb_scalar[2], exe_to_wb_simd[0], exe_to_wb_fp[0]}),
        .output_o({wb_scalar[0], wb_scalar[2], wb_simd[0], wb_fp[0]})
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


    assign wb_amo_int = wb_scalar[1].mem_type == AMO;

    //WB data for the bypasses (the CSRs should not be bypassed)
    always_comb begin
        for (int i = 0; i<NUM_SCALAR_WB; ++i) begin
            //Graduation list writeback arrays
            if (i == 1) begin
                gl_valid[i] = wb_scalar[i].valid & ~wb_amo_int;
                gl_index[i] = wb_scalar[i].gl_index;
                instruction_writeback_gl[i].csr_addr = wb_scalar[i].csr_addr;
                instruction_writeback_gl[i].exception = wb_scalar[i].ex;
                instruction_writeback_gl[i].result   = wb_scalar[i].result;
                instruction_writeback_gl[i].fp_status = wb_scalar[i].fp_status;
            end else begin
                gl_valid[i] = wb_scalar[i].valid;
                gl_index[i] = wb_scalar[i].gl_index;
                instruction_writeback_gl[i].csr_addr = wb_scalar[i].csr_addr;
                instruction_writeback_gl[i].exception = wb_scalar[i].ex;
                instruction_writeback_gl[i].result   = wb_scalar[i].result;
                instruction_writeback_gl[i].fp_status = wb_scalar[i].fp_status;
            end

            // Write data regfile from WB or from Commit (CSR)
            // CSR are exclusive with the rest of instrucitons. Therefor, there are no conflicts
            if (i == 0) begin
                // Change the data of write port 0 with dbg ring data
                wb_cu_int.write_enable[i] = wb_scalar[i].regfile_we;
                data_wb_to_exe[i] = wb_scalar[i].result;
                write_paddr_exe[i] = wb_scalar[i].prd;
                write_vaddr[i] = (commit_cu_int.write_enable) ? instruction_to_commit[0].rd :
                                  wb_scalar[i].rd;
                wb_cu_int.snoop_enable[i] = wb_scalar[i].regfile_we;
            end else begin
                data_wb_to_exe[i]  = wb_scalar[i].result;
                write_paddr_exe[i] = wb_scalar[i].prd;
                write_vaddr[i]     = wb_scalar[i].rd;
                wb_cu_int.write_enable[i] = wb_scalar[i].regfile_we;
                wb_cu_int.snoop_enable[i] = wb_scalar[i].regfile_we;
            end
            wb_cu_int.valid[i]        = wb_scalar[i].valid;
        end
        wb_cu_int.change_pc_ena = wb_scalar[0].change_pc_ena;

        for (int i = 0; i<NUM_SIMD_WB; ++i) begin
            //Graduation list writeback arrays
            gl_valid_simd[i] = wb_simd[i].valid & wb_simd[i].vregfile_we;
            gl_index_simd[i] = wb_simd[i].gl_index;
            instruction_simd_writeback_gl[i].csr_addr  = wb_simd[i].csr_addr;
            instruction_simd_writeback_gl[i].exception = wb_simd[i].ex;
            instruction_simd_writeback_gl[i].result    = wb_simd[i].vresult;
            simd_data_wb_to_exe[i]  = wb_simd[i].vresult;
            simd_write_paddr_exe[i] = wb_simd[i].pvd;
            simd_write_vaddr[i]     = wb_simd[i].vd;
            wb_cu_int.vwrite_enable[i] = wb_simd[i].vregfile_we;
            wb_cu_int.vsnoop_enable[i] = wb_simd[i].vregfile_we;
            wb_cu_int.vvalid[i]        = wb_simd[i].valid;
        end
        
        for (int i = 0; i<NUM_FP_WB; ++i) begin
            //Graduation list writeback arrays
            gl_valid_fp[i] = wb_fp[i].valid  & wb_fp[i].regfile_we;
            gl_index_fp[i] = wb_fp[i].gl_index;
            instruction_fp_writeback_gl[i].csr_addr  = wb_fp[i].csr_addr;
            instruction_fp_writeback_gl[i].exception = wb_fp[i].ex;
            instruction_fp_writeback_gl[i].result    = wb_fp[i].result;
            instruction_fp_writeback_gl[i].fp_status = wb_fp[i].fp_status;
            fp_data_wb_to_exe[i]  = wb_fp[i].result;
            fp_write_paddr_exe[i] = wb_fp[i].fprd;
            fp_write_vaddr[i]     = wb_fp[i].rd;
            wb_cu_int.fwrite_enable[i] = wb_fp[i].regfile_we;
            wb_cu_int.fsnoop_enable[i] = wb_fp[i].regfile_we;
            wb_cu_int.fvalid[i]        = wb_fp[i].valid;
        end

        wb_cu_int.checkpoint_done = wb_scalar[0].checkpoint_done;
        wb_cu_int.chkp = wb_scalar[0].chkp;
        wb_cu_int.gl_index = wb_scalar[0].gl_index;

    end


    // WB data to RR
    always_comb begin
        for (int i = 0; i<NUM_SCALAR_WB; ++i) begin
            if (i == 0) begin
                // Change the data of write port 0 with dbg ring data
                if (debug_i.reg_write_valid && debug_i.halt_valid) begin
                    data_wb_to_rr[i] = debug_i.reg_write_data;
                    write_paddr_rr[i] = debug_i.reg_read_write_paddr;
                end else begin
                    data_wb_to_rr[i] = (commit_cu_int.write_enable) ? resp_csr_cpu_i.csr_rw_rdata : wb_scalar[i].result;
                    write_paddr_rr[i] = (commit_cu_int.write_enable) ? instruction_to_commit[0].prd : wb_scalar[i].prd;
                end
            end else begin
                data_wb_to_rr[i] = wb_scalar[i].result;
                write_paddr_rr[i] = wb_scalar[i].prd;
            end
        end

        for (int i = 0; i<NUM_SIMD_WB; ++i) begin
            simd_data_wb_to_rr[i] = wb_simd[i].vresult;
            simd_write_paddr_rr[i] = wb_simd[i].pvd;
        end

        for (int i = 0; i<NUM_FP_WB; ++i) begin
            fp_data_wb_to_rr[i]  = wb_fp[i].result;
            fp_write_paddr_rr[i] = wb_fp[i].fprd;
        end
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// COMMIT STAGE                                                                                 /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign instruction_to_commit = instruction_gl_commit;
    assign commit_cu_int.gl_index = index_gl_commit;

    csr_interface csr_interface_inst
    (
        .commit_xcpt_i              (commit_xcpt),
        .result_gl_i                (result_gl_out_int),
        .csr_addr_gl_i              (csr_addr_gl_out_int),
        .instruction_to_commit_i    (instruction_to_commit),
        .stall_exe_i                (control_int.stall_exe),
        .commit_store_or_amo_i      (commit_store_or_amo_int),
        .mem_commit_stall_i         (commit_cu_int.stall_commit),
        .exception_mem_commit_i     (exception_mem_commit_int),
        .exception_gl_i             (ex_gl_out_int),
        .csr_ena_int_o              (csr_ena_int),
        .req_cpu_csr_o              (req_cpu_csr_o),
        .retire_inst_o              (retire_inst_gl)
    );

    // Delay the PC_EVEC treatment one cycle
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            pc_evec_q <= 'b0;
            pc_next_csr_q <= 'b0;
        end else begin 
            pc_evec_q <= resp_csr_cpu_i.csr_evec;
            pc_next_csr_q <= instruction_to_commit[0].pc + 64'h4;
        end
    end

    // if there is an exception that can be from:
    // the instruction itself or the interrupt
    assign commit_xcpt = (~commit_store_or_amo_int)? ex_gl_out_int.valid & instruction_to_commit[0].ex_valid : exception_mem_commit_int.valid;
    assign commit_xcpt_cause = (~commit_store_or_amo_int)? ex_gl_out_int.cause : exception_mem_commit_int.cause;

    // Control Unit From Commit
    assign commit_cu_int.valid = instruction_to_commit[0].valid;
    assign commit_cu_int.regfile_we = {instruction_to_commit[1].regfile_we,instruction_to_commit[0].regfile_we};
    assign commit_cu_int.vregfile_we = {instruction_to_commit[1].vregfile_we,instruction_to_commit[0].vregfile_we};
    assign commit_cu_int.fregfile_we = {instruction_to_commit[1].fregfile_we,instruction_to_commit[0].fregfile_we};
    assign commit_cu_int.csr_enable = csr_ena_int;
    assign commit_cu_int.stall_csr_fence = instruction_to_commit[0].stall_csr_fence && instruction_to_commit[0].valid;
    assign commit_cu_int.xcpt = commit_xcpt;

    // tell cu that ecall was taken
    assign commit_cu_int.ecall_taken = (instruction_to_commit[0].instr_type == ECALL  ||
                                        instruction_to_commit[0].instr_type == MRTS   ||
                                        instruction_to_commit[0].instr_type == EBREAK );

    // tell cu that there is a fence or fence_i
    assign commit_cu_int.fence = (instruction_to_commit[0].instr_type == FENCE_I || 
                                  instruction_to_commit[0].instr_type == FENCE || 
                                  instruction_to_commit[0].instr_type == SFENCE_VMA);
    // tell cu there is a fence i to flush the icache
    assign commit_cu_int.fence_i = (instruction_to_commit[0].instr_type == FENCE_I || 
                                    instruction_to_commit[0].instr_type == SFENCE_VMA);

    // tell cu that commit needs to write there is a fence
    assign commit_cu_int.write_enable = instruction_to_commit[0].valid &
                                        (instruction_to_commit[0].instr_type == CSRRW  ||
                                         instruction_to_commit[0].instr_type == CSRRS  ||
                                         instruction_to_commit[0].instr_type == CSRRC  ||
                                         instruction_to_commit[0].instr_type == CSRRWI ||
                                         instruction_to_commit[0].instr_type == CSRRSI ||
                                         instruction_to_commit[0].instr_type == CSRRCI ||
                                         instruction_to_commit[0].instr_type == VSETVL ||
                                         instruction_to_commit[0].instr_type == VSETVLI);

    assign commit_store_or_amo_int = ((instruction_to_commit[0].mem_type == STORE) || 
                                     (instruction_to_commit[0].mem_type == AMO)) && !instruction_to_commit[0].ex_valid;

    assign commit_cu_int.stall_commit = mem_commit_stall_int | (commit_store_or_amo_int & ((commit_cu_int.gl_index != mem_gl_index_int) | !mem_commit_store_or_amo_int));
    assign commit_cu_int.retire = retire_inst_gl;
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// DEBUG SIGNALS                                                                                /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef VERILATOR
    // Debug signals
    always_comb begin 
        for (int i=0; i<2; i++) begin
            commit_valid[i]      = retire_inst_gl[i];
            commit_pc[i]         = (instruction_to_commit[i].valid) ? instruction_to_commit[i].pc : 64'b0;
            commit_addr_reg[i]   = instruction_to_commit[i].rd;
            commit_addr_freg[i]  = instruction_to_commit[i].rd;
            commit_addr_vreg[i]  = instruction_to_commit[i].vd;
            commit_reg_we[i]     = instruction_to_commit[i].regfile_we && commit_valid;
            commit_vreg_we[i]    = instruction_to_commit[i].vregfile_we;
            commit_freg_we[i]    = instruction_to_commit[i].fregfile_we && commit_valid;
            if (i==0) begin
                if(instruction_to_commit[0].valid) begin
                    if (commit_cu_int.write_enable) begin
                        commit_data[0] = resp_csr_cpu_i.csr_rw_rdata;
                    end else if (commit_store_or_amo_int & (commit_cu_int.gl_index == mem_gl_index_int)) begin
                        commit_data[0] = wb_scalar[1].result;
                    end else begin
                        commit_data[0] = instruction_to_commit[0].result;
                    end
                end else begin
                    commit_data[0] = 64'b0;
                end
            end else begin
                if(instruction_to_commit[i].valid) begin
                    commit_data[i] = instruction_to_commit[i].result;
                end else begin
                    commit_data[i] = 64'b0;
                end
            end
        end
    end


    // Module that generates the signature of the core to compare with spike
    `ifdef VERILATOR_TORTURE_TESTS
        logic commit_store_int, is_commit_store_valid;
        assign commit_store_int = instruction_to_commit[0].mem_type == STORE;
        assign is_commit_store_valid = instruction_to_commit[0].valid && !commit_cu_int.stall_commit && 
                                        commit_store_int && (commit_cu_int.gl_index == mem_gl_index_int);
        torture_dump_behav torture_dump
        (
            .clk(clk_i),
            .rst(rstn_i),
            .commit_valid_0(commit_valid[0]),
            .reg_wr_valid_0(commit_reg_we[0] && (commit_addr_reg[0] != 5'b0)),
            .freg_wr_valid_0(commit_freg_we[0]),
            .vreg_wr_valid_0(commit_vreg_we[0]),
            .pc_0(commit_pc[0]),
            .inst_0(instruction_to_commit[0].inst),
            .reg_dst_0(commit_addr_reg[0]),
            .freg_dst_0(commit_addr_freg[0]),
            .vreg_dst_0(commit_addr_vreg[0]),
            .data_0(commit_data[0]),
            .commit_valid_1(commit_valid[1]),
            .reg_wr_valid_1(commit_reg_we[1] && (commit_addr_reg[1] != 5'b0)),
            .freg_wr_valid_1(commit_freg_we[1]),
            .vreg_wr_valid_1(commit_vreg_we[1]),
            .pc_1(commit_pc[1]),
            .inst_1(instruction_to_commit[1].inst),
            .reg_dst_1(commit_addr_reg[1]),
            .freg_dst_1(commit_addr_freg[1]),
            .vreg_dst_1(commit_addr_vreg[1]),
            .data_1(commit_data[1]),
            .sew(sew_i),
            .xcpt(commit_xcpt),
            .xcpt_cause(commit_xcpt_cause),
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

            .ir_valid(stage_iq_ir_q.instr.valid),
            .ir_id(stage_iq_ir_q.instr.id),
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
            .exe_unit(reg_to_exe.instr.unit),

            .wb1_valid(wb_scalar[0].valid),
            .wb1_id(wb_scalar[0].id),

            .wb2_valid(wb_scalar[1].valid),
            .wb2_id(wb_scalar[1].id),

            .wb_store_valid(is_commit_store_valid),
            .wb_srore_id(instruction_to_commit[0].id),
            // Scalar 
            .wb3_valid(wb_scalar[2].valid),
            .wb3_id(wb_scalar[2].id),
            // FP 1
            .wb1_fp_valid(wb_fp[0].valid),
            .wb1_fp_id(wb_fp[0].id),
            // FP 2
            .wb2_fp_valid(wb_fp[1].valid),
            .wb2_fp_id(wb_fp[1].id),
            // SIMD 1
            .wb1_simd_valid(wb_simd[0].valid),
            .wb1_simd_id(wb_simd[0].id),
            // SIMD 2
            .wb2_simd_valid(wb_simd[1].valid),
            .wb2_simd_id(wb_simd[1].id)
        );
    `endif
`endif

        // PCcommit_freg_we
    assign pc_if1  = stage_if_1_if_2_d.pc_inst;
    assign pc_if2  = stage_if_2_id_d.pc_inst;
    assign pc_id  = (valid_id)  ? decoded_instr.instr.pc : 64'b0;
    assign pc_rr  = (valid_rr)  ? stage_rr_exe_d.instr.pc : 64'b0;
    assign pc_exe = (valid_exe) ? stage_rr_exe_q.instr.pc : 64'b0;
    assign pc_wb = (valid_wb) ? wb_scalar[0].pc : 64'b0;
    
        // Valid
    assign valid_if1  = stage_if_1_if_2_d.valid;
    assign valid_if2  = stage_if_2_id_d.valid;
    assign valid_id  = decoded_instr.instr.valid;
    assign valid_rr  = stage_rr_exe_d.instr.valid;
    assign valid_exe = stage_rr_exe_q.instr.valid;
    assign valid_wb = wb_scalar[0].valid;

    // Debug Ring signals Output
    // PC
    assign debug_o.pc_fetch = pc_if1[39:0];
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
    
    assign pmu_flags_o.stall_id        = control_int.stall_id || ~decoded_instr.instr.valid;
    assign pmu_flags_o.stall_exe       = control_int.stall_exe || ~reg_to_exe.instr.valid;
    assign pmu_flags_o.load_store      = (~commit_cu_int.stall_commit) && (commit_store_or_amo_int || instruction_to_commit[0].mem_type == LOAD);
    assign pmu_flags_o.data_depend     = ~pmu_exe_ready && ~pmu_flags_o.stall_exe;
    assign pmu_flags_o.grad_list_full  = rr_cu_int.gl_full && ~resp_csr_cpu_i.csr_stall && ~exe_cu_int.stall;
    assign pmu_flags_o.free_list_empty = free_list_empty && ~rr_cu_int.gl_full && ~resp_csr_cpu_i.csr_stall && ~exe_cu_int.stall;

    /*
    (* keep="TRUE" *) (* mark_debug="TRUE" *) gl_instruction_t [1:0] instruction_to_commit_reg;
    (* keep="TRUE" *) (* mark_debug="TRUE" *) commit_cu_t commit_cu_int_reg;
    (* keep="TRUE" *) (* mark_debug="TRUE" *) cu_ir_t cu_ir_int_reg;
    always_ff @(posedge clk_i) 
    begin
        instruction_to_commit_reg <= instruction_to_commit;
        commit_cu_int_reg <= commit_cu_int;
        cu_ir_int_reg <= cu_ir_int;
    end*/

endmodule
