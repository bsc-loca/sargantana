/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : tb_module.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria
 * Email(s)       : victor.soria@bsc.es
 * References     :
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author     | Commit | Description
 * -----------------------------------------------
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
    addr_t tb_pc_fetch_i;
    addr_t tb_pc_execution_i;
    addr_t tb_branch_addr_result_exec_i;
    reg tb_branch_taken_result_exec_i;
    reg tb_is_branch_EX_i;
    logic tb_push_return_address_i;
    logic tb_pop_return_address_i;

    // Output
    reg tb_branch_predict_is_branch_o;
    reg tb_branch_predict_taken_o;
    addr_t tb_branch_predict_addr_o;


    ////////////////////////////////////////
    // MODULE
    ///////////////////////////////////////

    branch_predictor module_inst (
        .clk_i(tb_clk_i),
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
            #CLK_PERIOD;
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
            tb_push_return_address_i <= '{default:0};
            tb_pop_return_address_i <= '{default:0};
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
            for (int j = 0; j < 1024; j++) begin
                tb_pc_fetch_i <= { 6'b0, j, 2'b00};
                assert (module_inst.is_branch_valid_bit == 0);                          // Entrie is not valid
                assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b10);  // State machine is set to default '10' or "soft taken"
                assert (tb_branch_predict_is_branch_o == 0);                            // BP says pc is not a branch
                tick();
            end

            $display("Test 1 END");
        end
    endtask

    // Test that all structures are able to store values
    // Output should be nothing
    task automatic test_sim_2;
        begin
            #CLK_HALF_PERIOD;
            // Second half of the cycle branch execution unit gives result
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};                                // New branch pc. Least two bits are not taken into account
            tb_is_branch_EX_i <= 1'b1;                                                 // It is a branch
            tb_branch_taken_result_exec_i <= 1'b1;                                     // Branch was taken
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};                      // The address of the branch

            // Branch predictor stores actualization on rise edge
            #CLK_HALF_PERIOD;
            // First half of the cycle fetch PC arrives to branch predictor
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};                                    // Reads the updated branch. The prediction is available two half cycles after the read
                                                                                       // In theory the prediction should be ready in half cycle. But assertions are broken in verilog
                                                                                       // An insant in verilog can be divided in delta cycles. They are use to implement signal propagation
                                                                                       // An assert is alway executed in the cycle 0
                                                                                       // Update of signals is done in cycle 1,2,3, and so on.

            // Assert Loop
            for (int j = 1; j < 1024; j++) begin
                // Read pc_fetch
                #CLK_HALF_PERIOD;
                tb_pc_execution_i <= { 6'b0, (j + j*1024), 2'b00};
                tb_is_branch_EX_i <= 1'b1;
                tb_branch_taken_result_exec_i <= 1'b1;
                tb_branch_addr_result_exec_i <= {6'b0, j + 1, 2'b00};

                // Write update branch
                #CLK_HALF_PERIOD;
                tb_pc_fetch_i <= { 6'b0, (j + j*1024), 2'b00};

                // Asserts are done half cycle after the read because of delta cycles
                assert (module_inst.is_branch_valid_bit == 1'b1);                      // Entry in branch predictor is valid
                assert (tb_branch_predict_is_branch_o == 1'b1);                        // Is a branch
                assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11); // Machine is updated to '11' or "hard taken"
                assert (tb_branch_predict_addr_o == {6'b0, j, 2'b00});                 // Check Target prediction
                assert (tb_branch_predict_taken_o == 1'b1);                            // Is predict taken
            end
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            // Asserts are done half cycle after the read because of delta cycles
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h400, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            $display("Test 2 END");
        end
    endtask

    // Test that all structures are able to store values
    // Output should be nothing
    task automatic test_sim_3;
        begin
            // CHECK THAT ADDRESS 0 state machine is equal to 11
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            #CLK_HALF_PERIOD;
            // UPDATE ADDRESS 0 state machine to 10
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 10
            #CLK_HALF_PERIOD;
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b10);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            #CLK_HALF_PERIOD;
            // UPDATE ADDRESS 0 state machine to 10
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 01
            #CLK_HALF_PERIOD;
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b01);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b0);

            #CLK_HALF_PERIOD;
            // UPDATE ADDRESS 0 state machine to 00
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 00
            #CLK_HALF_PERIOD;
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b00);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b0);

            #CLK_HALF_PERIOD;
            // UPDATE ADDRESS 0 state machine to 00
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b0;
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 00
            #CLK_HALF_PERIOD;
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b00);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b0);

            #CLK_HALF_PERIOD;
            // UPDATE ADDRESS 0 state machine to 01
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b1;
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 01
            #CLK_HALF_PERIOD;
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b01);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b0);

            #CLK_HALF_PERIOD;
            // UPDATE ADDRESS 0 state machine to 10
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b1;
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 10
            #CLK_HALF_PERIOD;
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b10);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            #CLK_HALF_PERIOD;
            // UPDATE ADDRESS 0 state machine to 11
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b1;
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 11
            #CLK_HALF_PERIOD;
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
            assert (tb_branch_predict_taken_o == 1'b1);

            #CLK_HALF_PERIOD;
            // UPDATE ADDRESS 0 state machine to 11
            tb_pc_execution_i <= { 6'b0, 32'h0, 2'b00};
            tb_is_branch_EX_i <= 1'b1;
            tb_branch_taken_result_exec_i <= 1'b1;
            tb_branch_addr_result_exec_i <= {6'b0, 32'h1, 2'b00};

            // CHECK THAT ADDRESS 0 state machine is equal to 11 SATURATION WORKS
            #CLK_HALF_PERIOD;
            tb_is_branch_EX_i <= 1'b0;
            tb_pc_fetch_i <= { 6'b0, 32'h0, 2'b00};
            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
            assert (module_inst.is_branch_valid_bit == 1'b1);
            assert (tb_branch_predict_is_branch_o == 1'b1);
            assert (module_inst.bimodal_predictor_inst.readed_state_pht == 2'b11);
            assert (tb_branch_predict_addr_o == {6'b0, 32'h1, 2'b00});
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
            if (tb_branch_predict_is_branch_o) begin
                hit_is_predict++;
                if (tb_branch_predict_taken_o == taken_table[0]) begin
                    hit_taken++;
                    if (tb_branch_predict_addr_o == target_table[0]) begin
                        hit_target++;
                    end
                end
            end
            tb_pc_fetch_i <= pc_table[1];

            tick();
            if (tb_branch_predict_is_branch_o) begin
                hit_is_predict++;
                if (tb_branch_predict_taken_o == taken_table[1]) begin
                    hit_taken++;
                    if (tb_branch_predict_addr_o == target_table[1]) begin
                        hit_target++;
                    end
                end
            end
            tb_pc_fetch_i <= pc_table[2];

            tick();
            if (tb_branch_predict_is_branch_o) begin
                hit_is_predict++;
                if (tb_branch_predict_taken_o == taken_table[2]) begin
                    hit_taken++;
                    if (tb_branch_predict_addr_o == target_table[2]) begin
                        hit_target++;
                    end
                end
            end
            tb_pc_fetch_i <= pc_table[3];


            // For each branch compute prediction and update
            for (int i = 4; i < 4096; i++) begin

                #CLK_HALF_PERIOD;
                tb_pc_execution_i <= pc_table[i-4];
                tb_is_branch_EX_i <= 1'b1;
                tb_branch_taken_result_exec_i <= taken_table[i-4];
                tb_branch_addr_result_exec_i <= target_table[i-4];

                #CLK_HALF_PERIOD;
                if (tb_branch_predict_is_branch_o) begin
                    hit_is_predict++;
                    if (tb_branch_predict_taken_o == taken_table[i-1]) begin
                        hit_taken++;
                        if (tb_branch_predict_addr_o == target_table[i-1]) begin
                            hit_target++;
                        end
                    end
                end
                tb_pc_fetch_i <= pc_table[i];
            end

            #CLK_HALF_PERIOD;
            #CLK_HALF_PERIOD;
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
    end



endmodule
`default_nettype wire

