/* -----------------------------------------------
* Project Name   : DRAC
* File           : control_unit.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
*                  Victor Soria Pardos
* Email(s)       : guillem.lopez@bsc.es
*                  victor.soria@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
* -----------------------------------------------
*/

import drac_pkg::*;
import riscv_pkg::*;

module control_unit(
    input logic             rstn_i,
    input logic             clk_i,

    input logic             valid_fetch,
    input id_cu_t           id_cu_i,
    input rr_cu_t           rr_cu_i,
    input exe_cu_t          exe_cu_i,
    input wb_cu_t           wb_cu_i,
    input commit_cu_t       commit_cu_i,
    input resp_csr_cpu_t    csr_cu_i,
    input logic             correct_branch_pred_i,
    input logic             debug_halt_i,
    input logic             debug_change_pc_i,
    input logic             debug_wr_valid_i,


    output pipeline_ctrl_t  pipeline_ctrl_o,
    output pipeline_flush_t pipeline_flush_o,
    output cu_if_t          cu_if_o,
    output logic            invalidate_icache_o,
    output logic            invalidate_buffer_o,

    output cu_id_t          cu_id_o,
    output cu_rr_t          cu_rr_o,
    output cu_wb_t          cu_wb_o,
    output cu_commit_t      cu_commit_o

);
    reg csr_fence_in_pipeline;
    logic flush_csr_fence;

    always_ff@(posedge clk_i, negedge rstn_i)
    begin
        if (~rstn_i)
            csr_fence_in_pipeline <= 0;
        else if (flush_csr_fence)
            csr_fence_in_pipeline <= 0;
        else if(id_cu_i.valid & id_cu_i.stall_csr_fence)
            csr_fence_in_pipeline <= 1;
        else if (commit_cu_i.valid & commit_cu_i.stall_csr_fence)
                csr_fence_in_pipeline <= 0;
    end

    logic jump_enable_int;
    logic exception_enable_q, exception_enable_d;
    // jump enable logic
    always_comb begin
        jump_enable_int =   (exe_cu_i.valid_1 && ~correct_branch_pred_i) ||   // branch at exe
                            id_cu_i.valid_jal;                              // valid jal
    end

    // set the exception state that will stall the pipeline on cycle to reduce the delay of the CSRs
    assign exception_enable_d = exception_enable_q ? 1'b0 : ((commit_cu_i.valid && commit_cu_i.xcpt) || 
                                                            csr_cu_i.csr_eret || 
                                                            csr_cu_i.csr_exception || 
                                                            (commit_cu_i.valid && commit_cu_i.ecall_taken));

    // logic enable write register file at commit
    always_comb begin
        // we don't allow regular reads/writes if not halted
        if (( commit_cu_i.valid && !commit_cu_i.xcpt &&
                       !csr_cu_i.csr_exception && commit_cu_i.write_enable) ||
                     ( wb_cu_i.valid_1 && wb_cu_i.write_enable_1)) 
        begin
            cu_rr_o.write_enable_1 = 1'b1;
        end else begin
            cu_rr_o.write_enable_1 = 1'b0;
        end
    end

    always_comb begin
        // we don't allow regular reads/writes if not halted
        if (debug_wr_valid_i && debug_halt_i) begin
            cu_rr_o.write_enable_dbg = 1'b1;
        end else begin
            cu_rr_o.write_enable_dbg = 1'b0;
        end
    end
    
    always_comb begin
        if (wb_cu_i.valid_2 && wb_cu_i.write_enable_2)
        begin
            cu_rr_o.write_enable_2 = 1'b1;
        end else begin
            cu_rr_o.write_enable_2 = 1'b0;
        end
    end


    // logic to select the next pc
    always_comb begin
        // branches or valid jal
        if (debug_change_pc_i && debug_halt_i) begin
            cu_if_o.next_pc = NEXT_PC_SEL_DEBUG;
        end else if (jump_enable_int || exception_enable_q) begin
            cu_if_o.next_pc = NEXT_PC_SEL_JUMP;
        end else if (!valid_fetch                               || 
                     pipeline_ctrl_o.stall_if                   || 
                     (id_cu_i.valid & id_cu_i.stall_csr_fence)  || 
                     csr_fence_in_pipeline                      || 
                     (commit_cu_i.valid && commit_cu_i.fence)   ||
                     debug_halt_i                               )  begin
                     
            cu_if_o.next_pc = NEXT_PC_SEL_KEEP_PC;
        end else begin
            cu_if_o.next_pc = NEXT_PC_SEL_BP_OR_PC_4;
        end
    end

    // logic to select which pc to use in fetch
    always_comb begin
        // if exception or eret select from csr
        if (exception_enable_q) begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_CSR;
        end else if (exe_cu_i.valid_1 && ~correct_branch_pred_i) begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_EXECUTION;
        end else if (debug_change_pc_i && debug_halt_i) begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_DEBUG;
        end else begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_DECODE;
        end
    end

    // logic invalidate icache

    // when there is a fence, it could be a self modifying code
    // invalidate icache
    assign invalidate_icache_o = (commit_cu_i.valid && commit_cu_i.fence_i);
    // logic invalidate buffer and repeat fetch
    // when a fence, invalidate buffer and also when csr eret
    // when it is a csr it should be checked more?
    assign invalidate_buffer_o = (commit_cu_i.valid && (commit_cu_i.fence_i | 
                                                    exception_enable_q |
                                                    (commit_cu_i.stall_csr_fence & !commit_cu_i.fence)));

    // logic do rename/free list checkpoint
    assign cu_id_o.do_checkpoint = (id_cu_i.is_branch | id_cu_i.predicted_as_branch) &
                                   id_cu_i.valid &  ~(id_cu_i.out_of_checkpoints) &
                                   ~(pipeline_flush_o.flush_id) & ~(pipeline_ctrl_o.stall_id);

    assign cu_id_o.do_recover = (~correct_branch_pred_i & exe_cu_i.checkpoint_done & exe_cu_i.valid_1);

    assign cu_id_o.recover_checkpoint = exe_cu_i.chkp;

    assign cu_id_o.delete_checkpoint = (correct_branch_pred_i & exe_cu_i.checkpoint_done & exe_cu_i.valid_1);

    // logic about flush the pipeline if branch
    always_comb begin
        // if exception
        pipeline_flush_o.flush_if       = 1'b0;
        pipeline_flush_o.flush_id       = 1'b0;
        pipeline_flush_o.flush_rr       = 1'b0;
        pipeline_flush_o.flush_exe      = 1'b0;
        pipeline_flush_o.flush_wb       = 1'b0;
        pipeline_flush_o.flush_commit   = 1'b0;
        flush_csr_fence                 = 1'b0;
        if (exception_enable_q) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b1;
            pipeline_flush_o.flush_rr  = 1'b1;
            pipeline_flush_o.flush_exe = 1'b1;
            pipeline_flush_o.flush_wb  = 1'b0;
            flush_csr_fence            = 1'b1;
        end else if (exe_cu_i.valid_1 & ~correct_branch_pred_i) begin
            if (exe_cu_i.stall) begin
                pipeline_flush_o.flush_if  = 1'b1;
                pipeline_flush_o.flush_id  = 1'b1;
                pipeline_flush_o.flush_rr  = 1'b0;
                pipeline_flush_o.flush_exe = 1'b0;
                pipeline_flush_o.flush_wb  = 1'b0;
                flush_csr_fence            = 1'b1;
            end else begin
                pipeline_flush_o.flush_if  = 1'b1;
                pipeline_flush_o.flush_id  = 1'b1;
                pipeline_flush_o.flush_rr  = 1'b1;
                pipeline_flush_o.flush_exe = 1'b0;
                pipeline_flush_o.flush_wb  = 1'b0;
                flush_csr_fence            = 1'b1;
            end
        end else if ((id_cu_i.stall_csr_fence | 
                      csr_fence_in_pipeline   | 
                      commit_cu_i.stall_csr_fence) && !(csr_cu_i.csr_stall || exe_cu_i.stall)) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b0;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
            pipeline_flush_o.flush_wb  = 1'b0;
        end else if ((id_cu_i.valid_jal ||
                    (commit_cu_i.valid && commit_cu_i.fence)) && !(csr_cu_i.csr_stall || exe_cu_i.stall)) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b0;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
            pipeline_flush_o.flush_wb  = 1'b0;
        end else if (id_cu_i.empty_free_list) begin
            pipeline_flush_o.flush_if  = 1'b0;
            pipeline_flush_o.flush_id  = 1'b1;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
            pipeline_flush_o.flush_wb  = 1'b0;
        end else if (id_cu_i.out_of_checkpoints) begin
            pipeline_flush_o.flush_if  = 1'b0;
            pipeline_flush_o.flush_id  = 1'b1;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
            pipeline_flush_o.flush_wb  = 1'b0;
        end
    end


    // Logic to stall the pipeline
    always_comb begin
        pipeline_ctrl_o.stall_if  = 1'b0;
        pipeline_ctrl_o.stall_id  = 1'b0;
        pipeline_ctrl_o.stall_rr  = 1'b0;
        pipeline_ctrl_o.stall_exe = 1'b0;
        pipeline_ctrl_o.stall_wb  = 1'b0;
        if (csr_cu_i.csr_stall || exe_cu_i.stall) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b1;
            pipeline_ctrl_o.stall_exe = 1'b0;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end else if (rr_cu_i.gl_full) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b1;
            pipeline_ctrl_o.stall_exe = 1'b0;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end else if (id_cu_i.empty_free_list) begin
            pipeline_ctrl_o.stall_if     = 1'b1;
            pipeline_ctrl_o.stall_id     = 1'b1;
            pipeline_ctrl_o.stall_rr     = 1'b0;
            pipeline_ctrl_o.stall_exe    = 1'b0;
            pipeline_ctrl_o.stall_wb     = 1'b0;
        end else if (id_cu_i.out_of_checkpoints) begin
            pipeline_ctrl_o.stall_if     = 1'b1;
            pipeline_ctrl_o.stall_id     = 1'b1;
            pipeline_ctrl_o.stall_rr     = 1'b0;
            pipeline_ctrl_o.stall_exe    = 1'b0;
            pipeline_ctrl_o.stall_wb     = 1'b0;
        end else if (commit_cu_i.valid && commit_cu_i.stall_csr_fence) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b0;
            pipeline_ctrl_o.stall_rr  = 1'b0;
            pipeline_ctrl_o.stall_exe = 1'b0;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end
    end

    assign cu_commit_o.enable_commit = ~(commit_cu_i.stall_commit);

    assign pipeline_ctrl_o.stall_commit = commit_cu_i.stall_commit;


    // logic flush gl
    always_comb begin
        if (~correct_branch_pred_i & exe_cu_i.valid_1) begin
            cu_wb_o.flush_gl = 1'b1;
            cu_wb_o.flush_gl_index = exe_cu_i.gl_index;
        end else begin
            cu_wb_o.flush_gl = 1'b0;
            cu_wb_o.flush_gl_index = 'b0;
        end
    end


    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            exception_enable_q <= 1'b0;
        end else begin 
            exception_enable_q <= exception_enable_d;
        end
    end

endmodule
