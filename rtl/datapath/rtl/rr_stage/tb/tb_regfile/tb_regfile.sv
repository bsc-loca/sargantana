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


    task automatic test_sim1;
        output int tmp;
        begin
            //$display("*** tick");
            tmp = 0;
	    #CLK_PERIOD;
            tb_write_enable_i = 1'b1;
            tb_write_addr_i = 5'b00001;
            tb_write_data_i = 64'h01;
            tb_read_addr1_i = 5'b00000;
            tb_read_addr2_i = 5'b00000;
            #CLK_PERIOD;
            tb_write_enable_i = 1'b0;
	    tb_write_addr_i = 5'b00000;
	    assert(tb_read_data1_o == 0) else begin tmp++; assert(1 == 0); end
            assert(tb_read_data2_o == 0) else begin tmp++; assert(1 == 0); end
	    tb_read_addr1_i = 5'b00001;
	    tb_read_addr2_i = 5'b00001;
	    #CLK_PERIOD;
            assert(tb_read_data1_o == 64'h01) else begin tmp++; assert(1 == 0); end
            assert(tb_read_data2_o == 64'h01) else begin tmp++; assert(1 == 0); end
        end
    endtask

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            $display("*** test_sim");
            test_sim1(tmp);
	    if(tmp == 0) begin
                `START_GREEN_PRINT
                $display("PASS");
                `END_COLOR_PRINT
	    end else begin
                `START_RED_PRINT
                $error("FAIL");
                `END_COLOR_PRINT
            end
        end
    endtask


//***init_sim***
//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_sim();
        init_dump();
        test_sim();
    end


endmodule
//`default_nettype wire
