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
    parameter N2000_CLK_PERIOD = CLK_PERIOD*2000;

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
    
    phreg_t pr;
    

    logic [31:0] tb_addr_i;
    logic [31:0] tb_line_o;
    logic [31:0] tb_line2_o;

    assign tb_icache_fetch_i.data = tb_line_o;
    assign tb_addr_i = tb_fetch_icache_o.vaddr;

    assign tb_resp_dcache_cpu_i.lock = 1'b0;

    assign resp_csr_cpu_i.csr_rw_rdata = (req_cpu_csr_o.csr_rw_addr == 12'h342) ? 64'h0B : 64'h0;
    assign resp_csr_cpu_i.csr_replay = 1'b0;
    assign resp_csr_cpu_i.csr_stall = 1'b0;
    assign resp_csr_cpu_i.csr_exception = 1'b0;
    assign resp_csr_cpu_i.csr_eret = 1'b0;
    assign resp_csr_cpu_i.csr_evec = 64'h04;
    assign resp_csr_cpu_i.csr_interrupt = 1'b0;
    assign resp_csr_cpu_i.csr_interrupt_cause = 64'b0;
    
    
    logic [1:0] csr_priv_lvl_i;
    to_PMU_t pmu_flags;

//-----------------------------
// Module
//-----------------------------

    datapath datapath_inst( 
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .resp_icache_cpu_i(tb_icache_fetch_i),
        .req_cpu_icache_o(tb_fetch_icache_o),
        .soft_rstn_i(1'b1),
        .reset_addr_i(40'h000),
        .debug_contr_i('0),
        .debug_reg_i('0),
        .resp_csr_cpu_i(resp_csr_cpu_i),
        .req_cpu_csr_o(req_cpu_csr_o),
        .req_cpu_dcache_o(tb_req_cpu_dcache_o),
        .resp_dcache_cpu_i(tb_resp_dcache_cpu_i),
        .csr_priv_lvl_i(csr_priv_lvl_i),
        .pmu_flags_o        (pmu_flags)
    );

    perfect_memory_hex perfect_memory_hex_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .addr_i(tb_addr_i),
        .valid_i(tb_fetch_icache_o.valid),
        .line_o(tb_line_o),
        .ready_o(tb_icache_fetch_i.valid)
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
            csr_priv_lvl_i<='{default:0};
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
            $display("*** test_sim");
            // check req valid 0
            test_sim1(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask


    task automatic test_sim1;
        output int tmp;
        begin
            tmp = 0;
            $display("*** test_sim1");
            #N2000_CLK_PERIOD;
            pr <= datapath_inst.rename_table_inst.commit_table[3];
            #CLK_PERIOD;
            if (datapath_inst.regfile.registers[pr] == 1) begin
                //FAIL
                tmp = 0;
            end else begin
                //PASS
                tmp = 1;
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
        $finish;
    end
endmodule
