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

logic             valid_fetch;
id_cu_t           id_cu_i;
rr_cu_t           rr_cu_i;
exe_cu_t          exe_cu_i;
wb_cu_t           wb_cu_i;
resp_csr_cpu_t    csr_cu_i;
logic             correct_branch_pred_i;

pipeline_ctrl_t  pipeline_ctrl_o;
pipeline_flush_t pipeline_flush_o;
cu_if_t          cu_if_o;
logic            invalidate_icache_o;
logic            invalidate_buffer_o;
cu_rr_t          cu_rr_o;

reg[64*8:0] tb_test_name;

//-----------------------------
// Module
//-----------------------------

control_unit module_inst (
    .valid_fetch(valid_fetch),
    .id_cu_i(id_cu_i),
    .rr_cu_i(rr_cu_i),
    .exe_cu_i(exe_cu_i),
    .wb_cu_i(wb_cu_i),
    .csr_cu_i(csr_cu_i),
    .correct_branch_pred_i(correct_branch_pred_i),

    .pipeline_ctrl_o(pipeline_ctrl_o),
    .pipeline_flush_o(pipeline_flush_o),
    .cu_if_o(cu_if_o),
    .invalidate_icache_o(invalidate_icache_o),
    .invalidate_buffer_o(invalidate_buffer_o),
    .cu_rr_o(cu_rr_o)
);


//-----------------------------
// DUT
//-----------------------------

//***task automatic init_sim***
    task automatic init_sim;
        begin
            $display("*** init_sim");
            valid_fetch<='{default:0};
            id_cu_i<='{default:0};
            rr_cu_i<='{default:0};
            exe_cu_i<='{default:0};
            wb_cu_i<='{default:0};
            csr_cu_i<='{default:0};
            correct_branch_pred_i<='{default:0};
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
            if (status == 1) begin
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
            //test_sim_2(tmp);
            //check_out(2,tmp);
            //test_sim_3(tmp);
            //check_out(3,tmp);
            //test_sim_4(tmp);
            //check_out(4,tmp);
            //test_sim_5(tmp);
            //check_out(5,tmp);
            //test_sim_6(tmp);
            //check_out(6,tmp);
        end
    endtask

// Testing add
    task automatic test_sim_1;
        output int tmp;
        begin
            int incorrect_result;
            tb_test_name = "test_sim_1";
            tmp = 0;

//pipeline_ctrl_t  pipeline_ctrl_o,
//pipeline_flush_t pipeline_flush_o,
//cu_if_t          cu_if_o,
//logic            invalidate_icache_o,
//logic            invalidate_buffer_o,
//cu_rr_t          cu_rr_o
            for(int i = 0; i < 100; i++) begin
                valid_fetch<=0;
                id_cu_i<=0;
                rr_cu_i<=0;
                exe_cu_i<=0;
                wb_cu_i<=0;
                csr_cu_i<=0;
                correct_branch_pred_i<=0;
                #CLK_PERIOD;
                incorrect_result = 0;
                incorrect_result += (pipeline_ctrl_o.sel_addr_if!=SEL_JUMP_DECODE);
                if (incorrect_result) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect");
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

