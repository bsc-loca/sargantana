//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_datapath.sv
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

module tb_datapath();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

//-----------------------------
// Signals
//-----------------------------
    reg     tb_clk_i;
    reg     tb_rstn_i;

    req_icache_cpu_t tb_icache_fetch_i;
    req_cpu_icache_t tb_fetch_icache_o;

    req_cpu_dcache_t tb_req_cpu_dcache_o;
    req_dcache_cpu_t tb_req_dcache_cpu_i;

    req_cpu_csr_t req_cpu_csr_o;
    

    logic [31:0] tb_addr_i;
    logic [31:0] tb_line_o;
    logic [31:0] tb_line2_o;

    assign tb_icache_fetch_i.data = tb_line_o;
    assign tb_addr_i = tb_fetch_icache_o.vaddr;

    assign tb_req_dcache_cpu_i.dmem_resp_replay_i = 1'b0;
    //assign tb_req_dcache_cpu_i.dmem_resp_data_i = 64'b0;
    //assign tb_req_dcache_cpu_i.dmem_req_ready_i = 1'b0;
    //assign tb_req_dcache_cpu_i.dmem_resp_valid_i = 1'b0;
    assign tb_req_dcache_cpu_i.dmem_resp_nack_i = 1'b0;
    assign tb_req_dcache_cpu_i.dmem_xcpt_ma_st_i = 1'b0;
    assign tb_req_dcache_cpu_i.dmem_xcpt_ma_ld_i = 1'b0;
    assign tb_req_dcache_cpu_i.dmem_xcpt_pf_st_i = 1'b0;
    assign tb_req_dcache_cpu_i.dmem_xcpt_pf_ld_i = 1'b0;

    assign tb_req_dcache_cpu_i.dmem_req_ready_i = 1;//tb_req_dcache_cpu_i.dmem_resp_valid_i;
//-----------------------------
// Module
//-----------------------------

    datapath datapath_inst( 
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .soft_rstn_i(1'b1),

        .req_icache_cpu_i(tb_icache_fetch_i),
        .req_dcache_cpu_i(tb_req_dcache_cpu_i),
        .req_csr_cpu_i(197'b0),

        .req_cpu_icache_o(tb_fetch_icache_o),
        .req_cpu_dcache_o(tb_req_cpu_dcache_o),
        .req_cpu_csr_o(req_cpu_csr_o)

    );

    /*perfect_memory perfect_memory_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .addr_i(tb_addr_i),
        .line_o(tb_line2_o)
    );*/

    perfect_memory_hex perfect_memory_hex_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .addr_i(tb_addr_i),
        .valid_i(tb_fetch_icache_o.valid),
        .line_o(tb_line_o),
        .ready_o(tb_icache_fetch_i.valid)
    );

    perfect_memory_hex_write perfect_memory_hex_write_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .addr_i(tb_req_cpu_dcache_o.dmem_req_addr_o),
        .valid_i(tb_req_cpu_dcache_o.dmem_req_valid_o),
        .wr_ena_i(tb_req_cpu_dcache_o.dmem_req_cmd_o == 5'b00001),
        .wr_data_i(tb_req_cpu_dcache_o.dmem_req_data_o),
        .word_size_i(tb_req_cpu_dcache_o.dmem_op_type_o),
        .line_o(tb_req_dcache_cpu_i.dmem_resp_data_i),
        .ready_o(tb_req_dcache_cpu_i.dmem_resp_valid_i)
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
            //$display("*** Toggle reset.");
            tb_rstn_i <= 1'b0; 
            #CLK_PERIOD;
            tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            //$display("Done");
        end
    endtask



    //***task automatic init_sim***
    //This is an empty structure for initializing your testbench, 
    // consider how the real hardware will behave instead of set all 
    // to zero as the initial state. Remove the TODO label and start writing.
    task automatic init_sim;
        begin
            //$display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};
            //tb_icache_fetch_i.valid<='{default:0};
            //tb_icache_fetch_i.data<='{default:0};
            //tb_icache_fetch_i.ex.valid<={default:0};
	    //tb_icache_fetch_i.instr_addr_misaligned<='{default:0};
            //tb_icache_fetch_i.instr_access_fault<='{default:0};
            //tb_icache_fetch_i.instr_page_fault<='{default:0};
            //tb_addr_i<='{default:0};
            //$display("Done");
            
        end
    endtask

    //***task automatic init_dump***
    //This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
    //If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            //$display("*** init_dump");
            $dumpfile("dump_file.vcd");
            $dumpvars(0,datapath_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

//***task automatic test_sim***
//This is an empty structure for a test. Remove the TODO label and start writing, several tasks can be used.
    task automatic test_sim;
        begin
            int tmp;
            //$display("*** test_sim");
            // check req valid 0
            test_sim1(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        //$display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        //$display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask

    task automatic read_mem; 
        begin
            // Simulate memory maybe made a delay here?
            if (tb_fetch_icache_o.valid == 1'b1) begin
                //tb_addr_i = tb_fetch_icache_o.vaddr;
                //tb_icache_fetch_i.valid <= 1;
                // /tb_icache_fetch_i.data  = tb_line_o;
                // /tb_icache_fetch_i.ex    ='{default:0};
            end          
        end
    endtask

    task automatic set_mem_valid;
        input bit valid; 
        begin
            // Simulate memory maybe made a delay here?
            //if (tb_fetch_icache_o.valid == 1'b1) begin
                //tb_addr_i = tb_fetch_icache_o.vaddr;
            //tb_icache_fetch_i.valid <= valid;
                // /tb_icache_fetch_i.data  = tb_line_o;
                // /tb_icache_fetch_i.ex    ='{default:0};         
        end
    endtask

//    2000:   00000093                slt     x0,x0,-1
//    2004:   00000113                sltiu   x0,x0,0
//    2008:   00500013                addi    x0,x0,5
//    200C:   00804013                xori    x0,x0,8

    task automatic test_sim1;
        output int tmp;
        begin
            tmp = 0;
            //$display("*** test_sim1");
            tick();
            

        end
    endtask


//***init_sim***
//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        string testname;
        string filename;
        integer f;
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        $value$plusargs({"TESTNAME","=%s"}, testname);
        //filename="tests_status.txt";
        $value$plusargs({"FILENAME","=%s"}, filename);
        f=$fopen(filename,"a");
        #2000;
        if (datapath_inst.rr_stage_inst.registers[28] == 1) begin
            $fwrite(f,"%c[1;34m",27);
            $fwrite(f,"%s TEST PASSED.",testname);
            $fwrite(f,"%c[0m",27);
            $fwrite(f,"\n");
        end else begin
            $fwrite(f,"%c[1;31m",27);
            $fwrite(f,"%s TEST FAILED.",testname);
            $fwrite(f,"%c[0m",27);
            $fwrite(f,"\n");
        end
    end
//assert property (@(posedge tb_clk_i) (tb_fetch_icache_o.vaddr != 'h0740));
//assert property (@(posedge tb_clk_i) (datapath_inst.wb_cu_int.branch_taken == 0 | datapath_inst.exe_to_wb_wb.result_pc != 'h0740));

endmodule
//`default_nettype wire
