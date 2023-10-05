//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_datapath.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
*  0.2        | Guillem.LP | Adapt for generic simulation use, HPDC interface, ELF loading.
* -----------------------------------------------
*/

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
//`default_nettype none

`define START_GREEN_PRINT $write("%c[1;32m",27); 
`define START_RED_PRINT $write("%c[1;31m",27);
`define END_COLOR_PRINT $write("%c[0m",27);

import drac_pkg::*;

module questa_top();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
    parameter N4000_CLK_PERIOD = CLK_PERIOD*10000000;

//-----------------------------
// Signals
//-----------------------------
    reg     tb_clk_i;
    reg     tb_rstn_i;

    phreg_t pr;

    // Bootrom wires
    logic [23:0] brom_req_address;
    logic brom_req_valid;
    logic brom_ready;
    logic [31:0] brom_resp_data;
    logic brom_resp_valid;

    // icache wires
    logic l1_request_valid;
    logic l2_response_valid;
    logic [25:0] l1_request_paddr;
    logic [511:0] l2_response_data;
    logic [1:0] l2_response_seqnum;

    //      Miss read interface
    logic                          mem_req_miss_read_ready;
    logic                          mem_req_miss_read_valid;
    hpdcache_mem_req_t             mem_req_miss_read;
    hpdcache_mem_id_t              mem_req_miss_read_base_id;

    logic                          mem_resp_miss_read_ready;
    logic                          mem_resp_miss_read_valid;
    hpdcache_mem_resp_r_t          mem_resp_miss_read;

    //      Write-buffer write interface
    logic                          mem_req_wbuf_write_ready;
    logic                          mem_req_wbuf_write_valid;
    hpdcache_mem_req_t             mem_req_wbuf_write;
    hpdcache_mem_id_t              mem_req_wbuf_write_base_id;

    logic                          mem_req_wbuf_write_data_ready;
    logic                          mem_req_wbuf_write_data_valid;
    hpdcache_mem_req_w_t           mem_req_wbuf_write_data;

    logic                          mem_resp_wbuf_write_ready;
    logic                          mem_resp_wbuf_write_valid;
    hpdcache_mem_resp_w_t          mem_resp_wbuf_write;

    //      Uncached read interface
    logic                          mem_req_uc_read_ready;
    logic                          mem_req_uc_read_valid;
    hpdcache_mem_req_t             mem_req_uc_read;
    hpdcache_mem_id_t              mem_req_uc_read_base_id;

    logic                          mem_resp_uc_read_ready;
    logic                          mem_resp_uc_read_valid;
    hpdcache_mem_resp_r_t          mem_resp_uc_read;

    //      Uncached write interface
    logic                          mem_req_uc_write_ready;
    logic                          mem_req_uc_write_valid;
    hpdcache_mem_req_t             mem_req_uc_write;
    hpdcache_mem_id_t              mem_req_uc_write_base_id;

    logic                          mem_req_uc_write_data_ready;
    logic                          mem_req_uc_write_data_valid;
    hpdcache_mem_req_w_t           mem_req_uc_write_data;

    logic                          mem_resp_uc_write_ready;
    logic                          mem_resp_uc_write_valid;
    hpdcache_mem_resp_w_t          mem_resp_uc_write;

//-----------------------------
// Module
//-----------------------------

    top_drac top_drac_inst(
        .CLK(tb_clk_i),
        .RST(tb_rstn_i),
        .SOFT_RST(1'b1),
        .RESET_ADDRESS(40'h0000000100),
        .debug_halt_i(1'b0),

        // Bootrom ports
        .brom_ready_i(brom_ready),
        .brom_resp_data_i(brom_resp_data),
        .brom_resp_valid_i(brom_resp_valid),
        .brom_req_address_o(brom_req_address),
        .brom_req_valid_o(brom_req_valid),

        // icache ports
        .io_mem_acquire_valid(l1_request_valid),               
        .io_mem_acquire_bits_addr_block(l1_request_paddr),   
        .io_mem_grant_valid(l2_response_valid),         
        .io_mem_grant_bits_data(l2_response_data),     
        .io_mem_grant_bits_addr_beat(l2_response_seqnum),

        // dmem ports

        // dMem miss-read interface
        .mem_req_miss_read_ready_i(mem_req_miss_read_ready),
        .mem_req_miss_read_valid_o(mem_req_miss_read_valid),
        .mem_req_miss_read_o(mem_req_miss_read),
        .mem_req_miss_read_base_id_i(mem_req_miss_read_base_id),

        .mem_resp_miss_read_ready_o(mem_resp_miss_read_ready),
        .mem_resp_miss_read_valid_i(mem_resp_miss_read_valid),
        .mem_resp_miss_read_i(mem_resp_miss_read),

        // dMem writeback interface
        .mem_req_wbuf_write_ready_i(mem_req_wbuf_write_ready),
        .mem_req_wbuf_write_valid_o(mem_req_wbuf_write_valid),
        .mem_req_wbuf_write_o(mem_req_wbuf_write),
        .mem_req_wbuf_write_base_id_i(mem_req_wbuf_write_base_id),

        .mem_req_wbuf_write_data_ready_i(mem_req_wbuf_write_data_ready),
        .mem_req_wbuf_write_data_valid_o(mem_req_wbuf_write_data_valid),
        .mem_req_wbuf_write_data_o(mem_req_wbuf_write_data),

        .mem_resp_wbuf_write_ready_o(mem_resp_wbuf_write_ready),
        .mem_resp_wbuf_write_valid_i(mem_resp_wbuf_write_valid),
        .mem_resp_wbuf_write_i(mem_resp_wbuf_write),

        // dMem uncacheable write interface
        .mem_req_uc_write_ready_i(mem_req_uc_write_ready),
        .mem_req_uc_write_valid_o(mem_req_uc_write_valid),
        .mem_req_uc_write_o(mem_req_uc_write),
        .mem_req_uc_write_base_id_i(mem_req_uc_write_base_id),

        .mem_req_uc_write_data_ready_i(mem_req_uc_write_data_ready),
        .mem_req_uc_write_data_valid_o(mem_req_uc_write_data_valid),
        .mem_req_uc_write_data_o(mem_req_uc_write_data),

        .mem_resp_uc_write_ready_o(mem_resp_uc_write_ready),
        .mem_resp_uc_write_valid_i(mem_resp_uc_write_valid),
        .mem_resp_uc_write_i(mem_resp_uc_write),

        // dMem uncacheable read interface
        .mem_req_uc_read_ready_i(mem_req_uc_read_ready),
        .mem_req_uc_read_valid_o(mem_req_uc_read_valid),
        .mem_req_uc_read_o(mem_req_uc_read),
        .mem_req_uc_read_base_id_i(mem_req_uc_read_base_id),

        .mem_resp_uc_read_ready_o(mem_resp_uc_read_ready),
        .mem_resp_uc_read_valid_i(mem_resp_uc_read_valid),
        .mem_resp_uc_read_i(mem_resp_uc_read),

        .IO_FETCH_PC_VALUE(),
        .IO_FETCH_PC_UPDATE(),
        .IO_REG_READ(),
        .IO_REG_ADDR(),
        .IO_REG_WRITE(),
        .IO_REG_WRITE_DATA(),
        .IO_REG_READ_DATA(),
        .IO_FETCH_PC(),
        .IO_DEC_PC(),
        .IO_RR_PC(),
        .IO_EXE_PC(),
        .IO_WB_PC(),
        .IO_WB_PC_VALID(),
        .IO_WB_ADDR(),
        .IO_WB_WE(),
        .IO_WB_BITS_ADDR(),

        .pcr_req_core_id_o(),
        .pcr_req_we_o(),
        .pcr_req_data_o(),
        .pcr_req_addr_o(),
        .pcr_req_valid_o(),
        .pcr_resp_core_id_i(),
        .pcr_resp_data_i(),
        .pcr_resp_valid_i(),
        .pcr_req_ready_i(),
        .time_i(),
        .irq_i(),
        .time_irq_i(),
        .csr_spi_config_i(1'b0),
        .io_core_pmu_l2_hit_i(),
        .IO_REG_LIST_PADDR(),
        .IO_REG_BACKEND_EMPTY(),
        .io_mem_grant_ready(),
        .io_mem_acquire_bits_union(),
        .io_mem_acquire_bits_a_type(),
        .io_mem_acquire_bits_is_builtin_type(),
        .io_mem_acquire_bits_data(),
        .io_mem_acquire_bits_addr_beat(),
        .io_mem_acquire_bits_client_xact_id(),
        .IO_REG_PREAD(),
        .IO_REG_PADDR()
);

    bootrom_behav brom(
        .clk(tb_clk_i),
        .rstn(tb_rstn_i),
        .brom_req_address_i(brom_req_address),
        .brom_req_valid_i(brom_req_valid),
        .brom_ready_o(brom_ready),
        .brom_resp_data_o(brom_resp_data),
        .brom_resp_valid_o(brom_resp_valid)
    );

    l2_behav l2_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),

        // *** Instruction Cache Interface ***

        .ic_addr_i(l1_request_paddr),
        .ic_valid_i(l1_request_valid),
        .ic_valid_o(l2_response_valid),
        .ic_line_o(l2_response_data),
	    .ic_seq_num_o(l2_response_seqnum),
        .ic_ready_o(),

        // *** dCache Miss Read Interface ***

        .dc_mr_addr_i(mem_req_miss_read.mem_req_addr),
        .dc_mr_valid_i(mem_req_miss_read_valid),
        .dc_mr_ready_i(mem_resp_miss_read_ready),
        .dc_mr_tag_i(mem_req_miss_read.mem_req_id),
        .dc_mr_word_size_i(mem_req_miss_read.mem_req_size),
        .dc_mr_data_o(mem_resp_miss_read.mem_resp_r_data),
        .dc_mr_ready_o(mem_req_miss_read_ready),
        .dc_mr_valid_o(mem_resp_miss_read_valid),
        .dc_mr_tag_o(mem_resp_miss_read.mem_resp_r_id),
        .dc_mr_last_o(mem_resp_miss_read.mem_resp_r_last),

        // *** dCache Writeback Interface ***
        .dc_wb_req_ready_o(mem_req_wbuf_write_ready),
        .dc_wb_req_valid_i(mem_req_wbuf_write_valid),
        .dc_wb_req_addr_i(mem_req_wbuf_write.mem_req_addr),
        .dc_wb_req_len_i(mem_req_wbuf_write.mem_req_len),
        .dc_wb_req_size_i(mem_req_wbuf_write.mem_req_size),
        .dc_wb_req_id_i(mem_req_wbuf_write.mem_req_id),
        .dc_wb_req_base_id_o(mem_req_wbuf_write_base_id),

        .dc_wb_req_data_ready_o(mem_req_wbuf_write_data_ready),
        .dc_wb_req_data_valid_i(mem_req_wbuf_write_data_valid),
        .dc_wb_req_data_i(mem_req_wbuf_write_data.mem_req_w_data),
        .dc_wb_req_be_i(mem_req_wbuf_write_data.mem_req_w_be),
        .dc_wb_req_last_i(mem_req_wbuf_write_data.mem_req_w_last),

        .dc_wb_resp_ready_i(mem_resp_wbuf_write_ready),
        .dc_wb_resp_valid_o(mem_resp_wbuf_write_valid),
        .dc_wb_resp_error_o(mem_resp_wbuf_write.mem_resp_w_error),
        .dc_wb_resp_id_o(mem_resp_wbuf_write.mem_resp_w_id),

        // *** dCache Uncacheable Writes Interface ***
        .dc_uc_wr_req_ready_o(mem_req_uc_write_ready),
        .dc_uc_wr_req_valid_i(mem_req_uc_write_valid),
        .dc_uc_wr_req_addr_i(mem_req_uc_write.mem_req_addr),
        .dc_uc_wr_req_len_i(mem_req_uc_write.mem_req_len),
        .dc_uc_wr_req_size_i(mem_req_uc_write.mem_req_size),
        .dc_uc_wr_req_id_i(mem_req_uc_write.mem_req_id),
        .dc_uc_wr_req_command_i(mem_req_uc_write.mem_req_command),
        .dc_uc_wr_req_atomic_i(mem_req_uc_write.mem_req_atomic),
        .dc_uc_wr_req_base_id_o(mem_req_uc_write_base_id),

        .dc_uc_wr_req_data_ready_o(mem_req_uc_write_data_ready),
        .dc_uc_wr_req_data_valid_i(mem_req_uc_write_data_valid),
        .dc_uc_wr_req_data_i(mem_req_uc_write_data.mem_req_w_data),
        .dc_uc_wr_req_be_i(mem_req_uc_write_data.mem_req_w_be),
        .dc_uc_wr_req_last_i(mem_req_uc_write_data.mem_req_w_last),

        .dc_uc_wr_resp_ready_i(mem_resp_uc_write_ready),
        .dc_uc_wr_resp_valid_o(mem_resp_uc_write_valid),
        .dc_uc_wr_resp_is_atomic_o(mem_resp_uc_write.mem_resp_w_is_atomic),
        .dc_uc_wr_resp_error_o(mem_resp_uc_write.mem_resp_w_error),
        .dc_uc_wr_resp_id_o(mem_resp_uc_write.mem_resp_w_id),

        // *** dCache Uncacheable Reads Interface ***
        .dc_uc_rd_req_ready_o(mem_req_uc_read_ready),
        .dc_uc_rd_req_valid_i(mem_req_uc_read_valid),
        .dc_uc_rd_req_addr_i(mem_req_uc_read.mem_req_addr),
        .dc_uc_rd_req_len_i(mem_req_uc_read.mem_req_len),
        .dc_uc_rd_req_size_i(mem_req_uc_read.mem_req_size),
        .dc_uc_rd_req_id_i(mem_req_uc_read.mem_req_id),
        .dc_uc_rd_req_command_i(mem_req_uc_read.mem_req_command),
        .dc_uc_rd_req_atomic_i(mem_req_uc_read.mem_req_atomic),
        .dc_uc_rd_req_base_id_o(mem_req_uc_read_base_id),

        .dc_uc_rd_valid_o(mem_resp_uc_read_valid),
        .dc_uc_rd_error_o(mem_resp_uc_read_error),
        .dc_uc_rd_id_o(mem_resp_uc_read.mem_resp_r_id),
        .dc_uc_rd_data_o(mem_resp_uc_read.mem_resp_r_data),
        .dc_uc_rd_last_o(mem_resp_uc_read.mem_resp_r_last),
        .dc_uc_rd_ready_i(mem_resp_uc_read_ready)
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
            //$display("*** Toggle reset.");
            tb_rstn_i <= 1'b0; 
            #CLK_PERIOD;
            #CLK_PERIOD;
            tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            //$display("Done");
        end
    endtask



    //***task automatic init_sim***
    task automatic init_sim;
        begin
            //$display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};
            //tb_addr_i<='{default:0};
            //$display("Done");
            
        end
    endtask

    //***task automatic init_dump***
    //This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
    //If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            if ($test$plusargs("vcd")) begin
                $display("*** init_dump");
                $dumpfile("dump_file.vcd");
                $dumpvars(0,top_drac_inst);
            end
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            //$display("*** test_sim");
            // check req valid 0
            test_sim1(tmp);
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

    task automatic test_sim1;
        output int tmp;
        begin
            tmp = 0;
            //$display("*** test_sim1");
            #N4000_CLK_PERIOD;
            pr <= top_drac_inst.datapath_inst.rename_table_inst.commit_table_q[3];
            #CLK_PERIOD;
            if (top_drac_inst.datapath_inst.regfile_inst.registers[pr] == 1) begin
                //FAIL
                tmp = 0;
            end else begin
                //PASS
                tmp = 1;
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


//assert property (@(posedge tb_clk_i) (tb_fetch_icache_o.vaddr != 'h0740));
//assert property (@(posedge tb_clk_i) (datapath_inst.wb_cu_int.branch_taken == 0 | datapath_inst.exe_to_wb_wb.result_pc != 'h0740));

endmodule
//`default_nettype wire
