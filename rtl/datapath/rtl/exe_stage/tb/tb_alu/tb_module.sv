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

//-----------------------------
// Signals
//-----------------------------

rr_exe_arith_instr_t  tb_instr_i;
exe_wb_scalar_instr_t tb_instr_o;

reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

alu module_inst (
    .instruction_i(tb_instr_i),
    .instruction_o(tb_instr_o)
);

//-----------------------------
// DUT
//-----------------------------

//***task automatic init_sim***
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_instr_i.data_rs1<='{default:0};
            tb_instr_i.data_rs2<='{default:0};
            tb_instr_i.instr.instr_type<='{default:0};
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
        end
    endtask

// Testing add
    task automatic test_sim_1;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_1";
            tmp = 0;
            tb_instr_i.instr.instr_type <= ADD;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_instr_i.data_rs1 <= src1;
                tb_instr_i.data_rs2 <= src2;
                #CLK_PERIOD;
                correct_result = src1+src2;
                if (tb_instr_o.result != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h + %h = %h out: %h",src1,src2,correct_result,tb_instr_o.result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing sub
    task automatic test_sim_2;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_2";
            tmp = 0;
            tb_instr_i.instr.instr_type <= SUB;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_instr_i.data_rs1 <= src1;
                tb_instr_i.data_rs2 <= src2;
                #CLK_PERIOD;
                correct_result = src1-src2;
                if (tb_instr_o.result != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h + %h = %h out: %h",src1,src2,correct_result,tb_instr_o.result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing Shift Left Logical
    task automatic test_sim_3;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_3";
            tmp = 0;
            tb_instr_i.instr.instr_type <= SLL;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2[5:0] = $urandom();
                src2[63:6] = 0;
                tb_instr_i.data_rs1 <= src1;
                tb_instr_i.data_rs2 <= src2;
                #CLK_PERIOD;
                correct_result = src1<<src2;
                if (tb_instr_o.result != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h << %h = %h out: %h",src1,src2,correct_result,tb_instr_o.result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing Shift Right Logical
    task automatic test_sim_4;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_4";
            tmp = 0;
            tb_instr_i.instr.instr_type <= SRL;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2[5:0] = $urandom();
                src2[63:6] = 0;
                tb_instr_i.data_rs1 <= src1;
                tb_instr_i.data_rs2 <= src2;
                #CLK_PERIOD;
                correct_result = src1>>src2;
                if (tb_instr_o.result != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h >> %h = %h out: %h",src1,src2,correct_result,tb_instr_o.result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing add word
    task automatic test_sim_5;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_5";
            tmp = 0;
            tb_instr_i.instr.instr_type <= ADDW;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src2 = $urandom();
                tb_instr_i.data_rs1 <= src1;
                tb_instr_i.data_rs2 <= src2;
                #CLK_PERIOD;
                correct_result[31:0] = src1+src2;
                correct_result[63:32] = {32{correct_result[31]}};
                if (tb_instr_o.result != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h + %h = %h out: %h",src1,src2,correct_result,tb_instr_o.result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing sub word
    task automatic test_sim_6;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_6";
            tmp = 0;
            tb_instr_i.instr.instr_type <= SUBW;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src2 = $urandom();
                tb_instr_i.data_rs1 <= src1;
                tb_instr_i.data_rs2 <= src2;
                #CLK_PERIOD;
                correct_result[31:0] = src1-src2;
                correct_result[63:32] = {32{correct_result[31]}};
                if (tb_instr_o.result != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h - %h = %h out: %h",src1,src2,correct_result,tb_instr_o.result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_dump();
        test_sim();
        $finish;
    end


endmodule
//`default_nettype wire

