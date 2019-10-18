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

logic        tb_valid_i;
logic        tb_kill_i;
logic        tb_csr_eret_i;
bus64_t      tb_data_op1_i;
bus64_t      tb_data_op2_i;
mem_op_t     tb_mem_op_i;
mem_format_t tb_mem_format_i;
amo_op_t     tb_amo_op_i;
logic [2:0]   tb_funct3_i;
reg_t        tb_rd_i;
logic [39:0]       tb_imm_i;
addr_t   tb_io_base_addr_i;
logic         tb_dmem_resp_replay_i;
bus64_t   tb_dmem_resp_data_i;
logic         tb_dmem_req_ready_i;
logic         tb_dmem_resp_valid_i;
logic         tb_dmem_resp_nack_i;
logic         tb_dmem_xcpt_ma_st_i;
logic         tb_dmem_xcpt_ma_ld_i;
logic         tb_dmem_xcpt_pf_st_i;
logic         tb_dmem_xcpt_pf_ld_i;

reg          tb_dmem_req_valid_o;
reg  [4:0]   tb_dmem_req_cmd_o;
addr_t   tb_dmem_req_addr_o;
bus64_t   tb_dmem_op_type_o;
bus64_t   tb_dmem_req_data_o;
logic [7:0]   tb_dmem_req_tag_o;
logic         tb_dmem_req_invalidate_lr_o;
logic         tb_dmem_req_kill_o;
logic        tb_ready_o;
bus64_t      tb_data_o;
logic        tb_lock_o;


//-----------------------------
// Module
//-----------------------------

mem_unit module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),

    .valid_i(tb_valid_i),
    .kill_i(tb_kill_i),
    .csr_eret_i(tb_csr_eret_i),
    .data_op1_i(tb_data_op1_i),
    .data_op2_i(tb_data_op2_i),
    .mem_op_i(tb_mem_op_i),
    .mem_format_i(tb_mem_format_i),
    .amo_op_i(tb_amo_op_i),
    .funct3_i(tb_funct3_i),
    .rd_i(tb_rd_i),
    .imm_i(tb_imm_i),
    .io_base_addr_i(tb_io_base_addr_i),
    .dmem_resp_replay_i(tb_io_base_addr_i),
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
    .ready_o(tb_ready_o),
    .data_o(tb_data_o),
    .lock_o(tb_lock_o)
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

            tb_valid_i<='{default:0};
            tb_kill_i<='{default:0};
            tb_csr_eret_i<='{default:0};
            tb_data_op1_i<='{default:0};
            tb_data_op2_i<='{default:0};
            tb_mem_op_i<='{default:0};
            tb_mem_format_i<='{default:0};
            tb_amo_op_i<='{default:0};
            tb_funct3_i<='{default:0};
            tb_rd_i<='{default:0};
            tb_imm_i<='{default:0};
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

            tb_dmem_req_valid_o<='{default:0};
            tb_dmem_req_cmd_o<='{default:0};
            tb_dmem_req_addr_o<='{default:0};
            tb_dmem_op_type_o<='{default:0};
            tb_dmem_req_data_o<='{default:0};
            tb_dmem_req_tag_o<='{default:0};
            tb_dmem_req_invalidate_lr_o<='{default:0};
            tb_dmem_req_kill_o<='{default:0};
            tb_ready_o<='{default:0};
            tb_data_o<='{default:0};
            tb_lock_o<='{default:0};
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
            $random(10);
            for(int i = 0; i < 1000; i++) begin
                tb_valid_i<=1;
                tb_kill_i<=0;
                tb_csr_eret_i<=0;
                tb_data_op1_i<=57;
                tb_data_op2_i<=109;
                tb_mem_op_i<=MEM_LOAD;
                tb_mem_format_i<=DOUBLEWORD;
                tb_amo_op_i<=AMO_LR;
                tb_funct3_i<=0;
                tb_rd_i<=2;
                tb_imm_i<=5;
                tb_dmem_req_ready_i<=1;
                #CLK_PERIOD;
                #CLK_PERIOD;
                tb_dmem_req_ready_i<=0;
                tb_dmem_resp_valid_i<=1;
                tb_dmem_resp_data_i<=45;
                #CLK_PERIOD;
                tb_dmem_resp_valid_i<=0;
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

