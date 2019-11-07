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
//`default_nettype none
import drac_pkg::*;



module exe_top (
    input logic         clk_i,
    input logic         rstn_i,
    input logic         kill_i,
    input logic         csr_eret_i,

    // INPUTS
    input rr_exe_instr_t    from_rr_i,
    input wb_exe_instr_t    from_wb_i,

    // Response from cache
    input addr_t   io_base_addr_i,

    input logic     dmem_resp_replay_i,
    input bus64_t   dmem_resp_data_i,
    input logic     dmem_req_ready_i,
    input logic     dmem_resp_valid_i,
    input logic     dmem_resp_nack_i,
    input logic     dmem_xcpt_ma_st_i,
    input logic     dmem_xcpt_ma_ld_i,
    input logic     dmem_xcpt_pf_st_i,
    input logic     dmem_xcpt_pf_ld_i,

    // OUTPUTS
    output exe_wb_instr_t to_wb_o,
    output logic stall_o,

    // Request to cache
    output logic        dmem_req_valid_o,
    output logic [4:0]  dmem_req_cmd_o,
    output addr_t       dmem_req_addr_o,
    output bus64_t      dmem_op_type_o,
    output bus64_t      dmem_req_data_o,
    output logic [7:0]  dmem_req_tag_o,
    output logic        dmem_req_invalidate_lr_o,
    output logic        dmem_req_kill_o,

    output logic        dmem_lock_o // TODO connect
);

// Declarations
bus64_t rs1_data_bypass;
bus64_t rs2_data_bypass;
bus64_t rs2_data_def;

bus64_t result_alu;
bus64_t result_mul;
logic stall_mul;
logic ready_mul;
bus64_t result_div;
bus64_t result_rmd;
logic stall_div;
logic ready_div;

logic taken_branch;
addrPC_t target_branch;
addrPC_t result_branch;
bus64_t reg_data_branch;

logic ready_mem;
bus64_t result_mem;
logic stall_mem;

// Bypasses
`ifdef ASSERTIONS
    always @(posedge clk_i) begin
        if(from_rr_i.instr.rs1 == 0)
            assert rs1_data_bypass==0;
        if(from_rr_i.instr.rs2 == 0)
            assert rs2_data_bypass==0;
    end
`endif

assign rs1_data_bypass = ((from_rr_i.instr.rs1 != 0) & (from_rr_i.instr.rs1 == from_wb_i.rd) & from_wb_i.valid) ? from_wb_i.data : from_rr_i.data_rs1;
assign rs2_data_bypass = ((from_rr_i.instr.rs2 != 0) & (from_rr_i.instr.rs2 == from_wb_i.rd) & from_wb_i.valid) ? from_wb_i.data : from_rr_i.data_rs2;

// Select rs2 from imm to avoid bypasses
assign rs2_data_def = from_rr_i.instr.use_imm ? from_rr_i.instr.imm : rs2_data_bypass;

alu alu_inst (
    .data_rs1_i     (rs1_data_bypass),
    .data_rs2_i     (rs2_data_def),
    .instr_type_i   (from_rr_i.instr.instr_type),
    .result_o       (result_alu)
);

mul_unit mul_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_mul_i     (kill_i),
    .request_i      (from_rr_i.instr.unit == UNIT_MUL),
    .func3_i        (from_rr_i.instr.funct3),
    .int_32_i       (from_rr_i.instr.op_32),
    .src1_i         (rs1_data_bypass),
    .src2_i         (rs2_data_bypass),

    .result_o       (result_mul),
    .stall_o        (stall_mul),
    .done_tick_o    (ready_mul)
);

div_unit div_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_div_i     (kill_i),
    .request_i      (from_rr_i.instr.unit == UNIT_DIV),
    .int_32_i       (from_rr_i.instr.op_32),
    .signed_op_i    (from_rr_i.instr.signed_op),
    .dvnd_i         (rs1_data_bypass),
    .dvsr_i         (rs2_data_def),

    .quo_o          (result_div),
    .rmd_o          (result_rmd),
    .stall_o        (stall_div),
    .done_tick_o    (ready_div)
);

