/*
 * Copyright 2023 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
//`default_nettype none

`include "colors.vh"
import drac_pkg::*;

module tb_module();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
//***DUT parameters***    
    //parameter TB_DATA_WIDTH = 32;
    //parameter TB_WEIGHTS_WIDTH = 7;
    //parameter TB_N_CORES = 1;
    //parameter TB_CORE_EVENTS = 1;

//-----------------------------
// Signals
//-----------------------------
reg tb_clk_i;
reg tb_rstn_i;
reg tb_kill_i;
reg tb_csr_i;
bus64_t tb_csr_cause_i;

addr_t        tb_io_base_addr_i;
logic         tb_dmem_resp_replay_i;
bus64_t       tb_dmem_resp_data_i;
logic         tb_dmem_req_ready_i;
logic         tb_dmem_resp_valid_i;
logic         tb_dmem_resp_nack_i;
logic         tb_dmem_xcpt_ma_st_i;
logic         tb_dmem_xcpt_ma_ld_i;
logic         tb_dmem_xcpt_pf_st_i;
logic         tb_dmem_xcpt_pf_ld_i;

reg           tb_dmem_req_valid_o;
reg  [4:0]    tb_dmem_req_cmd_o;
addr_t        tb_dmem_req_addr_o;
bus64_t       tb_dmem_op_type_o;
bus64_t       tb_dmem_req_data_o;
logic [7:0]   tb_dmem_req_tag_o;
logic         tb_dmem_req_invalidate_lr_o;
logic         tb_dmem_req_kill_o;
logic         tb_lock_o;
logic         tb_stall_o;
logic         tb_correct_branch_pred_o;
exe_if_branch_pred_t tb_exe_if_branch_pred_o;

rr_exe_instr_t      tb_from_rr_i;
wb_exe_instr_t      tb_from_wb_i;
exe_wb_instr_t      tb_to_wb_o;

resp_dcache_cpu_t tb_dmem_resp_i;
req_cpu_dcache_t  tb_cpu_req_o;

reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

exe_stage module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .kill_i(tb_kill_i),
    .csr_interrupt_i(tb_csr_i),
    .csr_interrupt_cause_i(tb_csr_cause_i),

    .from_rr_i(tb_from_rr_i),
    .from_wb_i(tb_from_wb_i),

    .resp_dcache_cpu_i(tb_dmem_resp_i),
    .req_cpu_dcache_o(tb_cpu_req_o),
    .io_base_addr_i(tb_io_base_addr_i),

    .to_wb_o(tb_to_wb_o),
    .stall_o(tb_stall_o),

    .correct_branch_pred_o(tb_correct_branch_pred_o),
    .exe_if_branch_pred_o(tb_exe_if_branch_pred_o)
);

//-----------------------------
// DUT
//-----------------------------

//***clk_gen***
// A single clock source is used in this design.
    initial tb_clk_i = 1;
    always #CLK_HALF_PERIOD tb_clk_i = !tb_clk_i;

    //***task automatic reset_dut***
    task automatic reset_dut;
        begin
            $display("*** Toggle reset.");
            tb_rstn_i <= 1'b0;
            #CLK_PERIOD;
            tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            $display("Done");
        end
    endtask

//***task automatic init_sim***
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};
            tb_kill_i<='{default:0};
            tb_csr_i<='{default:0};
            tb_csr_cause_i<='{default:0};

            tb_from_rr_i<='{default:0};
            tb_from_wb_i<='{default:0};

            tb_io_base_addr_i<='{default:0};
            tb_dmem_resp_replay_i<='{default:0};
            tb_dmem_resp_data_i<='{default:0};
            tb_dmem_req_ready_i<='{default:0};
            tb_dmem_resp_valid_i<='{default:0};
            tb_dmem_resp_nack_i<='{default:0};
            tb_dmem_xcpt_ma_st_i<='{default:0};
            tb_dmem_xcpt_ma_ld_i<='{default:0};
            tb_dmem_xcpt_pf_st_i<='{default:0};
            tb_dmem_xcpt_pf_ld_i<='{default:0};
            tb_dmem_resp_i<='{default:0};

            $display("Done");
        end
    endtask

//***task automatic init_dump***
//This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
//If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("dump_file.vcd");
            $dumpvars(0,module_inst);
        end
    endtask

//***task automatic test_sim***
    task automatic check_out;
        input int test;
        input int status;
        begin
            if (status) begin
                `START_RED_PRINT
                        $display("TEST %d FAILED.",test);
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST %d PASSED.",test);
                `END_COLOR_PRINT
            end
        end
    endtask

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            $display("*** test_sim");
            test_sim_1(tmp);
            check_out(1,tmp);
            test_sim_2(tmp);
            check_out(2,tmp);
            test_sim_3(tmp);
            check_out(3,tmp);
            test_sim_4(tmp);
            check_out(4,tmp);
            test_sim_5(tmp);
            check_out(5,tmp);
            test_sim_6(tmp);
            check_out(6,tmp);
            test_sim_7(tmp);
            check_out(7,tmp);
        end
    endtask

// Testing add
    task automatic test_sim_1;
        output int tmp;
        begin
            longint src1,src2;
            tb_test_name = "test_sim_1";
            tmp = 0;
            tb_from_rr_i.instr.unit <= UNIT_ALU;
            tb_from_rr_i.instr.instr_type <= ADD;
            tb_from_rr_i.instr.use_imm <= 0;
            tb_from_rr_i.instr.result <= 0;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_from_rr_i.data_rs1 <= src1;
                tb_from_rr_i.data_rs2 <= src2;
                #CLK_PERIOD;
                if (tb_to_wb_o.result != (src1+src2)) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h + %h = %h out: %h",src1,src2,(src1+src2),tb_to_wb_o.result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing substraction
    task automatic test_sim_2;
        output int tmp;
        begin
            longint src1,src2;
            tb_test_name = "test_sim_2";
            tmp = 0;
            tb_from_rr_i.instr.unit <= UNIT_ALU;
            tb_from_rr_i.instr.instr_type <= SUB;
            tb_from_rr_i.instr.use_imm <= 0;
            tb_from_rr_i.instr.result <= 0;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_from_rr_i.data_rs1 <= src1;
                tb_from_rr_i.data_rs2 <= src2;
                #CLK_PERIOD;
                if (tb_to_wb_o.result != (src1-src2)) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h - %h = %h out: %h",src1,src2,(src1-src2),tb_to_wb_o.result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing multiplication
    task automatic test_sim_3;
        output int tmp;
        begin
            longint src1,src2;
            tb_test_name = "test_sim_3";
            tmp = 0;
            tb_from_rr_i.instr.unit <= UNIT_MUL;
            tb_from_rr_i.instr.instr_type <= MUL;
            tb_from_rr_i.instr.use_imm <= 0;
            tb_from_rr_i.instr.result <= 0;
            tb_from_rr_i.instr.valid <= 1;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_from_rr_i.data_rs1 <= src1;
                tb_from_rr_i.data_rs2 <= src2;
                #CLK_HALF_PERIOD;
                while(tb_stall_o)#CLK_PERIOD;
                //#CLK_PERIOD;
                if (tb_to_wb_o.result != (src1*src2)) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h * %h = %h out: %h",src1,src2,(src1*src2),tb_to_wb_o.result);
                    `END_COLOR_PRINT
                end
                #CLK_HALF_PERIOD;
            end
        end
    endtask

// Testing division
    task automatic test_sim_4;
        output int tmp;
        begin
            longint src1,src2;
            tb_test_name = "test_sim_4";
            tmp = 0;
            tb_from_rr_i.instr.unit <= UNIT_DIV;
            tb_from_rr_i.instr.instr_type <= DIV;
            tb_from_rr_i.instr.use_imm <= 0;
            tb_from_rr_i.instr.result <= 0;
            tb_from_rr_i.instr.valid <= 1;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_from_rr_i.data_rs1 <= src1;
                tb_from_rr_i.data_rs2 <= src2;
                #CLK_HALF_PERIOD;
                while(tb_stall_o)#CLK_PERIOD;
                //#CLK_PERIOD;
                if (tb_to_wb_o.result != (src1/src2)) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h / %h = %h out: %h",src1,src2,(src1/src2),tb_to_wb_o.result);
                    `END_COLOR_PRINT
                end
                #CLK_HALF_PERIOD;
            end
        end
    endtask

// Testing JAL
    task automatic test_sim_5;
        output int tmp;
        begin
            longint src1,src2,pc,imm;
            tb_test_name = "test_sim_5";
            tmp = 0;
            tb_from_rr_i.instr.unit <= UNIT_BRANCH;
            tb_from_rr_i.instr.instr_type <= JAL;
            tb_from_rr_i.instr.use_imm <= 1;
            tb_from_rr_i.instr.valid <= 1;
            for(int i = 0; i < 100; i++) begin
                pc = $urandom();
                imm = $urandom();
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_from_rr_i.instr.pc <= pc;
                tb_from_rr_i.instr.result <= imm;
                tb_from_rr_i.data_rs1 <= src1;
                tb_from_rr_i.data_rs2 <= src2;
                #CLK_HALF_PERIOD;
                while(tb_stall_o)#CLK_PERIOD;
                //#CLK_PERIOD;
                if (tb_to_wb_o.result != pc + 4 | tb_to_wb_o.result_pc != 0) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect rd %h out: %h pc %h out: %h",pc + 4,tb_to_wb_o.result,pc + imm,tb_to_wb_o.result_pc);
                    `END_COLOR_PRINT
                end
                #CLK_HALF_PERIOD;
            end
        end
    endtask

// Testing JALR
    task automatic test_sim_6;
        output int tmp;
        begin
            longint src1,src2,pc,imm;
            tb_test_name = "test_sim_6";
            tmp = 0;
            tb_from_rr_i.instr.unit <= UNIT_BRANCH;
            tb_from_rr_i.instr.instr_type <= JALR;
            tb_from_rr_i.instr.use_imm <= 1;
            tb_from_rr_i.instr.valid <= 1;
            for(int i = 0; i < 100; i++) begin
                pc = $urandom();
                imm = $urandom();
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_from_rr_i.instr.pc <= pc;
                tb_from_rr_i.instr.result <= imm;
                tb_from_rr_i.data_rs1 <= src1;
                tb_from_rr_i.data_rs2 <= src2;
                #CLK_HALF_PERIOD;
                while(tb_stall_o)#CLK_PERIOD;
                //#CLK_PERIOD;
                if (tb_to_wb_o.result != pc + 4 | tb_to_wb_o.result_pc != (src1 + imm) & 64'hFFFFFFFFFFFFFFFE) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect rd %h out: %h pc %h out: %h",pc + 4,tb_to_wb_o.result,(src1 + imm) & 64'hFFFFFFFFFFFFFFFE,tb_to_wb_o.result_pc);
                    `END_COLOR_PRINT
                end
                #CLK_HALF_PERIOD;
            end
        end
    endtask

// Testing csr interruption
    task automatic test_sim_7;
        output int tmp;
        begin
            longint src1,src2,pc,imm;
            tb_test_name = "test_sim_7";
            tmp = 0;
            tb_from_rr_i.instr.unit <= UNIT_ALU;
            tb_from_rr_i.instr.instr_type <= ADD;
            tb_from_rr_i.instr.use_imm <= 0;
            tb_from_rr_i.instr.valid <= 1;
            for(int i = 0; i < 100; i++) begin
                pc = $urandom();
                imm = $urandom();
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_from_rr_i.instr.pc <= pc;
                tb_from_rr_i.instr.result <= imm;
                tb_from_rr_i.data_rs1 <= src1;
                tb_from_rr_i.data_rs2 <= src2;
                #CLK_HALF_PERIOD;
                if (tb_to_wb_o.result != (src1+src2)) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h + %h = %h out: %h",src1,src2,(src1+src2),tb_to_wb_o.result);
                    `END_COLOR_PRINT
                end
                #CLK_HALF_PERIOD;
                tb_csr_i <= 1;
                #CLK_HALF_PERIOD;
                if (!tb_to_wb_o.ex.valid) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect: unhandled exception");
                    `END_COLOR_PRINT
                end
                #CLK_HALF_PERIOD;
                tb_csr_i <= 0;
            end
        end
    endtask

//***init_sim***
//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        $finish;
    end


endmodule
//`default_nettype wire

