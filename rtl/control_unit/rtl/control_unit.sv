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
    input                   clk_i,
    input                   rstn_i,

    input logic             valid_fetch,
    //input if_cu_t           if_cu_i,
    input id_cu_t           id_cu_i,
    input rr_cu_t           rr_cu_i,
    input exe_cu_t          exe_cu_i,
    input wb_cu_t           wb_cu_i,
    input resp_csr_cpu_t    csr_cu_i,

    output pipeline_ctrl_t  pipeline_ctrl_o,
    output cu_if_t          cu_if_o,
    //output cu_id_t          cu_id_o,
    output cu_rr_t          cu_rr_o
    //output cu_exe_t         cu_exe_o,
    //output cu_wb_t          cu_wb_o,

    //output cu_datapath_t    cu_datapath_t

);
    logic jump_enable_int;
    // jump enable logic
    // TODO add exceptions and csr
    always_comb begin
        jump_enable_int =   (wb_cu_i.valid && wb_cu_i.xcpt) ||
                            // branch at commit
                            (wb_cu_i.valid && wb_cu_i.change_pc_ena && wb_cu_i.branch_taken) || 
                            // valid jal
                            id_cu_i.valid_jal ||
                            // jump to evec when eret
                            csr_cu_i.csr_eret ||
                            // jump to evec when xcpt from csr
                            csr_cu_i.csr_exception ||
                            // jump to evec when ecall
                            (wb_cu_i.valid && wb_cu_i.ecall_taken);
    end

    // logic enable write register file at commit
    always_comb begin
        if (wb_cu_i.valid &&
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
    // TODO: Branch Predictor
    always_comb begin
        // branches or valid jal
        if (jump_enable_int) begin
            cu_if_o.next_pc = NEXT_PC_SEL_JUMP;
        end else if (!valid_fetch || 
                     pipeline_ctrl_o.stall_if || 
                     id_cu_i.stall_csr_fence  || 
                     rr_cu_i.stall_csr_fence  || 
                     exe_cu_i.stall_csr_fence || 
                     (wb_cu_i.valid && wb_cu_i.fence) )  begin
            cu_if_o.next_pc = NEXT_PC_SEL_PC;
        end else begin
            cu_if_o.next_pc = NEXT_PC_SEL_PC_4;
        end
    end

    // logic select which pc to use in fetch
    always_comb begin
        // if exception or eret select from csr
        if (wb_cu_i.xcpt & wb_cu_i.valid || csr_cu_i.csr_eret || csr_cu_i.csr_exception ||
                     (wb_cu_i.valid && wb_cu_i.ecall_taken)) begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_CSR;
        end else if (wb_cu_i.branch_taken & wb_cu_i.valid) begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_COMMIT;
        end else begin
            pipeline_ctrl_o.sel_addr_if = SEL_JUMP_DECODE;
        end
    end


    // logic about flush the pipeline if branch
    always_comb begin
        // if exception
        if ((wb_cu_i.xcpt & wb_cu_i.valid) ||
                     (wb_cu_i.branch_taken & wb_cu_i.valid) || 
                     (csr_cu_i.csr_eret) ||
                     (csr_cu_i.csr_exception) ||
                     (wb_cu_i.valid && wb_cu_i.ecall_taken)) begin
            pipeline_ctrl_o.flush_if  = 1'b1;
            pipeline_ctrl_o.flush_id  = 1'b1;
            pipeline_ctrl_o.flush_rr  = 1'b1;
            pipeline_ctrl_o.flush_exe = 1'b1;
            pipeline_ctrl_o.flush_wb  = 1'b0;
        end else if (id_cu_i.stall_csr_fence | 
                     rr_cu_i.stall_csr_fence | 
                     exe_cu_i.stall_csr_fence |
                     exe_cu_i.stall_csr_fence ) begin
            pipeline_ctrl_o.flush_if  = 1'b1;
            pipeline_ctrl_o.flush_id  = 1'b0;
            pipeline_ctrl_o.flush_rr  = 1'b0;
            pipeline_ctrl_o.flush_exe = 1'b0;
            pipeline_ctrl_o.flush_wb  = 1'b0;
        end else if (id_cu_i.valid_jal ||
                    (wb_cu_i.valid && wb_cu_i.fence)) begin
            pipeline_ctrl_o.flush_if  = 1'b1;
            pipeline_ctrl_o.flush_id  = 1'b0;
            pipeline_ctrl_o.flush_rr  = 1'b0;
            pipeline_ctrl_o.flush_exe = 1'b0;
            pipeline_ctrl_o.flush_wb  = 1'b0;
        end else begin
            pipeline_ctrl_o.flush_if  = 1'b0;
            pipeline_ctrl_o.flush_id  = 1'b0;
            pipeline_ctrl_o.flush_rr  = 1'b0;
            pipeline_ctrl_o.flush_exe = 1'b0;
            pipeline_ctrl_o.flush_wb  = 1'b0;
        end
    end


    // logic stalls
    always_comb begin
        // TODO: check if this works guillemlp
        if (csr_cu_i.csr_stall || exe_cu_i.stall) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b1;
            pipeline_ctrl_o.stall_exe = 1'b1;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end /*else if (exe_cu_i.stall_csr_fence) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b1;
            pipeline_ctrl_o.stall_exe = 1'b0;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end /*else if (rr_cu_i.stall_csr_fence) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b1;
            pipeline_ctrl_o.stall_rr  = 1'b0;
            pipeline_ctrl_o.stall_exe = 1'b0;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end else if (id_cu_i.stall_csr_fence) begin
            pipeline_ctrl_o.stall_if  = 1'b1;
            pipeline_ctrl_o.stall_id  = 1'b0;
            pipeline_ctrl_o.stall_rr  = 1'b0;
            pipeline_ctrl_o.stall_exe = 1'b0;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end */else begin
            pipeline_ctrl_o.stall_if  = 1'b0;
            pipeline_ctrl_o.stall_id  = 1'b0;
            pipeline_ctrl_o.stall_rr  = 1'b0;
            pipeline_ctrl_o.stall_exe = 1'b0;
            pipeline_ctrl_o.stall_wb  = 1'b0;
        end
        
    end

endmodule
