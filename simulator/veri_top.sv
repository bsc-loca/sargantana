
module veri_top
    (
    // debugring disable
    input       i_dr_dis,
    input         clk_p,
    input         clk_n,
    input         rst_top
    );

    // Bootrom wiressd
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
    bus_simd_t dmem_resp_data;
    logic dmem_resp_valid;
    logic [7:0] dmem_resp_tag;

    logic dmem_req_ready;
    logic dmem_req_valid_o;
    logic [4:0] dmem_req_cmd_o;
    addr_t  dmem_req_addr_o;
    logic [3:0] dmem_op_type_o;
    bus_simd_t dmem_req_data_o;
    logic [7:0] dmem_req_tag_o;

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
        .DMEM_REQ_READY(dmem_req_ready),
        .DMEM_RESP_BITS_DATA_SUBW(dmem_resp_data),
        .DMEM_RESP_BITS_NACK(1'b0),
        .DMEM_RESP_BITS_REPLAY(1'b0),
        .DMEM_RESP_VALID(dmem_resp_valid),
        .DMEM_RESP_TAG(dmem_resp_tag),
        .DMEM_ORDERED(1'b1),
        .DMEM_REQ_VALID(dmem_req_valid_o),
        .DMEM_OP_TYPE(dmem_op_type_o),
        .DMEM_REQ_CMD(dmem_req_cmd_o),
        .DMEM_REQ_BITS_DATA(dmem_req_data_o),
        .DMEM_REQ_BITS_ADDR(dmem_req_addr_o),
        .DMEM_REQ_BITS_TAG(dmem_req_tag_o)

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

        // *** Data Cache Interface ***

        .dc_addr_i(dmem_req_addr_o),
        .dc_valid_i(dmem_req_valid_o),
        .dc_tag_i(dmem_req_tag_o),
        .dc_cmd_i(dmem_req_cmd_o),
        .dc_wr_data_i(dmem_req_data_o),
        .dc_word_size_i(dmem_op_type_o),
        .dc_line_o(dmem_resp_data),
        .dc_ready_o(dmem_req_ready),
        .dc_valid_o(dmem_resp_valid),
        .dc_tag_o(dmem_resp_tag)
    );

endmodule // veri_top
