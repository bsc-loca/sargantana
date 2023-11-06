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


module tb_ls_queue();

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

    lsq_interface_t tb_instruction_i;

    logic tb_flush_i;
    logic tb_read_head_i;

    lsq_interface_t tb_instruction_o;

    logic [2:0] tb_ls_queue_entry_o;
    logic tb_full_o;
    logic tb_empty_o;
    

//-----------------------------
// Module
//-----------------------------

    load_store_queue load_store_queue_inst (
        .clk_i (tb_clk_i),        
        .rstn_i (tb_rstn_i),          
        .instruction_i (tb_instruction_i),         
        .flush_i (tb_flush_i),          
        .read_head_i (tb_read_head_i), 
        .instruction_o (tb_instruction_o),        
        .ls_queue_entry_o (tb_ls_queue_entry_o),       
        .full_o (tb_full_o),           
        .empty_o (tb_empty_o) 
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
    //Initializing the testbench.
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <= '{default:1};
            tb_rstn_i <= '{default:0};
            tb_instruction_i.valid <= '{default:0};
            tb_instruction_i.addr <= '{default:0};
            tb_instruction_i.data <= '{default:0};
            tb_instruction_i.mem_op <= '{default:0};
            tb_instruction_i.instr_type <= '{default:ADD};
            tb_instruction_i.funct3 <= '{default:0};
            tb_instruction_i.rd <= '{default:0};

            tb_flush_i <='{default:0};
            tb_read_head_i <='{default:0};
            $display("Done");
        end
    endtask

    //***task automatic init_dump***
    //This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
    //If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("ls_queue.vcd");
            $dumpvars(0, load_store_queue_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

    //***task automatic test_sim***
    //Run all test
    task automatic test_sim;
        begin
            $display("*** test_sim");
            test_sim_1();                 // Check initial state intialization
            test_sim_2();                 // Check all cells are writable and lsq does not override data
            test_sim_3();                 // Flush all entries
        end
    endtask


    // Test initial state and reset
    // Output should be nothing 
    task automatic test_sim_1;
        begin
            tick();
            tick();
            // Check after reset that lsq is empty
            assert(tb_instruction_o.valid == 0);
            assert(tb_empty_o == 1); 
            assert(tb_full_o == 0);
            assert(load_store_queue_inst.head == 0);
            assert(load_store_queue_inst.tail == 0);
            assert(load_store_queue_inst.num == 0);

            // Check that all entries are empty
            for (int j = 0; j < 8; j++) begin
                assert(load_store_queue_inst.control_table[j][16] == 16'h0);
            end  
        end
    endtask

    // Test write and read of all cells
    // Output should be nothing 
    task automatic test_sim_2;
        begin
            #CLK_HALF_PERIOD

            // Fill the queue
            for (int j = 0; j < 8; j++) begin
                // Write entry
                tb_instruction_i.valid <= 1'b1;
                tb_instruction_i.addr <= {8'h0, j + 1};
                tb_instruction_i.data <= {32'h0, j + 1};
                tb_instruction_i.mem_op <= MEM_STORE;
                tb_instruction_i.instr_type <= SD;
                tb_instruction_i.funct3 <= 3'b001;
                tb_instruction_i.rd <= 5'h1;
                
                tick();
                assert(tb_instruction_o.valid == 0);
                assert(tb_empty_o == 0);
                if (j != 7)
                    assert(tb_full_o == 0);
                else
                    assert(tb_full_o == 1);
                assert(load_store_queue_inst.tail == (j[2:0] + 1'b1) );
                assert(load_store_queue_inst.head == 0 );
                assert(load_store_queue_inst.num == (j[3:0] + 1'b1) ); 
                assert(tb_ls_queue_entry_o == j[2:0] );

            end

            // Leave signals as they are, to try to write with queue full
            assert(tb_full_o == 1);
            tick();
            assert(tb_instruction_o.valid == 0);
            assert(tb_empty_o == 0);
            assert(tb_full_o == 1);
            assert(load_store_queue_inst.tail == 3'b000 );
            assert(load_store_queue_inst.head == 3'b000 );
            assert(load_store_queue_inst.num  == 4'b1000); 
            assert(tb_ls_queue_entry_o == 3'b000 );

            // Read first entry and stop writting
            tb_read_head_i <= 1'b1;
            tb_instruction_i.valid <= 1'b0;
            tick();
            tb_read_head_i <= 1'b0;
            assert(tb_instruction_o.valid == 1);
            assert(tb_empty_o == 0);
            assert(tb_full_o == 0);
            assert(tb_instruction_o.addr == 40'h1);
            assert(tb_instruction_o.data == 64'h1);
            assert(tb_instruction_o.mem_op == MEM_STORE);
            assert(tb_instruction_o.instr_type == SD);
            assert(tb_instruction_o.funct3 == 3'b001);
            assert(tb_instruction_o.rd == 5'h1);
            assert(load_store_queue_inst.tail == 3'b000 );
            assert(load_store_queue_inst.head == 3'b001 );
            assert(load_store_queue_inst.num  == 4'b0111); 
            assert(tb_ls_queue_entry_o == 3'b000 );

            tick();

            // Read head entry and write head for 8 cycles
            for (int j = 0; j < 8; j++) begin
                tb_read_head_i <= 1'b1;
                tb_instruction_i.valid <= 1'b1;
                tb_instruction_i.addr <= {8'h0, j + 9};
                tb_instruction_i.data <= {32'h0, j + 9};
                tb_instruction_i.mem_op <= MEM_STORE;
                tb_instruction_i.instr_type <= SD;
                tb_instruction_i.funct3 <= 3'b001;
                tb_instruction_i.rd <= 5'h1;
                
                tick();
                assert(tb_instruction_o.valid == 1);
                assert(tb_empty_o == 0);
                assert(tb_full_o == 0);
                assert(load_store_queue_inst.tail == j[2:0] + 3'b001 );
                assert(load_store_queue_inst.head == j[2:0] + 3'b010);
                assert(load_store_queue_inst.num ==  4'b0111); 
                assert(tb_ls_queue_entry_o == j[2:0]);
                assert(tb_instruction_o.addr == {8'h0, j + 2});
                assert(tb_instruction_o.data == {32'h0, j + 2});
                assert(tb_instruction_o.mem_op == MEM_STORE);
                assert(tb_instruction_o.instr_type == SD);
                assert(tb_instruction_o.funct3 == 3'b001);
                assert(tb_instruction_o.rd == 5'h1);
            end

            // Read all values stored in lsq
            for (int j = 0; j < 7; j++) begin
                tb_read_head_i <= 1'b1;
                tb_instruction_i.valid <= 1'b0;
                
                tick();
                assert(tb_instruction_o.valid == 1);
                if (j == 6)
                    assert(tb_empty_o == 1);
                else
                    assert(tb_empty_o == 0);
                assert(tb_full_o == 0);
                assert(load_store_queue_inst.tail == 3'b000 );
                assert(load_store_queue_inst.head == j[2:0] + 3'b010);
                assert(load_store_queue_inst.num ==  4'b0111 - {1'b0, j[3:0] + 1'b1}); 
                assert(tb_ls_queue_entry_o == 3'b000);
                assert(tb_instruction_o.addr == {8'h0, j + 10});
                assert(tb_instruction_o.data == {32'h0, j + 10});
                assert(tb_instruction_o.mem_op == MEM_STORE);
                assert(tb_instruction_o.instr_type == SD);
                assert(tb_instruction_o.funct3 == 3'b001);
                assert(tb_instruction_o.rd == 5'h1);
            end

            // Try Read head but is empty
            tb_read_head_i <= 1'b1;
            tick();
            tb_read_head_i <= 1'b0;
            assert(tb_instruction_o.valid == 0);
            assert(tb_empty_o == 1);
            assert(tb_full_o == 0);
            assert(load_store_queue_inst.tail == 3'b000 );
            assert(load_store_queue_inst.head == 3'b000 );
            assert(load_store_queue_inst.num  == 4'b0000); 
            assert(tb_ls_queue_entry_o == 3'b000 );

            // Test bypass when lsq empty and read and write at same time
            tb_read_head_i <= 1'b1;
            tb_instruction_i.valid <= 1'b1;
            tb_instruction_i.addr <= 40'h55;
            tb_instruction_i.data <= 64'h55;
            tb_instruction_i.mem_op <= MEM_LOAD;
            tb_instruction_i.instr_type <= LB;
            tb_instruction_i.funct3 <= 3'b001;
            tb_instruction_i.rd <= 5'h1;

            tick();
            assert(tb_instruction_o.valid == 1);
            assert(tb_empty_o == 1);
            assert(tb_full_o == 0);
            assert(load_store_queue_inst.tail == 3'b001 );
            assert(load_store_queue_inst.head == 3'b001 );
            assert(load_store_queue_inst.num ==  4'b0000); 
            assert(tb_ls_queue_entry_o == 3'b000);
            assert(tb_instruction_o.addr == 40'h55);
            assert(tb_instruction_o.data == 64'h55);
            assert(tb_instruction_o.mem_op == MEM_LOAD);
            assert(tb_instruction_o.instr_type == LB);
            assert(tb_instruction_o.funct3 == 3'b001);
            assert(tb_instruction_o.rd == 5'h1);
        end
    endtask

    // Test write and read of all cells
    // Output should be nothing 
    task automatic test_sim_3;
        begin

            tb_read_head_i <= 1'b0;
            tb_instruction_i.valid <= 1'b0;

            // Fill the queue
            for (int j = 0; j < 8; j++) begin
                // Write entry
                tb_instruction_i.valid <= 1'b1;
                tb_instruction_i.addr <= {8'h0, j + 1};
                tb_instruction_i.data <= {32'h0, j + 1};
                tb_instruction_i.mem_op <= MEM_STORE;
                tb_instruction_i.instr_type <= SD;
                tb_instruction_i.funct3 <= 3'b001;
                tb_instruction_i.rd <= 5'h1;
                
                tick();
                assert(tb_instruction_o.valid == 0);
                assert(tb_empty_o == 0);
                if (j != 7)
                    assert(tb_full_o == 0);
                else
                    assert(tb_full_o == 1);
                assert(load_store_queue_inst.tail == (j[2:0] + 2'b10) );
                assert(load_store_queue_inst.head == 1'b1 );
                assert(load_store_queue_inst.num == (j[3:0] + 1'b1) ); 
                assert(tb_ls_queue_entry_o ==  (j[2:0] + 2'b01)  );

            end

            tb_instruction_i.valid <= 1'b0;

            tick();
            tick();

            tb_flush_i <= 1'b1;
   
            tick();

            assert(load_store_queue_inst.tail == 3'b0 );
            assert(load_store_queue_inst.head == 3'b0 );
            assert(load_store_queue_inst.num ==  4'b0 ); 
            assert(tb_ls_queue_entry_o ==  3'b0 );

            tb_flush_i <= 1'b0;
   
            tick();
            
        end
    endtask




    //***init_sim***
    //The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        $display("Test Finished\n");
    end


endmodule
`default_nettype wire
