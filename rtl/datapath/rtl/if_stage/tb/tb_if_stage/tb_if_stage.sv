//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_if_stage.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
//`default_nettype none

`include "colors.vh"

import drac_pkg::*;

module tb_if_stage();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

//-----------------------------
// Signals
//-----------------------------

    logic                 tb_clk_i;
    logic                 tb_rstn_i;
    addr_t                tb_reset_addr_i;
    
    logic                 tb_stall_i;
    cu_if_t               tb_cu_if_i;
    // Signals to invalidate buffer/icache
    // from control unit
    logic                 tb_invalidate_icache_i;
    logic                 tb_invalidate_buffer_i;
    // PC comming from commit/decode/ecall
    addrPC_t              tb_pc_jump_i;
    // Response packet coming from Icache
    resp_icache_cpu_t     tb_resp_icache_cpu_i;
    // Signals for branch predictor from exe stage 
    exe_if_branch_pred_t  tb_exe_if_branch_pred_i;
    // Retry requesto to icache
    logic                 tb_retry_fetch_i;
    // Request packet going from Icache
    req_cpu_icache_t     tb_req_cpu_icache_o;  
    // fetch data output
    if_id_stage_t        tb_fetch_o;


//-----------------------------
// Module
//-----------------------------

    if_stage if_stage_inst(
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .reset_addr_i(tb_reset_addr_i),
        .stall_i(tb_stall_i),
        .cu_if_i(tb_cu_if_i),
        .invalidate_icache_i(tb_invalidate_icache_i),
        .invalidate_buffer_i(tb_invalidate_buffer_i),
        .pc_jump_i(tb_pc_jump_i),
        .resp_icache_cpu_i(tb_resp_icache_cpu_i),
        .exe_if_branch_pred_i(tb_exe_if_branch_pred_i),
        .retry_fetch_i(tb_retry_fetch_i),
        .req_cpu_icache_o(tb_req_cpu_icache_o),  
        .fetch_o(tb_fetch_o)
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
            $display("Toggle reset");
            tb_rstn_i <= 1'b0; 
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
            tb_reset_addr_i<='{default:0};
            tb_stall_i<='{default:0};
            tb_cu_if_i<='{default:0};
            tb_invalidate_icache_i<='{default:0};
            tb_invalidate_buffer_i<='{default:0};
            tb_pc_jump_i<='{default:0};
            tb_resp_icache_cpu_i<='{default:0};
            tb_exe_if_branch_pred_i<='{default:0};
            tb_retry_fetch_i<='{default:0};            
            $display("Done");
            
        end
    endtask

//***task automatic init_dump***
//This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
//If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("tb_if_stage.vcd");
            $dumpvars(0,if_stage_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

    task automatic half_tick();
        begin
            //$display("*** tick");
            #CLK_HALF_PERIOD;
        end
    endtask

    //***task automatic test_sim***
    task automatic print;
        input int value;
        begin
            $display("Value: %h ",value);
        end
    endtask

    //***task automatic test_sim***
    task automatic check_out;
        input int test;
        input int status;
        begin
            if (status == 1) begin
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

    task automatic test_sim_1;
        output int tmp;
        begin
            $display(" %0tns:   *** test sim 1 ***",$time);
            // this tests resets and checks
            // that the output to icache 
            // is the reset addr 
            tmp=0;
            tb_reset_addr_i<=40'h0080000000;
            tick();
            tb_rstn_i <= 1'b0; 
            tick();
            tb_rstn_i <= 1'b1;
            tick();
            if (tb_req_cpu_icache_o.vaddr != 40'h0080000000) begin
                tmp=1;
                $error("Reset addr not set appropiatly");
            end
        end
    endtask

    // test we are adding +4 at every cycle
    // if everything is okay
    // no stop from cu neither branch
    // neither datapath
    task automatic test_sim_2;
        output int tmp;
        begin
            $display("%0tns:   *** test sim 2 ***",$time);
            tmp=0;
            //reset_dut();
            // reset addr is 0x8000_0000
            tick(); // 0x8000_0004 (+4)
            tick(); // 0x8000_0008 (+4)
            tick(); // 0x8000_000C (+4)
            tick(); // 0x8000_0010 (+4)
            tick(); // 0x8000_0014 (+4)
            tick(); // 0x8000_0018 (+4)
            if (tb_req_cpu_icache_o.vaddr != 40'h0080000018) begin
                tmp=1;
                $error("Incorrect expected addr");
            end
        end
    endtask

    // test we are adding +4 at every cycle
    // if everything is okay
    // no stop from cu neither branch
    // neither datapath
    task automatic test_sim_3;
        output int tmp;
        begin
            $display("%0tns:   *** test sim 3 ***",$time);
            tmp=0;
            reset_dut();
            // reset addr is 0x8000_0004
            //print(tb_req_cpu_icache_o.vaddr);
            //###############################
            //          TEST 1 
            //###############################
            // this mini test checks if blocking
            // the same addr from cu works
            tick(); // 0x8000_0008 (+4)
            tb_cu_if_i.next_pc <= NEXT_PC_SEL_KEEP_PC;
            tb_stall_i<=1'b1;
            tick(); // 0x8000_0008 
            tick();
            tick();
            // we should get the same addr
            if (tb_req_cpu_icache_o.vaddr != 40'h0080000008 |
                tb_fetch_o.valid != 1'b0) begin
                tmp=1;
                $error("We should have the same addr");
            end
            tb_stall_i<=1'b0;
            tick();
            //###############################
            //          TEST 2
            //###############################
            // this mini test jumps from decode
            // commit ecall
            tb_cu_if_i.next_pc <= NEXT_PC_SEL_JUMP;
            tb_pc_jump_i<=40'h11_1111_1110;
            tick();
            half_tick();
            if (tb_req_cpu_icache_o.vaddr != 40'h11_1111_1110 |
                tb_req_cpu_icache_o.valid != 1'b1) begin
                tmp=1;
                $error("Jump addr is not set correctly");
            end
            half_tick();
            //###############################
            //          TEST 3
            //###############################
            // this mini test checks 
            // invalidate_icache_i
            tb_invalidate_icache_i <= 1'b1;
            half_tick();
            if (tb_req_cpu_icache_o.invalidate_icache != 1'b1) begin
                tmp=1;
                $error("Invalidate icache not set correctly");
            end
            half_tick();
            tb_invalidate_icache_i <= 1'b0;
            tb_invalidate_buffer_i <= 1'b1;
            half_tick();
            if (tb_req_cpu_icache_o.invalidate_buffer != 1'b1) begin
                tmp=1;
                $error("Invalidate icache not set correctly");
            end
            tb_invalidate_buffer_i <= 1'b0;
            tb_cu_if_i.next_pc <= NEXT_PC_SEL_BP_OR_PC_4;
            half_tick();
        end
    endtask

    // test input checks output from fetch match the resp from icache
    task automatic test_sim_4;
        output int tmp;
        begin
            $display("%0tns:   *** test sim 4 ***",$time);
            tmp=0;
            reset_dut();
            half_tick(); // 0x8000_0004 (+4)
            //$display("Result %h %h",tb_req_cpu_icache_o.vaddr,tb_req_cpu_icache_o.valid);

            if (tb_req_cpu_icache_o.valid != 1'b1 &
                tb_req_cpu_icache_o.vaddr != 40'h0080000004 &
                tb_req_cpu_icache_o.invalidate_icache != 1'b0 &
                tb_req_cpu_icache_o.invalidate_buffer != 1'b0) 
            begin
                tmp=1;
                $error("Bad sending req to icache");
            end
            half_tick(); // Get a response from icache
            tb_resp_icache_cpu_i.valid<=1'b1;
            tb_resp_icache_cpu_i.data<=32'h1234_5678;
            // Add BRED check
            half_tick();
            if (tb_fetch_o.pc_inst != 40'h0080000008 |
                tb_fetch_o.inst != 32'h1234_5678 |
                tb_fetch_o.valid != 1'b1 |
                tb_fetch_o.ex.valid != 1'b0) 
            begin
                tmp=1;
                $error("Bad sending req to icache");
            end
            half_tick();
            tb_resp_icache_cpu_i.valid<=1'b0;
            tick();
        end
    endtask
    

    // test exceptions from icache acces_fault
    task automatic test_sim_5;
        output int tmp;
        begin
            $display("%0tns:   *** test sim 5 ***",$time);
            tmp=0;
            reset_dut();
            tick(); // 0x8000_0004 (+4)
            tb_resp_icache_cpu_i.valid<=1'b1;
            tb_resp_icache_cpu_i.data<=32'h1234_5678;
            tb_resp_icache_cpu_i.instr_access_fault<=1'b1;
            tb_resp_icache_cpu_i.instr_page_fault<=1'b0;
            half_tick();
            // Add BRED check
            if (tb_fetch_o.pc_inst != 40'h0080000008 |
                tb_fetch_o.inst != 32'h1234_5678 |
                tb_fetch_o.valid != 1'b1 |
                tb_fetch_o.ex.valid != 1'b1 |
                tb_fetch_o.ex.cause != 64'h01) 
            begin
                tmp=1;
                $error("There should be an exception from icache access fault");
            end
            half_tick();
        end
    endtask

    // test exceptions from icache  instr_page_fault
    task automatic test_sim_6;
        output int tmp;
        begin
            $display("%0tns:   *** test sim 6 ***",$time);
            tmp=0;
            reset_dut();
            tick(); // 0x8000_0004 (+4)
            tb_resp_icache_cpu_i.valid<=1'b1;
            tb_resp_icache_cpu_i.data<=32'h1234_5678;
            tb_resp_icache_cpu_i.instr_access_fault<=1'b0;
            tb_resp_icache_cpu_i.instr_page_fault<=1'b1;
            // Add BRED check
            half_tick();
            if (tb_fetch_o.pc_inst != 40'h0080000008 |
                tb_fetch_o.inst != 32'h1234_5678 |
                tb_fetch_o.valid != 1'b1 |
                tb_fetch_o.ex.valid != 1'b1 |
                tb_fetch_o.ex.cause != 64'h0C) 
            begin
                tmp=1;
                $error("There should be an exception from icache access fault");
            end
            //$display("origin: %h", tb_fetch_o.ex.cause);
            half_tick();
        end
    endtask

    // test exceptions from icache mislaigned
    task automatic test_sim_7;
        output int tmp;
        begin
            $display("%0tns:   *** test sim 7 ***",$time);
            tmp=0;
            reset_dut();
            tb_cu_if_i.next_pc <= NEXT_PC_SEL_JUMP;
            tb_pc_jump_i<=40'b11_1111_1111;
            tick(); // 0x8000_0004
            tick();
            if (tb_req_cpu_icache_o.vaddr != 40'b11_1111_1111 |
                tb_req_cpu_icache_o.valid != 1'b0 |
                tb_fetch_o.valid != 1'b1 |
                tb_fetch_o.ex.valid != 1'b1 |
                tb_fetch_o.ex.cause != 64'h00) begin
                tmp=1;
                $error("misaligned exception not correct");
            end
            //$display("cause: %h", tb_fetch_o.ex.cause);
        end
    endtask

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            //$display("*** test_sim");
            // check reset addr
            test_sim_1(tmp);
            check_out(1,tmp);
            // check +4 addr regular working
            test_sim_2(tmp);
            check_out(2,tmp);
            // checks cu inputs
            test_sim_3(tmp);
            check_out(3,tmp);
            // checks inputs from icache
            test_sim_4(tmp);
            check_out(4,tmp);
            // checks exceptions access_fault
            test_sim_5(tmp);
            check_out(5,tmp);
            // checks exceptions page_fault
            test_sim_6(tmp);
            check_out(6,tmp);
            // checks exceptions addr misaligned
            test_sim_7(tmp);
            check_out(7,tmp);
        end
    endtask


//***init_sim***
//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        //`START_GREEN_PRINT                       
        //        $display("PASS, add one of this for each test."); 
        //`END_COLOR_PRINT 
        //if(VERBOSE)
        //        $display("Define a parameter (parameter VERBOSE=0;) and guard\n\
        //        messages that are not needed. Most of the times with PASS/FAIL name of the \n\
        //        tests is enough"); 
        //`START_RED_PRINT
        //        $error("FAIL, add one of this for each test");
        //`END_COLOR_PRINT
    end


endmodule
//`default_nettype wire
