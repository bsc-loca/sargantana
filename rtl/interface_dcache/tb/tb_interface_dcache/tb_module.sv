//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : tb_module.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : 
 * Email(s)       : victor.soria@bsc.es
 * References     : 
 * -----------------------------------------------
 * Revision History
 * Revision | Author     | Commit | Description
 * 0.1      | Victor SP  | 
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
    parameter MISS_TIMING     = 15;

//-----------------------------
// Signals
//-----------------------------
    reg tb_clk_i; 
    reg tb_rstn_i;

    req_cpu_dcache_t tb_req_cpu_dcache_i;
    logic        tb_dmem_resp_replay_i;
    bus64_t      tb_dmem_resp_data_i;
    logic        tb_dmem_req_ready_i;
    logic        tb_dmem_resp_valid_i;
    logic        tb_dmem_resp_nack_i;
    logic        tb_dmem_xcpt_ma_st_i;
    logic        tb_dmem_xcpt_ma_ld_i;
    logic        tb_dmem_xcpt_pf_st_i;
    logic        tb_dmem_xcpt_pf_ld_i;

    reg          tb_dmem_req_valid_o;
    reg  [4:0]   tb_dmem_req_cmd_o;
    addr_t       tb_dmem_req_addr_o;
    reg  [3:0]   tb_dmem_op_type_o;
    bus64_t      tb_dmem_req_data_o;
    logic [7:0]  tb_dmem_req_tag_o;
    logic        tb_dmem_req_invalidate_lr_o;
    logic        tb_dmem_req_kill_o;
    resp_dcache_cpu_t tb_resp_dcache_cpu_o;


//-----------------------------
// Module
//-----------------------------