branch_unit branch_unit_inst (
    .instr_type_i       (from_rr_i.instr.instr_type),
    .pc_i               (from_rr_i.instr.pc),
    .data_rs1_i         (rs1_data_bypass),
    .data_rs2_i         (rs2_data_bypass),
    .imm_i              (from_rr_i.instr.imm),

    .taken_o            (taken_branch),
    .target_o           (target_branch),
    .result_o           (result_branch),
    .reg_data_o         (reg_data_branch)
);

mem_unit mem_unit_inst (
//TODO: This module need work... a lot of signals connected to get rid of
//errors
.clk_i                          (clk_i),
    .rstn_i                         (rstn_i),

//    .valid_i                        (from_rr_i.instr.unit == UNIT_MEM),
//    .kill_i                         (kill_i),
    .csr_eret_i                     (csr_eret_i),
//    .data_rs1_i                     (rs1_data_bypass),
//    .data_rs2_i                     (rs2_data_bypass),
//    .instr_type_i                   (from_rr_i.instr.instr_type),
//    .mem_op_i                       (from_rr_i.instr.mem_op),
//   .funct3_i                       (from_rr_i.instr.funct3),
//    .rd_i                           (from_rr_i.instr.rd),
//    .imm_i                          (from_rr_i.instr.imm),

    .io_base_addr_i                 (io_base_addr_i),

    // dcache answer
//    .dmem_resp_replay_i             (dmem_resp_replay_i),
//    .dmem_resp_data_i               (dmem_resp_data_i),
    .dmem_req_ready_i               (dmem_req_ready_i),
    .dmem_resp_valid_i              (dmem_resp_valid_i),
//    .dmem_resp_nack_i               (dmem_resp_nack_i),
    .dmem_xcpt_ma_st_i              (dmem_xcpt_ma_st_i),
    .dmem_xcpt_ma_ld_i              (dmem_xcpt_ma_ld_i),
    .dmem_xcpt_pf_st_i              (dmem_xcpt_pf_st_i),
    .dmem_xcpt_pf_ld_i              (dmem_xcpt_pf_ld_i),

    // request to dcache
//    .dmem_req_valid_o               (dmem_req_valid_o),
//    .dmem_op_type_o                 (dmem_op_type_o),
//    .dmem_req_cmd_o                 (dmem_req_cmd_o),
//    .dmem_req_data_o                (dmem_req_data_o),
//    .dmem_req_addr_o                (dmem_req_addr_o),
//    .dmem_req_tag_o                 (dmem_req_tag_o),
//    .dmem_req_invalidate_lr_o       (dmem_req_invalidate_lr_o),
//    .dmem_req_kill_o                (dmem_req_kill_o),

    // output to wb
//TODO:figureout why they are missign
//    .ready_o                        (ready_mem),
//    .data_o                         (result_mem),
    .lock_o                         (stall_mem)
);

//------------------------------------------------------------------------------
// DATA  TO WRITE_BACK
//------------------------------------------------------------------------------

always_comb begin
    to_wb_o.branch_taken = 1'b0;
    case(from_rr_i.instr.unit)
        UNIT_ALU: begin
            to_wb_o.result_rd = result_alu;
            to_wb_o.result_pc = 0;

        end
        UNIT_MUL: begin
            to_wb_o.result_rd = result_mul;
            to_wb_o.result_pc = 0;
        end
        UNIT_DIV: begin
            to_wb_o.result_rd = result_div;
            to_wb_o.result_pc = 0;
        end
        UNIT_BRANCH: begin
            to_wb_o.result_rd = reg_data_branch;
            to_wb_o.result_pc = result_branch;
            to_wb_o.branch_taken = taken_branch;
        end
        UNIT_MEM: begin
            to_wb_o.result_rd = result_mem;
            to_wb_o.result_pc = 0;
        end
        default: begin
            to_wb_o.result_rd = 0;
            to_wb_o.result_pc = 0;
        end
    endcase
end

assign to_wb_o.rd = from_rr_i.instr.rd;
assign stall_o = (from_rr_i.instr.unit == UNIT_MUL) ? stall_mul :
                 (from_rr_i.instr.unit == UNIT_DIV) ? stall_div :
                 (from_rr_i.instr.unit == UNIT_MEM) ? stall_mem :
                 0;

endmodule

