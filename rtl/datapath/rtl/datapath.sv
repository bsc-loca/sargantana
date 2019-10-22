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
    // icache/dcache interface
    // naming could be improved
    input req_icache_cpu_t  req_icache_cpu_i,
    input req_dcache_cpu_t  req_dcache_cpu_i,

    output req_cpu_dcache_t req_cpu_dcache_o, 
    output req_cpu_icache_t req_cpu_icache_o

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
    // RR
    rr_exe_instr_t stage_rr_exe_d;
    rr_exe_instr_t stage_rr_exe_q;
    // EXE
    exe_wb_instr_t stage_exe_wb_d;
    exe_wb_instr_t stage_exe_wb_q;
    // WB->Commit
    exe_wb_instr_t stage_commit;


    // Exe
    logic stall_exe_out;
    exe_wb_instr_t exe_to_wb_exe;
    exe_wb_instr_t exe_to_wb_wb;
    // this can be inserted to rr_exe
    dec_wb_instr_t dec_to_wb_exe;
    dec_wb_instr_t dec_to_wb_wb;

    dec_exe_instr_t dec_to_exe_exe;
    rr_exe_instr_t rr_to_exe_exe;
    wb_exe_instr_t wb_to_exe_exe;

    reg_addr_t io_base_addr;


    // What is this????
    // TODO: Ruben
    always_ff @(posedge clk_i, negedge rstn_i) begin
        // What is that?????
        //if(~soft_rstn_i)
        if(!soft_rstn_i) begin
            io_base_addr <=  40'h0080000000;
        end else if(~rstn_i) begin
            io_base_addr <=  40'h0040000000;
        end else begin 
            io_base_addr <= io_base_addr;
        end
    end

    // IF Stage
    if_stage if_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .stall_i(stall_if_int),
        .next_pc_sel_i(next_pc_sel_if_int),
        .pc_commit_i(pc_commit_if_int),
        .req_icache_cpu_i(req_icache_cpu_i),
        .req_cpu_icache_o(req_cpu_icache_o),
        .fetch_o(stage_if_id_d)
    );

    // Register IF to ID
    register #($bits(if_id_stage_t)) reg_if_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .load_i(!stall_if_int),
        .input_i(stage_if_id_d),
        .output_o(stage_if_id_q)
    );

    // ID Stage
    decoder id_decode_inst(
        .decode_i(stage_if_id_q),
        .decode_instr_o(stage_id_rr_d)
    );

    // Register ID to RR
    register #($bits(instr_entry_t)) reg_id_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .load_i(!stall_id_int),
        .input_i(stage_id_rr_d),
        .output_o(stage_id_rr_q)
    );

    // RR Stage
    regfile rr_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .write_enable_i(dec_to_wb_wb.regfile_we),
        .write_addr_i(exe_to_wb_wb.rd),
        .write_data_i(exe_to_wb_wb.result_rd),
        .read_addr1_i(stage_id_rr_q.rs1),
        .read_addr2_i(stage_id_rr_q.rs2),
        .read_data1_o(stage_rr_exe_d.data_rs1),
        .read_data2_o(stage_rr_exe_d.data_rs2)
    );

    assign stage_rr_exe_d.rs1 = stage_id_rr_q.rs1;
    assign stage_rr_exe_d.rs2 = stage_id_rr_q.rs2;
    assign stage_rr_exe_d.instr = stage_id_rr_q;

    // Register RR to EXE
    register #($bits(stage_rr_exe_d)) reg_rr_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .load_i(!stall_rr_int),
        .input_i(stage_rr_exe_d),
        .output_o(stage_rr_exe_q)
    );

    // Workaround
    // This can be definetaly be thought again
    // TODO: Guillem and Ruben fix this mess
    assign dec_to_exe_exe.functional_unit   = stage_rr_exe_q.instr.unit;
    assign dec_to_exe_exe.int_32            = stage_rr_exe_q.instr.op_32;
    assign dec_to_exe_exe.alu_op            = stage_rr_exe_q.instr.alu_op;
    assign dec_to_exe_exe.mul_op            = ALU_REMU;//stage_rr_exe_q.instr.mul_op;
    assign dec_to_exe_exe.use_imm           = stage_rr_exe_q.instr.use_imm;
    assign dec_to_exe_exe.imm               = stage_rr_exe_q.instr.result;
    assign dec_to_exe_exe.ctrl_xfer_op      = CT_JAL;//stage_rr_exe_q.instr.;
    assign dec_to_exe_exe.branch_op         = B_NE;//stage_rr_exe_q.instr;
    assign dec_to_exe_exe.pc                = stage_rr_exe_q.instr.pc;
    assign dec_to_exe_exe.mem_op            = MEM_LOAD;//stage_rr_exe_q.instr.
    assign dec_to_exe_exe.funct3            = STORE_SH;//stage_rr_exe_q.instr.;
    assign dec_to_exe_exe.mem_format        = BYTE;//stage_rr_exe_q.instr.;
    assign dec_to_exe_exe.amo_op            = AMO_SC;//stage_rr_exe_q.instr.;
    assign dec_to_exe_exe.rd                = stage_rr_exe_q.instr.rd;

    assign dec_to_wb_exe.regfile_we    = stage_rr_exe_q.instr.regfile_we;
    assign dec_to_wb_exe.change_pc_ena = stage_rr_exe_q.instr.change_pc_ena;


    exe_top exe_stage_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .from_dec_i(dec_to_exe_exe),
        .from_rr_i(stage_rr_exe_q),
        .from_wb_i(wb_to_exe_exe),

        .io_base_addr_i(io_base_addr),
        .dmem_resp_replay_i(req_dcache_cpu_i.dmem_resp_replay_i),
        .dmem_resp_data_i(req_dcache_cpu_i.dmem_resp_data_i),
        .dmem_req_ready_i(req_dcache_cpu_i.dmem_req_ready_i),
        .dmem_resp_valid_i(req_dcache_cpu_i.dmem_resp_valid_i),
        .dmem_resp_nack_i(req_dcache_cpu_i.dmem_resp_nack_i),
        .dmem_xcpt_ma_st_i(req_dcache_cpu_i.dmem_xcpt_ma_st_i),
        .dmem_xcpt_ma_ld_i(req_dcache_cpu_i.dmem_xcpt_ma_ld_i),
        .dmem_xcpt_pf_st_i(req_dcache_cpu_i.dmem_xcpt_pf_st_i),
        .dmem_xcpt_pf_ld_i(req_dcache_cpu_i.dmem_xcpt_pf_ld_i),

        .to_wb_o(exe_to_wb_exe),
        .stall_o(stall_exe_out),

        .dmem_req_valid_o   (req_cpu_dcache_o.dmem_req_valid_o),
        .dmem_req_cmd_o     (req_cpu_dcache_o.dmem_req_cmd_o),
        .dmem_req_addr_o    (req_cpu_dcache_o.dmem_req_addr_o),
        .dmem_op_type_o     (req_cpu_dcache_o.dmem_op_type_o),
        .dmem_req_data_o    (req_cpu_dcache_o.dmem_req_data_o),
        .dmem_req_tag_o     (req_cpu_dcache_o.dmem_req_tag_o),
        .dmem_req_invalidate_lr_o(req_cpu_dcache_o.dmem_req_invalidate_lr_o),
        .dmem_req_kill_o(req_cpu_dcache_o.dmem_req_kill_o),
        .dmem_lock_o(req_cpu_dcache_o.dmem_lock_o)
    );

    register #($bits(dec_wb_instr_t)+$bits(exe_wb_instr_t)) reg_exe_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .load_i(!stall_exe_int),
        .input_i({dec_to_wb_exe,exe_to_wb_exe}),
        .output_o({dec_to_wb_wb,exe_to_wb_wb})
    );

    assign wb_to_exe_exe.valid  = 1'b0;//dec_to_wb_wb.regfile_we;
    assign wb_to_exe_exe.rd     = exe_to_wb_wb.rd;
    assign wb_to_exe_exe.data   = exe_to_wb_wb.result_rd;

endmodule
