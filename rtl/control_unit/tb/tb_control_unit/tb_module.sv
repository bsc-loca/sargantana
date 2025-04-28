//-----------------------------
// Header
//-----------------------------

/*
 * Copyright 2025 BSC*
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

//-----------------------------
// Signals
//-----------------------------

logic     tb_clk_i;
logic     tb_rstn_i;

logic             valid_fetch;
id_cu_t           id_cu_i;
rr_cu_t           rr_cu_i;
exe_cu_t          exe_cu_i;
wb_cu_t           wb_cu_i;
resp_csr_cpu_t    csr_cu_i;
logic             correct_branch_pred_i;

pipeline_ctrl_t  pipeline_ctrl_o;
pipeline_flush_t pipeline_flush_o;
cu_if_t          cu_if_o;
logic            invalidate_icache_o;
logic            invalidate_buffer_o;
cu_rr_t          cu_rr_o;

reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

control_unit module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .valid_fetch(valid_fetch),
    .id_cu_i(id_cu_i),
    .rr_cu_i(rr_cu_i),
    .exe_cu_i(exe_cu_i),
    .wb_cu_i(wb_cu_i),
    .csr_cu_i(csr_cu_i),
    .correct_branch_pred_i(correct_branch_pred_i),

    .pipeline_ctrl_o(pipeline_ctrl_o),
    .pipeline_flush_o(pipeline_flush_o),
    .cu_if_o(cu_if_o),
    .invalidate_icache_o(invalidate_icache_o),
    .invalidate_buffer_o(invalidate_buffer_o),
    .cu_rr_o(cu_rr_o)
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
            //$display("*** Toggle reset.");
            tb_rstn_i <= 1'b0; 
            #CLK_PERIOD;
            #CLK_PERIOD;
            tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            //$display("Done");
        end
    endtask

//***task automatic init_sim***
    task automatic init_sim;
        begin
            $display("*** init_sim");
            valid_fetch<='{default:0};
            id_cu_i<='{default:0};
            rr_cu_i<='{default:0};
            exe_cu_i<='{default:0};
            wb_cu_i<='{default:0};
            csr_cu_i<='{default:0};
            correct_branch_pred_i<='{default:0};
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
            // Nothing happen
            test_sim_1(tmp);
            check_out(1,tmp);
            // Testing fetch valid, go to next pc
            test_sim_2(tmp);
            check_out(2,tmp);
            // Testing execution stall and valid fetch
            test_sim_3(tmp);
            check_out(3,tmp);
            // Stall in execution and write back simultaneously
            test_sim_4(tmp);
            check_out(4,tmp);
            // CSR exception
            test_sim_5(tmp);
            check_out(5,tmp);
            // Correct instruction
            test_sim_6(tmp);
            check_out(6,tmp);
            // Fence
            test_sim_7(tmp);
            check_out(7,tmp);
        end
    endtask

// Nothing happen
    task automatic test_sim_1;
        output int incorrect_result;
        begin
            tb_test_name = "test_sim_1";

            valid_fetch<=0;

            id_cu_i.valid_jal<=0;
            id_cu_i.stall_csr_fence<=0;

            rr_cu_i.stall_csr_fence<=0;

            exe_cu_i.valid<=0;
            exe_cu_i.is_branch<=0;
            exe_cu_i.stall<=0;
            exe_cu_i.stall_csr_fence<=0;

            wb_cu_i.pc<=64'h0;
            wb_cu_i.valid<=0;
            wb_cu_i.csr_enable_wb<=0;
            wb_cu_i.write_enable<=0;
            wb_cu_i.stall_csr_fence<=0;
            wb_cu_i.xcpt<=0;
            wb_cu_i.ecall_taken<=0;
            wb_cu_i.fence<=0;
            wb_cu_i.fence_i<=0;

            csr_cu_i.csr_rw_rdata<=0;
            csr_cu_i.csr_replay<=0;
            csr_cu_i.csr_stall<=0;
            csr_cu_i.csr_exception<=0;
            csr_cu_i.csr_eret<=0;
            csr_cu_i.csr_evec<=0;
            csr_cu_i.csr_interrupt<=0;
            csr_cu_i.csr_interrupt_cause<=0;

            correct_branch_pred_i<=0;

            #CLK_PERIOD;
            incorrect_result = 0;

            // --- pipeline_ctrl_o ---
            incorrect_result += (pipeline_ctrl_o.sel_addr_if!=SEL_JUMP_DECODE);
            incorrect_result += (pipeline_ctrl_o.stall_if!=0);
            incorrect_result += (pipeline_ctrl_o.stall_id!=0);
            incorrect_result += (pipeline_ctrl_o.stall_rr!=0);
            incorrect_result += (pipeline_ctrl_o.stall_exe!=0);
            //incorrect_result += (pipeline_ctrl_o.stall_wb!=0);

            // --- pipeline_flush_o ---
            incorrect_result += (pipeline_flush_o.flush_if!=0);
            incorrect_result += (pipeline_flush_o.flush_id!=0);
            incorrect_result += (pipeline_flush_o.flush_rr!=0);
            incorrect_result += (pipeline_flush_o.flush_exe!=0);
            //incorrect_result += (pipeline_flush_o.flush_wb!=0);

            // --- cu_if_o ---
            incorrect_result += (cu_if_o.next_pc!=NEXT_PC_SEL_KEEP_PC);
            //incorrect_result += (cu_if_o.invalidate_icache!=0);

            // --- invalidate_icache_o ---
            incorrect_result += (invalidate_icache_o!=0);

            // --- invalidate_buffer_o ---
            incorrect_result += (invalidate_buffer_o!=0);

            // --- cu_rr_o ---
            incorrect_result += (cu_rr_o.write_enable!=0);
        end
    endtask

// Testing fetch valid, go to next pc
    task automatic test_sim_2;
        output int incorrect_result;
        begin
            tb_test_name = "test_sim_2";

            valid_fetch<=1;

            id_cu_i.valid_jal<=0;
            id_cu_i.stall_csr_fence<=0;

            rr_cu_i.stall_csr_fence<=0;

            exe_cu_i.valid<=0;
            exe_cu_i.is_branch<=0;
            exe_cu_i.stall<=0;
            exe_cu_i.stall_csr_fence<=0;

            wb_cu_i.pc<=64'h0;
            wb_cu_i.valid<=0;
            wb_cu_i.csr_enable_wb<=0;
            wb_cu_i.write_enable<=0;
            wb_cu_i.stall_csr_fence<=0;
            wb_cu_i.xcpt<=0;
            wb_cu_i.ecall_taken<=0;
            wb_cu_i.fence<=0;
            wb_cu_i.fence_i<=0;
            
            csr_cu_i.csr_rw_rdata<=0;
            csr_cu_i.csr_replay<=0;
            csr_cu_i.csr_stall<=0;
            csr_cu_i.csr_exception<=0;
            csr_cu_i.csr_eret<=0;
            csr_cu_i.csr_evec<=0;
            csr_cu_i.csr_interrupt<=0;
            csr_cu_i.csr_interrupt_cause<=0;

            correct_branch_pred_i<=0;

            #CLK_PERIOD;
            incorrect_result = 0;

            // --- pipeline_ctrl_o ---
            incorrect_result += (pipeline_ctrl_o.sel_addr_if!=SEL_JUMP_DECODE);
            incorrect_result += (pipeline_ctrl_o.stall_if!=0);
            incorrect_result += (pipeline_ctrl_o.stall_id!=0);
            incorrect_result += (pipeline_ctrl_o.stall_rr!=0);
            incorrect_result += (pipeline_ctrl_o.stall_exe!=0);
            //incorrect_result += (pipeline_ctrl_o.stall_wb!=0);

            // --- pipeline_flush_o ---
            incorrect_result += (pipeline_flush_o.flush_if!=0);
            incorrect_result += (pipeline_flush_o.flush_id!=0);
            incorrect_result += (pipeline_flush_o.flush_rr!=0);
            incorrect_result += (pipeline_flush_o.flush_exe!=0);
            //incorrect_result += (pipeline_flush_o.flush_wb!=0);

            // --- cu_if_o ---
            incorrect_result += (cu_if_o.next_pc!=NEXT_PC_SEL_BP_OR_PC_4);
            //incorrect_result += (cu_if_o.invalidate_icache!=0);

            // --- invalidate_icache_o ---
            incorrect_result += (invalidate_icache_o!=0);

            // --- invalidate_buffer_o ---
            incorrect_result += (invalidate_buffer_o!=0);

            // --- cu_rr_o ---
            incorrect_result += (cu_rr_o.write_enable!=0);
        end
    endtask

// Testing execution stall and valid fetch
    task automatic test_sim_3;
        output int incorrect_result;
        begin
            tb_test_name = "test_sim_3";

            valid_fetch<=1;

            id_cu_i.valid_jal<=0;
            id_cu_i.stall_csr_fence<=0;

            rr_cu_i.stall_csr_fence<=0;

            exe_cu_i.valid<=1;
            exe_cu_i.is_branch<=0;
            exe_cu_i.stall<=1;
            exe_cu_i.stall_csr_fence<=0;

            wb_cu_i.pc<=64'h0;
            wb_cu_i.valid<=0;
            wb_cu_i.csr_enable_wb<=0;
            wb_cu_i.write_enable<=0;
            wb_cu_i.stall_csr_fence<=0;
            wb_cu_i.xcpt<=0;
            wb_cu_i.ecall_taken<=0;
            wb_cu_i.fence<=0;
            wb_cu_i.fence_i<=0;
            
            csr_cu_i.csr_rw_rdata<=0;
            csr_cu_i.csr_replay<=0;
            csr_cu_i.csr_stall<=0;
            csr_cu_i.csr_exception<=0;
            csr_cu_i.csr_eret<=0;
            csr_cu_i.csr_evec<=0;
            csr_cu_i.csr_interrupt<=0;
            csr_cu_i.csr_interrupt_cause<=0;

            correct_branch_pred_i<=1;

            #CLK_PERIOD;
            incorrect_result = 0;

            // --- pipeline_ctrl_o ---
            incorrect_result += (pipeline_ctrl_o.sel_addr_if!=SEL_JUMP_DECODE);
            incorrect_result += (pipeline_ctrl_o.stall_if!=1);
            incorrect_result += (pipeline_ctrl_o.stall_id!=1);
            incorrect_result += (pipeline_ctrl_o.stall_rr!=1);
            incorrect_result += (pipeline_ctrl_o.stall_exe!=1);
            //incorrect_result += (pipeline_ctrl_o.stall_wb!=0);

            // --- pipeline_flush_o ---
            incorrect_result += (pipeline_flush_o.flush_if!=0);
            incorrect_result += (pipeline_flush_o.flush_id!=0);
            incorrect_result += (pipeline_flush_o.flush_rr!=0);
            incorrect_result += (pipeline_flush_o.flush_exe!=0);
            //incorrect_result += (pipeline_flush_o.flush_wb!=0);

            // --- cu_if_o ---
            incorrect_result += (cu_if_o.next_pc!=NEXT_PC_SEL_KEEP_PC);
            //incorrect_result += (cu_if_o.invalidate_icache!=0);

            // --- invalidate_icache_o ---
            incorrect_result += (invalidate_icache_o!=0);

            // --- invalidate_buffer_o ---
            incorrect_result += (invalidate_buffer_o!=0);

            // --- cu_rr_o ---
            incorrect_result += (cu_rr_o.write_enable!=0);
        end
    endtask

// Stall in execution and write back simultaneously
    task automatic test_sim_4;
        output int incorrect_result;
        begin
            tb_test_name = "test_sim_4";

            valid_fetch<=1;

            id_cu_i.valid_jal<=0;
            id_cu_i.stall_csr_fence<=0;

            rr_cu_i.stall_csr_fence<=0;

            exe_cu_i.valid<=1;
            exe_cu_i.is_branch<=0;
            exe_cu_i.stall<=1;
            exe_cu_i.stall_csr_fence<=0;

            wb_cu_i.pc<=64'h0;
            wb_cu_i.valid<=1;
            wb_cu_i.csr_enable_wb<=0;
            wb_cu_i.write_enable<=0;
            wb_cu_i.stall_csr_fence<=0;
            wb_cu_i.xcpt<=1;
            wb_cu_i.ecall_taken<=0;
            wb_cu_i.fence<=0;
            wb_cu_i.fence_i<=0;
            
            csr_cu_i.csr_rw_rdata<=0;
            csr_cu_i.csr_replay<=0;
            csr_cu_i.csr_stall<=0;
            csr_cu_i.csr_exception<=0;
            csr_cu_i.csr_eret<=0;
            csr_cu_i.csr_evec<=0;
            csr_cu_i.csr_interrupt<=0;
            csr_cu_i.csr_interrupt_cause<=0;

            correct_branch_pred_i<=0;

            #CLK_PERIOD;
            #CLK_PERIOD;
            incorrect_result = 0;

            // --- pipeline_ctrl_o ---
            incorrect_result += (pipeline_ctrl_o.sel_addr_if!=SEL_JUMP_CSR);
            incorrect_result += (pipeline_ctrl_o.stall_if!=1);
            incorrect_result += (pipeline_ctrl_o.stall_id!=1);
            incorrect_result += (pipeline_ctrl_o.stall_rr!=1);
            incorrect_result += (pipeline_ctrl_o.stall_exe!=1);


            // --- pipeline_flush_o ---
            incorrect_result += (pipeline_flush_o.flush_if!=1);
            incorrect_result += (pipeline_flush_o.flush_id!=1);
            incorrect_result += (pipeline_flush_o.flush_rr!=1);
            incorrect_result += (pipeline_flush_o.flush_exe!=1);

            // --- cu_if_o ---
            incorrect_result += (cu_if_o.next_pc!=NEXT_PC_SEL_JUMP);
            //incorrect_result += (cu_if_o.invalidate_icache!=0);

            // --- invalidate_icache_o ---
            incorrect_result += (invalidate_icache_o!=0);

            // --- invalidate_buffer_o ---
            incorrect_result += (invalidate_buffer_o!=1);

            // --- cu_rr_o ---
            incorrect_result += (cu_rr_o.write_enable!=0);
        end
    endtask

    // CSR exception
    task automatic test_sim_5;
        output int incorrect_result;
        begin
            tb_test_name = "test_sim_5";

            valid_fetch<=1;

            id_cu_i.valid_jal<=0;
            id_cu_i.stall_csr_fence<=0;

            rr_cu_i.stall_csr_fence<=0;

            exe_cu_i.valid<=0;
            exe_cu_i.is_branch<=0;
            exe_cu_i.stall<=0;
            exe_cu_i.stall_csr_fence<=0;

            wb_cu_i.pc<=64'h0;
            wb_cu_i.valid<=0;
            wb_cu_i.csr_enable_wb<=0;
            wb_cu_i.write_enable<=0;
            wb_cu_i.stall_csr_fence<=0;
            wb_cu_i.xcpt<=0;
            wb_cu_i.ecall_taken<=0;
            wb_cu_i.fence<=0;
            wb_cu_i.fence_i<=0;
            
            csr_cu_i.csr_rw_rdata<=0;
            csr_cu_i.csr_replay<=0;
            csr_cu_i.csr_stall<=0;
            csr_cu_i.csr_exception<=1;
            csr_cu_i.csr_eret<=0;
            csr_cu_i.csr_evec<=0;
            csr_cu_i.csr_interrupt<=0;
            csr_cu_i.csr_interrupt_cause<=0;

            correct_branch_pred_i<=0;

            #CLK_PERIOD;
            #CLK_PERIOD;
            incorrect_result = 0;

            // --- pipeline_ctrl_o ---
            incorrect_result += (pipeline_ctrl_o.sel_addr_if!=SEL_JUMP_CSR);
            incorrect_result += (pipeline_ctrl_o.stall_if!=0);
            incorrect_result += (pipeline_ctrl_o.stall_id!=0);
            incorrect_result += (pipeline_ctrl_o.stall_rr!=0);
            incorrect_result += (pipeline_ctrl_o.stall_exe!=0);
            //incorrect_result += (pipeline_ctrl_o.stall_wb!=0);

            // --- pipeline_flush_o ---
            incorrect_result += (pipeline_flush_o.flush_if!=1);
            incorrect_result += (pipeline_flush_o.flush_id!=1);
            incorrect_result += (pipeline_flush_o.flush_rr!=1);
            incorrect_result += (pipeline_flush_o.flush_exe!=1);
            //incorrect_result += (pipeline_flush_o.flush_wb!=0);

            // --- cu_if_o ---
            incorrect_result += (cu_if_o.next_pc!=NEXT_PC_SEL_JUMP);
            //incorrect_result += (cu_if_o.invalidate_icache!=0);

            // --- invalidate_icache_o ---
            incorrect_result += (invalidate_icache_o!=0);

            // --- invalidate_buffer_o ---
            incorrect_result += (invalidate_buffer_o!=0);

            // --- cu_rr_o ---
            incorrect_result += (cu_rr_o.write_enable!=0);
        end
    endtask

    // Correct instruction
    task automatic test_sim_6;
        output int incorrect_result;
        begin
            tb_test_name = "test_sim_6";

            valid_fetch<=1;

            id_cu_i.valid_jal<=0;
            id_cu_i.stall_csr_fence<=0;

            rr_cu_i.stall_csr_fence<=0;

            exe_cu_i.valid<=0;
            exe_cu_i.is_branch<=0;
            exe_cu_i.stall<=0;
            exe_cu_i.stall_csr_fence<=0;

            wb_cu_i.pc<=64'h0;
            wb_cu_i.valid<=1;
            wb_cu_i.csr_enable_wb<=0;
            wb_cu_i.write_enable<=1;
            wb_cu_i.stall_csr_fence<=0;
            wb_cu_i.xcpt<=0;
            wb_cu_i.ecall_taken<=0;
            wb_cu_i.fence<=0;
            wb_cu_i.fence_i<=0;
            
            csr_cu_i.csr_rw_rdata<=0;
            csr_cu_i.csr_replay<=0;
            csr_cu_i.csr_stall<=0;
            csr_cu_i.csr_exception<=0;
            csr_cu_i.csr_eret<=0;
            csr_cu_i.csr_evec<=0;
            csr_cu_i.csr_interrupt<=0;
            csr_cu_i.csr_interrupt_cause<=0;

            correct_branch_pred_i<=0;

            #CLK_PERIOD;
            incorrect_result = 0;

            // --- pipeline_ctrl_o ---
            incorrect_result += (pipeline_ctrl_o.sel_addr_if!=SEL_JUMP_DECODE);
            incorrect_result += (pipeline_ctrl_o.stall_if!=0);
            incorrect_result += (pipeline_ctrl_o.stall_id!=0);
            incorrect_result += (pipeline_ctrl_o.stall_rr!=0);
            incorrect_result += (pipeline_ctrl_o.stall_exe!=0);
            //incorrect_result += (pipeline_ctrl_o.stall_wb!=0);

            // --- pipeline_flush_o ---
            incorrect_result += (pipeline_flush_o.flush_if!=0);
            incorrect_result += (pipeline_flush_o.flush_id!=0);
            incorrect_result += (pipeline_flush_o.flush_rr!=0);
            incorrect_result += (pipeline_flush_o.flush_exe!=0);
            //incorrect_result += (pipeline_flush_o.flush_wb!=0);

            // --- cu_if_o ---
            incorrect_result += (cu_if_o.next_pc!=NEXT_PC_SEL_BP_OR_PC_4);
            //incorrect_result += (cu_if_o.invalidate_icache!=0);

            // --- invalidate_icache_o ---
            incorrect_result += (invalidate_icache_o!=0);

            // --- invalidate_buffer_o ---
            incorrect_result += (invalidate_buffer_o!=0);

            // --- cu_rr_o ---
            incorrect_result += (cu_rr_o.write_enable!=1);
        end
    endtask

    // Fence
    task automatic test_sim_7;
        output int incorrect_result;
        begin
            tb_test_name = "test_sim_7";

            valid_fetch<=1;

            id_cu_i.valid_jal<=0;
            id_cu_i.stall_csr_fence<=0;

            rr_cu_i.stall_csr_fence<=0;

            exe_cu_i.valid<=0;
            exe_cu_i.is_branch<=0;
            exe_cu_i.stall<=0;
            exe_cu_i.stall_csr_fence<=0;

            wb_cu_i.pc<=64'h0;
            wb_cu_i.valid<=1;
            wb_cu_i.csr_enable_wb<=0;
            wb_cu_i.write_enable<=0;
            wb_cu_i.stall_csr_fence<=0;
            wb_cu_i.xcpt<=0;
            wb_cu_i.ecall_taken<=0;
            wb_cu_i.fence<=1;
            wb_cu_i.fence_i<=1;
            
            csr_cu_i.csr_rw_rdata<=0;
            csr_cu_i.csr_replay<=0;
            csr_cu_i.csr_stall<=0;
            csr_cu_i.csr_exception<=0;
            csr_cu_i.csr_eret<=0;
            csr_cu_i.csr_evec<=0;
            csr_cu_i.csr_interrupt<=0;
            csr_cu_i.csr_interrupt_cause<=0;

            correct_branch_pred_i<=0;

            #CLK_PERIOD;
            incorrect_result = 0;

            // --- pipeline_ctrl_o ---
            incorrect_result += (pipeline_ctrl_o.sel_addr_if!=SEL_JUMP_DECODE);
            incorrect_result += (pipeline_ctrl_o.stall_if!=0);
            incorrect_result += (pipeline_ctrl_o.stall_id!=0);
            incorrect_result += (pipeline_ctrl_o.stall_rr!=0);
            incorrect_result += (pipeline_ctrl_o.stall_exe!=0);
            //incorrect_result += (pipeline_ctrl_o.stall_wb!=0);

            // --- pipeline_flush_o ---
            incorrect_result += (pipeline_flush_o.flush_if!=1);
            incorrect_result += (pipeline_flush_o.flush_id!=0);
            incorrect_result += (pipeline_flush_o.flush_rr!=0);
            incorrect_result += (pipeline_flush_o.flush_exe!=0);
            //incorrect_result += (pipeline_flush_o.flush_wb!=0);

            // --- cu_if_o ---
            incorrect_result += (cu_if_o.next_pc!=NEXT_PC_SEL_KEEP_PC);

            // --- invalidate_icache_o ---
            incorrect_result += (invalidate_icache_o!=1);

            // --- invalidate_buffer_o ---
            incorrect_result += (invalidate_buffer_o!=1);

            // --- cu_rr_o ---
            incorrect_result += (cu_rr_o.write_enable!=0);
        end
    endtask

//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        reset_dut();
        init_dump();
        test_sim();
        $finish;
    end


endmodule
//`default_nettype wire

