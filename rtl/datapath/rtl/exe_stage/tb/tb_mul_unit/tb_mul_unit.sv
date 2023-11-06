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
`default_nettype none

`include "colors.vh"
import drac_pkg::*;

module tb_mul_unit();

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
logic tb_wb_exception_i;
logic tb_valid_mul;
logic [2:0] tb_funct3_field;
logic tb_int_32;
logic [63:0] tb_source_1;
logic [63:0] tb_source_2;
reg [63:0] tb_mul_result;
reg tb_lock_mul;
reg tb_ready_mul;

rr_exe_instr_t tb_instruction_i;
exe_wb_instr_t tb_instruction_o;

reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

mul_unit mul_unit_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .kill_mul_i(tb_wb_exception_i),
    .instruction_i(tb_instruction_i),
    .data_src1_i(tb_source_1),
    .data_src2_i(tb_source_2),
    .instruction_o(tb_instruction_o)
);

//-----------------------------
// INSTRUCTION ASSIGNATIONS
//-----------------------------

assign tb_instruction_i.data_rs1       = tb_source_1;
assign tb_instruction_i.data_rs2       = tb_source_2;
assign tb_instruction_i.instr.valid    = tb_valid_mul;
assign tb_instruction_i.instr.mem_size = tb_funct3_field;
assign tb_instruction_i.instr.op_32    = tb_int_32;

assign tb_mul_result = tb_instruction_o.result;
assign tb_lock_mul   = tb_instruction_o.stall_csr_fence; 

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
            tb_wb_exception_i<='{default:0};
            tb_valid_mul<='{default:0};
            tb_funct3_field<='{default:0};
            tb_int_32<='{default:0};
            tb_source_1<='{default:0};
            tb_source_2<='{default:0};
            tb_ready_mul<='{default:0};
            $display("Done");
        end
    endtask

//***task automatic init_dump***
//This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
//If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("mul_unit.vcd");
            $dumpvars(0,mul_unit_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

//ReadCheck: assert (data === correct_data)
//               else $error("memory read error");
//  Igt10: assert (I > 10)
//           else $warning("I is less than or equal to 10");

    task automatic set_srcs;
        input longint src1;
        input longint src2;
        begin
            tb_source_1  <= src1;
            tb_source_2  <= src2;
            tb_valid_mul <= 1;
        end
    endtask

// Test 1000 random multiplications
    task automatic test_sim_1;
        output int tmp;
        begin
            tb_test_name = "test_sim_1";
            tmp = 0;
            for(int i = 0; i < 1000; i++) begin
                longint result;
                longint src1 = {$urandom(),$urandom()};
                longint src2 = {$urandom(),$urandom()};
                set_srcs(src1,src2);
                tick();
                tick();
                tick();
                result = src1*src2;
                if (tb_mul_result != result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h * %h = %h, output: %h",src1,src2,result,tb_mul_result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Test 1000 random 32-bit multiplications
    task automatic test_sim_2;
        output int tmp;
        begin
            tb_test_name = "test_sim_2";
            tmp = 0;
            tb_int_32 = 1;
            for(int i = 0; i < 1000; i++) begin
                longint result;
                longint src1 = {$urandom(),$urandom()};
                longint src2 = {$urandom(),$urandom()};
                set_srcs(src1,src2);
                tick();
                tick();
                tick();
                result = src1*src2;
                result = {{32{result[31]}},result[31:0]};
                if (tb_mul_result != result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h * %h = %h, output: %h",src1,src2,result,tb_mul_result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Test 1000 random high part unsigned sources multiplications
    task automatic test_sim_3;
        output int tmp;
        begin
            tb_test_name = "test_sim_3";
            tmp = 0;
            tb_int_32 = 0;
            tb_funct3_field = 3'b011;
            for(int i = 0; i < 1000; i++) begin
                logic [127:0] result;
                longint unsigned src1 = {$urandom(),$urandom()};
                longint unsigned src2 = {$urandom(),$urandom()};
                set_srcs(src1,src2);
                tick();
                tick();
                tick();
                result = src1*src2;
                result = {64'b0,result[127:64]};
                if (tb_mul_result != result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h * %h = %h, output: %h",src1,src2,result,tb_mul_result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

task automatic check_test;
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
            test_sim_1(tmp);
            check_test(1,tmp);
            test_sim_2(tmp);
            check_test(2,tmp);
            test_sim_3(tmp);
            check_test(3,tmp);
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
`default_nettype wire
