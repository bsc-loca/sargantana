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

addr_t        tb_io_base_addr_i;
logic         tb_dmem_resp_replay_i;
bus64_t       tb_dmem_resp_data_i;
logic         tb_dmem_req_ready_i;
logic         tb_dmem_resp_valid_i;
logic         tb_dmem_resp_nack_i;
logic         tb_dmem_xcpt_ma_st_i;
logic         tb_dmem_xcpt_ma_ld_i;
logic         tb_dmem_xcpt_pf_st_i;
logic         tb_dmem_xcpt_pf_ld_i;

reg           tb_dmem_req_valid_o;
reg  [4:0]    tb_dmem_req_cmd_o;
addr_t        tb_dmem_req_addr_o;
bus64_t       tb_dmem_op_type_o;
bus64_t       tb_dmem_req_data_o;
logic [7:0]   tb_dmem_req_tag_o;
logic         tb_dmem_req_invalidate_lr_o;
logic         tb_dmem_req_kill_o;
logic         tb_lock_o;

dec_exe_instr_t     tb_from_dec_i;
rr_exe_instr_t      tb_from_rr_i;
wb_exe_instr_t      tb_from_wb_i;
exe_wb_instr_t      tb_to_wb_o;

//-----------------------------
// Module
//-----------------------------

exe_top module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),

    .from_dec_i(tb_from_dec_i),
    .from_rr_i(tb_from_rr_i),
    .from_wb_i(tb_from_wb_i),

    .io_base_addr_i(tb_io_base_addr_i),
    .dmem_resp_replay_i(tb_resp_replay_i),
    .dmem_resp_data_i(tb_dmem_resp_data_i),
    .dmem_req_ready_i(tb_dmem_req_ready_i),
    .dmem_resp_valid_i(tb_dmem_resp_valid_i),
    .dmem_resp_nack_i(tb_dmem_resp_nack_i),
    .dmem_xcpt_ma_st_i(tb_dmem_xcpt_ma_st_i),
    .dmem_xcpt_ma_ld_i(tb_dmem_xcpt_ma_ld_i),
    .dmem_xcpt_pf_st_i(tb_dmem_xcpt_pf_st_i),
    .dmem_xcpt_pf_ld_i(tb_dmem_xcpt_pf_ld_i),

    .dmem_req_valid_o(tb_dmem_req_valid_o),
    .dmem_req_cmd_o(tb_dmem_req_cmd_o),
    .dmem_req_addr_o(tb_dmem_req_addr_o),
    .dmem_op_type_o(tb_dmem_op_type_o),
    .dmem_req_data_o(tb_dmem_req_data_o),
    .dmem_req_tag_o(tb_dmem_req_tag_o),
    .dmem_req_invalidate_lr_o(tb_dmem_req_invalidate_lr_o),
    .dmem_req_kill_o(tb_dmem_req_kill_o),
    .dmem_lock_o(tb_lock_o),

    .to_wb_o(tb_to_wb_o)
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

            tb_from_dec_i<='{default:0};
            tb_from_rr_i<='{default:0};
            tb_from_wb_i<='{default:0};

            tb_io_base_addr_i<='{default:0};
            tb_dmem_resp_replay_i<='{default:0};
            tb_dmem_resp_data_i<='{default:0};
            tb_dmem_req_ready_i<='{default:0};
            tb_dmem_resp_valid_i<='{default:0};
            tb_dmem_resp_nack_i<='{default:0};
            tb_dmem_xcpt_ma_st_i<='{default:0};
            tb_dmem_xcpt_ma_ld_i<='{default:0};
            tb_dmem_xcpt_pf_st_i<='{default:0};
            tb_dmem_xcpt_pf_ld_i<='{default:0};

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
//This is an empty structure for a test. Remove the TODO label and start writing, several tasks can be used.
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
        end
    endtask

// Test getting a petition that is not valid
// Output should be nothing 
    task automatic test_sim_1;
        output int tmp;
        begin
            tmp = 0;
            for(int i = 0; i < 1000; i++) begin
                tb_from_dec_i.functional_unit <= UNIT_ALU;
                tb_from_dec_i.alu_op <= ALU_ADD;
                tb_from_dec_i.use_imm <= 0;
                tb_from_dec_i.imm <= 0;
                tb_from_rr_i.data_rs1 <= 24;
                tb_from_rr_i.data_rs2 <= 28;
                #CLK_PERIOD;
                /*#CLK_HALF_PERIOD;
                if (tb_div_o != (src1/src2) | tb_rem_o != (src1%src2)) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %h / %h = %h mod %h out: %h mod %h",src1,src2,(src1/src2),(src1%src2),tb_div_o,tb_rem_o);
                    `END_COLOR_PRINT
                end
                #CLK_HALF_PERIOD;*/
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
//`default_nettype wire

