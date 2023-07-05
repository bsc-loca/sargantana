
module veri_top
    (
    // debugring disable
    input       i_dr_dis,
    input         clk_p,
    input         clk_n,
    input         rst_top
    );

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
    logic [127:0] l2_response_data;
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

    top_drac DUT(
        .CLK(clk_p),
        .RST(~rst_top),
        .SOFT_RST(~rst_top),
        .debug_halt_i(0),
        .RESET_ADDRESS('h00000100),

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
        .mem_resp_uc_read_i(mem_resp_uc_read)
    );

    bootrom_behav brom(
        .clk(clk_p),
        .rstn(~rst_top),
        .brom_req_address_i(brom_req_address),
        .brom_req_valid_i(brom_req_valid),
        .brom_ready_o(brom_ready),
        .brom_resp_data_o(brom_resp_data),
        .brom_resp_valid_o(brom_resp_valid)
    );

    l2_behav l2_inst (
        .clk_i(clk_p),
        .rstn_i(~rst_top),

        // *** Instruction Cache Interface ***

        .ic_addr_i(l1_request_paddr),
        .ic_valid_i(l1_request_valid),
        .ic_valid_o(l2_response_valid),
        .ic_line_o(l2_response_data),
	    .ic_seq_num_o(l2_response_seqnum),

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

endmodule // veri_top
