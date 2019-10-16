//`default_nettype none
import drac_pkg::*;

/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : execution.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */


module exe_top (
    input wire         clk_i,
    input wire         rstn_i,

    // INPUTS
    input dec_exe_instr_t   from_dec_i,
    input rr_exe_instr_t    from_rr_i,
    input wb_exe_instr_t    from_wb_i,

    // Response from cache
    input addr_t   io_base_addr_i,

    input wire     dmem_resp_replay_i,
    input bus64_t  dmem_resp_data_i,
    input wire     dmem_req_ready_i,
    input wire     dmem_resp_valid_i,
    input wire     dmem_resp_nack_i,
    input wire     dmem_xcpt_ma_st_i,
    input wire     dmem_xcpt_ma_ld_i,
    input wire     dmem_xcpt_pf_st_i,
    input wire     dmem_xcpt_pf_ld_i,

    // OUTPUTS
    input exe_wb_instr_t to_wb_o,

    // Request to cache
    output wire         dmem_req_valid_o,
    output bus64_t      dmem_op_type_o,
    output wire         dmem_req_cmd_o,
    output bus64_t      dmem_req_data_o,
    output addr_t       dmem_req_addr_o,
    output wire [7:0]   dmem_req_tag_o,
    output wire         dmem_req_invalidate_lr_o,
    output wire         dmem_req_kill_o,
    output wire         dmem_lock_o
);

// Declarations
bus64_t rs1_data_bypass;
bus64_t rs2_data_bypass;
bus64_t rs2_data_def;

bus64_t stall_alu;
bus64_t result_alu;

logic taken_branch;
addr_t target_branch;
addr_t result_branch;
bus64_t reg_data_branch;

logic ready_mem;
bus64_t result_mem;
bus64_t stall_mem;

// Bypasses
assign rs1_data_bypass = ((from_rr_i.rs1 == from_wb_i.rd) & from_wb_i.valid) ? from_wb_i.data : from_rr_i.data_rs1;
assign rs2_data_bypass = ((from_rr_i.rs2 == from_wb_i.rd) & from_wb_i.valid) ? from_wb_i.data : from_rr_i.data_rs2;

// Select src2 from imm to avoid bypasses
assign src2_data_def = from_dec_i.use_imm ? from_dec_i.imm : rs2_data_bypass;

integer_unit integer_unit_inst (
    .data_rs1_i     (src1_data_bypass),
    .data_rs2_i     (src2_data_def),
    .alu_op_i       (from_dec_i.alu_op),

    .result_o       (result_alu),
    .stall_o        (stall_alu)
);

branch_unit branch_unit_inst (
    .ctrl_xfer_op_i     (from_dec_i.ctrl_xfer_op),
    .branch_op_i        (from_dec_i.branch_op),
    .pc_i               (from_dec_i.pc),
    .data_rs1_i         (rs1_data_bypass),
    .data_rs2_i         (rs2_data_bypass),
    .imm_i              (from_dec_i.imm),

    .taken_o            (taken_branch),
    .target_o           (target_branch),
    .result_o           (result_branch),
    .reg_data_o         (reg_data_branch)
);

mem_unit mem_unit_inst (
    .clk_i                          (clk_i),
    .rstn_i                         (rstn_i),

    .valid_i                        (from_dec_i.functional_unit == UNIT_MEM),
    .kill_i                         (kill_i),
    .csr_eret_i                     (csr_eret_i),
    .data_rs1_i                     (rs1_data_bypass),
    .data_rs2_i                     (rs2_data_bypass),
    .mem_op_i                       (from_dec_i.mem_op),
    .mem_format_i                   (from_dec_i.mem_format),
    .amo_op_i                       (from_dec_i.amo_op),
    .funct3_i                       (from_dec_i.funct3),
    .rd_i                           (from_dec_i.rd),
    .imm_i                          (from_dec_i.imm),

    .io_base_addr_i                 (io_base_addr_i),

    // dcache answer
    .dmem_resp_replay_i             (dmem_resp_replay_i),
    .dmem_resp_data_i               (dmem_resp_data_i),
    .dmem_req_ready_i               (dmem_req_ready_i),
    .dmem_resp_valid_i              (dmem_resp_valid_i),
    .dmem_resp_nack_i               (dmem_resp_nack_i),
    .dmem_xcpt_ma_st_i              (dmem_xcpt_ma_st_i),
    .dmem_xcpt_ma_ld_i              (dmem_xcpt_ma_ld_i),
    .dmem_xcpt_pf_st_i              (dmem_xcpt_pf_st_i),
    .dmem_xcpt_pf_ld_i              (dmem_xcpt_pf_ld_i),

    // request to dcache
    .dmem_req_valid_o               (dmem_req_valid_o),
    .dmem_op_type_o                 (dmem_op_type_o),
    .dmem_req_cmd_o                 (dmem_req_cmd_o),
    .dmem_req_data_o                (dmem_req_data_o),
    .dmem_req_addr_o                (dmem_req_addr_o),
    .dmem_req_tag_o                 (dmem_req_tag_o),
    .dmem_req_invalidate_lr_o       (dmem_req_invalidate_lr_o),
    .dmem_req_kill_o                (dmem_req_kill_o),

    // output to wb
    .ready_o                        (ready_mem),
    .data_o                         (result_mem),
    .lock_o                         (stall_mem)
);

//------------------------------------------------------------------------------
// DATA  TO WRITE_BACK
//------------------------------------------------------------------------------

//assign to_wb_o.rd = from_dec_i.rd;

always_comb begin
    case(from_dec_i.functional_unit)
        UNIT_ALU: begin
            to_wb_o.rd = from_dec_i.rd;
            to_wb_o.result_rd = result_alu;
            to_wb_o.result_pc = 0;
        end
        UNIT_BRANCH: begin
            to_wb_o.rd = from_dec_i.rd;
            to_wb_o.result_rd = reg_data_branch;
            to_wb_o.result_pc = result_branch;
        end
        UNIT_MEM: begin
            to_wb_o.rd = from_dec_i.rd;
            to_wb_o.result_rd = result_mem;
            to_wb_o.result_pc = 0;
        end
        default: begin
            to_wb_o.rd = 0;
            to_wb_o.result_rd = 0;
            to_wb_o.result_pc = 0;
        end
    endcase
end

endmodule

