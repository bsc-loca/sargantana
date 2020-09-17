/* -----------------------------------------------
* Project Name   : DRAC
* File           : control_unit.sv
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

module control_unit(
    input logic             valid_fetch,
    input id_cu_t           id_cu_i,
    input rr_cu_t           rr_cu_i,
    input exe_cu_t          exe_cu_i,
    input wb_cu_t           wb_cu_i,
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
    output cu_rr_t          cu_rr_o
);
    logic jump_enable_int;
    // jump enable logic
    always_comb begin
        jump_enable_int =   (wb_cu_i.valid && wb_cu_i.xcpt) ||
                            // branch at exe
                            (exe_cu_i.valid && ~correct_branch_pred_i) || 
                            // valid jal
                            id_cu_i.valid_jal ||
                            // jump to evec when eret
                            csr_cu_i.csr_eret ||
                            // jump to evec when xcpt from csr
                            csr_cu_i.csr_exception ||
                            // jump to evec when ecall
                            (wb_cu_i.valid && wb_cu_i.ecall_taken);
                            // we can add here the debug jump also
    end

    // logic enable write register file at commit
    always_comb begin
        // we don't allow regular reads/writes if not halted
        if (debug_wr_valid_i && debug_halt_i) begin
            cu_rr_o.write_enable = 1'b1;
        end else if (wb_cu_i.valid &&
           !wb_cu_i.xcpt &&
           !csr_cu_i.csr_exception &&
            wb_cu_i.write_enable) 
        begin
            cu_rr_o.write_enable = 1'b1;
        end else begin
            cu_rr_o.write_enable = 1'b0;
        end
    end
    // logic to select the next pc
    always_comb begin
        // branches or valid jal
        if (debug_change_pc_i && debug_halt_i) begin
            cu_if_o.next_pc = NEXT_PC_SEL_DEBUG;
        end else if (jump_enable_int) begin
            cu_if_o.next_pc = NEXT_PC_SEL_JUMP;
        end else if (!valid_fetch || 
                     pipeline_ctrl_o.stall_if || 
                     id_cu_i.stall_csr_fence  || 
                     rr_cu_i.stall_csr_fence  || 
                     exe_cu_i.stall_csr_fence || 
                     (wb_cu_i.valid && wb_cu_i.fence))  begin
            cu_if_o.next_pc = NEXT_PC_SEL_KEEP_PC;
        end else begin
            cu_if_o.next_pc = NEXT_PC_SEL_BP_OR_PC_4;
        end
    end

    // logic select which pc to use in fetch
    always_comb begin
        // if exception or eret select from csr
        if (wb_cu_i.xcpt & wb_cu_i.valid || csr_cu_i.csr_eret || csr_cu_i.csr_exception ||
                     (wb_cu_i.valid && wb_cu_i.ecall_taken)) begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_CSR;
        end else if (exe_cu_i.valid && ~correct_branch_pred_i) begin
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
    assign invalidate_icache_o = (wb_cu_i.valid && wb_cu_i.fence);
    // logic invalidate buffer and repeat fetch
    // when a fence, invalidate buffer and also when csr eret
    // when it is a csr it should be checked more?
    assign invalidate_buffer_o = (wb_cu_i.valid && (wb_cu_i.fence | 
                                                    csr_cu_i.csr_eret));


    // logic about flush the pipeline if branch
    always_comb begin
        // if exception
        pipeline_flush_o.flush_if  = 1'b0;
        pipeline_flush_o.flush_id  = 1'b0;
        pipeline_flush_o.flush_rr  = 1'b0;
        pipeline_flush_o.flush_exe = 1'b0;
        pipeline_flush_o.flush_wb  = 1'b0;
        if ((wb_cu_i.xcpt & wb_cu_i.valid) ||
                     (csr_cu_i.csr_eret) ||
                     (csr_cu_i.csr_exception) ||
                     (wb_cu_i.valid && wb_cu_i.ecall_taken)) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b1;
            pipeline_flush_o.flush_rr  = 1'b1;
            pipeline_flush_o.flush_exe = 1'b1;
            pipeline_flush_o.flush_wb  = 1'b0;
        end else if (exe_cu_i.valid & ~correct_branch_pred_i) begin
            if (exe_cu_i.stall) begin
                pipeline_flush_o.flush_if  = 1'b1;
                pipeline_flush_o.flush_id  = 1'b1;
                pipeline_flush_o.flush_rr  = 1'b0;
                pipeline_flush_o.flush_exe = 1'b0;
                pipeline_flush_o.flush_wb  = 1'b0;
            end else begin
                pipeline_flush_o.flush_if  = 1'b1;
                pipeline_flush_o.flush_id  = 1'b1;
                pipeline_flush_o.flush_rr  = 1'b1;
                pipeline_flush_o.flush_exe = 1'b0;
                pipeline_flush_o.flush_wb  = 1'b0;
            end
        end else if ((id_cu_i.stall_csr_fence | 
                     rr_cu_i.stall_csr_fence | 
                     exe_cu_i.stall_csr_fence )  && !(csr_cu_i.csr_stall || exe_cu_i.stall)) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b0;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
            pipeline_flush_o.flush_wb  = 1'b0;
        end else if ((id_cu_i.valid_jal ||
                    (wb_cu_i.valid && wb_cu_i.fence)) && !(csr_cu_i.csr_stall || exe_cu_i.stall)) begin
            pipeline_flush_o.flush_if  = 1'b1;
            pipeline_flush_o.flush_id  = 1'b0;
            pipeline_flush_o.flush_rr  = 1'b0;
            pipeline_flush_o.flush_exe = 1'b0;
            pipeline_flush_o.flush_wb  = 1'b0;
        end 
    end


    // logic about stall the pipeline if branch
    always_comb begin
        // if exception
        pipeline_ctrl_o.stall_if  = 1'b0;
        pipeline_ctrl_o.stall_id  = 1'b0;
        pipeline_ctrl_o.stall_rr  = 1'b0;
        pipeline_ctrl_o.stall_exe = 1'b0;
        pipeline_ctrl_o.stall_wb  = 1'b0;
        if (csr_cu_i.csr_stall || exe_cu_i.stall) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b1;
            pipeline_ctrl_o.stall_exe = 1'b1;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end
        /*else if (debug_halt_i) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b0;
            pipeline_ctrl_o.stall_rr  = 1'b0;
            pipeline_ctrl_o.stall_exe = 1'b0;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end*/
    end
endmodule
