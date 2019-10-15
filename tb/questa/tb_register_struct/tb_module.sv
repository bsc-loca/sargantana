//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : .v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : 
* Email(s)       : @bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
* -----------------------------------------------
*/

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
`default_nettype none

`include "colors.vh"
import drac_pkg::*;

module tb_module();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
//***DUT parameters***    
    //parameter TB_DATA_WIDTH = 32;
    //parameter TB_WEIGHTS_WIDTH = 7;
    //parameter TB_N_CORES = 1;
    //parameter TB_CORE_EVENTS = 1;

//-----------------------------
// Signals
//-----------------------------
reg tb_clk_i;
reg tb_rstn_i;
reg tb_load_i;
instr_entry_t in;
instr_entry_t in2;
instr_entry_t out;
instr_entry_t out2;

//-----------------------------
// Module
//-----------------------------

register #($bits(instr_entry_t)+$bits(instr_entry_t)) module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .load_i(tb_load_i),
    .input_i({in,in2}),
    .output_o({out,out2})
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
//This is an empty structure for initializing your testbench, consider how the real hardware will behave instead of set all to zero as the initial state. Remove the TODO label and start writing.
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};
            tb_load_i<='{default:0};
            in<='{default:0};
            in2<='{default:0};
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
//This is an empty structure for a test. Remove the TODO label and start writing, several tasks can be used.
    task automatic test_sim;
        begin
            $display("*** test_sim");
            test_sim_1();
            reset_dut();
            test_sim_2();
            reset_dut();
            test_sim_3();
            reset_dut();
        end
    endtask

// Test load register
    task automatic test_sim_1;
        begin
            int unsigned tmp = 0;
            tb_load_i <= 1;
            $random(10);
            @(negedge tb_clk_i);
            for(int i = 0; i < 10; i++) begin
                in.result <= $urandom();
                in2.result <= $urandom();
                //wait(tb_clk_i == 0);
                //wait(tb_clk_i == 1);
                //#CLK_PERIOD;
                @(posedge tb_clk_i);
                @(negedge tb_clk_i);
                if (out.result != in.result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect out: %d != correct: %d",out.result,in.result);
                    $error("clk %d",tb_clk_i);
                    `END_COLOR_PRINT
                end
            end
            if (tmp == 1) begin
                `START_RED_PRINT
                    $display("TEST LOAD FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                    $display("TEST LOAD PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask

// Test no load register
    task automatic test_sim_2;
        begin
            int unsigned tmp = 0;
            int unsigned aux = 0;
            $random(10);
            // Load first value
            tb_load_i <= 1;
            aux = $urandom();
            in.result <= aux;
            #CLK_PERIOD;
            // Turn off load
            tb_load_i <= 0;
            for(int i = 0; i < 10; i++) begin
                in.result <= $urandom();
                #CLK_PERIOD;
                if (out.result != aux) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect out: %d != correct: %d",out.result,aux);
                    `END_COLOR_PRINT
                end
            end
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST NO LOAD FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST NO LOAD PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask

// Test reset register
    task automatic test_sim_3;
        begin
            int unsigned tmp = 0;
            $random(10);
            tb_load_i <= 1;
            in.result <= $urandom();
            #CLK_PERIOD;
            tb_rstn_i <= 0;
            for(int i = 0; i < 10; i++) begin
                in.result <= $urandom();
                #CLK_PERIOD;
                if (out.result != 0) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect out: %d",out.result);
                    `END_COLOR_PRINT
                end
            end
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST RESET FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST RESET PASSED.");
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
    end


endmodule
`default_nettype wire

