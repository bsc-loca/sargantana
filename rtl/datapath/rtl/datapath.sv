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
    // icache interface naming could be improved
    input icache_req_out_t  icache_req_receive_i,
    output icache_req_in_t  icache_req_send_o,

    // dcache interface for execution
    input logic     dmem_resp_replay_i,
    input bus64_t   dmem_resp_data_i,
    input logic     dmem_req_ready_i,
    input logic     dmem_resp_valid_i,
    input logic     dmem_resp_nack_i,
    input logic     dmem_xcpt_ma_st_i,
    input logic     dmem_xcpt_ma_ld_i,
    input logic     dmem_xcpt_pf_st_i,
    input logic     dmem_xcpt_pf_ld_i,
    output logic        dmem_req_valid_o,
    output logic [4:0]  dmem_req_cmd_o,
    output addr_t       dmem_req_addr_o,
    output bus64_t      dmem_op_type_o,
    output bus64_t      dmem_req_data_o,
    output logic [7:0]  dmem_req_tag_o,
    output logic        dmem_req_invalidate_lr_o,
    output logic        dmem_req_kill_o,
    output logic        dmem_lock_o

);

    // Stages: if -- id -- rr -- ex -- wb
    // Signals stalls to be coming from the control unit
    logic stall_if_int;
    logic stall_id_int;
    logic stall_rr_int;
    logic stall_exe_int;
    assign stall_if_int = '0;
    assign stall_id_int = '0;
    assign stall_rr_int = '0;
    assign stall_exe_int = '0;

    // TODO: Remove Stage IF stub
    next_pc_sel_t next_pc_sel_if_int;
    addr_t pc_commit_if_int;

    assign pc_commit_if_int = '0;
    assign next_pc_sel_if_int = NEXT_PC_SEL_PC_4;
    // Pipelines stages data
    // Fetch
    if_id_stage_t stage_if_id_d; // this is the saving in the current cycle
    if_id_stage_t stage_if_id_q; // this is the next or output of reg
    // Decode
    instr_entry_t stage_id_rr_d;
    instr_entry_t stage_id_rr_q;

    logic stall_exe_out;
    exe_wb_instr_t exe_to_wb_exe;
    exe_wb_instr_t exe_to_wb_wb;
    dec_wb_instr_t dec_to_wb_exe;
    dec_wb_instr_t dec_to_wb_wb

    dec_exe_instr_t dec_to_exe_exe;
    rr_exe_instr_t rr_to_exe_exe;
    wb_exe_instr_t wb_to_exe_exe;

    reg_addr_t io_base_addr;

    always@(posedge clk)
    begin
    if(~soft_rstn_i)
        io_base_addr <=  40'h0080000000;
    else if(~rstn_i)
            io_base_addr <=  40'h0040000000;
        else
            io_base_addr <= io_base_addr;
    end

    // Instruction Fetch Stage
    if_stage if_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .stall_i(stall_if_int),
        .next_pc_sel_i(next_pc_sel_if_int),
        .pc_commit_i(pc_commit_if_int),
        .icache_req_receive_i(icache_req_receive_i),
        .icache_req_send_o(icache_req_send_o),
        .fetch_o(stage_if_id_d)
    );

    register #($bits(if_id_stage_t)) reg_if_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .load_i(!stall_if_int),
        .input_i(stage_if_id_d),
        .output_o(stage_if_id_q)
    );

    decoder id_decode_inst(
        .decode_i(stage_if_id_q),
        .decode_instr_o(stage_id_rr_d)
    );

    register #($bits(instr_entry_t)) reg_id_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .load_i(!stall_id_int),
        .input_i(stage_id_rr_d),
        .output_o(stage_id_rr_q)
    );

    /*read_reg read_reg(
    );

    register reg_rr(
    );*/

    exe_top exe_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .from_dec_i(dec_to_exe_exe),
        .from_rr_i(rr_to_exe_exe),
        .from_wb_i(wb_to_exe_exe),

        .io_base_addr_i(io_base_addr),
        .dmem_resp_replay_i(dmem_resp_replay_i),
        .dmem_resp_data_i(dmem_resp_data_i),
        .dmem_req_ready_i(dmem_req_ready_i),
        .dmem_resp_valid_i(dmem_resp_valid_i),
        .dmem_resp_nack_i(dmem_resp_nack_i),
        .dmem_xcpt_ma_st_i(dmem_xcpt_ma_st_i),
        .dmem_xcpt_ma_ld_i(dmem_xcpt_ma_ld_i),
        .dmem_xcpt_pf_st_i(dmem_xcpt_pf_st_i),
        .dmem_xcpt_pf_ld_i(dmem_xcpt_pf_ld_i),

        .to_wb_o(exe_to_wb_exe),
        .stall_o(stall_exe_out),

        .dmem_req_valid_o   (dmem_req_valid_o),
        .dmem_req_cmd_o     (dmem_req_cmd_o),
        .dmem_req_addr_o    (dmem_req_addr_o),
        .dmem_op_type_o     (dmem_op_type_o),
        .dmem_req_data_o    (dmem_req_data_o),
        .dmem_req_tag_o     (dmem_req_tag_o),
        .dmem_req_invalidate_lr_o(dmem_req_invalidate_lr_o),
        .dmem_req_kill_o(dmem_req_kill_o),
        .dmem_lock_o(dmem_lock_o)
    );

    register #($bits(dec_wb_instr_t)+$bits(exe_wb_instr_t)) reg_exe_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .load_i(!stall_exe_int),
        .input_i({dec_to_wb_exe,exe_to_wb_exe}),
        .output_o({dec_to_wb_wb,exe_to_wb_wb})
    );

endmodule
