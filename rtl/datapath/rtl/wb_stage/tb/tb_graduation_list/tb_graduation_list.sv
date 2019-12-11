//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_graduation_list.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : David Álvarez
* Email(s)       : david.alvarez@bsc.es
* References     :
*/

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
//`default_nettype none

`include "colors.vh"
//`include "../definitions.v"

import riscv_pkg::*;
import drac_pkg::*;

module tb_graduation_list();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
    parameter NUM_PORTS       = 1;
    parameter GL_ENTRIES      = 32;
//***DUT parameters***
    //parameter TB_DATA_WIDTH = 32;
    //parameter TB_WEIGHTS_WIDTH = 7;
    //parameter TB_N_CORES = 1;
    //parameter TB_CORE_EVENTS = 1;

//-----------------------------
// Signals
//-----------------------------
reg                             tb_clk_i;
reg                             tb_rstn_i;
rob_instruction_in_interface_t  tb_instruction_i[NUM_PORTS];
logic                           tb_read_head_i;
logic                           tb_read_tail_i;
rob_index                       tb_instruction_writeback_i;
logic                           tb_instruction_writeback_enable_i;
rob_index                       tb_instruction_exc_i;
logic                           tb_instruction_exc_enable_i;
exception_t                     tb_instruction_exc_data_i;
rob_index                       tb_assigned_rob_entry_o[NUM_PORTS];
rob_instruction_in_interface_t  tb_instruction_o[NUM_PORTS];
reg                             tb_full_o;
reg                             tb_empty_o;

//-----------------------------
// Module
//-----------------------------

graduation_list module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .instruction_i(tb_instruction_i),
    .read_head_i(tb_read_head_i),
    .read_tail_i(tb_read_tail_i),
    .instruction_writeback_i(tb_instruction_writeback_i),
    .instruction_writeback_enable_i(tb_instruction_writeback_enable_i),
    .instruction_exc_i(tb_instruction_exc_i),
    .instruction_exc_enable_i(tb_instruction_exc_enable_i),
    .instruction_exc_data_i(tb_instruction_exc_data_i),
    .assigned_rob_entry_o(tb_assigned_rob_entry_o),
    .instruction_o(tb_instruction_o),
    .full_o(tb_full_o),
    .empty_o(tb_empty_o)
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
            #CLK_PERIOD;
            #CLK_PERIOD;
            tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            $display("Done");
        end
    endtask

//***task automatic init_sim***
//This is an empty structure for initializing your testbench, consider how the real hardware will behave instead of set all to zero as the initial state. Remove the TODO label and start writing.
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};
            tb_instruction_i[0] <= '{default: 0};
            tb_read_head_i <= '{default:0};
            tb_read_tail_i <= '{default:0};
            tb_instruction_writeback_i <= '{default:0};
            tb_instruction_writeback_enable_i <= '{default:0};
            tb_instruction_exc_i <= '{default:0};
            tb_instruction_exc_enable_i <= '{default:0};
            tb_instruction_exc_data_i <= '{default:0};
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
//This is an empty structure for a test. Remove the TODO label and start writing, several tasks can be used.
    task automatic test_sim;
        begin
            $display("*** test_sim");
            test_sim_1();
            test_sim_2();
            test_sim_3();
            test_sim_4();
            test_sim_5();
            $display("*** finished tests. Please check for assertion failures");
        end
    endtask

// Test getting a petition that is not valid
// Output should be nothing
    task automatic test_sim_1;
        begin
            $display("Testing GL is empty to begin");
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;
            assert(tb_full_o == 0);
            assert(tb_empty_o == 1);
        end
    endtask

