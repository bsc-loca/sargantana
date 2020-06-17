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
    logic          tb_icache_resp_valid_i; // ICACHE_RESP_VALID;
    logic          tb_ptw_invalidate_i; // PTWINVALIDATE;
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

//-----------------------------
// Module
//-----------------------------

    icache_interface icache_interface_inst(
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .req_fetch_icache_i(tb_req_fetch_icache_i),
        .icache_resp_datablock_i(tb_icache_resp_datablock_i), // ICACHE_RESP_BITS_DATABLOCK
        .icache_resp_valid_i(tb_icache_resp_valid_i), // ICACHE_RESP_VALID,
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
            tb_icache_resp_valid_i<='{default:0}; // ICACHE_RESP_VALID;
            tb_ptw_invalidate_i<='{default:0}; // PTWINVALIDATE;
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
//***task automatic test_sim***
    task automatic test_sim;
        begin
            $display("*** test_sim");
            // check req valid 0
            test_sim_1();
            // check req valid
            test_sim_2();
            // check read a stream
            test_sim_3();
            // check read a block from next datablock create a miss
            test_sim_4();
            // test getting a block with if_exception
            test_sim_5();
            // test getting a stream of 2020 2030 2040 2050
            test_sim_6();
            // test getting a stream of 200 until 20C then no reting next
            test_sim_7();
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
            //tb_req_fetch_icache_i.vaddr <= vaddr;       
            //tb_req_fetch_icache_i.valid = 1'b10       
        end
    endtask

    task automatic set_req_from_icache;
        input logic [127:0] datablock;
        input int unsigned valid;
        input int unsigned ptw_invalidate;
        input int unsigned tlb_miss;
        input int unsigned resp_xcp_if;
        begin
            if(VERBOSE) begin
                $display("*** set_req from icache addr:");
            end
            tb_icache_resp_datablock_i <= datablock; // ICACHE_RESP_BITS_DATABLOCK
            tb_icache_resp_valid_i <= valid; // ICACHE_RESP_VALID,
            tb_ptw_invalidate_i <= ptw_invalidate; // PTWINVALIDATE,
            tb_tlb_resp_miss_i <= tlb_miss; // TLB_RESP_MISS,
            tb_tlb_resp_xcp_if_i <= resp_xcp_if; // TLB_RESP_XCPT_IF,
          
        end
    endtask

// Test getting a petition that is not valid
// Output should be nothing 
    task automatic test_sim_1;
        begin
            set_req_to_icache(8192,0);
            tick();
            // Assert to check whether if we req a valid addr
            // the valid req to the cache is valid and the tlb
            assert (tb_icache_req_valid_o == 0)
                else $error("Icache Req not valid ");
            assert (tb_tlb_req_valid_o == 0)
                else $error("TLB Req not valid ");
            assert (tb_resp_icache_fetch_o.valid == 0)
                else $error("req_icache_fetch_o.valid is 1");
            tick();
            //ReadCheck: assert (data === correct_data)
            //   else $error("memory read error");
            //Igt10: assert (I > 10)
            //    else $warning("I is less than or equal to 10");
        end
    endtask

    // Test getting a petition that is misaligned
    // Output should be nothing 
    task automatic test_sim_2;
        begin
            int unsigned core_i;
            int unsigned value_o;
            $display("*** test_sim 2");
            set_req_to_icache(8193,1);
            tick();
            // Assert to check whether if we req a valid addr
            // the valid req to the cache is valid and the tlb
            assert (tb_icache_req_valid_o == 0)
                else $error("Icache Req not valid ");
            assert (tb_tlb_req_valid_o == 0)
                else $error("TLB Req not valid ");
            // Since we don't have anything on datablock
            // assert there is a miss in the buffer by answering
            // with not ready
            assert (tb_resp_icache_fetch_o.valid == 0)
                else $error("req_icache_fetch_o.valid is 1");
            tick();
            
        end
    endtask

    task automatic checkWaitingReady;
        begin
            if(VERBOSE)
                $display("*** Checking req valid output not");
            // Assert to check whether if we req a valid addr
            // the valid req to the cache is valid and the tlb
            assert (tb_icache_req_valid_o == 0)
                else $error("Icache Req valid ");
            assert (tb_tlb_req_valid_o == 0)
                else $error("TLB Req valid ");
            // we don't have a datablock
            assert (tb_resp_icache_fetch_o.valid == 0)
                else $error("req_icache_fetch_o.valid is 1");     
        end
    endtask 

    task automatic checkAssertOutput;
        input int unsigned valid;
        input int unsigned ex_valid;
        input int unsigned data;
        begin
            if(VERBOSE)
                $display("*** Checking Assert valid output data: %h %d %d",data,valid,ex_valid);
            assert (tb_resp_icache_fetch_o.valid == valid)
                else $error("req_icache_fetch_o.valid should be 1");
            assert (tb_resp_icache_fetch_o.data == data)
                else $error("req_icache_fetch_o.data wrong data value");
        end
    endtask
// Test getting a petition that is normal
// Output should be the requested data
// we define addr 8192 (0x2000) 
//    2000:   fff02013                slt     x0,x0,-1
//    2004:   00003013                sltiu   x0,x0,0
//    2008:   00500013                addi    x0,x0,5
//    200C:   00804013                xori    x0,x0,8
// datablock: 008040130050001300003013fff02013 
    task automatic test_sim_3;
        begin
            int unsigned core_i;
            int unsigned value_o;
            $display("*** test_sim 3");
            set_req_to_icache(8192,1);
            tick();
            // Assert to check whether if we req a valid addr
            // the valid req to the cache is valid and the tlb
            assertIcache: assert (tb_icache_req_valid_o == 1)
                else $error("Icache Req not valid ");
            assertTLB: assert (tb_tlb_req_valid_o == 1)
                else $error("TLB Req not valid ");
            // Since we don't have anything on datablock
            // assert there is a miss in the buffer by answering
            // with not ready
            assertValidOut: assert (tb_resp_icache_fetch_o.valid == 0)
                else $error("req_icache_fetch_o.valid is 1");
            tick();
            // It's a hit
            checkWaitingReady();
            tick();
            set_req_from_icache(128'h008040130050001300003013fff02013,1,0,0,0);
            tick();
            checkAssertOutput(1,0,32'hfff02013);
            set_req_to_icache(8196,1);
            tick();
            checkAssertOutput(1,0,32'h00003013);
            set_req_to_icache(8200,1);
            tick();
            checkAssertOutput(1,0,32'h00500013);
            set_req_to_icache(8204,1);
            tick();
            checkAssertOutput(1,0,32'h00804013);
            tick();
            tick();
            // okay now data is back
        end
    endtask

// Test getting a petition that is normal
// Output should be the requested data
// we define addr 8192 (0x2000) 
//    2010:   87654321                
//    2014:   87654321                
//    2018:   87654321                
//    201C:   87654321                
// datablock: 87654321123456788765432112345678 
    task automatic test_sim_4;
        begin
            int unsigned core_i;
            int unsigned value_o;
            $display("*** test_sim 4");
            set_req_to_icache(40'h002010,1);
            set_req_from_icache(128'h0,0,0,0,0);
            tick();
            // Assert to check whether if we req a valid addr
            // the valid req to the cache is valid and the tlb
            assertIcache: assert (tb_icache_req_valid_o == 1)
                else $error("Icache Req not valid ");
            assertTLB: assert (tb_tlb_req_valid_o == 1)
                else $error("TLB Req not valid ");
            // Since we don't have anything on datablock
            // assert there is a miss in the buffer by answering
            // with not ready
            assertValidOut: assert (tb_resp_icache_fetch_o.valid == 0)
                else $error("req_icache_fetch_o.valid is 1");
            tick();
            // It's a hit
            checkWaitingReady();
            tick();
            set_req_from_icache(128'h87654321123456788765432112345678,1,0,0,0);
            tick();
            checkAssertOutput(1,0,32'h12345678);
            set_req_to_icache(40'h002014,1);
            tick();
            checkAssertOutput(1,0,32'h87654321);
            set_req_to_icache(40'h002018,1);
            tick();
            checkAssertOutput(1,0,32'h12345678);
            set_req_to_icache(40'h00201C,1);
            tick();
            checkAssertOutput(1,0,32'h87654321);
            tick();
            // okay now data is back
        end
    endtask

    task automatic checkAssertAfterNewPetition;
        input int unsigned valid;
        input int unsigned valid_tlb;
        input int unsigned valid_out;
        begin
            if (VERBOSE)
                $display("*** Checking icache tlb and out req valid: %h %d %d",valid,valid_tlb,valid_out);
            // Assert to check whether if we req a valid addr
            // the valid req to the cache is valid and the tlb
            assertIcache: assert (tb_icache_req_valid_o == valid)
                else $error("Icache Req not valid ");
            assertTLB: assert (tb_tlb_req_valid_o == valid_tlb)
                else $error("TLB Req not valid ");
            // Since we don't have anything on datablock
            // assert there is a miss in the buffer by answering
            // with not ready
            assertValidOut: assert (tb_resp_icache_fetch_o.valid == valid_out)
                else $error("req_icache_fetch_o.valid is 1");
        end
    endtask

// Test getting a stream of petitions
// 2030
// 2040
// 2050
    task automatic test_sim_5;
        begin
            int unsigned core_i;
            int unsigned value_o;
            $display("*** test_sim 5");
            set_req_to_icache(40'h002030,1);
            set_req_from_icache(128'h0,0,0,0,0);
            tick();
            checkAssertAfterNewPetition(1,1,0);
            tick();
            // It's a hit
            checkWaitingReady();
            tick();
            set_req_from_icache(128'h87654321123456788765432112345678,1,0,0,0);
            tick();
            checkAssertOutput(1,0,32'h12345678);
            set_req_to_icache(40'h002040,1);
            set_req_from_icache(128'h0,0,0,0,0);
            tick();
            checkAssertAfterNewPetition(1,1,0);
            set_req_from_icache(128'h87654321123456788765432112345678,1,0,0,0);
            tick();
            checkAssertOutput(1,0,32'h12345678);
            set_req_to_icache(40'h002050,1);
            set_req_from_icache(128'h0,0,0,0,0);
            tick();
            checkAssertAfterNewPetition(1,1,0);
            set_req_from_icache(128'h87654321123456788765432112345678,1,0,0,0);
            tick();
        end
    endtask

// Test getting a petition that is normal
// Output should be the requested data
// we define addr 8192 (0x2000) 
//    2060:   has an exception                              
// datablock: 87654321123456788765432112345678 
    task automatic test_sim_6;
        begin
            int unsigned core_i;
            int unsigned value_o;
            $display("*** test_sim 6");
            set_req_to_icache(40'h002060,1);
            set_req_from_icache(128'h0,0,0,0,0);
            tick();
            checkAssertAfterNewPetition(1,1,0);
            tick();
            set_req_from_icache(128'h87654321123456788765432112345678,1,0,0,1);
            tick();
            // okay now data is back
        end
    endtask

    // check 8 petitions in sequence
    // h00200 204 208 20C
    // h00210 214 218 21C
    // output is   11111111222222223333333344444444
    // output 2 is 55555555666666667777777788888888
    task automatic test_sim_7;
        begin
            int unsigned core_i;
            int unsigned value_o;
            // make a reset
            $display("*** test_sim 7");
            //reset_dut();
            tick();
            set_req_from_icache(128'h0,0,0,0,0);
            tick();
            tick(); // Sim a miss 
            tick();
            set_req_to_icache(40'h00200,1);
            tick();
            tick();
            tick();
            set_req_from_icache(128'h11111111222222223333333344444444,1,0,0,0);
            
            tick();
            checkAssertOutput(1,0,32'h44444444);
            set_req_to_icache(40'h00204,1);
            
            tick();
            checkAssertOutput(1,0,32'h33333333);
            set_req_to_icache(40'h00208,1);
            
            tick();
            checkAssertOutput(1,0,32'h22222222);
            set_req_to_icache(40'h0020C,1);
            
            tick();
            checkAssertOutput(1,0,32'h11111111);
            set_req_to_icache(40'h00210,1); // No rest
            //checkAssertAfterNewPetition(1,1,0);
            //tick();
            //set_req_from_icache(128'h87654321123456788765432112345678,1,0,0,1);
            tick();
            checkAssertOutput(0,0,32'hxxxxxxxx);
            tick();
            // okay now data is back
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
        if(VERBOSE) begin
                $display("Define a parameter (parameter VERBOSE=0;) and guard\n\
                messages that are not needed. Most of the times with PASS/FAIL name of the \n\
                tests is enough"); 
        end
        `START_RED_PRINT
                $error("FAIL, add one of this for each test");
        `END_COLOR_PRINT
    end


endmodule
//`default_nettype wire
