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
import fpuv_pkg::*;
import fpuv_wrapper_pkg::*;

module tb_fpu();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

//-----------------------------
// Signals
//-----------------------------
// Inputs
logic               tb_clk_i;
logic               tb_rstn_i;
bus64_t             tb_src1_data_i;
bus64_t             tb_src2_data_i;
bus64_t             tb_src3_data_i;
std_element_width_e tb_sew_i;
logic               tb_lsw_valid_i;
logic               tb_masked_op_i;
logic [8 - 1 : 0]   tb_mask_bits_i;
logic [1 : 0]       tb_inactive_element_select_i; 
roundmode_e         tb_rnd_mode_i;
opcode_e            tb_opcode_funct6_i;
opcode_unary_e      tb_opcode_vs1_i;
logic               tb_valid_op_i;
logic               tb_kill_i;
// Outputs
logic               tb_in_ready_o;
logic               tb_result_valid_o;
bus64_t            tb_result_data_o;
status_t            tb_status_o;

reg[64*8:0] tb_test_name;


//-----------------------------
// Module
//-----------------------------

fpuv_wrapper fpuv_wrapper_inst (
    .clk_i(tb_clk_i),
    .rsn_i(tb_rstn_i),
    .sew_i(1'b0),
    .rnd_mode_i(tb_rnd_mode_i ),
    .valid_op_i(tb_valid_op_i),
    .opcode_funct6_i(tb_opcode_funct6_i),
    .opcode_vs1_i(tb_opcode_vs1_i),
    .masked_op_i(tb_masked_op_i),
    .inactive_element_select_i(fpu_old_dest_location ),
    .mask_bits_i(tb_mask_bits_i),
    .src1_data_i(tb_src1_data_i),
    .src2_data_i(tb_src2_data_i),
    .src3_data_i(tb_src3_data_i),
    .lsw_valid_i(tb_lsw_valid_i),

    .in_ready_o(tb_in_ready_o),
    .result_valid_o(tb_result_valid_o),
    .result_data_o(tb_result_data_o),
    .status_o(tb_status_o),
    .kill_i(tb_kill_i)
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
            // inputs
            tb_valid_op_i<='{default:0};
            tb_opcode_funct6_i<='{default:0};
            tb_opcode_vs1_i<='{default:0};
            tb_masked_op_i<='{default:0};
            tb_inactive_element_select_i<='{default:0};
            tb_mask_bits_i<='{default:0};
            tb_src1_data_i<='{default:0};
            tb_src2_data_i<='{default:0};
            tb_src3_data_i<='{default:0};
            tb_lsw_valid_i<='{default:0};
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
            $dumpvars(0,fpuv_wrapper_inst);
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
            /*test_sim_2(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 2 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 2 PASSED.");
                `END_COLOR_PRINT
            end*/
        end
    endtask


// Test performs division and remanent on unsigned 32 bit operands
    task automatic test_sim_1;
        output int tmp;
        begin
            tb_test_name = "test_sim_1";
            tmp = 0;
            //for(int i = 0; i < 1; i++) begin
            tb_src1_data_i = 64'h0000_0000_0000_0000;
            tb_src2_data_i = 64'h0000_0000_0000_0000;
            tb_src3_data_i = 64'h0000_0000_0000_0000;

            tb_sew_i = '{default:0};
            tb_lsw_valid_i = 1'b0;
            tb_masked_op_i = 0;
            tb_mask_bits_i = 0;
            tb_inactive_element_select_i = BINARY64; 
            tb_rnd_mode_i = RNE;
            tb_opcode_funct6_i = OP_VFADD;
            tb_opcode_vs1_i = '{default:0};
            tb_valid_op_i = 1'b1;
            tb_kill_i = 1'b0;

            #CLK_PERIOD;
            for(int i = 0; i < 17; i++)begin
                #CLK_PERIOD;
            end
                /*
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
                end*/
            //end
        end
    endtask


// Test performs division and remanent on unsigned 64 bit operands 
   /* task automatic test_sim_2;
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
    endtask*/

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