// Test getting a petition that is not valid
// Output should be nothing
    task automatic test_sim_2;
        begin
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;

            // Now let's fill this with instructions
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_full_o == 0);

                tb_instruction_i[0] = {
                    1'b1,
                    reg_t'(1),
                    reg_t'(1),
                    reg_t'(1),
                    addr_t'(i),
                    1'b0,
                    exception_t'(0)
                };
                #CLK_PERIOD;

                assert(tb_assigned_rob_entry_o[0] == rob_index'(i));
            end

            assert(tb_full_o == 1);
            // Disable writing
            tb_instruction_i[0].valid = 1'b0;
            #CLK_PERIOD;

            // Enable reading
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;

            // We do the assertions one cycle after because we're dealing with flops in instruction_o
            // Recover the instructions. This is a FIFO, so we want to check everything is in the same order.
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_empty_o == 0);
                #CLK_PERIOD;

                // We haven't marked it as valid!
                assert(tb_instruction_o[0].valid == 0);
                assert(tb_instruction_o[0].destination_register == 1);
                assert(tb_instruction_o[0].source_register_1 == 1);
                assert(tb_instruction_o[0].source_register_2 == 1);
                assert(tb_instruction_o[0].program_counter == addr_t'(i));
                assert(tb_instruction_o[0].exception == 0);
                assert(tb_full_o == 0);
            end

            assert(tb_empty_o == 1);
        end
    endtask


// Test getting a petition that is not valid
// Output should be nothing
    task automatic test_sim_3;
        begin
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;
            assert(tb_empty_o == 1);
            #CLK_PERIOD;

            // Now let's fill this with instructions
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_full_o == 0);

                tb_instruction_i[0] = {
                    1'b1,
                    reg_t'(1),
                    reg_t'(1),
                    reg_t'(1),
                    addr_t'(i),
                    1'b0,
                    exception_t'(0)
                };
                #CLK_PERIOD;

                assert(tb_assigned_rob_entry_o[0] == rob_index'(i));
            end

            assert(tb_full_o == 1);
            // Disable writing
            tb_instruction_i[0].valid = 1'b0;
            #CLK_PERIOD;

            tb_instruction_writeback_enable_i <= 1'b1;

            // Mark everything as valid (finished)
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                tb_instruction_writeback_i <= rob_index'(i);
                #CLK_PERIOD;
            end

            tb_instruction_writeback_enable_i <= 1'b0;

            // Enable reading
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;

            // We do the assertions one cycle after because we're dealing with flops in instruction_o
            // Recover the instructions. This is a FIFO, so we want to check everything is in the same order.
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_empty_o == 0);
                #CLK_PERIOD;

                assert(tb_instruction_o[0].valid == 1);
                assert(tb_instruction_o[0].destination_register == 1);
                assert(tb_instruction_o[0].source_register_1 == 1);
                assert(tb_instruction_o[0].source_register_2 == 1);
                assert(tb_instruction_o[0].program_counter == addr_t'(i));
                assert(tb_instruction_o[0].exception == 0);
                assert(tb_full_o == 0);
            end

            assert(tb_empty_o == 1);
        end
    endtask

// Test getting a petition that is not valid
// Output should be nothing
    task automatic test_sim_4;
        begin
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;
            assert(tb_empty_o == 1);
            #CLK_PERIOD;

            // Now let's fill this with instructions
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_full_o == 0);

                tb_instruction_i[0] = {
                    1'b1,
                    reg_t'(1),
                    reg_t'(1),
                    reg_t'(1),
                    addr_t'(i),
                    1'b0,
                    exception_t'(0)
                };
                #CLK_PERIOD;

                assert(tb_assigned_rob_entry_o[0] == rob_index'(i));
            end

            assert(tb_full_o == 1);
            // Disable writing
            tb_instruction_i[0].valid = 1'b0;
            #CLK_PERIOD;

            tb_instruction_exc_enable_i <= 1'b1;

            // Mark everything as exception
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                tb_instruction_exc_i <= rob_index'(i);
                tb_instruction_exc_data_i <= {
                    INSTR_ACCESS_FAULT,
                    addrPC_t'(i),
                    1'b1
                };
                #CLK_PERIOD;
            end

            tb_instruction_exc_enable_i <= 1'b0;

            // Enable reading
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;

            // We do the assertions one cycle after because we're dealing with flops in instruction_o
            // Recover the instructions. This is a FIFO, so we want to check everything is in the same order.
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_empty_o == 0);
                #CLK_PERIOD;

                // Setting an exception marks this as valid.
                assert(tb_instruction_o[0].valid == 1);
                assert(tb_instruction_o[0].destination_register == 1);
                assert(tb_instruction_o[0].source_register_1 == 1);
                assert(tb_instruction_o[0].source_register_2 == 1);
                assert(tb_instruction_o[0].program_counter == addr_t'(i));
                assert(tb_instruction_o[0].exception == 1);
                assert(tb_instruction_o[0].exception_data.valid == 1);
                assert(tb_instruction_o[0].exception_data.cause == INSTR_ACCESS_FAULT);
                assert(tb_instruction_o[0].exception_data.origin == addrPC_t'(i));
                assert(tb_full_o == 0);
            end

            assert(tb_empty_o == 1);
        end
    endtask

    task automatic test_sim_5;
        begin
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;
            assert(tb_empty_o == 1);
            #CLK_PERIOD;

            // Now let's fill this with instructions
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_full_o == 0);

                tb_instruction_i[0] = {
                    1'b1,
                    reg_t'(1),
                    reg_t'(1),
                    reg_t'(1),
                    addr_t'(i),
                    1'b0,
                    exception_t'(0)
                };
                #CLK_PERIOD;

                assert(tb_assigned_rob_entry_o[0] == rob_index'(i));
            end

            assert(tb_full_o == 1);
            // Disable writing
            tb_instruction_i[0].valid = 1'b0;
            #CLK_PERIOD;

            // Enable reading _backwards_
            tb_read_tail_i <= 1'b1;
            #CLK_PERIOD;

            // We do the assertions one cycle after because we're dealing with flops in instruction_o
            // Recover the instructions. Should be LIFO as we're reading backwards.
            for(int i = GL_ENTRIES - 1; i >= 0; --i) begin
                assert(tb_empty_o == 0);
                #CLK_PERIOD;

                // Should not be valid
                assert(tb_instruction_o[0].valid == 0);
                assert(tb_instruction_o[0].destination_register == 1);
                assert(tb_instruction_o[0].source_register_1 == 1);
                assert(tb_instruction_o[0].source_register_2 == 1);
                assert(tb_instruction_o[0].program_counter == addr_t'(i));
                assert(tb_instruction_o[0].exception == 0);
                assert(tb_full_o == 0);
            end

            assert(tb_empty_o == 1);
            tb_read_tail_i <= 1'b0;
            #CLK_PERIOD;
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
//`default_nettype wire
