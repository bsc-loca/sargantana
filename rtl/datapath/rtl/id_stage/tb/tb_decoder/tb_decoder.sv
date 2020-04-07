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

import riscv_pkg::*;
import drac_pkg::*;

module tb_decoder();

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

    if_id_stage_t tb_decode_i;
    instr_entry_t tb_decode_instr_o;


//-----------------------------
// Module
//-----------------------------

    decoder decoder_inst(
        .decode_i(tb_decode_i),
        .decode_instr_o(tb_decode_instr_o)
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
            tb_decode_i<='{default:0};
            
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
            $dumpvars(0,decoder_inst);
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
            tb_decode_i.pc_inst = 40'h002010;
            tb_decode_i.inst = 32'hfff02013;
            tb_decode_i.valid = 1'b1;
            
            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;

            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;
            #CLK_PERIOD;

        end
    endtask

//***task automatic test_sim***
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
