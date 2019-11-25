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

module tb_rename_table();

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

    logic [4:0] tb_read_src1_i;
    logic [4:0] tb_read_src2_i;
    logic [4:0] tb_old_dst_i;

    logic tb_write_dst_i;
    logic [5:0] tb_new_dst_i;

    logic tb_do_checkpoint_i;
    logic tb_do_recover_i;
    logic tb_delete_checkpoint_i;
    logic [1:0] tb_recover_checkpoint_i;
    logic [1:0] tb_checkpoint_o;
    logic tb_out_of_checkpoints_o;

    logic [5:0] tb_src1_o;
    logic [5:0] tb_src2_o;
    logic [5:0] tb_old_dst_o;

//-----------------------------
// Module
//-----------------------------

    rename_table rename_table_inst(
        .clk_i(tb_clk_i),               
        .rstn_i(tb_rstn_i),             
        .read_src1_i(tb_read_src1_i),   
        .read_src2_i(tb_read_src2_i),
        .old_dst_i(tb_old_dst_i),
        .write_dst_i(tb_write_dst_i),
        .new_dst_i(tb_new_dst_i),
        .do_checkpoint_i(tb_do_checkpoint_i),
        .do_recover_i(tb_do_recover_i),
        .delete_checkpoint_i(tb_delete_checkpoint_i),
        .recover_checkpoint_i(tb_recover_checkpoint_i),           
        .src1_o(tb_src1_o),
        .src2_o(tb_src2_o),
        .old_dst_o(tb_old_dst_o),
        .checkpoint_o(tb_checkpoint_o),
        .out_of_checkpoints_o(tb_out_of_checkpoints_o)
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
            tb_read_src1_i<='{default:0};
            tb_read_src2_i<='{default:0};
            tb_old_dst_i<='{default:0};
            tb_write_dst_i<='{default:0};
            tb_new_dst_i<='{default:0};

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
            $dumpvars(0,rename_table_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask


// Check reset of renaming table
    task automatic test_sim_1;
        output int tmp;
        begin
            tmp = 0;
            #CLK_PERIOD;
            assert(tb_out_of_checkpoints_o == 0) else begin tmp++; assert(1 == 0); end
    
            for (int i=0; i<32; i++) begin
                assert(rename_table_inst.register_table[i][0] == i ) else begin tmp++; assert(1 == 0); end
            end

            assert(rename_table_inst.version_head == 0) else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.version_tail == 0) else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.num_checkpoints == 0) else begin tmp++; assert(1 == 0); end
            #CLK_PERIOD;

        end
    endtask

// Reads mapping of ISA registers to Physical and renames all register mapping
// No checkpointing involved
    task automatic test_sim_2;
        output int tmp;
        begin
            for(int i=0; i<32; i++) begin            // Reads 32 registers mapping
                tb_read_src1_i <= i[4:0];
                tb_read_src2_i <= i[4:0];
                tb_old_dst_i <= i[4:0]; 
                tick();
                tb_read_src1_i <= 5'h0;
                tb_read_src2_i <= 5'h0;
                tb_old_dst_i <= 5'h0; 
                tick();
                assert(tb_src1_o == i[4:0]) else begin tmp++; assert(1 == 0); end
                assert(tb_src2_o == i[4:0]) else begin tmp++; assert(1 == 0); end
                assert(tb_old_dst_o == i[4:0]) else begin tmp++; assert(1 == 0); end

                assert(rename_table_inst.version_head == 0) else begin tmp++; assert(1 == 0); end
                assert(rename_table_inst.version_tail == 0) else begin tmp++; assert(1 == 0); end
                assert(rename_table_inst.num_checkpoints == 0) else begin tmp++; assert(1 == 0); end
            end

            for(int i=0; i<32; i++) begin            // Reads a register and renames it
                tb_read_src1_i <= i[4:0];
                tb_read_src2_i <= i[4:0];
                tb_old_dst_i <= i[4:0];
                tb_write_dst_i <= 1'b1;
                tb_new_dst_i <= {1'b1,i[4:0]};
                tick();
                tb_read_src1_i <= 5'h0;
                tb_read_src2_i <= 5'h0;
                tb_old_dst_i <= 5'h0;
                tb_write_dst_i <= 1'b0;
                tb_new_dst_i <= 6'h0;
                tick();
                assert(tb_src1_o == i[4:0]) else begin tmp++; assert(1 == 0); end
                assert(tb_src2_o == i[4:0]) else begin tmp++; assert(1 == 0); end
                assert(tb_old_dst_o == i[4:0]) else begin tmp++; assert(1 == 0); end

                assert(rename_table_inst.version_head == 0) else begin tmp++; assert(1 == 0); end
                assert(rename_table_inst.version_tail == 0) else begin tmp++; assert(1 == 0); end
                assert(rename_table_inst.num_checkpoints == 0) else begin tmp++; assert(1 == 0); end
            end

            assert(tb_out_of_checkpoints_o == 0) else begin tmp++; assert(1 == 0); end
    
            for (int i=0; i<32; i++) begin
                assert(rename_table_inst.register_table[i][0] == i + 32) else begin tmp++; assert(1 == 0); end
            end

            assert(rename_table_inst.version_head == 0) else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.version_tail == 0) else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.num_checkpoints == 0) else begin tmp++; assert(1 == 0); end
            
        end
    endtask

