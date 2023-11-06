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

    parameter VERBOSE = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
    parameter LENGTH_RAS = 4;

    // Input
    reg tb_clk_i;
    reg tb_rstn_i;
    
    addrPC_t tb_pc_fetch_i;
    addrPC_t tb_pc_execution_i;
    addrPC_t tb_branch_addr_result_exec_i;
    reg tb_branch_taken_result_exec_i;
    reg tb_is_branch_EX_i;

    // Output
    reg tb_branch_predict_is_branch_o;
    reg tb_branch_predict_taken_o;
    addrPC_t tb_branch_predict_addr_o;


    ////////////////////////////////////////
    // MODULE
    ///////////////////////////////////////

    branch_predictor module_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .pc_fetch_i(tb_pc_fetch_i),
        .pc_execution_i(tb_pc_execution_i),
        .branch_addr_result_exec_i(tb_branch_addr_result_exec_i),
        .branch_taken_result_exec_i(tb_branch_taken_result_exec_i),
        .is_branch_EX_i(tb_is_branch_EX_i),
        .branch_predict_is_branch_o(tb_branch_predict_is_branch_o),
        .branch_predict_taken_o(tb_branch_predict_taken_o),
        .branch_predict_addr_o(tb_branch_predict_addr_o)
    );


    ////////////////////////////////////////
    // MEMORY TO READ FILES
    ////////////////////////////////////////

    logic [39:0] pc_table     [0:4096];
    logic [1:0]  taken_table  [0:4096];
    logic [39:0] target_table [0:4096];


    ////////////////////////////////////////
    // DUT
    ////////////////////////////////////////

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


    // Set default values
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <= '{default:1};
            tb_pc_fetch_i <= '{default:0};
            tb_pc_execution_i <= '{default:0};
            tb_branch_addr_result_exec_i <= '{default:0};
            tb_branch_taken_result_exec_i <= '{default:0};
            tb_is_branch_EX_i <= '{default:0};
            $display("Done");
         end
    endtask


    //***task automatic init_dump***
    //This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
    //If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("tb_module.vcd");
            $dumpvars(0,module_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

    /***task automatic test_sim***/
    task automatic test_sim;
        begin
            $display("*** test_sim");
            // check initial state
            test_sim_1();
            // check branch preiction stores past branches in BTB, PHT and is_branch
            test_sim_2();
            // check state machine works
            test_sim_3();
            // Test that all entries are not valid and set to zero
            test_sim_4();
        end
    endtask

    // Test that all entries are not valid and set to zero
    // Output should be nothing
    task automatic test_sim_1;
        begin
            tick();
            // Assert Loop
            //for (int j = 0; j < 1024; j++) begin
            //    tb_pc_fetch_i <= { 6'b0, j, 2'b00};
            //    assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b10);  // State machine is set to default '10' or "soft taken"
            //    assert (tb_branch_predict_is_branch_o == 0);                            // BP says pc is not a branch
            //    tick();
            //end
            $display("Test 1 END");
        end
    endtask

    // Test that all structures are able to store values
    // Output should be nothing
    task automatic test_sim_2;
        begin
            tick();
            // Assert Loop
            for (int j = 0; j < 64; j++) begin
                // Read pc_fetch
                tb_pc_execution_i <= { 30'b0, (j + j*64), 2'b00};
                tb_is_branch_EX_i <= 1'b1;
                tb_branch_taken_result_exec_i <= 1'b1;
                tb_branch_addr_result_exec_i <= {30'b0, j + 1, 2'b00};
                tick();
                tb_pc_execution_i <= 'h0;
                tb_is_branch_EX_i <= 1'b0;
                tb_branch_taken_result_exec_i <= 1'b0;
                tb_branch_addr_result_exec_i <= 'h0;
                
                // Write update branch
                tb_pc_fetch_i <= { 30'b0, (j + j*64), 2'b00};
                tick();
                tick();
                
                // Asserts are done half cycle after the read because of delta cycles
                assert (tb_branch_predict_is_branch_o == 1'b1);                        // Is not a branch
                assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11); // Machine is updated to '11' or "hard taken"
                assert (tb_branch_predict_addr_o == {30'b0, j + 1, 2'b00});                // Check Target prediction
                assert (tb_branch_predict_taken_o == 1'b1);                             // Is predict taken
            end
            tick();
            tb_pc_execution_i <= 'h0;
            tb_is_branch_EX_i <= 1'b0;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= 'h0;
            tick();

            $display("Test 2 END");
        end
    endtask

    // Test that all structures are able to store values
    // Output should be nothing
    task automatic test_sim_3;
        begin
            // CHECK THAT ADDRESS 0 state machine is equal to 11
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h0, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            // UPDATE ADDRESS 0 state machine to 10
            tb_pc_execution_i <= { 30'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= {30'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 10
            tick();
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b10);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            tick();
            // UPDATE ADDRESS 0 state machine to 10
            tb_pc_execution_i <= { 30'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= {30'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 01
            tick();
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b01);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b0);

            tick();
            // UPDATE ADDRESS 0 state machine to 00
            tb_pc_execution_i <= { 30'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= {30'b0, 32'h1, 2'b00};s

            // CHECK THAT ADDRESS 0 state machine is equal to 00
            tick();
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b00);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b0);

            tick();
            // UPDATE ADDRESS 0 state machine to 00
            tb_pc_execution_i <= { 30'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= {30'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 00
            tick();
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b00);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b0);

            tick();
            tick();
            // UPDATE ADDRESS 0 state machine to 01
            tb_pc_execution_i <= { 30'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b1;
            tb_branch_addr_result_exec_i <= {30'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 01
            tick();
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b01);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b0);

            tick();
            // UPDATE ADDRESS 0 state machine to 10
            tb_pc_execution_i <= { 30'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b1;
            tb_branch_addr_result_exec_i <= {30'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 10
            tick();
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b10);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            tick();
            // UPDATE ADDRESS 0 state machine to 11
            tb_pc_execution_i <= { 30'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b1;
            tb_branch_addr_result_exec_i <= { 30'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 11
            tick();
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            tick();
            // UPDATE ADDRESS 0 state machine to 11
            tb_pc_execution_i <= { 30'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b1;
            tb_branch_addr_result_exec_i <= {30'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 11 SATURATION WORKS
            tick();
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 30'b0, 32'h0, 2'b00};
            tick();
            tick();
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11);
            assert (tb_branch_predict_addr_o == {30'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            $display("Test 3 END");
        end
    endtask

    // Test that all entries are not valid and set to zero
    // Output should be nothing
    task automatic test_sim_4;
        begin
            int hit_is_predict = 0;
            int hit_taken = 0;
            int hit_target = 0;

            // Load trace files
            $readmemh("trace_pc.hex", pc_table);
            $readmemh("trace_taken.hex", taken_table);
            $readmemh("trace_target.hex", target_table);


            // Prologue to loop
            tb_pc_fetch_i <= pc_table[0];
            tick();
            tb_pc_fetch_i <= pc_table[1];
            #CLK_HALF_PERIOD
            if (tb_branch_predict_is_branch_o) begin
                hit_is_predict++;
                if (tb_branch_predict_taken_o == taken_table[0]) begin
                    hit_taken++;
                    if (tb_branch_predict_addr_o == target_table[0]) begin
                        hit_target++;
                    end
                end
            end
            #CLK_HALF_PERIOD
                    
            tb_pc_fetch_i <= pc_table[2];
            #CLK_HALF_PERIOD
            if (tb_branch_predict_is_branch_o) begin
                hit_is_predict++;
                if (tb_branch_predict_taken_o == taken_table[1]) begin
                    hit_taken++;
                    if (tb_branch_predict_addr_o == target_table[1]) begin
                        hit_target++;
                    end
                end
            end
            #CLK_HALF_PERIOD

            // For each branch compute prediction and update
            for (int i = 3; i < 4096; i++) begin
                tb_pc_fetch_i <= pc_table[i];
                #CLK_HALF_PERIOD
                tb_pc_execution_i <= pc_table[i-3];
                tb_is_branch_EX_i <= 1'b1;
                tb_branch_taken_result_exec_i <= taken_table[i-3];
                tb_branch_addr_result_exec_i <= target_table[i-3];

                if (tb_branch_predict_is_branch_o) begin
                    hit_is_predict++;
                    if (tb_branch_predict_taken_o == taken_table[i-1]) begin
                        hit_taken++;
                        if (tb_branch_predict_addr_o == target_table[i-1]) begin
                            hit_target++;
                        end
                    end
                end
                #CLK_HALF_PERIOD;
            end

            #CLK_HALF_PERIOD
            if (tb_branch_predict_is_branch_o) begin
                hit_is_predict++;
                if (tb_branch_predict_taken_o == taken_table[1023]) begin
                    hit_taken++;
                    if (tb_branch_predict_addr_o == target_table[1023]) begin
                        hit_target++;
                    end
                end
            end

            $display("Hits is_predict %i", hit_is_predict);
            $display("Hits taken %i", hit_taken);
            $display("Hits target %i", hit_target);
            $display("Accuracy %f",  (hit_target / 4096.0));
            $display("Test 4 END");
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

