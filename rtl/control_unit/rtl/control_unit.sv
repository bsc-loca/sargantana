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

module control_unit
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic             rstn_i,
    input logic             clk_i,

    input logic             miss_icache_i,
    input logic             ready_icache_i,
    input logic             if2_cu_valid_i,
    input id_cu_t           id_cu_i,
    input ir_cu_t           ir_cu_i,
    input rr_cu_t           rr_cu_i,
    input exe_cu_t          exe_cu_i,
    input wb_cu_t           wb_cu_i,
    input commit_cu_t       commit_cu_i,
    input resp_csr_cpu_t    csr_cu_i,
    input logic             correct_branch_pred_wb_i,
    input logic             correct_branch_pred_exe_i,
    input logic             debug_wr_valid_i,

    input logic             gl_empty_i,

    input debug_contr_in_t  debug_contr_i,

    output pipeline_ctrl_t  pipeline_ctrl_o,
    output pipeline_flush_t pipeline_flush_o,
    output cu_if_t          cu_if_o,
    output logic            invalidate_icache_o,
    output logic            invalidate_buffer_o,

    output cu_ir_t          cu_ir_o,
    output cu_rr_t          cu_rr_o,
    output cu_wb_t          cu_wb_o,
    output cu_commit_t      cu_commit_o,

    output debug_contr_out_t debug_contr_o,
    output logic             debug_csr_halt_ack_o,

    output logic            pmu_jump_misspred_o

);
    reg csr_fence_in_pipeline;
    logic flush_csr_fence;
    logic flush_step_inst;
    logic step_inst_in_pipeline;
    logic step_inst_in_if2;
    logic step_inst_in_id;

    logic exception_enable_q, exception_enable_d;
    bus64_t exception_cause_q, exception_cause_d;

    debug_contr_state_t state_debug_q, state_debug_d;
    logic on_halt_state;
    logic debug_progbuf_xcpt_d, debug_progbuf_xcpt_q;

    always_comb begin
        debug_contr_o.resume_ack = 1'b0;
        debug_contr_o.halt_ack = 1'b0;
        state_debug_d = state_debug_q;
        on_halt_state = 1'b0;
        debug_contr_o.halted = 1'b0;
        debug_contr_o.running = 1'b0;
        debug_contr_o.parked = 1'b0; 
        debug_contr_o.unavail = 1'b0;
        debug_contr_o.progbuf_ack = 1'b0;
        debug_contr_o.progbuf_xcpt = debug_progbuf_xcpt_q;
        debug_csr_halt_ack_o = 1'b0;
        debug_progbuf_xcpt_d = debug_progbuf_xcpt_q;

        case (state_debug_q)
            DEBUG_STATE_RESET: begin
                if (debug_contr_i.halt_on_reset) begin
                    state_debug_d = DEBUG_STATE_HALTED;
                    debug_contr_o.halt_ack = 1'b1;
                    on_halt_state = 1'b1;
                end else begin
                    state_debug_d = DEBUG_STATE_RUNNING;
                    on_halt_state = 1'b0;
                end
            end
            DEBUG_STATE_RUNNING: begin
                if (csr_cu_i.debug_ebreak) begin
                    state_debug_d = DEBUG_STATE_HALTED;
                    debug_contr_o.halt_ack = 1'b1;
                end else if (debug_contr_i.halt_req) begin
                    state_debug_d = DEBUG_STATE_HALTING;
                end 
                on_halt_state = 1'b0;
                debug_contr_o.running = 1'b1;
                debug_contr_o.resume_ack = debug_contr_i.resume_req;
            end
            DEBUG_STATE_HALTING: begin
                if (gl_empty_i || csr_cu_i.debug_ebreak) begin
                    state_debug_d = DEBUG_STATE_HALTED;
                    debug_contr_o.halt_ack = 1'b1;
                    if (gl_empty_i) begin
                        debug_csr_halt_ack_o = 1'b1;
                    end 
                end 
                on_halt_state = 1'b1;
                debug_contr_o.running = 1'b1;
            end
            DEBUG_STATE_HALTED: begin
                if (debug_contr_i.resume_req) begin
                    state_debug_d = DEBUG_STATE_RUNNING;
                    debug_contr_o.resume_ack = 1'b1;
                end else if (debug_contr_i.progbuf_req) begin
                    state_debug_d = DEBUG_STATE_PROGBUFF;
                    debug_contr_o.progbuf_ack = 1'b1;
                    debug_progbuf_xcpt_d = 1'b0;
                end
                on_halt_state = 1'b1;
                debug_contr_o.halted = 1'b1;
                debug_contr_o.parked = 1'b1;
            end
            DEBUG_STATE_PROGBUFF: begin
                if (debug_contr_i.resume_req) begin
                    state_debug_d = DEBUG_STATE_RUNNING;
                    debug_contr_o.resume_ack = 1'b1;
                end else if (csr_cu_i.debug_ebreak || exception_enable_q) begin
                    state_debug_d = DEBUG_STATE_HALTED;
                    debug_contr_o.halt_ack = 1'b1;
                    debug_progbuf_xcpt_d = (exception_enable_q & (exception_cause_q != BREAKPOINT));
                end 
                on_halt_state = 1'b0;
                debug_contr_o.halted = 1'b1;
            end
        endcase
    end

    assign step_inst_in_if2 = (if2_cu_valid_i & csr_cu_i.debug_step & (state_debug_q == DEBUG_STATE_RUNNING));
    assign step_inst_in_id = (id_cu_i.valid & csr_cu_i.debug_step & (state_debug_q == DEBUG_STATE_RUNNING));

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

    always_ff@(posedge clk_i, negedge rstn_i)
    begin
        if (~rstn_i)
            step_inst_in_pipeline <= 0;
        else if (flush_step_inst)
            step_inst_in_pipeline <= 0;
        else if (step_inst_in_id)
            step_inst_in_pipeline <= 1;
    end

    logic jump_enable_int;
    logic csr_enable_d, csr_enable_q;
    // jump enable logic
    always_comb begin
        jump_enable_int =   (wb_cu_i.valid[0] && ~correct_branch_pred_wb_i) ||   // branch at exe
                            (id_cu_i.valid && !id_cu_i.is_branch && id_cu_i.predicted_as_branch) || // invalid prediction
                            id_cu_i.valid_jal; // valid jal
    end

    // set the exception state that will stall the pipeline on cycle to reduce the delay of the CSRs
    assign exception_enable_d = exception_enable_q ? 1'b0 : ((commit_cu_i.valid && commit_cu_i.xcpt) || 
                                                            csr_cu_i.csr_eret || 
                                                            csr_cu_i.csr_exception || 
                                                            csr_cu_i.debug_ebreak ||
                                                            debug_contr_o.halt_ack ||
                                                            (commit_cu_i.valid && commit_cu_i.ecall_taken));
    assign exception_cause_d = exception_enable_q ? 'h0 : csr_cu_i.csr_exception_cause;
    // set the exception state that will stall the pipeline on cycle to reduce the delay of the CSRs
    assign csr_enable_d = csr_enable_q ? 1'b0 : (commit_cu_i.valid && commit_cu_i.stall_csr_fence) &&
                                                            !((commit_cu_i.valid && commit_cu_i.xcpt) || 
                                                            csr_cu_i.csr_eret || 
                                                            csr_cu_i.csr_exception || 
                                                            csr_cu_i.debug_ebreak ||
                                                            debug_contr_o.halt_ack ||
                                                            (commit_cu_i.valid && commit_cu_i.ecall_taken));

    // logic enable write register file at commit
    always_comb begin
        for (int i = 0; i<NUM_SCALAR_WB; ++i) begin
            if (i == 0) begin
                // we don't allow regular reads/writes if not halted
                if (( commit_cu_i.valid && !commit_cu_i.xcpt &&
                               !csr_cu_i.csr_exception && commit_cu_i.write_enable) ||
                             ( wb_cu_i.valid[i] && wb_cu_i.write_enable[i]) || (debug_wr_valid_i && on_halt_state)) 
                begin
                    cu_rr_o.write_enable[i] = 1'b1;
                end else begin
                    cu_rr_o.write_enable[i] = 1'b0;
                end
            end else begin
                if (wb_cu_i.valid[i] && wb_cu_i.write_enable[i]) begin
                    cu_rr_o.write_enable[i] = 1'b1;
                end else begin
                    cu_rr_o.write_enable[i] = 1'b0;
                end
            end
        end
        for (int i = 0; i<drac_pkg::NUM_SCALAR_WB; ++i) begin
            if (i == 0) begin
                // we don't allow regular reads/writes if not halted
                if ( wb_cu_i.valid[i] && wb_cu_i.snoop_enable[i])
                begin
                    cu_rr_o.snoop_enable[i] = 1'b1;
                end else begin
                    cu_rr_o.snoop_enable[i] = 1'b0;
                end
            end else begin
                if (wb_cu_i.valid[i] && wb_cu_i.snoop_enable[i]) begin
                    cu_rr_o.snoop_enable[i] = 1'b1;
                end else begin
                    cu_rr_o.snoop_enable[i] = 1'b0;
                end
            end
        end

        for (int i = 0; i<NUM_SIMD_WB; ++i) begin
            if (wb_cu_i.vvalid[i] && wb_cu_i.vwrite_enable[i]) begin
                cu_rr_o.vwrite_enable[i] = 1'b1;
            end else begin
                cu_rr_o.vwrite_enable[i] = 1'b0;
            end
            if (wb_cu_i.vvalid[i] && wb_cu_i.vsnoop_enable[i]) begin
                cu_rr_o.vsnoop_enable[i] = 1'b1;
            end else begin
                cu_rr_o.vsnoop_enable[i] = 1'b0;
            end
        end
        // logic enable write FP register file at commit
        for (int i = 0; i<drac_pkg::NUM_FP_WB; ++i) begin
            if (wb_cu_i.fvalid[i] && wb_cu_i.fwrite_enable[i]) begin
                cu_rr_o.fwrite_enable[i] = 1'b1;
            end else begin
                cu_rr_o.fwrite_enable[i] = 1'b0;
            end
            if (wb_cu_i.fvalid[i] && wb_cu_i.fsnoop_enable[i]) begin
                cu_rr_o.fsnoop_enable[i] = 1'b1;
            end else begin
                cu_rr_o.fsnoop_enable[i] = 1'b0;
            end
        end

        // we don't allow regular reads/writes if not halted
        if (debug_wr_valid_i && on_halt_state) begin
            cu_rr_o.write_enable_dbg = 1'b1;
        end else begin
            cu_rr_o.write_enable_dbg = 1'b0;
        end
    end

    // logic to select the next pc
    always_comb begin
        // branches or valid jal
        if (jump_enable_int || exception_enable_q || csr_enable_q) begin
            cu_if_o.next_pc = NEXT_PC_SEL_JUMP;
        end else if (pipeline_ctrl_o.stall_if_1                 || 
                     (id_cu_i.valid & id_cu_i.stall_csr_fence)  ||
                     step_inst_in_if2                           ||
                     step_inst_in_id                            ||
                     csr_fence_in_pipeline                      ||
                     step_inst_in_pipeline                      || 
                     (commit_cu_i.valid && commit_cu_i.fence)   ||
                     on_halt_state)  begin
                     
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
        end else if (csr_enable_q) begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_CSR_RW;
        end else if (wb_cu_i.valid[0] && ~correct_branch_pred_wb_i) begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_EXECUTION;
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
                                                    debug_contr_o.halt_ack |
                                                    (commit_cu_i.stall_csr_fence & !commit_cu_i.fence)));

    // logic do rename/free list checkpoint
    assign cu_ir_o.do_checkpoint = (ir_cu_i.is_branch) &
                                   ir_cu_i.valid &  ~(ir_cu_i.out_of_checkpoints) &
                                   ~(pipeline_flush_o.flush_ir) & ~(pipeline_ctrl_o.stall_ir);

    assign cu_ir_o.do_recover = (~correct_branch_pred_wb_i & wb_cu_i.checkpoint_done & wb_cu_i.valid[0]);

    assign cu_ir_o.recover_checkpoint = wb_cu_i.chkp;

    assign cu_ir_o.delete_checkpoint = (correct_branch_pred_wb_i & wb_cu_i.checkpoint_done & wb_cu_i.valid[0]);

    // Logic To Flush the frontend
    always_comb begin
        // if exception
        pipeline_flush_o.flush_if       = 1'b0;
        pipeline_flush_o.flush_id       = 1'b0;
        if (exception_enable_q) begin
            pipeline_flush_o.flush_if       = 1'b1;
            pipeline_flush_o.flush_id       = 1'b1;
        end else if (csr_enable_q) begin
            pipeline_flush_o.flush_if       = 1'b1;
            pipeline_flush_o.flush_id       = 1'b1;
        end else if (wb_cu_i.valid[0] & ~correct_branch_pred_wb_i) begin
                pipeline_flush_o.flush_if  = 1'b1;
                pipeline_flush_o.flush_id  = 1'b1;
        end else if ((id_cu_i.stall_csr_fence | 
                      csr_fence_in_pipeline   |
                      step_inst_in_id         |
                      step_inst_in_pipeline   |
                      commit_cu_i.stall_csr_fence) && !(csr_cu_i.csr_stall)) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b0;
        end else if ((id_cu_i.valid_jal ||
                    (commit_cu_i.valid && commit_cu_i.fence)) && !(csr_cu_i.csr_stall)) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b0;
        end else if ((id_cu_i.valid && !id_cu_i.is_branch && id_cu_i.predicted_as_branch) && !(csr_cu_i.csr_stall)) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b0;
        end
    end

    // Logic To Flush the Backend
    always_comb begin
        // if exception
        pipeline_flush_o.flush_ir       = 1'b0;
        pipeline_flush_o.flush_rr       = 1'b0;
        pipeline_flush_o.flush_exe      = 1'b0;
        pipeline_flush_o.kill_exe       = 1'b0;
        pipeline_flush_o.flush_commit   = 1'b0;
        flush_csr_fence                 = 1'b0;
        flush_step_inst                 = 1'b0;
        if (exception_enable_q) begin
            pipeline_flush_o.flush_ir      = 1'b1;
            pipeline_flush_o.flush_rr      = 1'b1;
            pipeline_flush_o.flush_exe     = 1'b1;
            flush_csr_fence                = 1'b1;
            flush_step_inst                = 1'b1;
        end else if (wb_cu_i.valid[0] & ~correct_branch_pred_wb_i) begin
            pipeline_flush_o.flush_ir  = 1'b1;
            pipeline_flush_o.flush_rr  = 1'b1;
            pipeline_flush_o.flush_exe = 1'b0;
            pipeline_flush_o.kill_exe  = 1'b1;
            flush_csr_fence            = 1'b1;
        end /*else if (exe_cu_i.valid_1 & ~correct_branch_pred_exe_i) begin
            if (exe_cu_i.stall) begin
                pipeline_flush_o.flush_ir  = 1'b1;
                pipeline_flush_o.flush_rr  = 1'b0;
                pipeline_flush_o.flush_exe = 1'b0;
                flush_csr_fence            = 1'b1;
            end else begin
                pipeline_flush_o.flush_ir  = 1'b1;
                pipeline_flush_o.flush_rr  = 1'b1;
                pipeline_flush_o.flush_exe = 1'b0;
                flush_csr_fence            = 1'b1;
            end
        end */else if (exe_cu_i.stall) begin   
            pipeline_flush_o.flush_ir  = 1'b0;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
        end else if (rr_cu_i.gl_full) begin
            pipeline_flush_o.flush_ir  = 1'b0;
            pipeline_flush_o.flush_rr  = 1'b1;
            pipeline_flush_o.flush_exe = 1'b0;
        end else if (ir_cu_i.empty_free_list) begin
            pipeline_flush_o.flush_ir  = 1'b0;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
        end else if (ir_cu_i.out_of_checkpoints) begin
            pipeline_flush_o.flush_ir  = 1'b0;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
        end
    end


    // Logic to stall the Front End
    always_comb begin
        pipeline_ctrl_o.stall_if_1  = 1'b0;
        pipeline_ctrl_o.stall_if_2  = 1'b0;
        pipeline_ctrl_o.stall_id    = 1'b0;
        if (csr_cu_i.csr_stall) begin
            pipeline_ctrl_o.stall_if_1  = 1'b1;
            pipeline_ctrl_o.stall_if_2  = 1'b1;
            pipeline_ctrl_o.stall_id    = 1'b1;
        end else if (ir_cu_i.full_iq) begin
            pipeline_ctrl_o.stall_if_1  = 1'b1;
            pipeline_ctrl_o.stall_if_2  = 1'b1;
            pipeline_ctrl_o.stall_id    = 1'b1;
        end else if (miss_icache_i) begin
            pipeline_ctrl_o.stall_if_1  = 1'b1;
            pipeline_ctrl_o.stall_if_2  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b0;
        end else if ((commit_cu_i.valid && commit_cu_i.stall_csr_fence) || 
                    (!miss_icache_i && !ready_icache_i) || 
                    on_halt_state                       || 
                    step_inst_in_id                     ||
                    step_inst_in_pipeline               ||
                    step_inst_in_if2                    ) begin
            pipeline_ctrl_o.stall_if_1  = 1'b1;
            pipeline_ctrl_o.stall_if_2  = 1'b0;
            pipeline_ctrl_o.stall_id  = 1'b0;
        end
    end
    
    // Logic to stall the Back End
    always_comb begin
        pipeline_ctrl_o.stall_iq  = 1'b0;
        pipeline_ctrl_o.stall_ir  = 1'b0;
        pipeline_ctrl_o.stall_rr  = 1'b0;
        pipeline_ctrl_o.stall_exe = 1'b0;
        if (csr_cu_i.csr_stall) begin
            pipeline_ctrl_o.stall_iq  = 1'b1;
            pipeline_ctrl_o.stall_ir  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b1;
            pipeline_ctrl_o.stall_exe = 1'b1;
        end else if (exe_cu_i.stall) begin
            pipeline_ctrl_o.stall_iq  = 1'b1;
            pipeline_ctrl_o.stall_ir  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b1;
            pipeline_ctrl_o.stall_exe = 1'b0;
        end else if (rr_cu_i.gl_full) begin
            pipeline_ctrl_o.stall_iq  = 1'b1;
            pipeline_ctrl_o.stall_ir  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b1;
            pipeline_ctrl_o.stall_exe = 1'b0;
        end else if (ir_cu_i.empty_free_list) begin
            pipeline_ctrl_o.stall_iq  = 1'b1;
            pipeline_ctrl_o.stall_ir  = 1'b0;
            pipeline_ctrl_o.stall_rr  = 1'b0;
            pipeline_ctrl_o.stall_exe = 1'b0;
        end else if (ir_cu_i.out_of_checkpoints) begin
            pipeline_ctrl_o.stall_iq  = 1'b1;
            pipeline_ctrl_o.stall_ir  = 1'b0;
            pipeline_ctrl_o.stall_rr  = 1'b0;
            pipeline_ctrl_o.stall_exe = 1'b0;
        end 
    end

    // Enable Update of Free List and Rename from Commit
    assign cu_ir_o.enable_commit_update = commit_cu_i.retire & commit_cu_i.regfile_we & {2{~exception_enable_d}};
    assign cu_ir_o.simd_enable_commit_update = commit_cu_i.retire & commit_cu_i.vregfile_we & {2{~exception_enable_d}};
    assign cu_ir_o.fp_enable_commit_update = commit_cu_i.retire & commit_cu_i.fregfile_we & {2{~exception_enable_d}};

    // Recover checkpoint of Commit stage in Rename and Free List
    assign cu_ir_o.recover_commit = exception_enable_q;

    // Flush the Graduation List from commit
    assign cu_commit_o.flush_gl_commit = exception_enable_q;

    // Allow committing a new instruction (works like stall)
    assign cu_commit_o.enable_commit = ~(commit_cu_i.stall_commit) & ~(exception_enable_d);

    // Stall the commit stage
    assign pipeline_ctrl_o.stall_commit = commit_cu_i.stall_commit;


    // Logic to flush gl
    always_comb begin
        if (~correct_branch_pred_wb_i & wb_cu_i.valid[0]) begin
            cu_wb_o.flush_gl = 1'b1;
            cu_wb_o.flush_gl_index = wb_cu_i.gl_index;
        end else begin
            cu_wb_o.flush_gl = 1'b0;
            cu_wb_o.flush_gl_index = 'b0;
        end
    end

    // Delay exceptions one cycle
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            exception_enable_q <= 1'b0;
            csr_enable_q <= 1'b0;
            exception_cause_q <= 'h0;
        end else begin 
            exception_enable_q <= exception_enable_d;
            csr_enable_q <= csr_enable_d;
            exception_cause_q <= exception_cause_d;
        end
    end

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if(!rstn_i) begin
            state_debug_q <= DEBUG_STATE_RESET;
            debug_progbuf_xcpt_q <= 1'b0;
        end else begin 
            state_debug_q <= state_debug_d;
            debug_progbuf_xcpt_q <= debug_progbuf_xcpt_d;
        end
    end
    
    assign pmu_jump_misspred_o = (id_cu_i.valid && !id_cu_i.is_branch && id_cu_i.predicted_as_branch) || ~correct_branch_pred_wb_i;

endmodule
