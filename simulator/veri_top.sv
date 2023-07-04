
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

    // dmem wires
    hpdcache_mem_data_t dmem_resp_data;
    logic dmem_resp_valid;
    logic [7:0] dmem_resp_tag;

    logic dmem_req_ready;
    logic dmem_req_valid_o;
    addr_t  dmem_req_addr_o;
    logic [3:0] dmem_op_type_o;
    logic [7:0] dmem_req_tag_o;
    logic [2:0] dmem_req_size;
    logic dmem_rsp_ready;
    logic mem_resp_r_last;

    // L2 writeback
    logic                  mem_req_wbuf_write_ready;
    logic                  mem_req_wbuf_write_valid;
    hpdcache_mem_addr_t    mem_req_wbuf_write_addr;
    hpdcache_mem_len_t     mem_req_wbuf_write_len;
    hpdcache_mem_size_t    mem_req_wbuf_write_size;
    hpdcache_mem_id_t      mem_req_wbuf_write_id;
    hpdcache_mem_id_t      mem_req_wbuf_write_base_id;

    logic                  mem_req_wbuf_write_data_ready;
    logic                  mem_req_wbuf_write_data_valid;
    hpdcache_mem_data_t    mem_req_wbuf_write_data;
    hpdcache_mem_be_t      mem_req_wbuf_write_be;
    logic                  mem_req_wbuf_write_last;

    logic                  mem_resp_wbuf_write_ready;
    logic                  mem_resp_wbuf_write_valid;
    hpdcache_mem_error_e   mem_resp_wbuf_write_error;
    hpdcache_mem_id_t      mem_resp_wbuf_write_id;

    // L2 uncacheable writeback
    logic                  mem_req_uc_write_ready;
    logic                  mem_req_uc_write_valid;
    hpdcache_mem_addr_t    mem_req_uc_write_addr;
    hpdcache_mem_len_t     mem_req_uc_write_len;
    hpdcache_mem_size_t    mem_req_uc_write_size;
    hpdcache_mem_id_t      mem_req_uc_write_id;
    hpdcache_mem_command_e mem_req_uc_write_command;
    hpdcache_mem_atomic_e  mem_req_uc_write_atomic;
    hpdcache_mem_id_t      mem_req_uc_write_base_id;

    logic                  mem_req_uc_write_data_ready;
    logic                  mem_req_uc_write_data_valid;
    hpdcache_mem_data_t    mem_req_uc_write_data;
    hpdcache_mem_be_t      mem_req_uc_write_be;
    logic                  mem_req_uc_write_last;

    logic                  mem_resp_uc_write_ready;
    logic                  mem_resp_uc_write_valid;
    logic                  mem_resp_uc_write_is_atomic;
    hpdcache_mem_error_e   mem_resp_uc_write_error;
    hpdcache_mem_id_t      mem_resp_uc_write_id;

    // L2 uncacheable read
    logic                  mem_req_uc_read_ready;
    logic                  mem_req_uc_read_valid;
    hpdcache_mem_addr_t    mem_req_uc_read_addr;
    hpdcache_mem_len_t     mem_req_uc_read_len;
    hpdcache_mem_size_t    mem_req_uc_read_size;
    hpdcache_mem_id_t      mem_req_uc_read_id;
    hpdcache_mem_command_e mem_req_uc_read_command;
    hpdcache_mem_atomic_e  mem_req_uc_read_atomic;
    hpdcache_mem_id_t      mem_req_uc_read_base_id;

    logic                   mem_resp_uc_read_valid;
    hpdcache_mem_error_e    mem_resp_uc_read_error;
    hpdcache_mem_id_t       mem_resp_uc_read_id;
    hpdcache_mem_data_t     mem_resp_uc_read_data;
    logic                   mem_resp_uc_read_last;
    logic                   mem_resp_uc_read_ready;

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

        // Read miss request
        .mem_req_miss_read_ready_i(dmem_req_ready),
        .mem_resp_miss_read_ready_o(dmem_rsp_ready),
        .mem_resp_r_data_i(dmem_resp_data),
        .mem_resp_miss_read_valid_i(dmem_resp_valid),
        .mem_resp_r_id_i(dmem_resp_tag),
        .mem_req_miss_read_valid_o(dmem_req_valid_o),
        .mem_req_addr_o(dmem_req_addr_o),
        .mem_req_size_o(dmem_req_size),
        .mem_req_id_o(dmem_req_tag_o),
        .mem_resp_r_last_i(mem_resp_r_last),

        // Writeback
        .mem_req_wbuf_write_ready_i(mem_req_wbuf_write_ready),
        .mem_req_wbuf_write_valid_o(mem_req_wbuf_write_valid),
        .mem_req_wbuf_write_addr_o(mem_req_wbuf_write_addr),
        .mem_req_wbuf_write_len_o(mem_req_wbuf_write_len),
        .mem_req_wbuf_write_size_o(mem_req_wbuf_write_size),
        .mem_req_wbuf_write_id_o(mem_req_wbuf_write_id),
        .mem_req_wbuf_write_base_id_i(mem_req_wbuf_write_base_id),

        .mem_req_wbuf_write_data_ready_i(mem_req_wbuf_write_data_ready),
        .mem_req_wbuf_write_data_valid_o(mem_req_wbuf_write_data_valid),
        .mem_req_wbuf_write_data_o(mem_req_wbuf_write_data),
        .mem_req_wbuf_write_be_o(mem_req_wbuf_write_be),
        .mem_req_wbuf_write_last_o(mem_req_wbuf_write_last),

        .mem_resp_wbuf_write_ready_o(mem_resp_wbuf_write_ready),
        .mem_resp_wbuf_write_valid_i(mem_resp_wbuf_write_valid),
        .mem_resp_wbuf_write_error_i(mem_resp_wbuf_write_error),
        .mem_resp_wbuf_write_id_i(mem_resp_wbuf_write_id),

        // Uncacheable writes
        .mem_req_uc_write_ready_i(mem_req_uc_write_ready),
        .mem_req_uc_write_valid_o(mem_req_uc_write_valid),
        .mem_req_uc_write_addr_o(mem_req_uc_write_addr),
        .mem_req_uc_write_len_o(mem_req_uc_write_len),
        .mem_req_uc_write_size_o(mem_req_uc_write_size),
        .mem_req_uc_write_id_o(mem_req_uc_write_id),
        .mem_req_uc_write_command_o(mem_req_uc_write_command),
        .mem_req_uc_write_atomic_o(mem_req_uc_write_atomic),
        .mem_req_uc_write_base_id_i(mem_req_uc_write_base_id),

        .mem_req_uc_write_data_ready_i(mem_req_uc_write_data_ready),
        .mem_req_uc_write_data_valid_o(mem_req_uc_write_data_valid),
        .mem_req_uc_write_data_o(mem_req_uc_write_data),
        .mem_req_uc_write_be_o(mem_req_uc_write_be),
        .mem_req_uc_write_last_o(mem_req_uc_write_last),

        .mem_resp_uc_write_ready_o(mem_resp_uc_write_ready),
        .mem_resp_uc_write_valid_i(mem_resp_uc_write_valid),
        .mem_resp_uc_write_is_atomic_i(mem_resp_uc_write_is_atomic),
        .mem_resp_uc_write_error_i(mem_resp_uc_write_error),
        .mem_resp_uc_write_id_i(mem_resp_uc_write_id),

        // Uncacheable reads
        .mem_req_uc_read_ready_i(mem_req_uc_read_ready),
        .mem_req_uc_read_valid_o(mem_req_uc_read_valid),
        .mem_req_uc_read_addr_o(mem_req_uc_read_addr),
        .mem_req_uc_read_len_o(mem_req_uc_read_len),
        .mem_req_uc_read_size_o(mem_req_uc_read_size),
        .mem_req_uc_read_id_o(mem_req_uc_read_id),
        .mem_req_uc_read_command_o(mem_req_uc_read_command),
        .mem_req_uc_read_atomic_o(mem_req_uc_read_atomic),
        .mem_req_uc_read_base_id_i(mem_req_uc_read_base_id),

        .mem_resp_uc_read_valid_i(mem_resp_uc_read_valid),
        .mem_resp_uc_read_error_i(mem_resp_uc_read_error),
        .mem_resp_uc_read_id_i(mem_resp_uc_read_id),
        .mem_resp_uc_read_data_i(mem_resp_uc_read_data),
        .mem_resp_uc_read_last_i(mem_resp_uc_read_last),
        .mem_resp_uc_read_ready_o(mem_resp_uc_read_ready)

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

        .dc_mr_addr_i(dmem_req_addr_o),
        .dc_mr_valid_i(dmem_req_valid_o),
        .dc_mr_ready_i(dmem_rsp_ready),
        .dc_mr_tag_i(dmem_req_tag_o),
        .dc_mr_word_size_i(dmem_req_size),
        .dc_mr_data_o(dmem_resp_data),
        .dc_mr_ready_o(dmem_req_ready),
        .dc_mr_valid_o(dmem_resp_valid),
        .dc_mr_tag_o(dmem_resp_tag),
        .dc_mr_last_o(mem_resp_r_last),

        // *** dCache Writeback Interface ***
        .dc_wb_req_ready_o(mem_req_wbuf_write_ready),
        .dc_wb_req_valid_i(mem_req_wbuf_write_valid),
        .dc_wb_req_addr_i(mem_req_wbuf_write_addr),
        .dc_wb_req_len_i(mem_req_wbuf_write_len),
        .dc_wb_req_size_i(mem_req_wbuf_write_size),
        .dc_wb_req_id_i(mem_req_wbuf_write_id),
        .dc_wb_req_base_id_o(mem_req_wbuf_write_base_id),

        .dc_wb_req_data_ready_o(mem_req_wbuf_write_data_ready),
        .dc_wb_req_data_valid_i(mem_req_wbuf_write_data_valid),
        .dc_wb_req_data_i(mem_req_wbuf_write_data),
        .dc_wb_req_be_i(mem_req_wbuf_write_be),
        .dc_wb_req_last_i(mem_req_wbuf_write_last),

        .dc_wb_resp_ready_i(mem_resp_wbuf_write_ready),
        .dc_wb_resp_valid_o(mem_resp_wbuf_write_valid),
        .dc_wb_resp_error_o(mem_resp_wbuf_write_error),
        .dc_wb_resp_id_o(mem_resp_wbuf_write_id),

        // *** dCache Uncacheable Writes Interface ***
        .dc_uc_wr_req_ready_o(mem_req_uc_write_ready),
        .dc_uc_wr_req_valid_i(mem_req_uc_write_valid),
        .dc_uc_wr_req_addr_i(mem_req_uc_write_addr),
        .dc_uc_wr_req_len_i(mem_req_uc_write_len),
        .dc_uc_wr_req_size_i(mem_req_uc_write_size),
        .dc_uc_wr_req_id_i(mem_req_uc_write_id),
        .dc_uc_wr_req_command_i(mem_req_uc_write_command),
        .dc_uc_wr_req_atomic_i(mem_req_uc_write_atomic),
        .dc_uc_wr_req_base_id_o(mem_req_uc_write_base_id),

        .dc_uc_wr_req_data_ready_o(mem_req_uc_write_data_ready),
        .dc_uc_wr_req_data_valid_i(mem_req_uc_write_data_valid),
        .dc_uc_wr_req_data_i(mem_req_uc_write_data),
        .dc_uc_wr_req_be_i(mem_req_uc_write_be),
        .dc_uc_wr_req_last_i(mem_req_uc_write_last),

        .dc_uc_wr_resp_ready_i(mem_resp_uc_write_ready),
        .dc_uc_wr_resp_valid_o(mem_resp_uc_write_valid),
        .dc_uc_wr_resp_is_atomic_o(mem_resp_uc_write_is_atomic),
        .dc_uc_wr_resp_error_o(mem_resp_uc_write_error),
        .dc_uc_wr_resp_id_o(mem_resp_uc_write_id),

        // *** dCache Uncacheable Reads Interface ***
        .dc_uc_rd_req_ready_o(mem_req_uc_read_ready),
        .dc_uc_rd_req_valid_i(mem_req_uc_read_valid),
        .dc_uc_rd_req_addr_i(mem_req_uc_read_addr),
        .dc_uc_rd_req_len_i(mem_req_uc_read_len),
        .dc_uc_rd_req_size_i(mem_req_uc_read_size),
        .dc_uc_rd_req_id_i(mem_req_uc_read_id),
        .dc_uc_rd_req_command_i(mem_req_uc_read_command),
        .dc_uc_rd_req_atomic_i(mem_req_uc_read_atomic),
        .dc_uc_rd_req_base_id_o(mem_req_uc_read_base_id),

        .dc_uc_rd_valid_o(mem_resp_uc_read_valid),
        .dc_uc_rd_error_o(mem_resp_uc_read_error),
        .dc_uc_rd_id_o(mem_resp_uc_read_id),
        .dc_uc_rd_data_o(mem_resp_uc_read_data),
        .dc_uc_rd_last_o(mem_resp_uc_read_last),
        .dc_uc_rd_ready_i(mem_resp_uc_read_ready)
    );

endmodule // veri_top