dcache_interface module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),

    .req_cpu_dcache_i(tb_req_cpu_dcache_i), 

    .dmem_resp_replay_i(tb_dmem_resp_replay_i),
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

    .resp_dcache_cpu_o(tb_resp_dcache_cpu_o)
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
    //Initializing testbench.
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};

            tb_req_cpu_dcache_i.valid<='{default:0};
            tb_req_cpu_dcache_i.kill<='{default:0};
            tb_req_cpu_dcache_i.data_rs1<='{default:0};
            tb_req_cpu_dcache_i.data_rs2<='{default:0};
            tb_req_cpu_dcache_i.instr_type<='{default:0};
            tb_req_cpu_dcache_i.mem_size<='{default:0};
            tb_req_cpu_dcache_i.rd<='{default:0};
            tb_req_cpu_dcache_i.imm<='{default:0};
            tb_req_cpu_dcache_i.io_base_addr<='{default:40'h0040000000};
            tb_dmem_resp_replay_i<='{default:0};
            tb_dmem_resp_data_i<='{default:0};
            tb_dmem_req_ready_i<='{default:1};
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
            $dumpfile("dum_file.vcd");
            $dumpvars(0,module_inst);
        end
    endtask

    //***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            $display("*** test_sim");
            test_sim_1(tmp);
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end

            test_sim_2(tmp);
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 2 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 2 PASSED.");
                `END_COLOR_PRINT
            end

            test_sim_3(tmp);
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 3 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 3 PASSED.");
                `END_COLOR_PRINT
            end

            test_sim_4(tmp);
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 4 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 4 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask

    // Test does a load petition that misses and a load petition that hits the data cache
    task automatic test_sim_1;
        output int tmp;
        begin
            tmp = 0;

            // First memory access, load miss
            tb_dmem_req_ready_i <= 1;
            tb_req_cpu_dcache_i.valid <= 1;
            tb_req_cpu_dcache_i.kill <= 0;
            tb_req_cpu_dcache_i.data_rs1 <= 64'h1000;
            tb_req_cpu_dcache_i.data_rs2 <= 64'h1111;
            tb_req_cpu_dcache_i.instr_type <= LD;
            tb_req_cpu_dcache_i.mem_size <= 3'b011;
            tb_req_cpu_dcache_i.rd <= 5'h3;
            tb_req_cpu_dcache_i.imm <= 64'h01;
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            // Check request is done to dcache
            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h1111) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h06) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end     //ONLY CHANGE IN OUTPUT
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h1111) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h06) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end
            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 0;   // Simulate dcache blocked by a coherence req.

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1;   // Cache already online

            for (int i = 0; i < MISS_TIMING; i++) begin  // Wait 15 cycles of Miss
                #CLK_PERIOD;
            end

            tb_dmem_req_ready_i <= 0;

            // CHECK NOTHING CHANGES
            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h1111) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h06) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 0;

            // SERVE MISS
            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b1;
            tb_dmem_resp_valid_i <= 1'b1;
            tb_dmem_resp_data_i <= 64'h00FF00FF00FF00FF;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD
            // Stop serving miss
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;
 
            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h1111) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h06)  else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'h00FF00FF00FF00FF)  else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b1)  else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0)  else begin tmp++; assert(1 == 0); end

            // Some non related instructions
            tb_req_cpu_dcache_i.valid <= 1'b0;
            tb_req_cpu_dcache_i.instr_type <= ADD;
            
            // Wait some cycles
            #CLK_PERIOD
            #CLK_PERIOD
            #CLK_PERIOD
 

            // Second memory access, store hit.
            tb_dmem_req_ready_i <= 1;
            tb_req_cpu_dcache_i.valid <= 1;
            tb_req_cpu_dcache_i.kill <= 0;
            tb_req_cpu_dcache_i.data_rs1 <= 64'h1000;
            tb_req_cpu_dcache_i.data_rs2 <= 64'hFFFF;
            tb_req_cpu_dcache_i.instr_type <= LD;
            tb_req_cpu_dcache_i.mem_size <= 3'b011;
            tb_req_cpu_dcache_i.rd <= 5'h5;
            tb_req_cpu_dcache_i.imm <= 64'h08;
            assert (tb_resp_dcache_cpu_o.ready == 1'b0)  else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0)  else begin tmp++; assert(1 == 0); end

            // Check request is done
            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1)  else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00)  else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1008)  else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'hFFFF) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0A) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1008) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'hFFFF) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0A) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            // SERVE HIT
            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b1;
            tb_dmem_resp_data_i <= 64'hFF00FF00FF00FF00;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD;

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1008) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'hFFFF) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0A) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hFF00FF00FF00FF00) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end
        end
    endtask


    // Test does a store petition that misses and a store petition that hits the data cache
    task automatic test_sim_2;
        output int tmp;
        begin
            tb_req_cpu_dcache_i.io_base_addr <= 40'h0040000000;

            tmp = 0;
            tb_req_cpu_dcache_i.valid <= 0;
            tb_req_cpu_dcache_i.kill <= 0;
            tb_req_cpu_dcache_i.data_rs1 <= 64'h0;
            tb_req_cpu_dcache_i.data_rs2 <= 64'h0;
            
            #CLK_PERIOD;

            // First memory access, load miss
            tb_dmem_req_ready_i <= 1;
            tb_req_cpu_dcache_i.valid <= 1;
            tb_req_cpu_dcache_i.kill <= 0;
            tb_req_cpu_dcache_i.data_rs1 <= 64'h2000;
            tb_req_cpu_dcache_i.data_rs2 <= 64'h00AA00AA00AA00AA;
            tb_req_cpu_dcache_i.instr_type <= SD;
            tb_req_cpu_dcache_i.mem_size <= 3'b011;
            tb_req_cpu_dcache_i.rd <= 5'h00;
            tb_req_cpu_dcache_i.imm <= 64'h02;
            assert (tb_resp_dcache_cpu_o.ready == 1'b0)  else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end


            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end   // Is a store
            assert (tb_dmem_req_addr_o == 64'h2002) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h00AA00AA00AA00AA) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end     //ONLY CHANGE IN OUTPUT
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h2002) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h00AA00AA00AA00AA) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 0;   // Simulate dcache blocked by a coherence req.

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1;   // Cache already online

            for (int i = 0; i < MISS_TIMING; i++) begin  // Wait 15 cycles of Miss
                #CLK_PERIOD;
            end

            tb_dmem_req_ready_i <= 0;

            // CHECK NOTHING CHANGES
            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h2002) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h00AA00AA00AA00AA) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 0;

            // SERVE MISS
            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b1;
            tb_dmem_resp_valid_i <= 1'b1;
            tb_dmem_resp_data_i <= 64'hDEADBEEFDEADBEEF;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;
            tb_dmem_resp_data_i <= 64'h00AA00AA00AA00AA;
 
            assert (tb_dmem_req_valid_o == 1'b0)  else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h2002) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h00AA00AA00AA00AA) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end  // Store has no ready
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            tb_req_cpu_dcache_i.valid <= 1'b0;
            tb_req_cpu_dcache_i.instr_type <= ADD;
            
            // Wait some cycles
            #CLK_PERIOD
            #CLK_PERIOD
            #CLK_PERIOD
 

            // Second memory access, load hit.
            tb_dmem_req_ready_i <= 1;
            tb_req_cpu_dcache_i.valid <= 1;
            tb_req_cpu_dcache_i.kill <= 0;
            tb_req_cpu_dcache_i.data_rs1 <= 64'h0000;
            tb_req_cpu_dcache_i.data_rs2 <= 64'hAA00AA00AA00AA00;
            tb_req_cpu_dcache_i.instr_type <= SD;
            tb_req_cpu_dcache_i.mem_size <= 3'b011;
            tb_req_cpu_dcache_i.rd <= 5'h0;
            tb_req_cpu_dcache_i.imm <= 64'h00;
            assert (tb_resp_dcache_cpu_o.ready == 1'b0);
            assert (tb_resp_dcache_cpu_o.lock == 1'b0);

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'hAA00AA00AA00AA00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0)  else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'hAA00AA00AA00AA00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            // SERVE HIT
            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b1;
            tb_dmem_resp_data_i <= 64'hDEADBEEFDEADBEEF;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD;
            // Stop serving
            tb_dmem_req_ready_i <= 1'b0;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;
 
            assert (tb_dmem_req_valid_o == 1'b0)  else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'hAA00AA00AA00AA00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hDEADBEEFDEADBEEF)  else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            tb_req_cpu_dcache_i.valid <= 0;
        end
    endtask

    // Test performs memory accesses that rise exceptions
    task automatic test_sim_3;
        output int tmp;
        begin
            tmp = 0;

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1;
            #CLK_PERIOD;

            // Store Access that rises miss_aligned exception

            tb_req_cpu_dcache_i.valid <= 1;
            tb_req_cpu_dcache_i.kill <= 0;
            tb_req_cpu_dcache_i.data_rs1 <= 64'h1010;
            tb_req_cpu_dcache_i.instr_type <= LH;
            tb_req_cpu_dcache_i.mem_size <= 3'b001;
            tb_req_cpu_dcache_i.rd <= 5'h07;
            tb_req_cpu_dcache_i.imm <= 64'h09;
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1019) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0E) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b001) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_data_i <= 64'hBA00BA00BA00BA00;
            tb_dmem_resp_nack_i <= 1'b0;

            // Miss Aligned Address
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b1;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1019) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0E) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b001) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hBA00BA00BA00BA00) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            tb_req_cpu_dcache_i.kill <= 1;
            tb_req_cpu_dcache_i.valid <= 0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1019) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0E) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b001) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hBA00BA00BA00BA00) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;

            // Reset Senyales

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_data_i <= 64'hBA00BA00BA00BA00;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD;

            // Store Access that rises miss_aligned exception
            tb_dmem_req_ready_i <= 1;
            tb_req_cpu_dcache_i.valid <= 1;
            tb_req_cpu_dcache_i.kill <= 0;
            tb_req_cpu_dcache_i.data_rs1 <= 64'h1010;
            tb_req_cpu_dcache_i.data_rs2 <= 64'hAB00AB00AB00AB00;
            tb_req_cpu_dcache_i.instr_type <= SH;
            tb_req_cpu_dcache_i.mem_size <= 3'b001;
            tb_req_cpu_dcache_i.rd <= 5'h07;
            tb_req_cpu_dcache_i.imm <= 64'h09;
            assert (tb_resp_dcache_cpu_o.ready == 1'b0);
            assert (tb_resp_dcache_cpu_o.lock == 1'b0);

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1019) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'hAB00AB00AB00AB00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0E) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b001) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_data_i <= 64'hBA00BA00BA00BA00;
            tb_dmem_resp_nack_i <= 1'b0;

            // Memory alignment exception
            tb_dmem_xcpt_ma_st_i <= 1'b1;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1019) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0E) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b001) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hBA00BA00BA00BA00) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            tb_req_cpu_dcache_i.kill <= 1;
            tb_req_cpu_dcache_i.valid <= 0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1019) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h0E) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b001) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hBA00BA00BA00BA00) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;

            // Reset Senyales

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_data_i <= 64'hBA00BA00BA00BA00;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

        end
    endtask



    // Test nack response for a store petition
    // Output should be nothing 
    task automatic test_sim_4;
        output int tmp;
        begin

            tb_req_cpu_dcache_i.valid <= 1'b0;
            tb_req_cpu_dcache_i.instr_type <= ADD;
            
            // Wait some cycles
            #CLK_PERIOD
            #CLK_PERIOD
            #CLK_PERIOD
 

            // Second memory access, load hit.
            tb_dmem_req_ready_i <= 1;
            tb_req_cpu_dcache_i.valid <= 1;
            tb_req_cpu_dcache_i.kill <= 0;
            tb_req_cpu_dcache_i.data_rs1 <= 64'h1000;
            tb_req_cpu_dcache_i.data_rs2 <= 64'h0001;
            tb_req_cpu_dcache_i.instr_type <= SD;
            tb_req_cpu_dcache_i.mem_size <= 3'b011;
            tb_req_cpu_dcache_i.rd <= 5'h0;
            tb_req_cpu_dcache_i.imm <= 64'h0;
            assert (tb_resp_dcache_cpu_o.ready == 1'b0)  else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1000) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h0001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1000) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h0001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            // SERVE HIT
            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1'b0;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_data_i <= 64'hDEADBEEFDEADBEEF;
            tb_dmem_resp_nack_i <= 1'b1;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1000) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h0001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            // Stop serving
            tb_dmem_req_ready_i <= 1'b0;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;
 
            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1000) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h0001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hDEADBEEFDEADBEEF) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
            #CLK_PERIOD;
            #CLK_PERIOD;
            #CLK_PERIOD;

            tb_dmem_req_ready_i <= 1'b1;

            #CLK_PERIOD;
    
            assert (tb_dmem_req_valid_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1000) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h0001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hDEADBEEFDEADBEEF) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b1) else begin tmp++; assert(1 == 0); end

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_data_i <= 64'hDEADBEEFDEADBEEF;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b0;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b1;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1000) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h0001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hDEADBEEFDEADBEEF) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            tb_req_cpu_dcache_i.kill <= 1;
            tb_req_cpu_dcache_i.valid <= 0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_cmd_o == 5'h01) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_addr_o == 64'h1000) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_data_o == 64'h0001) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_tag_o == 8'h00) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_invalidate_lr_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_req_kill_o == 1'b1) else begin tmp++; assert(1 == 0); end
            assert (tb_dmem_op_type_o == 3'b011) else begin tmp++; assert(1 == 0); end

            assert (tb_resp_dcache_cpu_o.data == 64'hDEADBEEFDEADBEEF) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.ready == 1'b0) else begin tmp++; assert(1 == 0); end
            assert (tb_resp_dcache_cpu_o.lock == 1'b0) else begin tmp++; assert(1 == 0); end

            #CLK_PERIOD;
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

