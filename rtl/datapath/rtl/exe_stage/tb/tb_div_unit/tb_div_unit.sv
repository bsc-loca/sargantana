//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_mul_unit.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Rubén Langarita
* Email(s)       : ruben.langarita@bsc.es
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
//`default_nettype none

`include "colors.vh"
import drac_pkg::*;

module tb_div_unit();

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
logic tb_kill_div_i;
logic tb_request_i;
logic tb_int_32_i;
logic tb_signed_op_i;
bus64_t tb_src1_i;
bus64_t tb_src2_i;
bus64_t tb_quo_o;
bus64_t tb_rmd_o;
reg tb_stall_o;
reg[63:0] result_q;
reg[63:0] result_r;
reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

div_unit module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .kill_div_i(tb_kill_div_i),
    .request_i(tb_request_i),
    .int_32_i(tb_int_32_i),
    .signed_op_i(tb_signed_op_i),
    .dvnd_i(tb_src1_i),
    .dvsr_i(tb_src2_i),
    .quo_o(tb_quo_o),
    .rmd_o(tb_rmd_o),
    .stall_o(tb_stall_o)
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
            tb_kill_div_i<='{default:0};
            tb_request_i<='{default:0};
            tb_int_32_i<='{default:0};
            tb_signed_op_i<='{default:0};
            tb_src1_i<='{default:0};
            tb_src2_i<='{default:0};
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
            $dumpvars(0,module_inst);
        end
    endtask

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            $display("*** test_sim");
            test_sim_1(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end
            test_sim_2(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 2 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 2 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask

//ReadCheck: assert (data === correct_data)
//               else $error("memory read error");
//  Igt10: assert (I > 10)
//           else $warning("I is less than or equal to 10");

    task automatic set_srcs;
        input int unsigned src1;
        input int unsigned src2;
        begin
            tb_src1_i  <= src1;
            tb_src2_i  <= src2;
            tb_request_i <= 1;
        end
    endtask

// Test performs division and remanent on unsigned 32 bit operands
    task automatic test_sim_1;
        output int tmp;
        begin
            tb_test_name = "test_sim_1";
            tmp = 0;
            tb_int_32_i <= 1'b1;
            for(int i = 0; i < 500; i++) begin
                int unsigned src1 = $urandom();
                int unsigned src2 = $urandom();
                tb_signed_op_i <= 1'b0;
                set_srcs(src1,src2);
                #CLK_PERIOD;
                result_q[31:0] = (src1/src2);
                result_q[63:32] = {32{result_q[31]}}; 
                result_r[31:0] = (src1%src2);
                result_r[63:32] = {32{result_r[31]}};
                while(tb_stall_o == 1) begin
                    #CLK_PERIOD;
                end
                if (tb_quo_o != result_q) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h / %h = %h out: %h",src1,src2,result_q,tb_quo_o);
                    `END_COLOR_PRINT
                end
                if (tb_rmd_o != result_r) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h remainder %h = %h out: %h",src1,src2,result_r,tb_rmd_o);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask


// Test performs division and remanent on unsigned 64 bit operands 
    task automatic test_sim_2;
        output int tmp;
        begin
            tb_test_name = "test_sim_2";
            tmp = 0;
            for(int i = 0; i < 500; i++) begin
                longint unsigned src1;
                longint unsigned src2;
                tb_src1_i[31:0]  = $urandom();
                tb_src1_i[63:32] = $urandom();
                src1 = tb_src1_i;
                tb_src2_i[31:0]  = $urandom();
                tb_src2_i[63:32] = $urandom();
                src2 = tb_src2_i;
                tb_request_i <= 1'b1;
                tb_signed_op_i <= 1'b0;
                tb_int_32_i <= 1'b0;
                #CLK_PERIOD;
                result_q = (src1/src2);
                result_r = (src1%src2);
                while(tb_stall_o == 1) begin
                    #CLK_PERIOD;
                end
                if (tb_quo_o != result_q) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h / %h = %h out: %h",src1,src2,result_q,tb_quo_o);
                    `END_COLOR_PRINT
                end
                if (tb_rmd_o != result_r) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h remainder %h = %h out: %h",src1,src2,result_r,tb_rmd_o);
                    `END_COLOR_PRINT
                end
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
