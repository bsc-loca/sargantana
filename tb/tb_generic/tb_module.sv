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
reg tb_load_i;
logic bus32_t tb_inst;
logic bus32_t tb_inst_o;

//-----------------------------
// Module
//-----------------------------

mod module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .load_i(tb_load_i),
    .input_i(tb_inst),
    .output_o(tb_inst_o),
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
            tb_load_i<='{default:0};
            tb_inst<='{default:0};
            tb_inst_o<='{default:0};
            $display("Done");
        end
    endtask

//***task automatic init_dump***
//This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
//If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("dum_file.vcd");
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
        end
    endtask

//ReadCheck: assert (data === correct_data)
//               else $error("memory read error");
//  Igt10: assert (I > 10)
//           else $warning("I is less than or equal to 10");

    task automatic set_srcs;
        input int unsigned src1;
        input int unsigned src2;
        begin
            tb_src1_i  <= src1;
            tb_src2_i  <= src2;
        end
    endtask

// Test getting a petition that is not valid
// Output should be nothing 
    task automatic test_sim_1;
        output int tmp;
        begin
            tmp = 0;
            $random(10);
            for(int i = 0; i < 1000; i++) begin
                int unsigned src1 = $urandom();
                int unsigned src2 = $urandom();
                set_srcs(src1,src2);
                #CLK_HALF_PERIOD;
                if (tb_div_o != (src1/src2) | tb_rem_o != (src1%src2)) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h / %h = %h mod %h out: %h mod %h",src1,src2,(src1/src2),(src1%src2),tb_div_o,tb_rem_o);
                    `END_COLOR_PRINT
                end
                #CLK_HALF_PERIOD;
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
    end


endmodule
`default_nettype wire

