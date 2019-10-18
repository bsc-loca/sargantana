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
    // icache interface naming could be improved
    input icache_req_out_t  icache_req_receive_i,
    output icache_req_in_t  icache_req_send_o
);

    // Stages: if -- id -- rr -- ex -- wb
    // Signals stalls to be coming from the control unit
    logic stall_if_int;
    logic stall_id_int;
    logic stall_rr_int;
    assign stall_if_int = '0;
    assign stall_id_int = '0;
    assign stall_rr_int = '0;

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

endmodule