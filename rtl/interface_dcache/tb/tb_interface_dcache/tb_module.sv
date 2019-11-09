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

//-----------------------------
// Signals
//-----------------------------
    reg tb_clk_i; 
    reg tb_rstn_i;

    logic        tb_valid_i; 
    logic        tb_kill_i;
    logic        tb_csr_eret_i;
    bus64_t      tb_data_rs1_i;
    bus64_t      tb_data_rs2_i;
    instr_type_t tb_instr_type_i;
    mem_op_t     tb_mem_op_i;
    logic [2:0]  tb_funct3_i;
    reg_t        tb_rd_i;
    logic [63:0] tb_imm_i;
    addr_t       tb_io_base_addr_i;
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
    logic        tb_ready_o;
    bus64_t      tb_data_o;
    logic        tb_lock_o;


//-----------------------------
// Module
//-----------------------------

interface_dcache module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),

    .valid_i(tb_valid_i),
    .kill_i(tb_kill_i),
    .csr_eret_i(tb_csr_eret_i),
    .data_rs1_i(tb_data_rs1_i),
    .data_rs2_i(tb_data_rs2_i),
    .instr_type_i(tb_instr_type_i),
    .mem_op_i(tb_mem_op_i),
    .funct3_i(tb_funct3_i),
    .rd_i(tb_rd_i),
    .imm_i(tb_imm_i),
    .io_base_addr_i(tb_io_base_addr_i),
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
    //Initializing testbench.
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};

            tb_valid_i<='{default:0};
            tb_kill_i<='{default:0};
            tb_csr_eret_i<='{default:0};
            tb_data_rs1_i<='{default:0};
            tb_data_rs2_i<='{default:0};
            tb_mem_op_i<='{default:0};
            tb_instr_type_i<='{default:LD};
            tb_funct3_i<='{default:0};
            tb_rd_i<='{default:0};
            tb_imm_i<='{default:0};
            tb_io_base_addr_i<='{default:40'h0040000000};
            tb_dmem_resp_replay_i<='{default:0};
            tb_dmem_resp_data_i<='{default:0};
            tb_dmem_req_ready_i<='{default:1};
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
    //This is an empty structure for a test.
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

            test_sim_3(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 3 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 3 PASSED.");
                `END_COLOR_PRINT
            end

            test_sim_4(tmp);
            if (tmp == 1) begin
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
    // Output should be nothing 
    task automatic test_sim_1;
        output int tmp;
        begin
            tmp = 0;
            $random(10);

            // First memory access, load miss
            tb_dmem_req_ready_i <= 1;
            tb_valid_i <= 1;
            tb_kill_i <= 0;
            tb_csr_eret_i <= 0;
            tb_data_rs1_i <= 64'h1000;
            tb_data_rs2_i <= 64'h1111;
            tb_instr_type_i <= LD;
            tb_mem_op_i <= MEM_LOAD;
            tb_funct3_i <= 3'b011;
            tb_rd_i <= 5'h3;
            tb_imm_i <= 64'h01;
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            // Check request is done to dcache
            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1001);
            assert (tb_dmem_req_data_o == 64'h1111);
            assert (tb_dmem_req_tag_o == 8'h06);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b0);     //ONLY CHANGE IN OUTPUT
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1001);
            assert (tb_dmem_req_data_o == 64'h1111);
            assert (tb_dmem_req_tag_o == 8'h06);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);
            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 0;   // Simulate dcache blocked by a coherence req.

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1;   // Cache already online

            for (int i = 0; i < 15; i++) begin  // Wait 15 cycles of Miss
                #CLK_PERIOD;
            end

            tb_dmem_req_ready_i <= 0;

            // CHECK NOTHING CHANGES
            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1001);
            assert (tb_dmem_req_data_o == 64'h1111);
            assert (tb_dmem_req_tag_o == 8'h06);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

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
 
            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1001);
            assert (tb_dmem_req_data_o == 64'h1111);
            assert (tb_dmem_req_tag_o == 8'h06);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            //assert (tb_dmem_req_kill_o == 1'b0);        // NOT SURE IF should be 0 or 1
            assert (tb_dmem_op_type_o == 3'b011);

            assert (tb_data_o == 64'h00FF00FF00FF00FF);
            assert (tb_ready_o == 1'b1);
            assert (tb_lock_o == 1'b0);

            // Some non related instructions
            tb_valid_i <= 1'b0;
            tb_instr_type_i <= ADD;
            
            // Wait some cycles
            #CLK_PERIOD
            #CLK_PERIOD
            #CLK_PERIOD
 

            // Second memory access, store hit.
            tb_dmem_req_ready_i <= 1;
            tb_valid_i <= 1;
            tb_kill_i <= 0;
            tb_csr_eret_i <= 0;
            tb_data_rs1_i <= 64'h1000;
            tb_data_rs2_i <= 64'hFFFF;
            tb_instr_type_i <= LD;
            tb_mem_op_i <= MEM_LOAD;
            tb_funct3_i <= 3'b011;
            tb_rd_i <= 5'h5;
            tb_imm_i <= 64'h08;
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            // Check request is done
            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1008);
            assert (tb_dmem_req_data_o == 64'hFFFF);
            assert (tb_dmem_req_tag_o == 8'h0A);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1008);
            assert (tb_dmem_req_data_o == 64'hFFFF);
            assert (tb_dmem_req_tag_o == 8'h0A);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

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

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1008);
            assert (tb_dmem_req_data_o == 64'hFFFF);
            assert (tb_dmem_req_tag_o == 8'h0A);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);        
            assert (tb_dmem_op_type_o == 3'b011);

            assert (tb_data_o == 64'hFF00FF00FF00FF00);
            assert (tb_ready_o == 1'b1);
            assert (tb_lock_o == 1'b0);
            tmp = 0;
        end
    endtask


    // Test does a store petition that misses and a store petition that hits the data cache
    // Output should be nothing 
    task automatic test_sim_2;
        output int tmp;
        begin
            tb_io_base_addr_i <= 40'h0040000000;

            tmp = 0;
            tb_valid_i <= 0;
            tb_kill_i <= 0;
            tb_csr_eret_i <= 0;
            tb_data_rs1_i <= 64'h0;
            tb_data_rs2_i <= 64'h0;
            
            #CLK_PERIOD;

            // First memory access, load miss
            tb_dmem_req_ready_i <= 1;
            tb_valid_i <= 1;
            tb_kill_i <= 0;
            tb_csr_eret_i <= 0;
            tb_data_rs1_i <= 64'h2000;
            tb_data_rs2_i <= 64'h00AA00AA00AA00AA;
            tb_instr_type_i <= SD;
            tb_mem_op_i <= MEM_STORE;
            tb_funct3_i <= 3'b011;
            tb_rd_i <= 5'h00;
            tb_imm_i <= 64'h02;
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);


            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);         // Is a store
            assert (tb_dmem_req_addr_o == 64'h2002);
            assert (tb_dmem_req_data_o == 64'h00AA00AA00AA00AA);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b0);     //ONLY CHANGE IN OUTPUT
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h2002);
            assert (tb_dmem_req_data_o == 64'h00AA00AA00AA00AA);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 0;   // Simulate dcache blocked by a coherence req.

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1;   // Cache already online

            for (int i = 0; i < 15; i++) begin  // Wait 15 cycles of Miss
                #CLK_PERIOD;
            end

            tb_dmem_req_ready_i <= 0;

            // CHECK NOTHING CHANGES
            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h2002);
            assert (tb_dmem_req_data_o == 64'h00AA00AA00AA00AA);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

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
 
            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h2002);
            assert (tb_dmem_req_data_o == 64'h00AA00AA00AA00AA);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b1);        // NOT SURE IF should be 0 or 1
            assert (tb_dmem_op_type_o == 3'b011);

            assert (tb_ready_o == 1'b0);               // Store has no ready
            assert (tb_lock_o == 1'b0);

            tb_valid_i <= 1'b0;
            tb_instr_type_i <= ADD;
            
            // Wait some cycles
            #CLK_PERIOD
            #CLK_PERIOD
            #CLK_PERIOD
 

            // Second memory access, load hit.
            tb_dmem_req_ready_i <= 1;
            tb_valid_i <= 1;
            tb_kill_i <= 0;
            tb_csr_eret_i <= 0;
            tb_data_rs1_i <= 64'h0000;
            tb_data_rs2_i <= 64'hAA00AA00AA00AA00;
            tb_instr_type_i <= SD;
            tb_mem_op_i <= MEM_STORE;
            tb_funct3_i <= 3'b011;
            tb_rd_i <= 5'h0;
            tb_imm_i <= 64'h00;
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h0);
            assert (tb_dmem_req_data_o == 64'hAA00AA00AA00AA00);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h0);
            assert (tb_dmem_req_data_o == 64'hAA00AA00AA00AA00);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

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
 
            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h0);
            assert (tb_dmem_req_data_o == 64'hAA00AA00AA00AA00);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);        
            assert (tb_dmem_op_type_o == 3'b011);

            assert (tb_data_o == 64'hDEADBEEFDEADBEEF);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            tb_valid_i <= 0;

            tmp = 0;
        end
    endtask

    // Test performs memory accesses that rise exceptions
    // Output should be nothing 
    task automatic test_sim_3;
        output int tmp;
        begin
            tmp = 0;
            $random(10);

            #CLK_PERIOD;
            tb_dmem_req_ready_i <= 1;
            #CLK_PERIOD;

            // Store Access that rises miss_aligned exception

            tb_valid_i <= 1;
            tb_kill_i <= 0;
            tb_csr_eret_i <= 0;
            tb_data_rs1_i <= 64'h1010;
            tb_instr_type_i <= LH;
            tb_mem_op_i <= MEM_LOAD;
            tb_funct3_i <= 3'b001;
            tb_rd_i <= 5'h07;
            tb_imm_i <= 64'h09;
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1019);
            assert (tb_dmem_req_tag_o == 8'h0E);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b001);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

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

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1019);
            assert (tb_dmem_req_tag_o == 8'h0E);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b1);        
            assert (tb_dmem_op_type_o == 3'b001);

            assert (tb_data_o == 64'hBA00BA00BA00BA00);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            tb_kill_i <= 1;
            tb_valid_i <= 0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h00);
            assert (tb_dmem_req_addr_o == 64'h1019);
            assert (tb_dmem_req_tag_o == 8'h0E);
            assert (tb_dmem_req_invalidate_lr_o == 1'b1);
            assert (tb_dmem_req_kill_o == 1'b1);        
            assert (tb_dmem_op_type_o == 3'b001);

            assert (tb_data_o == 64'hBA00BA00BA00BA00);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

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
            tb_valid_i <= 1;
            tb_kill_i <= 0;
            tb_csr_eret_i <= 0;
            tb_data_rs1_i <= 64'h1010;
            tb_data_rs2_i <= 64'hAB00AB00AB00AB00;
            tb_instr_type_i <= SH;
            tb_mem_op_i <= MEM_STORE;
            tb_funct3_i <= 3'b001;
            tb_rd_i <= 5'h07;
            tb_imm_i <= 64'h09;
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1019);
            assert (tb_dmem_req_data_o == 64'hAB00AB00AB00AB00);
            assert (tb_dmem_req_tag_o == 8'h0E);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b001);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            tb_dmem_req_ready_i <= 1'b1;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_data_i <= 64'hBA00BA00BA00BA00;
            tb_dmem_resp_nack_i <= 1'b0;

            // NO EXCEPTIONS
            tb_dmem_xcpt_ma_st_i <= 1'b1;
            tb_dmem_xcpt_ma_ld_i <= 1'b0;
            tb_dmem_xcpt_pf_st_i <= 1'b0;
            tb_dmem_xcpt_pf_ld_i <= 1'b0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1019);
            assert (tb_dmem_req_tag_o == 8'h0E);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b1);        
            assert (tb_dmem_op_type_o == 3'b001);

            assert (tb_data_o == 64'hBA00BA00BA00BA00);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            tb_kill_i <= 1;
            tb_valid_i <= 0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1019);
            assert (tb_dmem_req_tag_o == 8'h0E);
            assert (tb_dmem_req_invalidate_lr_o == 1'b1);
            assert (tb_dmem_req_kill_o == 1'b1);        
            assert (tb_dmem_op_type_o == 3'b001);

            assert (tb_data_o == 64'hBA00BA00BA00BA00);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

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

            tmp = 0;
        end
    endtask



    // Test nack response for a store petition
    // Output should be nothing 
    task automatic test_sim_4;
        output int tmp;
        begin

            tb_valid_i <= 1'b0;
            tb_instr_type_i <= ADD;
            
            // Wait some cycles
            #CLK_PERIOD
            #CLK_PERIOD
            #CLK_PERIOD
 

            // Second memory access, load hit.
            tb_dmem_req_ready_i <= 1;
            tb_valid_i <= 1;
            tb_kill_i <= 0;
            tb_csr_eret_i <= 0;
            tb_data_rs1_i <= 64'h1000;
            tb_data_rs2_i <= 64'h0001;
            tb_instr_type_i <= SD;
            tb_mem_op_i <= MEM_STORE;
            tb_funct3_i <= 3'b011;
            tb_rd_i <= 5'h0;
            tb_imm_i <= 64'h0;
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            #CLK_PERIOD;
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1000);
            assert (tb_dmem_req_data_o == 64'h0001);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1000);
            assert (tb_dmem_req_data_o == 64'h0001);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

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

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1000);
            assert (tb_dmem_req_data_o == 64'h0001);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);
            assert (tb_dmem_op_type_o == 3'b011);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            #CLK_PERIOD;
            // Stop serving
            tb_dmem_req_ready_i <= 1'b0;
            tb_dmem_resp_replay_i <= 1'b0;
            tb_dmem_resp_valid_i <= 1'b0;
            tb_dmem_resp_nack_i <= 1'b0;
 
            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1000);
            assert (tb_dmem_req_data_o == 64'h0001);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);        
            assert (tb_dmem_op_type_o == 3'b011);

            assert (tb_data_o == 64'hDEADBEEFDEADBEEF);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

            #CLK_PERIOD;
            #CLK_PERIOD;
            #CLK_PERIOD;
            #CLK_PERIOD;

            tb_dmem_req_ready_i <= 1'b1;

            #CLK_PERIOD;
    
            assert (tb_dmem_req_valid_o == 1'b1);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1000);
            assert (tb_dmem_req_data_o == 64'h0001);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b0);        
            assert (tb_dmem_op_type_o == 3'b011);

            assert (tb_data_o == 64'hDEADBEEFDEADBEEF);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b1);

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

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1000);
            assert (tb_dmem_req_data_o == 64'h0001);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b0);
            assert (tb_dmem_req_kill_o == 1'b1);        
            assert (tb_dmem_op_type_o == 3'b011);

            assert (tb_data_o == 64'hDEADBEEFDEADBEEF);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            tb_kill_i <= 1;
            tb_valid_i <= 0;

            #CLK_PERIOD;

            assert (tb_dmem_req_valid_o == 1'b0);
            assert (tb_dmem_req_cmd_o == 5'h01);
            assert (tb_dmem_req_addr_o == 64'h1000);
            assert (tb_dmem_req_data_o == 64'h0001);
            assert (tb_dmem_req_tag_o == 8'h00);
            assert (tb_dmem_req_invalidate_lr_o == 1'b1);
            assert (tb_dmem_req_kill_o == 1'b1);        
            assert (tb_dmem_op_type_o == 3'b011);

            assert (tb_data_o == 64'hDEADBEEFDEADBEEF);
            assert (tb_ready_o == 1'b0);
            assert (tb_lock_o == 1'b0);

            #CLK_PERIOD;

            tmp = 0;
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

