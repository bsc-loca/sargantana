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
    logic commit_branch_taken;
`endif

    bus64_t pc_if, pc_id, pc_rr, pc_exe, pc_wb;
    logic valid_if, valid_id, valid_rr, valid_exe, valid_wb;

    pipeline_ctrl_t control_int;
    pipeline_flush_t flush_int;
    cu_if_t cu_if_int;
    addrPC_t pc_jump_if_int;
    addrPC_t pc_evec_q;

    
    // Pipelines stages data
    // Fetch
    if_id_stage_t stage_if_id_d; // this is the saving in the current cycle
    if_id_stage_t stage_if_id_q; // this is the next or output of reg
    logic invalidate_icache_int;
    logic invalidate_buffer_int;
    logic retry_fetch;
    // Decode
    id_rr_stage_t stage_id_rr_d;
    id_rr_stage_t stage_id_rr_q;
    id_rr_stage_t stage_stall_rr_q;
    id_rr_stage_t stage_no_stall_rr_q;

    cu_id_t cu_id_int;

    // RR
    rr_exe_instr_t stage_rr_exe_d;
    rr_exe_instr_t stage_rr_exe_q;

    // Control Unit Decode
    id_cu_t id_cu_int;
    jal_id_if_t jal_id_if_int;


    // Rename and free list
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

    logic src_select_id_rr_q;

    // Read Registers
    logic snoop_rs1_rr_alu_mul_div;
    logic snoop_rs2_rr_alu_mul_div;
    logic snoop_rs1_rr_mem;
    logic snoop_rs2_rr_mem;

    // Graduation List

    gl_instruction_t instruction_decode_gl;
    gl_instruction_t instruction_writeback_gl_1;
    gl_instruction_t instruction_writeback_gl_2;
    gl_instruction_t instruction_gl_commit; 
    
    // Exe
    rr_exe_instr_t selection_rr_exe_d;

    exe_cu_t exe_cu_int;
    exe_wb_instr_t alu_mul_div_to_wb;
    exe_wb_instr_t mem_to_wb;
    exe_wb_instr_t alu_mul_div_wb;
    exe_wb_instr_t mem_wb;

    logic snoop_rs1_exe_alu_mul_div;
    logic snoop_rs2_exe_alu_mul_div;
    logic snoop_rs1_exe_mem;
    logic snoop_rs2_exe_mem;
    rr_exe_instr_t reg_to_exe;

    reg_addr_t io_base_addr;

    // WB->Commit
    wb_cu_t wb_cu_int;
    cu_wb_t cu_wb_int;
    rr_cu_t rr_cu_int;
    cu_rr_t cu_rr_int;

    // Commit signals
    commit_cu_t commit_cu_int;
    cu_commit_t cu_commit_int;
    logic commit_xcpt;
    logic commit_store_or_amo_int;
    
    gl_instruction_t instruction_gl_commit_old_q;
    gl_instruction_t instruction_to_commit;
    logic src_select_commit;
    exception_t exception_mem_commit_int;

    // CSR signals
    logic   csr_ena_int;

    // Data to write to RR from WB or CSR
    bus64_t data_wb_csr_to_rr;
    phreg_t write_paddr_1;
    reg_t   write_vaddr_1;

    bus64_t data_mem_to_rr;
    phreg_t write_paddr_2;
    reg_t   write_vaddr_2;

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// IO ADDRESS SPACE                                                                             /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////


    // Debug signals
    bus64_t  reg_wr_data;
    //logic    reg_wr_enable;
    logic [REGFILE_WIDTH-1:0] reg_wr_addr;
    logic [REGFILE_WIDTH-1:0] reg_rd1_addr;
    // stall IF
    logic stall_if;

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
        .valid_fetch(resp_icache_cpu_i.valid),
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
        .id_cu_i(id_cu_int),
        .correct_branch_pred_i(correct_branch_pred),
        .debug_halt_i(debug_i.halt_valid),
        .debug_change_pc_i(debug_i.change_pc_valid),
        .debug_wr_valid_i(debug_i.reg_write_valid),
        .cu_id_o(cu_id_int),
        .commit_cu_i(commit_cu_int),
        .cu_commit_o(cu_commit_int)
    );

    // Combinational logic select the jump addr
    // from decode or wb 
    always_comb begin
        retry_fetch = 1'b0;
        // TODO (guillemlp) highest priority?
        if (control_int.sel_addr_if == SEL_JUMP_DEBUG) begin
            pc_jump_if_int = debug_i.change_pc_addr;
        end else if (control_int.sel_addr_if == SEL_JUMP_EXECUTION) begin
            pc_jump_if_int = alu_mul_div_wb.result_pc;
        end else if (control_int.sel_addr_if == SEL_JUMP_CSR) begin
            pc_jump_if_int = pc_evec_q;
            retry_fetch = 1'b1;
        end else begin
            pc_jump_if_int = jal_id_if_int.jump_addr;
        end
    end

    assign stall_if = control_int.stall_if || debug_i.halt_valid;

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// FETCH                  STAGE                                                                 /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // IF Stage
    if_stage if_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .reset_addr_i(reset_addr_i),
        .stall_debug_i(debug_i.halt_valid),
        .stall_i(stall_if),
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

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// DECODER, RENAME AND FREE LIST     STAGE                                                      /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // ID Stage
    decoder id_decode_inst(
        .decode_i(stage_if_id_q),
        .decode_instr_o(stage_id_rr_d.instr),
        .jal_id_if_o(jal_id_if_int)
    );

    // valid jal in decode
    assign id_cu_int.valid_jal = jal_id_if_int.valid;

    assign id_cu_int.stall_csr_fence = stage_id_rr_d.instr.stall_csr_fence && stage_id_rr_d.instr.valid;

    // Free List
    free_list free_list_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .read_head_i(stage_id_rr_d.instr.regfile_we & stage_id_rr_d.instr.valid & (stage_id_rr_d.instr.rd != 'h0) & (~control_int.stall_id)),
        .add_free_register_i(instruction_gl_commit.regfile_we & instruction_gl_commit.valid),
        .free_register_i(instruction_gl_commit.old_prd),
        .do_checkpoint_i(cu_id_int.do_checkpoint),
        .do_recover_i(cu_id_int.do_recover),
        .delete_checkpoint_i(cu_id_int.delete_checkpoint),
        .recover_checkpoint_i(cu_id_int.recover_checkpoint),
        .commit_read_head_i(instruction_gl_commit.regfile_we & instruction_gl_commit.valid & (instruction_gl_commit.rd != 'h0)),
        .commit_roll_back_i(commit_xcpt | resp_csr_cpu_i.csr_exception ),
        .new_register_o(free_register_to_rename),
        .checkpoint_o(checkpoint_free_list),
        .out_of_checkpoints_o(out_of_checkpoints_free_list),
        .empty_o(free_list_empty)
    );

    // Rename Table
    rename_table rename_table_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .read_src1_i(stage_id_rr_d.instr.rs1),
        .read_src2_i(stage_id_rr_d.instr.rs2),
        .old_dst_i(stage_id_rr_d.instr.rd),
        .write_dst_i(stage_id_rr_d.instr.regfile_we & stage_id_rr_d.instr.valid & (~control_int.stall_id)),
        .new_dst_i(free_register_to_rename),
        .ready1_i(cu_rr_int.write_enable_1),            
        .vaddr1_i(write_vaddr_1), 
        .paddr1_i(write_paddr_1),
        .ready2_i(cu_rr_int.write_enable_2),            
        .vaddr2_i(write_vaddr_2), 
        .paddr2_i(write_paddr_2), 
        .do_checkpoint_i(cu_id_int.do_checkpoint),
        .do_recover_i(cu_id_int.do_recover),
        .delete_checkpoint_i(cu_id_int.delete_checkpoint),
        .recover_checkpoint_i(cu_id_int.recover_checkpoint),
        .recover_commit_i(commit_xcpt | resp_csr_cpu_i.csr_exception), 
        .commit_old_dst_i(instruction_gl_commit.rd),    
        .commit_write_dst_i(instruction_gl_commit.regfile_we & instruction_gl_commit.valid),  
        .commit_new_dst_i(instruction_gl_commit.prd),
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

    assign id_cu_int.empty_free_list = free_list_empty;
    assign id_cu_int.out_of_checkpoints = out_of_checkpoints_rename;
    assign id_cu_int.is_branch = (stage_id_rr_d.instr.instr_type == BLT)  ||
                                 (stage_id_rr_d.instr.instr_type == BLTU) ||
                                 (stage_id_rr_d.instr.instr_type == BGE)  ||
                                 (stage_id_rr_d.instr.instr_type == BGEU) ||
                                 (stage_id_rr_d.instr.instr_type == BEQ)  ||
                                 (stage_id_rr_d.instr.instr_type == BNE)  ||
                                 (stage_id_rr_d.instr.instr_type == JALR);

    // Register ID to RR
    register #($bits(instr_entry_t) + $bits(phreg_t) + $bits(logic)) reg_id_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_id),
        .load_i(!control_int.stall_id),
        .input_i({stage_id_rr_d.instr,free_register_to_rename,cu_id_int.do_checkpoint}),
        .output_o({stage_no_stall_rr_q.instr,stage_no_stall_rr_q.prd,stage_no_stall_rr_q.checkpoint_done})
    );




    // Second ID to RR. To store rename in case of stall
    register #($bits(id_rr_stage_t)) reg_rename_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_id),
        .load_i(1'b1), // This register is always storing a one cycle old copy of reg_id_inst and the renaming.
        .input_i(stage_id_rr_q),
        .output_o(stage_stall_rr_q)
    );

    // Syncronus Mux to decide between actual (decode + rename) or one cycle before (decode + rename)
    always @(posedge clk_i) begin
        src_select_id_rr_q <= !control_int.stall_id;
    end

    always_comb begin
        if (src_select_id_rr_q) begin
            stage_id_rr_q.instr = stage_no_stall_rr_q.instr;
            stage_id_rr_q.prd = stage_no_stall_rr_q.prd;
            stage_id_rr_q.prs1 = stage_no_stall_rr_q.prs1;
            stage_id_rr_q.prs2 = stage_no_stall_rr_q.prs2;
            stage_id_rr_q.rdy1 = stage_no_stall_rr_q.rdy1 | snoop_rs1_rr_alu_mul_div | snoop_rs1_rr_mem;
            stage_id_rr_q.rdy2 = stage_no_stall_rr_q.rdy2 | snoop_rs2_rr_alu_mul_div | snoop_rs2_rr_mem;
            stage_id_rr_q.old_prd = stage_no_stall_rr_q.old_prd;
            stage_id_rr_q.chkp = stage_no_stall_rr_q.chkp;
            stage_id_rr_q.checkpoint_done = stage_no_stall_rr_q.checkpoint_done;
        end else begin
            stage_id_rr_q.instr = stage_stall_rr_q.instr;
            stage_id_rr_q.prd = stage_stall_rr_q.prd;
            stage_id_rr_q.prs1 = stage_stall_rr_q.prs1;
            stage_id_rr_q.prs2 = stage_stall_rr_q.prs2;
            stage_id_rr_q.rdy1 = stage_stall_rr_q.rdy1 | snoop_rs1_rr_alu_mul_div | snoop_rs1_rr_mem;
            stage_id_rr_q.rdy2 = stage_stall_rr_q.rdy2 | snoop_rs2_rr_alu_mul_div | snoop_rs2_rr_mem;
            stage_id_rr_q.old_prd = stage_stall_rr_q.old_prd;
            stage_id_rr_q.chkp = stage_stall_rr_q.chkp;
            stage_id_rr_q.checkpoint_done = stage_stall_rr_q.checkpoint_done;
        end
    end

    // Snoop ready from ALU MUL DIV to data source 1 and 2
    assign snoop_rs1_rr_alu_mul_div = cu_rr_int.write_enable_1 & (write_paddr_1 == stage_id_rr_q.prs1) & (stage_id_rr_q.instr.rs1 != 0);
    assign snoop_rs2_rr_alu_mul_div = cu_rr_int.write_enable_1 & (write_paddr_1 == stage_id_rr_q.prs2) & (stage_id_rr_q.instr.rs2 != 0); 

    // Snoop ready from MEM to data source 1 and 2
    assign snoop_rs1_rr_mem = cu_rr_int.write_enable_2 & (write_paddr_2 == stage_id_rr_q.prs1) & (stage_id_rr_q.instr.rs1 != 0);
    assign snoop_rs2_rr_mem = cu_rr_int.write_enable_2 & (write_paddr_2 == stage_id_rr_q.prs2) & (stage_id_rr_q.instr.rs2 != 0); 

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// GRADUATION LIST AND READ REGISTER  STAGE                                                     /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign instruction_decode_gl.valid                  = stage_id_rr_q.instr.valid & (~control_int.stall_rr);
    assign instruction_decode_gl.instr_type             = stage_id_rr_q.instr.instr_type;
    assign instruction_decode_gl.rd                     = stage_id_rr_q.instr.rd;
    assign instruction_decode_gl.rs1                    = stage_id_rr_q.instr.rs1;
    assign instruction_decode_gl.pc                     = stage_id_rr_q.instr.pc;
    assign instruction_decode_gl.exception              = stage_id_rr_q.instr.ex;
    assign instruction_decode_gl.stall_csr_fence        = stage_id_rr_q.instr.stall_csr_fence;
    assign instruction_decode_gl.old_prd                = stage_id_rr_q.old_prd;
    assign instruction_decode_gl.prd                    = stage_id_rr_q.prd;
    assign instruction_decode_gl.regfile_we             = stage_id_rr_q.instr.regfile_we;

    graduation_list graduation_list_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .instruction_i(instruction_decode_gl),
        .read_head_i(cu_commit_int.enable_commit),
        .read_tail_i(1'b0),
        .instruction_writeback_1_i(alu_mul_div_wb.gl_index),
        .instruction_writeback_enable_1_i(alu_mul_div_wb.valid),
        .instruction_writeback_data_1_i(instruction_writeback_gl_1),
        .instruction_writeback_2_i(mem_wb.gl_index),
        .instruction_writeback_enable_2_i(mem_wb.valid),
        .instruction_writeback_data_2_i(instruction_writeback_gl_2),
        .flush_i(cu_wb_int.flush_gl),
        .flush_index_i(cu_wb_int.flush_gl_index),
        .flush_commit_i(commit_xcpt),
        .assigned_gl_entry_o(stage_rr_exe_d.gl_index),
        .instruction_o(instruction_gl_commit),
        .commit_gl_entry_o(commit_cu_int.gl_index),
        .full_o(),
        .empty_o()
    );


    assign reg_wr_data    = (debug_i.reg_write_valid && debug_i.halt_valid) ? debug_i.reg_write_data : data_wb_csr_to_rr;
    assign reg_wr_addr    = (debug_i.reg_write_valid && debug_i.halt_valid)  ? debug_i.reg_read_write_addr : write_paddr_1;
    assign reg_prd1_addr  = (debug_i.reg_read_valid  && debug_i.halt_valid)  ? debug_i.reg_read_write_addr : stage_id_rr_q.prs1;
    
    // RR Stage
    regfile regfile(
        .clk_i(clk_i),

        .write_enable_1_i(cu_rr_int.write_enable_1 | cu_rr_int.write_enable_dbg),
        .write_addr_1_i(reg_wr_addr),
        .write_data_1_i(reg_wr_data),
        .write_enable_2_i(cu_rr_int.write_enable_2),
        .write_addr_2_i(write_paddr_2),
        .write_data_2_i(data_mem_to_rr),
        
        .read_addr1_i(reg_prd1_addr),
        .read_addr2_i(stage_id_rr_q.prs2),
        .read_data1_o(stage_rr_exe_d.data_rs1),
        .read_data2_o(stage_rr_exe_d.data_rs2)
    );

    assign stage_rr_exe_d.instr = stage_id_rr_q.instr;
    assign stage_rr_exe_d.csr_interrupt_cause = resp_csr_cpu_i.csr_interrupt_cause;
    assign stage_rr_exe_d.csr_interrupt = resp_csr_cpu_i.csr_interrupt;
    assign stage_rr_exe_d.prd = stage_id_rr_q.prd;
    assign stage_rr_exe_d.prs1 = stage_id_rr_q.prs1;
    assign stage_rr_exe_d.prs2 = stage_id_rr_q.prs2;
    assign stage_rr_exe_d.rdy1 = stage_id_rr_q.rdy1;
    assign stage_rr_exe_d.rdy2 = stage_id_rr_q.rdy2;
    assign stage_rr_exe_d.old_prd = stage_id_rr_q.old_prd;
    assign stage_rr_exe_d.chkp = stage_id_rr_q.chkp;
    assign stage_rr_exe_d.checkpoint_done = stage_id_rr_q.checkpoint_done;

    assign rr_cu_int.stall_csr_fence = stage_rr_exe_d.instr.stall_csr_fence && stage_rr_exe_d.instr.valid;



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

    // Snoop data and ready from ALU MUL DIV to data source 1 and 2
    assign snoop_rs1_exe_alu_mul_div = cu_rr_int.write_enable_1 & (write_paddr_1 == stage_rr_exe_q.prs1) & (stage_rr_exe_q.instr.rs1 != 0);
    assign snoop_rs2_exe_alu_mul_div = cu_rr_int.write_enable_1 & (write_paddr_1 == stage_rr_exe_q.prs2) & (stage_rr_exe_q.instr.rs2 != 0);
 
    // Snoop data and ready from MEM to data source 1 and 2
    assign snoop_rs1_exe_mem = cu_rr_int.write_enable_2 & (write_paddr_2 == stage_rr_exe_q.prs1) & (stage_rr_exe_q.instr.rs1 != 0);
    assign snoop_rs2_exe_mem = cu_rr_int.write_enable_2 & (write_paddr_2 == stage_rr_exe_q.prs2) & (stage_rr_exe_q.instr.rs2 != 0); 

    assign reg_to_exe.data_rs1 = (snoop_rs1_exe_alu_mul_div)? data_wb_csr_to_rr : (snoop_rs1_exe_mem)? data_mem_to_rr : stage_rr_exe_q.data_rs1;
    assign reg_to_exe.data_rs2 = (snoop_rs2_exe_alu_mul_div)? data_wb_csr_to_rr : (snoop_rs2_exe_mem)? data_mem_to_rr : stage_rr_exe_q.data_rs2;
    assign reg_to_exe.rdy1 = stage_rr_exe_q.rdy1 | snoop_rs1_exe_alu_mul_div | snoop_rs1_exe_mem;
    assign reg_to_exe.rdy2 = stage_rr_exe_q.rdy2 | snoop_rs2_exe_alu_mul_div | snoop_rs2_exe_mem;
    assign reg_to_exe.instr = stage_rr_exe_q.instr;
    assign reg_to_exe.prs1 = stage_rr_exe_q.prs1;
    assign reg_to_exe.prs2 = stage_rr_exe_q.prs2;
    assign reg_to_exe.prd = stage_rr_exe_q.prd;
    assign reg_to_exe.old_prd = stage_rr_exe_q.old_prd;
    assign reg_to_exe.checkpoint_done = stage_rr_exe_q.checkpoint_done;
    assign reg_to_exe.chkp = stage_rr_exe_q.chkp;
    assign reg_to_exe.gl_index = stage_rr_exe_q.gl_index;


    exe_stage exe_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .kill_i(flush_int.flush_exe),
        .csr_interrupt_i(stage_rr_exe_q.csr_interrupt),
        .csr_interrupt_cause_i(stage_rr_exe_q.csr_interrupt_cause),

        .from_rr_i(reg_to_exe),

        .resp_dcache_cpu_i(resp_dcache_cpu_i),
        .io_base_addr_i(io_base_addr),
        .flush_i(1'b0),
        .commit_store_or_amo_i(commit_store_or_amo_int),

        .exe_if_branch_pred_o(exe_if_branch_pred_int),
        .correct_branch_pred_o(correct_branch_pred),

        .alu_mul_div_to_wb_o(alu_mul_div_to_wb),
        .mem_to_wb_o(mem_to_wb),
        .stall_o(exe_cu_int.stall),

        .mem_commit_stall_o(mem_commit_stall_int),
        .exception_mem_commit_o(exception_mem_commit_int),

        .req_cpu_dcache_o(req_cpu_dcache_o),

        //PMU Neiel-Leyva
        .pmu_is_branch_o        ( pmu_flags_o.is_branch     ),      
        .pmu_branch_taken_o     ( pmu_flags_o.branch_taken  ),   
        .pmu_miss_prediction_o  ( pmu_flags_o.branch_miss   ),
        .pmu_stall_mul_o        ( pmu_flags_o.stall_rr      ),
        .pmu_stall_div_o        ( pmu_flags_o.stall_exe     ),
        .pmu_stall_mem_o        ( pmu_flags_o.stall_wb      )
    );

    assign exe_cu_int.valid = stage_rr_exe_q.instr.valid;
    assign exe_cu_int.change_pc_ena = stage_rr_exe_q.instr.change_pc_ena;
    assign exe_cu_int.stall_csr_fence = stage_rr_exe_q.instr.stall_csr_fence && stage_rr_exe_q.instr.valid;

    register #($bits(exe_wb_instr_t) + $bits(exe_wb_instr_t)) reg_exe_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_exe),
        .load_i(!control_int.stall_exe),
        .input_i({alu_mul_div_to_wb, mem_to_wb}),
        .output_o({alu_mul_div_wb, mem_wb})
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// WRITE BACK STAGE                                                                             /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    assign wb_cu_int.is_branch = (alu_mul_div_wb.instr_type == BLT)  ||
                                 (alu_mul_div_wb.instr_type == BLTU) ||
                                 (alu_mul_div_wb.instr_type == BGE)  ||
                                 (alu_mul_div_wb.instr_type == BGEU) ||
                                 (alu_mul_div_wb.instr_type == BEQ)  ||
                                 (alu_mul_div_wb.instr_type == BNE);

    assign instruction_writeback_gl_1.csr_addr = alu_mul_div_wb.csr_addr;
    assign instruction_writeback_gl_1.exception = alu_mul_div_wb.ex;
    assign instruction_writeback_gl_1.result = alu_mul_div_wb.result;

    assign instruction_writeback_gl_2.exception = mem_wb.ex;
    assign instruction_writeback_gl_2.result = mem_wb.result;

    // Write data regfile from WB or from Commit (CSR)
    // CSR are exclusive with the rest of instrucitons. Therefore, there are no conflicts
    assign data_wb_csr_to_rr = (commit_cu_int.write_enable) ?  resp_csr_cpu_i.csr_rw_rdata : 
                                                alu_mul_div_wb.result;
                                                
    assign data_mem_to_rr = mem_wb.result;
     
    assign write_paddr_1 = (commit_cu_int.write_enable) ? instruction_gl_commit.prd : alu_mul_div_wb.prd;
    assign write_vaddr_1 = (commit_cu_int.write_enable) ? instruction_gl_commit.rd  : alu_mul_div_wb.rd;
    
    assign write_paddr_2 = mem_wb.prd;
    assign write_vaddr_2 = mem_wb.rd;
    
    // For bypasses
    // IMPORTANT: since we can not do bypassig of a CSR, we will not take into acount the case 
    // of forwarding the result of a CSR to increasse the frequency
    assign wb_to_exe_exe.valid  = exe_to_wb_wb.valid;
    assign wb_to_exe_exe.rd     = exe_to_wb_wb.rd;
    assign wb_to_exe_exe.prd    = exe_to_wb_wb.prd;
    assign wb_to_exe_exe.data   = data_wb_rr_int;
    

    // Control Unit From Write Back
    assign wb_cu_int.valid_1 = alu_mul_div_wb.valid;
    assign wb_cu_int.change_pc_ena = alu_mul_div_wb.change_pc_ena;
    assign wb_cu_int.branch_taken = alu_mul_div_wb.branch_taken;
    assign wb_cu_int.write_enable_1 = alu_mul_div_wb.regfile_we;
    assign wb_cu_int.checkpoint_done = alu_mul_div_wb.checkpoint_done;
    assign wb_cu_int.chkp = alu_mul_div_wb.chkp;
    assign wb_cu_int.gl_index = alu_mul_div_wb.gl_index;

    assign wb_cu_int.valid_2 = mem_wb.valid;
    assign wb_cu_int.write_enable_2 = mem_wb.regfile_we;

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// COMMIT STAGE                                                                                 /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    register #($bits(gl_instruction_t)) commit_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_int.flush_commit),
        .load_i(src_select_commit),
        .input_i(instruction_gl_commit),
        .output_o(instruction_gl_commit_old_q)
    );


    // Syncronus Mux to decide between actual (decode + rename) or one cycle before (decode + rename)
    always @(posedge clk_i) begin
        src_select_commit <= !control_int.stall_commit;
    end

    assign instruction_to_commit = (src_select_commit)? instruction_gl_commit : instruction_gl_commit_old_q;

    csr_interface csr_interface_inst
    (
        .wb_xcpt_i(commit_xcpt),
        .exe_to_wb_wb_i(instruction_to_commit),
        .stall_exe_i(control_int.stall_exe),
        .wb_csr_ena_int_o(csr_ena_int),
        .req_cpu_csr_o(req_cpu_csr_o)
    );


    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            pc_evec_q <=  'b0;
        end else begin 
            pc_evec_q <= resp_csr_cpu_i.csr_evec;
        end
    end

    // CSR and Exceptions
    assign req_cpu_csr_o.csr_rw_addr = (csr_ena_int) ? instruction_to_commit.csr_addr : {CSR_ADDR_SIZE{1'b0}};
    // if csr not enabled send command NOP
    assign req_cpu_csr_o.csr_rw_cmd = (csr_ena_int) ? csr_cmd_int : CSR_CMD_NOPE;
    // if csr not enabled send the interesting addr that you are accesing, exception help
    assign req_cpu_csr_o.csr_rw_data = (csr_ena_int) ? csr_rw_data_int : (~commit_store_or_amo_int)? instruction_to_commit.exception.origin : exception_mem_commit_int.origin;

    // if there is an exception that can be from:
    // the instruction itself or the interrupt
    assign commit_xcpt = (~commit_store_or_amo_int)? instruction_to_commit.exception.valid : exception_mem_commit_int.valid;

    assign req_cpu_csr_o.csr_exception = commit_xcpt;

    // if we can retire an instruction
    assign req_cpu_csr_o.csr_retire = instruction_to_commit.valid && !commit_xcpt && (!commit_store_or_amo_int | !mem_commit_stall_int);
    // if there is a csr interrupt we take the interrupt?
    assign req_cpu_csr_o.csr_xcpt_cause = (~commit_store_or_amo_int)? instruction_to_commit.exception.cause : exception_mem_commit_int.cause;
    assign req_cpu_csr_o.csr_pc = instruction_to_commit.pc;

    // Control Unit From Commit
    assign commit_cu_int.valid = instruction_to_commit.valid;
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
    assign commit_cu_int.write_enable = (instruction_to_commit.instr_type == CSRRW  ||
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

    assign commit_cu_int.stall_commit = mem_commit_stall_int;

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////// DEBUG SIGNALS                                                                                /////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef VERILATOR
    // Debug signals
    assign commit_valid     = instruction_to_commit.valid;
    assign commit_pc        = (instruction_to_commit.valid) ? instruction_to_commit.pc : 64'b0;
    assign commit_data      = (instruction_to_commit.valid) ? data_wb_csr_to_rr  : 64'b0;
    assign commit_addr_reg  = instruction_to_commit.rd;

    // PC
    assign pc_if  = stage_if_id_d.pc_inst;
    assign pc_id  = (valid_id)  ? stage_id_rr_d.pc : 64'b0;
    assign pc_rr  = (valid_rr)  ? stage_rr_exe_d.instr.pc : 64'b0;
    assign pc_exe = (valid_exe) ? stage_rr_exe_q.instr.pc : 64'b0;
    assign pc_wb = (valid_wb) ? alu_mul_div_wb.pc : 64'b0;

    // Valid
    assign valid_if  = stage_if_id_d.valid;
    assign valid_id  = stage_id_rr_d.valid;
    assign valid_rr  = stage_rr_exe_d.instr.valid;
    assign valid_exe = stage_rr_exe_q.instr.valid;
    assign valid_wb = alu_mul_div_wb.valid;

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
            .data(commit_data),
            .xcpt(commit_xcpt),
            .xcpt_cause(instruction_gl_commit.exception.cause),
            .csr_priv_lvl(csr_priv_lvl_i),
            .csr_rw_data(req_cpu_csr_o.csr_rw_data),
            .csr_xcpt(resp_csr_cpu_i.csr_exception),
            .csr_xcpt_cause(resp_csr_cpu_i.csr_exception_cause),
            .csr_tval(resp_csr_cpu_i.csr_tval)
        );
    `endif

    // Debug Ring signals Output
    // PC
    assign debug_o.pc_fetch = pc_if[39:0];
    assign debug_o.pc_dec   = pc_id[39:0];
    assign debug_o.pc_rr    = pc_rr[39:0];
    assign debug_o.pc_exe   = pc_exe[39:0];
    assign debug_o.pc_wb    = pc_wb[39:0];
    // Write-back signals
    assign debug_o.wb_valid = exe_to_wb_wb.valid;
    assign debug_o.wb_reg_addr = exe_to_wb_wb.rd;
    assign debug_o.wb_reg_we = cu_rr_int.write_enable;
    // Register File read 
    assign debug_o.reg_read_data = stage_rr_exe_d.data_rs1;


    //PMU
    assign pmu_flags_o.stall_if     = resp_csr_cpu_i.csr_stall ; 
    assign pmu_flags_o.stall_id     = exe_cu_int.stall ; 

endmodule
