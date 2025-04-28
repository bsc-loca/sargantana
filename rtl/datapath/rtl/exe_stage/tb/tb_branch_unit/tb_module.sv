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

instr_type_t  tb_instr_type_i;
addrPC_t      tb_pc_i;
bus64_t       tb_data_rs1_i;
bus64_t       tb_data_rs2_i;
bus64_t       tb_imm_i;
bus64_t       tb_taken_o;
addrPC_t      tb_result_o;
addrPC_t      tb_link_pc_o;

rr_exe_instr_t tb_instr_i;
exe_wb_instr_t tb_instr_o;

reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

branch_unit module_inst (
    .instruction_i(tb_instr_i),
    .data_rs1_i(tb_data_rs1_i),
    .data_rs2_i(tb_data_rs2_i),
    .instruction_o(tb_instr_o)
);

//-----------------------------
// DUT
//-----------------------------

//***task automatic init_sim***
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_instr_type_i<='{default:0};
            tb_pc_i<='{default:0};
            tb_data_rs1_i<='{default:0};
            tb_data_rs2_i<='{default:0};
            tb_imm_i<='{default:0};
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
        end
    endtask

// Testing JAL
    task automatic test_sim_1;
        output int tmp;
        begin
            longint pc,src1,src2,imm,correct_result,correct_link,correct_taken;
            tb_test_name = "test_sim_1";
            tmp = 0;
            tb_instr_type_i <= JAL;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                pc = $urandom();
                pc[63:32] = $urandom();
                imm = $urandom();
                imm[63:32] = $urandom();

                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                tb_pc_i <= pc;
                tb_imm_i <= imm;

                #CLK_PERIOD;
                correct_taken = PRED_TAKEN;
                correct_link = pc+4;
                correct_result = (pc+imm) & 64'hFFFFFFFFFFFFFFFE;
                if (tb_result_o != correct_result || tb_taken_o != correct_taken || tb_link_pc_o != correct_link) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect (output:correct) taken: %h:%h, link: %h:%h, result: %h:%h",tb_taken_o,correct_taken,tb_link_pc_o,correct_link,tb_result_o,correct_result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing JALR
    task automatic test_sim_2;
        output int tmp;
        begin
            longint pc,src1,src2,imm,correct_result,correct_link,correct_taken;
            tb_test_name = "test_sim_2";
            tmp = 0;
            tb_instr_type_i <= JALR;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                pc = $urandom();
                pc[63:32] = $urandom();
                imm = $urandom();
                imm[63:32] = $urandom();

                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                tb_pc_i <= pc;
                tb_imm_i <= imm;

                #CLK_PERIOD;
                correct_taken = PRED_TAKEN;
                correct_link = pc+4;
                correct_result = (src1 + imm) & 64'hFFFFFFFFFFFFFFFE;
                if (tb_result_o != correct_result || tb_taken_o != correct_taken || tb_link_pc_o != correct_link) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect (output:correct) taken: %h:%h, link: %h:%h, result: %h:%h",tb_taken_o,correct_taken,tb_link_pc_o,correct_link,tb_result_o,correct_result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing BEQ
    task automatic test_sim_3;
        output int tmp;
        begin
            longint pc,src1,src2,imm,correct_result,correct_link,correct_taken;
            tb_test_name = "test_sim_3";
            tmp = 0;
            tb_instr_type_i <= BEQ;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                pc = $urandom();
                pc[63:32] = $urandom();
                imm = $urandom();
                imm[63:32] = $urandom();

                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                tb_pc_i <= pc;
                tb_imm_i <= imm;

                #CLK_PERIOD;
                correct_taken = (src1 == src2) ? PRED_TAKEN : PRED_NOT_TAKEN;
                correct_link = pc+4;
                correct_result = (correct_taken == PRED_TAKEN) ? pc + imm : pc + 4;
                if (tb_result_o != correct_result || tb_taken_o != correct_taken || tb_link_pc_o != correct_link) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect (output:correct) taken: %h:%h, link: %h:%h, result: %h:%h",tb_taken_o,correct_taken,tb_link_pc_o,correct_link,tb_result_o,correct_result);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing BGE
    task automatic test_sim_4;
        output int tmp;
        begin
            longint pc,src1,src2,imm,correct_result,correct_link,correct_taken;
            tb_test_name = "test_sim_4";
            tmp = 0;
            tb_instr_type_i <= BGE;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                pc = $urandom();
                pc[63:32] = $urandom();
                imm = $urandom();
                imm[63:32] = $urandom();

                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                tb_pc_i <= pc;
                tb_imm_i <= imm;

                #CLK_PERIOD;
                correct_taken = ($signed(src1) >= $signed(src2)) ? PRED_TAKEN : PRED_NOT_TAKEN;
                correct_link = pc+4;
                correct_result = (correct_taken == PRED_TAKEN) ? pc + imm : pc + 4;
                if (tb_result_o != correct_result || tb_taken_o != correct_taken || tb_link_pc_o != correct_link) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect (output:correct) taken: %h:%h, link: %h:%h, result: %h:%h",tb_taken_o,correct_taken,tb_link_pc_o,correct_link,tb_result_o,correct_result);
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

//Internal signals assignment
    assign tb_instr_i.instr.instr_type = tb_instr_type_i;
    assign tb_instr_i.instr.pc         = tb_pc_i;
    assign tb_instr_i.instr.result     = tb_imm_i;

    assign tb_taken_o   = tb_instr_o.branch_taken;
    assign tb_result_o  = tb_instr_o.result_pc;
    assign tb_link_pc_o = tb_instr_o.result;

endmodule
//`default_nettype wire

