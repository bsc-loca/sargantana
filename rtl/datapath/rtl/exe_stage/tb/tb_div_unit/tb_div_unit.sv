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

module tb_div_unit();

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
logic tb_kill_div_i;
rr_exe_instr_t tb_request_i;
bus64_t tb_data_src1_i;
bus64_t tb_data_src2_i;
exe_wb_instr_t tb_instruction_o;   // Output instruction
    
reg[63:0] result_q;
reg[63:0] result_r;
reg[64*8:0] tb_test_name;

bus64_t tb_quo_out;
bus64_t tb_rmd_out;

//-----------------------------
// Module
//-----------------------------

div_unit module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .kill_div_i(tb_kill_div_i),
    .instruction_i(tb_request_i),
    .data_src1_i(tb_data_src1_i),
    .data_src2_i(tb_data_src2_i),
    .instruction_o(tb_instruction_o)
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
            tb_kill_div_i<='{default:0};
            tb_request_i<='{default:0};
            tb_data_src1_i<='{default:0};
            tb_data_src2_i<='{default:0};
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
    task automatic test_sim;
        begin
            int tmp;
            $display("*** test_sim");
            test_sim_1(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end
            test_sim_2(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 2 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 2 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask


// Test performs division and remanent on unsigned 32 bit operands
    task automatic test_sim_1;
        output int tmp;
        begin
            tb_test_name = "test_sim_1";
            tmp = 0;
            tb_request_i.instr.op_32 = 1'b1;
            for(int i = 0; i < 500; i++) begin
                int unsigned src1 = $urandom();
                int unsigned src2 = $urandom();
                tb_request_i.instr.signed_op <= 1'b0;
                tb_request_i.instr.instr_type <= DIVUW;
                tb_request_i.instr.valid <= 1'b1;
                tb_request_i.instr.unit <= UNIT_DIV;
                tb_data_src1_i  <= src1;
                tb_data_src2_i  <= src2;
                result_q[31:0]  = (src1/src2);
                result_q[63:32] = {32{result_q[31]}}; 
                result_r[31:0]  = (src1%src2);
                result_r[63:32] = {32{result_r[31]}};
                #CLK_PERIOD;
                tb_data_src1_i  <= 'h0;
                tb_data_src2_i  <= 'h0;
                tb_request_i.instr.valid <= 1'b0;
                tb_request_i.instr.instr_type <= ADD;
                tb_request_i.instr.unit <= UNIT_ALU;
                for(int i = 0; i < 17; i++)begin
                    #CLK_PERIOD;
                end
                tb_quo_out = {{32{module_inst.quo_32[31]}},module_inst.quo_32[31:0]};
                tb_rmd_out = {{32{module_inst.rmd_32[31]}},module_inst.rmd_32[31:0]};
                if (tb_quo_out != result_q) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h / %h = %h out: %h",src1,src2,result_q,tb_quo_out);
                    `END_COLOR_PRINT
                end
                if (tb_rmd_out != result_r) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h remainder %h = %h out: %h",src1,src2,result_r,tb_rmd_out);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask


// Test performs division and remanent on unsigned 64 bit operands 
    task automatic test_sim_2;
        output int tmp;
        begin
            tb_test_name = "test_sim_2";
            tmp = 0;
            for(int i = 0; i < 500; i++) begin
                longint unsigned src1;
                longint unsigned src2;
                tb_data_src1_i[31:0]  = $urandom();
                tb_data_src1_i[63:32] = $urandom();
                src1 = tb_data_src1_i;
                tb_data_src2_i[31:0]  = $urandom();
                tb_data_src2_i[63:32] = $urandom();
                src2 = tb_data_src2_i;
                tb_request_i.instr.valid = 1'b1;
                tb_request_i.instr.signed_op = 1'b0;
                tb_request_i.instr.op_32 = 1'b0;
                tb_request_i.instr.unit = UNIT_DIV;
                tb_request_i.instr.instr_type = DIVU;
                tb_data_src1_i  = src1;
                tb_data_src2_i  = src2;
                result_q = (src1/src2);
                result_r = (src1%src2);
                for(int i = 0; i < 34; i++)begin
                    #CLK_PERIOD;
                end
                tb_quo_out = module_inst.quo_32;
                tb_rmd_out = module_inst.rmd_32;
                if (module_inst.quo_64 != result_q) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h / %h = %h out: %h",src1,src2,result_q,module_inst.quo_64);
                    `END_COLOR_PRINT
                end
                if (module_inst.rmd_64 != result_r) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h remainder %h = %h out: %h",src1,src2,result_r,module_inst.rmd_64);
                    `END_COLOR_PRINT
                end
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
