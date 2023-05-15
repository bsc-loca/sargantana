
module veri_top
    (
    // debugring disable
    input       i_dr_dis,
    input         clk_p,
    input         clk_n,
    input         rst_top
    );

    // TLB wires
    logic [27:0] vpn;

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
    bus_simd_t dmem_resp_data_i;
    logic dmem_resp_valid_i;
    logic [7:0] dmem_resp_tag_i;

    logic dmem_req_ready_i;
    logic dmem_req_valid_o;
    logic [4:0] dmem_req_cmd_o;
    addr_t  dmem_req_addr_o;
    logic [3:0] dmem_op_type_o;
    bus_simd_t dmem_req_data_o;
    logic [7:0] dmem_req_tag_o;

    // PCR wires (tohost)
    //PCR req inputs
    logic                            pcr_req_ready;            // ready bit of the pcr

    //PCR resp inputs
    logic                            pcr_resp_valid;           // ready bit of the pcr
    logic [63:0]           pcr_resp_data;            // read data from performance counter module
    logic                            pcr_resp_core_id;         // core id of the tile that the date is sended

    //PCR outputs request
    logic                            pcr_req_valid;            // valid bit to make a pcr request
    logic  [11:0]      pcr_req_addr;             // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    logic  [63:0]                    pcr_req_data;             // write data to performance counter module
    logic  [2:0]                     pcr_req_we;               // Cmd of the petition
    logic                            pcr_req_core_id;          // core id of the tile

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

        // TLB ports
        .TLB_REQ_BITS_VPN(vpn),
        .itlb_resp_ppn_i(vpn[19:0]),

        // icache ports
        .io_mem_acquire_valid(l1_request_valid),               
        .io_mem_acquire_bits_addr_block(l1_request_paddr),   
        .io_mem_grant_valid(l2_response_valid),         
        .io_mem_grant_bits_data(l2_response_data),     
        .io_mem_grant_bits_addr_beat(l2_response_seqnum),

        // dmem ports
        .DMEM_REQ_READY(dmem_req_ready_i),
        .DMEM_RESP_BITS_DATA_SUBW(dmem_resp_data_i),
        .DMEM_RESP_BITS_NACK(1'b0),
        .DMEM_RESP_BITS_REPLAY(1'b0),
        .DMEM_RESP_VALID(1'b1),
        .DMEM_RESP_TAG(dmem_resp_tag_i),
        .DMEM_XCPT_MA_ST(1'b0),
        .DMEM_XCPT_MA_LD(1'b0),
        .DMEM_XCPT_PF_ST(1'b0),
        .DMEM_XCPT_PF_LD(1'b0),
        .DMEM_ORDERED(1'b1),
        .DMEM_REQ_VALID(dmem_req_valid_o),
        .DMEM_OP_TYPE(dmem_op_type_o),
        .DMEM_REQ_CMD(dmem_req_cmd_o),
        .DMEM_REQ_BITS_DATA(dmem_req_data_o),
        .DMEM_REQ_BITS_ADDR(dmem_req_addr_o),
        .DMEM_REQ_BITS_TAG(dmem_req_tag_o),

        // PCR (tohost)
        .pcr_req_ready_i(pcr_req_ready),            // ready bit of the pcr
        .pcr_resp_valid_i(pcr_resp_valid),           // ready bit of the pcr
        .pcr_resp_data_i(pcr_resp_data),            // read data from performance counter module
        .pcr_resp_core_id_i(pcr_resp_core_id),         // core id of the tile that the date is sended
        .pcr_req_valid_o(pcr_req_valid),            // valid bit to make a pcr request
        .pcr_req_addr_o(pcr_req_addr),             // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
        .pcr_req_data_o(pcr_req_data),             // write data to performance counter module
        .pcr_req_we_o(pcr_req_we),               // Cmd of the petition
        .pcr_req_core_id_o(pcr_req_core_id)          // core id of the tile
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

    perfect_imem imem (
        .clk_i(clk_p),
        .rstn_i(~rst_top),
        .addr_i(l1_request_paddr),
        .valid_i(l1_request_valid),
        .valid_o(l2_response_valid),
        .line_o(l2_response_data),
	    .seq_num_o(l2_response_seqnum)
    );

    perfect_dmem dmem (
        .clk_i(clk_p),
        .rstn_i(~rst_top),
        .addr_i(dmem_req_addr_o),
        .valid_i(dmem_req_valid_o),
        .tag_i(dmem_req_tag_o),
        .cmd_i(dmem_req_cmd_o),
        .wr_data_i(dmem_req_data_o),
        .word_size_i(dmem_op_type_o),
        .line_o(dmem_resp_data_i),
        .ready_o(dmem_req_ready_i),
        .valid_o(dmem_resp_valid_i),
        .tag_o(dmem_resp_tag_i)
    );

    host_behav host_behav_inst (
        .clk(clk_p),
        .rstn(~rst_top),
        .req_valid(pcr_req_valid),
        .resp_ready(1'b1),
        .req_ready(pcr_req_ready),
        .resp_valid(pcr_resp_valid),
        .req_id(pcr_req_core_id),
        .resp_id(pcr_resp_core_id),
        .req(pcr_req_data),
        .resp(pcr_resp_data)
    );

endmodule // veri_top
