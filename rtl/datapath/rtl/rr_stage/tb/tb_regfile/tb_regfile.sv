//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_decoder.sv
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

module tb_regfile();

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

    reg     tb_write_enable_i;
    reg_t   tb_write_addr_i;
    bus64_t tb_write_data_i;
    // read ports input
    reg_t   tb_read_addr1_i;
    reg_t   tb_read_addr2_i;
    // read port output
    bus64_t tb_read_data1_o;
    bus64_t tb_read_data2_o;


//-----------------------------
// Module
//-----------------------------

    regfile regfile_inst( 
        .clk_i(tb_clk_i),
        .write_enable_i(tb_write_enable_i),
        .write_addr_i(tb_write_addr_i),
        .write_data_i(tb_write_data_i),
        .read_addr1_i(tb_read_addr1_i),
        .read_addr2_i(tb_read_addr2_i),
        .read_data1_o(tb_read_data1_o),
        .read_data2_o(tb_read_data2_o)
    );

//-----------------------------
// DUT
//-----------------------------


//***clk_gen***
// A single clock source is used in this design.
    initial tb_clk_i = 1;
    always #CLK_HALF_PERIOD tb_clk_i = !tb_clk_i;


//***task automatic init_sim***
//This is an empty structure for initializing your testbench, consider how the real hardware will behave instead of set all to zero as the initial state. Remove the TODO label and start writing.
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_write_enable_i<='{default:0};
            tb_write_addr_i<='{default:0};
            tb_write_data_i<='{default:0};
            tb_read_addr1_i<='{default:0};
            tb_read_addr2_i<='{default:0};
            
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
            $dumpvars(0,regfile_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

//    2000:   fff02013                slt     x0,x0,-1
//    2004:   00003013                sltiu   x0,x0,0
//    2008:   00500013                addi    x0,x0,5
//    200C:   00804013                xori    x0,x0,8

    task automatic test_sim1();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
            tb_write_enable_i = 1'b1;
            tb_write_addr_i = 5'b00001;
            tb_write_data_i = 64'h01;
            tb_read_addr1_i = 5'b00000;
            tb_read_addr2_i = 5'b00000;
            #CLK_PERIOD;

        end
    endtask

//***task automatic test_sim***
//This is an empty structure for a test. Remove the TODO label and start writing, several tasks can be used.
    task automatic test_sim;
        begin
            $display("*** test_sim");
            // check req valid 0
            test_sim1();
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
                $display("Define a parameter (parameter VERBOSE=0;) and guard\n\
                messages that are not needed. Most of the times with PASS/FAIL name of the \n\
                tests is enough"); 
        `START_RED_PRINT
                $error("FAIL, add one of this for each test");
        `END_COLOR_PRINT
    end


endmodule
//`default_nettype wire