// Checkpointing test
    task automatic test_sim_3;
        output int tmp;
        begin
            // We DO A CHECKPOINT
            tb_do_checkpoint_i <= 1'b1;

            tick();

            tb_do_checkpoint_i <= 1'b0;

            // Tick for ASSERTS

            tick();

            assert(tb_out_of_checkpoints_o == 0) else begin tmp++; assert(1 == 0); end
    
            for (int i=0; i<32; i++) begin
                assert(rename_table_inst.register_table[i][0] == i + 32) else begin tmp++; assert(1 == 0); end
            end

            assert(rename_table_inst.version_head == 1) else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.version_tail == 0) else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.num_checkpoints == 1) else begin tmp++; assert(1 == 0); end

            // Check new version pointers and state
            for (int i=0; i<32; i++) begin
                assert(rename_table_inst.register_table[i][1] == i + 32) else begin tmp++; assert(1 == 0); end
            end
            
            // Check checkpoint label is correct
            assert(tb_checkpoint_o == 0)  else begin tmp++; assert(1 == 0); end

            // Renames 16 registers

            for(int i=0; i<32; i+=2) begin

                tb_read_src1_i <= i[4:0];
                tb_read_src2_i <= i[4:0];
                tb_old_dst_i <= i[4:0];
                tb_write_dst_i <= 1'b1;
                tb_new_dst_i <= {1'b0,i[4:0]};
                tick();

                tb_read_src1_i <= 5'h0;
                tb_read_src2_i <= 5'h0;
                tb_old_dst_i <= 5'h0;
                tb_write_dst_i <= 1'b0;
                tb_new_dst_i <= 6'h0;
                tick();

                assert(tb_src1_o == i[4:0] + 32 ) else begin tmp++; assert(1 == 0); end
                assert(tb_src2_o == i[4:0] + 32 ) else begin tmp++; assert(1 == 0); end
                assert(tb_old_dst_o == i[4:0] + 32 ) else begin tmp++; assert(1 == 0); end

                assert(rename_table_inst.version_head == 1) else begin tmp++; assert(1 == 0); end
                assert(rename_table_inst.version_tail == 0) else begin tmp++; assert(1 == 0); end
                assert(rename_table_inst.num_checkpoints == 1) else begin tmp++; assert(1 == 0); end
            end


            // Tick for ASSERTS

            tick();

            // Check old version  state
            for (int i=0; i<32; i++) begin
                assert(rename_table_inst.register_table[i][0] == i + 32 ) else begin tmp++; assert(1 == 0); end
            end

            // Check new version  state
            for (int i=0; i<32; i++) begin
                if (i%2 == 0) 
                    assert(rename_table_inst.register_table[i][1] == i ) else begin tmp++; assert(1 == 0); end
                else
                    assert(rename_table_inst.register_table[i][1] == i + 32) else begin tmp++; assert(1 == 0); end
            end 

            // Check checkpoints pointers state
            assert(rename_table_inst.version_head == 1)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.version_tail == 0)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.num_checkpoints == 1)  else begin tmp++; assert(1 == 0); end
  
            // We DO A SECOND CHECKPOINT
            tb_do_checkpoint_i <= 1'b1;

            tick();

            tb_do_checkpoint_i <= 1'b0;

            // Tick for ASSERTS

            tick();

            // Check old version state
            for (int i=0; i<32; i++) begin
                if (i%2 == 0) 
                    assert(rename_table_inst.register_table[i][1] == i ) else begin tmp++; assert(1 == 0); end
                else
                    assert(rename_table_inst.register_table[i][1] == i + 32) else begin tmp++; assert(1 == 0); end
            end

            // Check new version state
            for (int i=0; i<32; i++) begin
                if (i%2 == 0) 
                    assert(rename_table_inst.register_table[i][2] == i ) else begin tmp++; assert(1 == 0); end
                else
                    assert(rename_table_inst.register_table[i][2] == i + 32) else begin tmp++; assert(1 == 0); end
            end 

            // Check checkpoints pointers state
            assert(rename_table_inst.version_head == 2)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.version_tail == 0)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.num_checkpoints == 2)  else begin tmp++; assert(1 == 0); end
            
            // Check checkpoint label is correct
            assert(tb_checkpoint_o == 1)  else begin tmp++; assert(1 == 0); end

            tick();

            // Renames 16 registers
            for(int i=1; i<32; i+=2) begin
                tb_read_src1_i <= i[4:0];
                tb_read_src2_i <= i[4:0];
                tb_old_dst_i <= i[4:0];
                tb_write_dst_i <= 1'b1;
                tb_new_dst_i <= {1'b0,i[4:0]};
                tick();

                tb_read_src1_i <= 5'h0;
                tb_read_src2_i <= 5'h0;
                tb_old_dst_i <= 5'h0;
                tb_write_dst_i <= 1'b0;
                tb_new_dst_i <= 6'h0;
                tick();

                assert(tb_src1_o == i[4:0] + 32 ) else begin tmp++; assert(1 == 0); end
                assert(tb_src2_o == i[4:0] + 32 ) else begin tmp++; assert(1 == 0); end
                assert(tb_old_dst_o == i[4:0] + 32 ) else begin tmp++; assert(1 == 0); end

                assert(rename_table_inst.version_head == 2) else begin tmp++; assert(1 == 0); end
                assert(rename_table_inst.version_tail == 0) else begin tmp++; assert(1 == 0); end
                assert(rename_table_inst.num_checkpoints == 2) else begin tmp++; assert(1 == 0); end
            end

            // Free Checkpoint

            tb_delete_checkpoint_i <= 1'b1;
            tick();
 
            tb_delete_checkpoint_i <= 1'b0;
            // Tick for ASSERTS

            tick();
            

            // Check old version state
            for (int i=0; i<32; i++) begin
                if (i%2 == 0) 
                    assert(rename_table_inst.register_table[i][1] == i ) else begin tmp++; assert(1 == 0); end
                else
                    assert(rename_table_inst.register_table[i][1] == i + 32) else begin tmp++; assert(1 == 0); end
            end

            // Check new version state
            for (int i=0; i<32; i++) begin
                assert(rename_table_inst.register_table[i][2] == i) else begin tmp++; assert(1 == 0); end
            end 

            // Check checkpoints pointers state
            assert(rename_table_inst.version_head == 2)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.version_tail == 1)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.num_checkpoints == 1)  else begin tmp++; assert(1 == 0); end
            
            // Check checkpoint label is correct
            assert(tb_checkpoint_o == 1)  else begin tmp++; assert(1 == 0); end
          
            // Recover checkpoint number 2
            tick();
            
            tb_do_recover_i <= 1'b1;
            tb_recover_checkpoint_i <= 2'b01;            

            tick();

            tb_do_recover_i <= 1'b0;

            tick();

            // Check checpoint recover
            // Check new version state
            for (int i=0; i<32; i++) begin
                if (i%2 == 0) 
                    assert(rename_table_inst.register_table[i][1] == i ) else begin tmp++; assert(1 == 0); end
                else
                    assert(rename_table_inst.register_table[i][1] == i + 32) else begin tmp++; assert(1 == 0); end
            end 

            // Check checkpoints pointers state
            assert(rename_table_inst.version_head == 1)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.version_tail == 1)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.num_checkpoints == 0)  else begin tmp++; assert(1 == 0); end

            // Do checkpoints until run out of them

            tb_do_checkpoint_i <= 1'b1;
            
            // First
            tick();
            // Second
            tick();
            // Third
            tick();
            
            tb_do_checkpoint_i <= 1'b0;

            tick();

            // Check checkpoints pointers state
            assert(rename_table_inst.version_head == 0)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.version_tail == 1)  else begin tmp++; assert(1 == 0); end
            assert(rename_table_inst.num_checkpoints == 3)  else begin tmp++; assert(1 == 0); end
        end
    endtask



//***task automatic test_sim***
//This is an empty structure for a test.
    task automatic test_sim;
        begin
            int tmp;
            $display("*** test_sim");
            // Check reset
            test_sim_1(tmp); 
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end
            // Check renaming
            test_sim_2(tmp); 
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 2 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 2 PASSED.");
                `END_COLOR_PRINT
            end
            // Test checkpointing
            test_sim_3(tmp); 
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 3 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 3 PASSED.");
                `END_COLOR_PRINT
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
//`default_nettype wire
