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
//`default_nettype none

`include "colors.vh"
import drac_pkg::*;

module tb_module();

//-----------------------------
// Local parameters
//-----------------------------

parameter VERBOSE         = 1;
parameter CLK_PERIOD      = 2;
parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

//-----------------------------
// Signals
//-----------------------------

bus64_t      tb_data_rs1_i;
bus64_t      tb_data_rs2_i;
instr_type_t tb_instr_type_i;
bus64_t      tb_result_o;

reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

alu module_inst (
    .data_rs1_i(tb_data_rs1_i),
    .data_rs2_i(tb_data_rs2_i),
    .instr_type_i(tb_instr_type_i),
    .result_o(tb_result_o)
);

//-----------------------------
// DUT
//-----------------------------

//***task automatic init_sim***
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_data_rs1_i<='{default:0};
            tb_data_rs2_i<='{default:0};
            tb_instr_type_i<='{default:0};
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

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            $display("*** test_sim");
            test_sim_1(tmp);
            check_out(1,tmp);
            test_sim_2(tmp);
            check_out(2,tmp);
            test_sim_3(tmp);
            check_out(3,tmp);
            test_sim_4(tmp);
            check_out(4,tmp);
            test_sim_5(tmp);
            check_out(5,tmp);
            test_sim_6(tmp);
            check_out(6,tmp);
        end
    endtask

// Testing add
    task automatic test_sim_1;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_1";
            tmp = 0;
            tb_instr_type_i <= ADD;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                #CLK_PERIOD;
                correct_result = src1+src2;
                if (tb_result_o != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h + %h = %h out: %h",src1,src2,correct_result,tb_result_o);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing sub
    task automatic test_sim_2;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_2";
            tmp = 0;
            tb_instr_type_i <= SUB;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2 = $urandom();
                src2[63:32] = $urandom();
                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                #CLK_PERIOD;
                correct_result = src1-src2;
                if (tb_result_o != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h + %h = %h out: %h",src1,src2,correct_result,tb_result_o);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing Shift Left Logical
    task automatic test_sim_3;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_3";
            tmp = 0;
            tb_instr_type_i <= SLL;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2[5:0] = $urandom();
                src2[63:6] = 0;
                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                #CLK_PERIOD;
                correct_result = src1<<src2;
                if (tb_result_o != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h << %h = %h out: %h",src1,src2,correct_result,tb_result_o);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing Shift Right Logical
    task automatic test_sim_4;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_4";
            tmp = 0;
            tb_instr_type_i <= SRL;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src1[63:32] = $urandom();
                src2[5:0] = $urandom();
                src2[63:6] = 0;
                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                #CLK_PERIOD;
                correct_result = src1>>src2;
                if (tb_result_o != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h >> %h = %h out: %h",src1,src2,correct_result,tb_result_o);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing add word
    task automatic test_sim_5;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_5";
            tmp = 0;
            tb_instr_type_i <= ADDW;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src2 = $urandom();
                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                #CLK_PERIOD;
                correct_result[31:0] = src1+src2;
                correct_result[63:32] = {32{correct_result[31]}};
                if (tb_result_o != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h + %h = %h out: %h",src1,src2,correct_result,tb_result_o);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

// Testing sub word
    task automatic test_sim_6;
        output int tmp;
        begin
            longint src1,src2,correct_result;
            tb_test_name = "test_sim_6";
            tmp = 0;
            tb_instr_type_i <= SUBW;
            for(int i = 0; i < 100; i++) begin
                src1 = $urandom();
                src2 = $urandom();
                tb_data_rs1_i <= src1;
                tb_data_rs2_i <= src2;
                #CLK_PERIOD;
                correct_result[31:0] = src1-src2;
                correct_result[63:32] = {32{correct_result[31]}};
                if (tb_result_o != correct_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h - %h = %h out: %h",src1,src2,correct_result,tb_result_o);
                    `END_COLOR_PRINT
                end
            end
        end
    endtask

//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_dump();
        test_sim();
        $finish;
    end


endmodule
//`default_nettype wire

