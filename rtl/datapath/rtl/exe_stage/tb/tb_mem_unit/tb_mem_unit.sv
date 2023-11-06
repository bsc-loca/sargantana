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
//`default_nettype none

`include "colors.vh"
import drac_pkg::*;

module tb_mem_unit();

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
    
    lsq_interface_t tb_interface_i;
    logic           tb_kill_i;
    logic           tb_flush_i;
    logic           tb_ready_from_dcache;
    bus64_t         tb_data_from_dcache;
    logic           tb_lock_from_dcache;

    logic           tb_valid_to_dcache;
    bus64_t         tb_data_rs1_to_dcache;
    bus64_t         tb_data_rs2_to_dcache;
    instr_type_t    tb_instr_type_to_dcache;
    mem_op_t        tb_mem_op_to_dcache;
    logic  [2:0]    tb_funct3_to_dcache;
    reg_t           tb_rd_to_dcache;
    bus64_t         tb_imm_to_dcache;
    bus64_t         tb_data_o;

    logic  [2:0]  tb_ls_queue_entry_o;
    logic         tb_ready_o;         
    logic         tb_lock_o;

    logic         tb_csr_eret_i;
    addr_t        tb_io_base_addr_i;

    logic         tb_dmem_resp_replay_i;
    bus64_t       tb_dmem_resp_data_i;
    logic         tb_dmem_req_ready_i;
    logic         tb_dmem_resp_valid_i;
    logic         tb_dmem_resp_nack_i;
    logic         tb_dmem_xcpt_ma_st_i;
    logic         tb_dmem_xcpt_ma_ld_i;
    logic         tb_dmem_xcpt_pf_st_i;
    logic         tb_dmem_xcpt_pf_ld_i;

    reg           tb_dmem_req_valid_o;
    reg  [4:0]    tb_dmem_req_cmd_o;
    addr_t        tb_dmem_req_addr_o;
    reg  [3:0]    tb_dmem_op_type_o;
    bus64_t       tb_dmem_req_data_o;
    logic [7:0]   tb_dmem_req_tag_o;
    logic         tb_dmem_req_invalidate_lr_o;
    logic         tb_dmem_req_kill_o;


//-----------------------------
// Module
//-----------------------------

    mem_unit module_inst (
        .clk_i(tb_clk_i),           
        .rstn_i(tb_rstn_i),          

        .interface_i(tb_interface_i),     
        .kill_i(tb_kill_i),          
        .flush_i(tb_flush_i),         
        .ready_i(tb_ready_from_dcache),
        .data_i(tb_data_from_dcache),
        .lock_i(tb_lock_from_dcache),          
        .valid_o(tb_valid_to_dcache),
        .data_rs1_o(tb_data_rs1_to_dcache),
        .data_rs2_o(tb_data_rs2_to_dcache),          
        .instr_type_o(tb_instr_type_to_dcache),        
        .mem_op_o(tb_mem_op_to_dcache),            
        .funct3_o(tb_funct3_to_dcache),            
        .rd_o(tb_rd_to_dcache),                
        .imm_o(tb_imm_to_dcache),               
        .data_o(tb_data_o),          
        .ls_queue_entry_o(tb_ls_queue_entry_o),
        .ready_o(tb_ready_o),         
        .lock_o(tb_lock_o)           
    );


    interface_dcache tb_interface_dcache_inst (
        .clk_i(tb_clk_i),           
        .rstn_i(tb_rstn_i),

        .valid_i(tb_valid_to_dcache),
        .kill_i(tb_kill_i),
        .csr_eret_i(tb_csr_eret_i),          
        .data_rs1_i(tb_data_rs1_to_dcache),  
        .data_rs2_i(tb_data_rs2_to_dcache), 
        .instr_type_i(tb_instr_type_to_dcache),
        .mem_op_i(tb_mem_op_to_dcache), 
        .funct3_i(tb_funct3_to_dcache),      
        .rd_i(tb_rd_to_dcache),
        .imm_i(tb_imm_to_dcache), 

        .io_base_addr_i(tb_io_base_addr_i),
        .dmem_resp_replay_i(tb_dmem_resp_replay_i),
        .dmem_resp_data_i(tb_dmem_resp_data_i),
        .dmem_req_ready_i(tb_dmem_req_ready_i),
        .dmem_resp_valid_i(tb_dmem_resp_valid_i),
        .dmem_resp_nack_i(tb_dmem_resp_nack_i),
        .dmem_xcpt_ma_st_i(tb_dmem_xcpt_ma_st_i),
        .dmem_xcpt_ma_ld_i(tb_dmem_xcpt_ma_ld_i),
        .dmem_xcpt_pf_st_i(tb_dmem_xcpt_pf_st_i),
        .dmem_xcpt_pf_ld_i(tb_dmem_xcpt_pf_ld_i),

        .dmem_req_valid_o(tb_dmem_req_valid_o),
        .dmem_req_cmd_o(tb_dmem_req_cmd_o),
        .dmem_req_addr_o(tb_dmem_req_addr_o),
        .dmem_op_type_o(tb_dmem_op_type_o),
        .dmem_req_data_o(tb_dmem_req_data_o),
        .dmem_req_tag_o(tb_dmem_req_tag_o),
        .dmem_req_invalidate_lr_o(tb_dmem_req_invalidate_lr_o),
        .dmem_req_kill_o(tb_dmem_req_kill_o),

        .ready_o(tb_ready_from_dcache),
        .data_o(tb_data_from_dcache),
        .lock_o(tb_lock_from_dcache)
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

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

    //***task automatic init_sim***
    //Initializing testbench.
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};

            tb_kill_i<='{default:0};
            tb_csr_eret_i<='{default:0};
 
            tb_io_base_addr_i<='{default:0};
            tb_dmem_resp_replay_i<='{default:0};
            tb_dmem_resp_data_i<='{default:0};
            tb_dmem_req_ready_i<='{default:0};
            tb_dmem_resp_valid_i<='{default:0};
            tb_dmem_resp_nack_i<='{default:0};
            tb_dmem_xcpt_ma_st_i<='{default:0};
            tb_dmem_xcpt_ma_ld_i<='{default:0};
            tb_dmem_xcpt_pf_st_i<='{default:0};
            tb_dmem_xcpt_pf_ld_i<='{default:0};

            tb_interface_i <= '{default:0};  
            tb_flush_i <= '{default:0};
    
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
            test_sim_1(tmp);            // Check fullfill of lsq
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end

            //test_sim_2(tmp);          // Check exception handling 
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 2 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 2 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask

    // Test inserts 8 loads in lsq and then removes them, one every 3 cycles.
    // Output should be nothing 
    task automatic test_sim_1;
        output int tmp;
        begin
            tmp = 0;
            $random(10);

            // Add 8 memory access instructions, all loads
            tb_dmem_req_ready_i <= 0;


            for (int j = 0; j < 9; j++) begin
                // Write entry
                tb_interface_i.valid <= 1'b1;
                tb_interface_i.addr <= {8'h0, j + 1};
                tb_interface_i.data <= {32'h0, j + 1};
                tb_interface_i.mem_op <= MEM_STORE;
                tb_interface_i.instr_type <= SD;
                tb_interface_i.funct3 <= 3'b001;
                tb_interface_i.rd <= 5'h1;
                
                tick();
                if (j == 0) begin
                    assert (tb_valid_to_dcache == 1'b0);
                    assert (tb_ls_queue_entry_o ==  3'h0);    
                end else begin
                    assert (tb_valid_to_dcache == 1'b1);
                    assert (tb_ls_queue_entry_o ==  (j[2:0] - 3'b1));
                end

                assert (tb_ready_o == 1'b0);
                assert (tb_lock_o == 1'b0);

            end
            
            tb_interface_i.valid <= 1'b0;

            tick();
            assert (tb_valid_to_dcache == 1'b1);
            assert (tb_ls_queue_entry_o ==  3'b000);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            // START attending request until empty

            tick();
            tb_dmem_req_ready_i <= 1'b1;
            
            tick();
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 40'h1);
            assert (tb_dmem_req_data_o == 64'h1);
            assert (tb_dmem_req_tag_o == 8'h02);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b001);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            tick();

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 40'h1);
            assert (tb_dmem_req_data_o == 64'h1);
            assert (tb_dmem_req_tag_o == 8'h02);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b001);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            // SERVE HIT
            tick();
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b1;
            tb_dmem_resp_data_i <= 64'hFF00FF00FF00FF00;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            assert (tb_lock_o == 1'b1);

            tick();

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;

            assert (tb_data_o == 64'hFF00FF00FF00FF00);
            assert (tb_lock_o == 1'b0);
            assert (tb_ready_o == 1'b0);

            // Second request
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h2);
            assert (tb_dmem_req_data_o == 64'h2);
            assert (tb_dmem_req_tag_o == 8'h02);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);        
            assert (tb_dmem_op_type_o == 3'b001);

            tick();

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 40'h2);
            assert (tb_dmem_req_data_o == 64'h2);
            assert (tb_dmem_req_tag_o == 8'h02);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b001);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            // SERVE HIT
            tick();
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b1;
            tb_dmem_resp_data_i <= 64'h00FF00FF00FF00FF;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            tick();

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;

            assert (tb_data_o == 64'h00FF00FF00FF00FF);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);
 
            // Third Request
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h3);
            assert (tb_dmem_req_data_o == 64'h3);
            assert (tb_dmem_req_tag_o == 8'h02);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);        
            assert (tb_dmem_op_type_o == 3'b001);

            tick();

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 40'h3);
            assert (tb_dmem_req_data_o == 64'h3);
            assert (tb_dmem_req_tag_o == 8'h02);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b001);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            // SERVE HIT
            tick();
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b1;
            tb_dmem_resp_data_i <= 64'h00AA00AA00AA00AA;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            tick();

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;

            assert (tb_data_o == 64'h00AA00AA00AA00AA);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            // Fourth Request
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h4);
            assert (tb_dmem_req_data_o == 64'h4);
            assert (tb_dmem_req_tag_o == 8'h02);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);        
            assert (tb_dmem_op_type_o == 3'b001);

            tick();

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 40'h4);
            assert (tb_dmem_req_data_o == 64'h4);
            assert (tb_dmem_req_tag_o == 8'h02);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b001);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            // SERVE HIT
            tick();
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b1;
            tb_dmem_resp_data_i <= 64'hAA00AA00AA00AA00;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            tick();

            tb_dmem_req_ready_i <= 1'b0;        // Stop Serving Requests
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;

            assert (tb_data_o == 64'hAA00AA00AA00AA00);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            tmp = 0;
        end
    endtask

    // Test check exception handling.
    // Output should be nothing 
    task automatic test_sim_2;
        output int tmp;
        begin
            tmp = 0;
            $random(10);

            // Kill all restant instructions
            tb_kill_i <= 1;
            tick();
            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_valid_to_dcache == 1'b0);
            assert (module_inst.state == 2'b00);
            assert (module_inst.empty_lsq == 1'b1);

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

