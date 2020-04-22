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

    resp_icache_cpu_t tb_icache_fetch_i;
    req_cpu_icache_t tb_fetch_icache_o;

    req_cpu_dcache_t tb_req_cpu_dcache_o;
    resp_dcache_cpu_t tb_resp_dcache_cpu_i;

    resp_csr_cpu_t resp_csr_cpu_i;
    req_cpu_csr_t req_cpu_csr_o;
    

    logic [31:0] tb_addr_i;
    logic [31:0] tb_line_o;
    logic [31:0] tb_line2_o;

    bus64_t tb_dmem_resp_data_i;
    logic tb_dmem_resp_valid_i;

    logic tb_dmem_req_valid_o;
    logic [4:0] tb_dmem_req_cmd_o;
    addr_t  tb_dmem_req_addr_o;
    logic [3:0] tb_dmem_op_type_o;
    bus64_t tb_dmem_req_data_o;

    assign tb_icache_fetch_i.data = tb_line_o;
    assign tb_addr_i = tb_fetch_icache_o.vaddr;

    assign resp_csr_cpu_i.csr_rw_rdata = (req_cpu_csr_o.csr_rw_addr == 12'hf10) ? 64'h0 : 64'hf123456776543210;
    assign resp_csr_cpu_i.csr_replay = 1'b0;
    assign resp_csr_cpu_i.csr_stall = 1'b0;
    assign resp_csr_cpu_i.csr_exception = 1'b0;
    assign resp_csr_cpu_i.csr_eret = 1'b0;
    assign resp_csr_cpu_i.csr_evec = 64'h0;
    assign resp_csr_cpu_i.csr_interrupt = 1'b0;
    assign resp_csr_cpu_i.csr_interrupt_cause = 64'b0;

//-----------------------------
// Module
//-----------------------------

    datapath datapath_inst( 
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .soft_rstn_i(1'b1),
        .reset_addr_i(64'h200),

        .resp_icache_cpu_i(tb_icache_fetch_i),
        .resp_dcache_cpu_i(tb_resp_dcache_cpu_i),
        .resp_csr_cpu_i(resp_csr_cpu_i),

        .req_cpu_icache_o(tb_fetch_icache_o),
        .req_cpu_dcache_o(tb_req_cpu_dcache_o),
        .req_cpu_csr_o(req_cpu_csr_o)

    );

    dcache_interface dcache_interface_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i), 
        .req_cpu_dcache_i(tb_req_cpu_dcache_o),
        .dmem_resp_replay_i(1'b0),
        .dmem_resp_data_i(tb_dmem_resp_data_i),
        .dmem_req_ready_i(tb_dmem_resp_valid_i),
        .dmem_resp_valid_i(1'b1),
        .dmem_resp_nack_i(1'b0),
        .dmem_xcpt_ma_st_i(1'b0),
        .dmem_xcpt_ma_ld_i(1'b0), 
        .dmem_xcpt_pf_st_i(1'b0),
        .dmem_xcpt_pf_ld_i(1'b0),
        .dmem_req_valid_o(tb_dmem_req_valid_o),
        .dmem_req_cmd_o(tb_dmem_req_cmd_o),
        .dmem_req_addr_o(tb_dmem_req_addr_o),
        .dmem_op_type_o(tb_dmem_op_type_o),
        .dmem_req_data_o(tb_dmem_req_data_o),
        .dmem_req_tag_o(), 
        .dmem_req_invalidate_lr_o(),
        .dmem_req_kill_o(),
        .resp_dcache_cpu_o(tb_resp_dcache_cpu_i) 
    );

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
        .addr_i(tb_dmem_req_addr_o),
        .valid_i(tb_dmem_req_valid_o),
        .wr_ena_i(tb_dmem_req_cmd_o == 5'b00001),
        .wr_data_i(tb_dmem_req_data_o),
        .word_size_i(tb_dmem_op_type_o),
        .line_o(tb_dmem_resp_data_i),
        .ready_o(tb_dmem_resp_valid_i)
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
        $finish;
    end
//assert property (@(posedge tb_clk_i) (tb_fetch_icache_o.vaddr != 'h0740));
//assert property (@(posedge tb_clk_i) (datapath_inst.wb_cu_int.branch_taken == 0 | datapath_inst.exe_to_wb_wb.result_pc != 'h0740));

endmodule
//`default_nettype wire
