//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_icache_interface.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem LP |        | Intial 3 tests
*  0.2        | Ruben L.   |        | Improved and added new tests
*  0.3        | Guillem LP |        | Added 3 new tests
* -----------------------------------------------
*/

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
//`default_nettype none

`include "colors.vh"

import drac_pkg::*;
import riscv_pkg::*;

module tb_icache_interface();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 0;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

//-----------------------------
// Signals
//-----------------------------
    reg tb_clk_i;
    reg tb_rstn_i;

    // Fetch stage interface - Request packet from fetch_stage
    req_cpu_icache_t tb_req_fetch_icache_i;

    // Request input signals from ICache
    icache_line_t  tb_icache_resp_datablock_i; // ICACHE_RESP_BITS_DATABLOCK
    addr_t         tb_icache_resp_vaddr_i;
    logic          tb_icache_resp_valid_i; // ICACHE_RESP_VALID;
    logic          tb_icache_req_ready_i;
    logic          tb_ptw_invalidate_i; // PTWINVALIDATE;
    logic          tb_iptw_resp_valid_i;
    logic          tb_tlb_resp_miss_i; // TLB_RESP_MISS;
    logic          tb_tlb_resp_xcp_if_i; // TLB_RESP_XCPT_IF;

    // Output to icache
    reg            tb_icache_invalidate_o; // ICACHE_INVALIDATE
    icache_idx_t   tb_icache_req_bits_idx_o; // ICACHE_REQ_BITS_IDX;
    reg            tb_icache_req_kill_o; // ICACHE_REQ_BITS_KILL;
    reg            tb_icache_req_valid_o; // ICACHE_REQ_VALID;
    logic          tb_icache_resp_ready_o; // ICACHE_RESP_READY;
    icache_vpn_t   tb_tlb_req_bits_vpn_o; // TLB_REQ_BITS_VPN;
    reg            tb_tlb_req_valid_o; // TLB_REQ_VALID
    
    // Fetch stage interface - Request packet icache to fetch
    resp_icache_cpu_t tb_resp_icache_fetch_o;

    reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

    icache_interface icache_interface_inst(
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .req_fetch_icache_i(tb_req_fetch_icache_i),
        .icache_resp_datablock_i(tb_icache_resp_datablock_i), // ICACHE_RESP_BITS_DATABLOCK
        .icache_resp_vaddr_i(tb_icache_resp_vaddr_i),
        .icache_resp_valid_i(tb_icache_resp_valid_i), // ICACHE_RESP_VALID,
        .icache_req_ready_i(tb_icache_req_ready_i),
        .iptw_resp_valid_i(tb_iptw_resp_valid_i),
        .ptw_invalidate_i(tb_ptw_invalidate_i), // PTWINVALIDATE,
        .tlb_resp_miss_i(tb_tlb_resp_miss_i), // TLB_RESP_MISS,
        .tlb_resp_xcp_if_i(tb_tlb_resp_xcp_if_i), // TLB_RESP_XCPT_IF,

        .icache_invalidate_o(tb_icache_invalidate_o), // ICACHE_INVALIDATE
        .icache_req_bits_idx_o(tb_icache_req_bits_idx_o), // ICACHE_REQ_BITS_IDX,
        .icache_req_kill_o(tb_icache_req_kill_o), // ICACHE_REQ_BITS_KILL,
        .icache_req_valid_o(tb_icache_req_valid_o), // ICACHE_REQ_VALID,
        .icache_resp_ready_o(tb_icache_resp_ready_o), // ICACHE_RESP_READY,
        .tlb_req_bits_vpn_o(tb_tlb_req_bits_vpn_o), // TLB_REQ_BITS_VPN,
        .tlb_req_valid_o(tb_tlb_req_valid_o), // TLB_REQ_VALID
        .resp_icache_fetch_o(tb_resp_icache_fetch_o)
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
            tb_icache_resp_datablock_i<='{default:0}; // ICACHE_RESP_BITS_DATABLOCK
            tb_icache_resp_vaddr_i<='{default:0};
            tb_icache_resp_valid_i<='{default:0}; // ICACHE_RESP_VALID;
            tb_icache_req_ready_i<='{default:0}; // ICACHE_RESP_VALID;
            tb_ptw_invalidate_i<='{default:0}; // PTWINVALIDATE;
            tb_iptw_resp_valid_i<='{default:0}; // PTWINVALIDATE;
            tb_tlb_resp_miss_i<='{default:0}; // TLB_RESP_MISS;
            tb_tlb_resp_xcp_if_i<='{default:0};
            tb_req_fetch_icache_i.valid<='{default:0};
            tb_req_fetch_icache_i.vaddr<='{default:0};
            $display("Done");
            
        end
    endtask

//***task automatic init_dump***
//This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
//If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("tb_icache_interface.vcd");
            $dumpvars(0,icache_interface_inst);
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
    task automatic test_sim;
        begin
            int tmp;
            // check req valid 0
            test_sim_1(tmp);
            check_out(1,tmp);
            // check req valid
            test_sim_2(tmp);
            check_out(2,tmp);
            // TLB miss
            test_sim_3(tmp);
            check_out(3,tmp);
            // PTW invalidate
            test_sim_4(tmp);
            check_out(4,tmp);
            // TLB exception
            test_sim_5(tmp);
            check_out(5,tmp);
            // Regular case obtain 
            // data from icache and 
            // send the data
            test_sim_6(tmp);
            check_out(6,tmp);
            // Check the buffer
            test_sim_7(tmp);
            check_out(7,tmp);
            // Check the buffer when changing addr of req
            // and coming back to the one in the buffer
            test_sim_8(tmp);
            check_out(8,tmp);
        end
    endtask

//ReadCheck: assert (data === correct_data)
//               else $error("memory read error");
//  Igt10: assert (I > 10)
//           else $warning("I is less than or equal to 10");

    task automatic set_req_to_icache;
        input int unsigned vaddr;
        input int unsigned valid;
        begin
            if(VERBOSE) begin
                $display("*** set_req from icache addr: %d valid: %d",vaddr,valid);
            end
            tb_req_fetch_icache_i.vaddr <= vaddr;       
            tb_req_fetch_icache_i.valid <= valid;
            tb_req_fetch_icache_i.invalidate_icache <= 0;
            tb_req_fetch_icache_i.invalidate_buffer <= 0;
        end
    endtask

    task automatic set_req_from_icache;
        input logic [127:0] datablock;
        input int unsigned vaddr;
        input int unsigned valid;
        input int unsigned ready;
        input int unsigned ptw_invalidate;
        input int unsigned tlb_miss;
        input int unsigned resp_xcp_if;
        begin
            if(VERBOSE) begin
                $display("*** set_req from icache addr:");
            end
            tb_icache_resp_datablock_i <= datablock; // ICACHE_RESP_BITS_DATABLOCK
            tb_icache_resp_vaddr_i <= vaddr;
            tb_icache_resp_valid_i <= valid; // ICACHE_RESP_VALID,
            tb_icache_req_ready_i <= ready;
            tb_ptw_invalidate_i <= ptw_invalidate; // PTWINVALIDATE,
            tb_tlb_resp_miss_i <= tlb_miss; // TLB_RESP_MISS,
            tb_tlb_resp_xcp_if_i <= resp_xcp_if; // TLB_RESP_XCPT_IF,
          
        end
    endtask

    // Output should be nothing
    task automatic test_sim_1;
        output int tmp;
        begin
            tb_test_name = "test_sim_1";
            set_req_to_icache(8192,0);
            #CLK_HALF_PERIOD;
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 0;
            #CLK_HALF_PERIOD;
        end
    endtask

    // Normal request
    task automatic test_sim_2;
        output int tmp;
        begin
            tb_test_name = "test_sim_2";
            set_req_to_icache(8192,1);
            set_req_from_icache(128'h0,40'h0,0,1,0,0,0);
            #CLK_HALF_PERIOD;
            tmp = 0;
            tmp += tb_icache_req_valid_o != 1;
            tmp += tb_tlb_req_valid_o != 1;
            tmp += tb_resp_icache_fetch_o.valid != 0;
            #CLK_HALF_PERIOD;
        end
    endtask

    // TLB miss
    task automatic test_sim_3;
        output int tmp;
        begin
            tb_test_name = "test_sim_3";
            // Normal request
            set_req_to_icache(8192,1);
            set_req_from_icache(128'h0,40'h0,0,1,0,0,0);
            tick();

            // TLB miss
            set_req_from_icache(128'h008040130050001300003013fff02013,8192,0,0,0,1,0);
            tick();

            // Check output
            #CLK_HALF_PERIOD;
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 0;
            #CLK_HALF_PERIOD;
        end
    endtask

    task automatic test_sim_4;
        output int tmp;
        begin
            tb_test_name = "test_sim_4";
            // Normal request
            set_req_to_icache(8192,1);
            set_req_from_icache(128'h0,40'h0,0,1,0,0,0);
            tick();

            // PTW invalidate
            set_req_from_icache(128'h008040130050001300003013fff02013,8192,0,0,1,0,0);
            tick();

            // Check output
            #CLK_HALF_PERIOD;
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 0;
            #CLK_HALF_PERIOD;
        end
    endtask

    task automatic test_sim_5;
        output int tmp;
        begin
            tb_test_name = "test_sim_5";
            // Normal request
            set_req_to_icache(8192,1);
            set_req_from_icache(128'h0,40'h0,0,1,0,0,0);
            tick();

            // TLB exception
            set_req_from_icache(128'h008040130050001300003013fff02013,8192,0,0,0,0,1);
            tick();

            // Check output
            #CLK_HALF_PERIOD;
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 0;
            #CLK_HALF_PERIOD;
        end
    endtask

    task automatic test_sim_6;
        output int tmp;
        begin
            tb_test_name = "test_sim_6";
            reset_dut();
            // Normal request
            set_req_to_icache(8192,1);
            set_req_from_icache(128'h0,40'h0,0,1,0,0,0);
            tick();

            // Normal case
            set_req_from_icache(128'h008040130050001300003013fff02013,8192,1,1,0,0,0);
            tick();

            // Check output
            half_tick();
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            //tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 1;
            half_tick();

        end
    endtask

    // We have a valid buffer
    // we make a request for 
    // the next 3 addresses until the 4th
    // makes a new request 
    task automatic test_sim_7;
        output int tmp;
        begin
            tb_test_name = "test_sim_7";
            // Normal request
            set_req_to_icache(8192,1);
            // Check output
            half_tick();
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            //tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 1;
            half_tick();
            
            // Normal request
            set_req_to_icache(8196,1);
            // Check output
            half_tick();
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            //tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 1;
            half_tick();
            
            // Normal request
            set_req_to_icache(8200,1);
            // Check output
            half_tick();
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            //tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 1;
            half_tick();
            
            // Normal request
            set_req_to_icache(8204,1);
            // Check output
            half_tick();
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            //tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 1;
            half_tick();

            // Normal request
            // now it creates a miss
            set_req_to_icache(8208,1);
            // Check output
            half_tick();
            tmp = 0;
            tmp += tb_icache_req_valid_o != 1;
            //tmp += tb_icache_req_kill_o != 1;
            tmp += tb_tlb_req_valid_o != 1;
            tmp += tb_resp_icache_fetch_o.valid != 0;
            half_tick();
            
        end
    endtask

    // We are making a request and
    // the req addr changes
    task automatic test_sim_8;
        output int tmp;
        begin
            tb_test_name = "test_sim_8";
            
            // Normal request from before
            set_req_to_icache(8208,1);
            tick();
            // change of @
            set_req_to_icache(8204,1);
            // Check output @
            // now should be hit from the buffer
            half_tick();
            tmp = 0;
            tmp += tb_icache_req_valid_o != 0;
            tmp += tb_icache_req_kill_o != 0;
            tmp += tb_tlb_req_valid_o != 0;
            tmp += tb_resp_icache_fetch_o.valid != 1;
            half_tick();
            
        end
    endtask

    task automatic check_out;
        input int test;
        input int status;
        begin
            if (status) begin
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
//`default_nettype wire
