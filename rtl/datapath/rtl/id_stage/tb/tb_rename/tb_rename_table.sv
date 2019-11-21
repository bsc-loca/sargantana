//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_rename.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Victor Soria Pardos
* Email(s)       : victor.soria@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Victor.SP  | 
* -----------------------------------------------
*/

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
//`default_nettype none

`include "colors.vh"

import drac_pkg::*;

module tb_free_list();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

//-----------------------------
// Signals
//-----------------------------
    reg tb_clk_i;
    reg tb_rstn_i;

    logic tb_read_head_i;
    logic tb_add_free_register_i;
    logic [5:0] tb_free_register_i;
    logic [5:0] tb_new_register_o;
    logic tb_empty_o;
    logic tb_do_checkpoint_i;
    logic tb_do_recover_i;
    logic tb_delete_checkpoint_i;
    logic [1:0] tb_recover_checkpoint_i;
    logic [1:0] tb_checkpoint_o;
    logic tb_out_of_checkpoints_o;

//-----------------------------
// Module
//-----------------------------

    rename_table rename_table_inst(
        .clk_i(tb_clk_i),               
        .rstn_i(tb_rstn_i),             
        .read_head_i(tb_read_head_i),   
        .add_free_register_i(tb_add_free_register_i),
        .free_register_i(tb_free_register_i),
        .do_checkpoint_i(tb_do_checkpoint_i),
        .do_recover_i(tb_do_recover_i),
        .delete_checkpoint_i(tb_delete_checkpoint_i),
        .recover_checkpoint_i(tb_recover_checkpoint_i),           
        .new_register_o(tb_new_register_o), 
        .checkpoint_o(tb_checkpoint_o),
        .out_of_checkpoints_o(tb_out_of_checkpoints_o),
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
            tb_read_head_i<='{default:0};
            tb_add_free_register_i<='{default:0};
            tb_free_register_i<='{default:0};
            tb_do_checkpoint_i<='{default:0};
            tb_do_recover_i<='{default:0};
            tb_delete_checkpoint_i<='{default:0};
            tb_recover_checkpoint_i<='{default:0};
            
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
            $dumpvars(0,free_list_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask


// Check reset of free list
    task automatic test_sim1();
        begin
            #CLK_PERIOD;
            assert(tb_empty_o == 0);
            assert(free_list_inst.head == 0);
            assert(free_list_inst.tail == 0);
            assert(free_list_inst.num == 32);
    
            for (int i=0; i<32; i++) begin
                assert(free_list_inst.register_table[i][0] == (i + 32));
            end

            assert(free_list_inst.version_head == 0);
            assert(free_list_inst.version_tail == 0);
            assert(free_list_inst.num_checkpoints == 0);
            #CLK_PERIOD;

        end
    endtask


// Reads some free registers and then frees other 8 registers
// No checkpointing involved
    task automatic test_sim2();
        begin
            tick();
            tb_read_head_i <= 1'b1;
            tick();
            for(int i=0; i<32; i++) begin            // Reads 32 free registers
                tick();
                if (i == 31)
                    assert(tb_empty_o == 1);
                else
                    assert(tb_empty_o == 0);
                if (i == 31)
                    assert(free_list_inst.head == 0);            
                else
                    assert(free_list_inst.head == i + 1);
                assert(free_list_inst.tail == 5'b0);
                assert(free_list_inst.num == 32 - 1 - i);
                assert(tb_new_register_o == i + 32);
            end

            tick(); // Tries to read but is empty

            assert(tb_empty_o == 1);
            assert(free_list_inst.head == 0);            
            assert(free_list_inst.tail == 5'b0);
            assert(free_list_inst.num == 0);
            assert(tb_new_register_o == 0);

            // Bypass from tail to head

            tb_free_register_i <= 5'b10101;
            tb_add_free_register_i <= 1'b1;
            tick();

            // Check Bypass
            tb_read_head_i <= 1'b0;
            tb_add_free_register_i <= 1'b0;
            tick();
            
            assert(tb_empty_o == 1);
            assert(free_list_inst.head == 5'h1);            
            assert(free_list_inst.tail == 5'h1);
            assert(free_list_inst.num == 0);
            assert(tb_new_register_o == 5'b10101);

            tick();

            for(int i=0; i<32; i++) begin            // Frees 32 registers
                tb_free_register_i <= i[5:0];
                tb_add_free_register_i <= 1'b1;

                tick();
                tb_add_free_register_i <= 1'b0;

                tick();
                assert(tb_empty_o == 0);
                assert(free_list_inst.head == 1);
                if (i > 29)
                    assert(free_list_inst.tail == 5'b00000 + i[5:0] - 30);
                else
                    assert(free_list_inst.tail == 5'b00001 + i[5:0] + 1);
                assert(free_list_inst.num == i + 1);
                assert(tb_new_register_o == 0);
            end
            
            tb_add_free_register_i <= 1'b1;
            tb_read_head_i <= 1'b0;

            assert(tb_empty_o == 0);
            assert(free_list_inst.head == 1);
            assert(free_list_inst.tail == 5'b1);
            assert(free_list_inst.num == 32);
    
            for (int i=1; i<32; i++) begin
                assert(free_list_inst.register_table[i][0] == i-1);
            end

            assert(free_list_inst.version_head == 0);
            assert(free_list_inst.version_tail == 0);
            assert(free_list_inst.num_checkpoints == 0);
        end
    endtask

//***task automatic test_sim***
//This is an empty structure for a test.
    task automatic test_sim;
        begin
            $display("*** test_sim");
            // check req valid 0
            test_sim1();
            test_sim2();
        end
    endtask


//***init_sim***
//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        `START_GREEN_PRINT                       
                $display("PASS, add one of this for each test."); 
        `END_COLOR_PRINT 
        if(VERBOSE)
                $display("Define a parameter (parameter VERBOSE=0;) and keep\n\
                messages that are not needed. Most of the times with PASS/FAIL name of the \n\
                tests is enough"); 
        `START_RED_PRINT
                $error("FAIL, add one of this for each test");
        `END_COLOR_PRINT
    end


endmodule
//`default_nettype wire
