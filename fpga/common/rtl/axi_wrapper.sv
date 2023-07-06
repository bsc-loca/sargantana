/*
 *  Authors       : Arnau Bigas
 *  Creation Date : July, 2023
 *  Description   : This file provides an AXI wrapper of the core, exposing the
 *                  memory hierarchy as a single AXI4 bus. Atomic operations are
 *                  implemented within this wrapper and thus needn't be
 *                  implemented upstream. This, however, implies that this
 *                  wrapper can only be used in single core applications.
 *                  Additionally, it also includes a bootrom.
 *  History      :
 */

import fpga_pkg::*;

module axi_wrapper (
    input logic clk_i,
    input logic rstn_i,

    AXI_BUS.Master axi_o
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

    top_drac core_inst(
        .CLK(clk_i),
        .RST(rstn_i),
        .SOFT_RST(rstn_i),
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

    bootrom brom(
        .clk(clk_i),
        .rstn(rstn_i),
        .brom_req_address_i(brom_req_address),
        .brom_req_valid_i(brom_req_valid),
        .brom_ready_o(brom_ready),
        .brom_resp_data_o(brom_resp_data),
        .brom_resp_valid_o(brom_resp_valid)
    );

    fpga_pkg::mst_req_t axi_req;
    fpga_pkg::mst_resp_t axi_resp;

    axi_arbiter axi_arbiter_inst(
        .clk_i(clk_i),
        .rst_ni(rstn_i),

        // *** iCache ***

        .icache_miss_valid_i(l1_request_valid),
        .icache_miss_paddr_i(l1_request_paddr),

        .icache_miss_resp_valid_o(l2_response_valid),
        .icache_miss_resp_data_o(l2_response_data),
        .icache_miss_resp_beat_o(l2_response_seqnum),

        // *** dCache ***

        //      Miss-read interface
        .dcache_miss_ready_o(mem_req_miss_read_ready),
        .dcache_miss_valid_i(mem_req_miss_read_valid),
        .dcache_miss_i(mem_req_miss_read),

        .dcache_miss_resp_ready_i(mem_resp_miss_read_ready),
        .dcache_miss_resp_valid_o(mem_resp_miss_read_valid),
        .dcache_miss_resp_o(mem_resp_miss_read),

        //      Write-buffer write interface
        .dcache_wbuf_ready_o(mem_req_wbuf_write_ready),
        .dcache_wbuf_valid_i(mem_req_wbuf_write_valid),
        .dcache_wbuf_i(mem_req_wbuf_write),

        .dcache_wbuf_data_ready_o(mem_req_wbuf_write_data_ready),
        .dcache_wbuf_data_valid_i(mem_req_wbuf_write_data_valid),
        .dcache_wbuf_data_i(mem_req_wbuf_write_data),

        .dcache_wbuf_resp_ready_i(mem_resp_wbuf_write_ready),
        .dcache_wbuf_resp_valid_o(mem_resp_wbuf_write_valid),
        .dcache_wbuf_resp_o(mem_resp_wbuf_write),

        //      Uncached read interface
        .dcache_uc_read_ready_o(mem_req_uc_read_ready),
        .dcache_uc_read_valid_i(mem_req_uc_read_valid),
        .dcache_uc_read_i(mem_req_uc_read),
        .dcache_uc_read_id_i('1),

        .dcache_uc_read_resp_ready_i(mem_resp_uc_read_ready),
        .dcache_uc_read_resp_valid_o(mem_resp_uc_read_valid),
        .dcache_uc_read_resp_o(mem_resp_uc_read),

        //      Uncached write interface
        .dcache_uc_write_ready_o(mem_req_uc_write_ready),
        .dcache_uc_write_valid_i(mem_req_uc_write_valid),
        .dcache_uc_write_i(mem_req_uc_write),
        .dcache_uc_write_id_i('1),

        .dcache_uc_write_data_ready_o(mem_req_uc_write_data_ready),
        .dcache_uc_write_data_valid_i(mem_req_uc_write_data_valid),
        .dcache_uc_write_data_i(mem_req_uc_write_data),

        .dcache_uc_write_resp_ready_i(mem_resp_uc_write_ready),
        .dcache_uc_write_resp_valid_o(mem_resp_uc_write_valid),
        .dcache_uc_write_resp_o(mem_resp_uc_write),

        //  AXI port to upstream memory/peripherals
        .axi_req_o(axi_req),
        .axi_resp_i(axi_resp)
    );

    AXI_BUS #(
        .AXI_ADDR_WIDTH (32),
        .AXI_DATA_WIDTH (512),
        .AXI_ID_WIDTH   (8),
        .AXI_USER_WIDTH (0)
    ) axi_to_core();

    `AXI_ASSIGN_TO_REQ(axi_req, axi_to_core)
    `AXI_ASSIGN_TO_RESP(axi_resp, axi_to_core)

    axi_riscv_atomics_wrap #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(512),
        .AXI_ID_WIDTH(8),
        .AXI_USER_WIDTH(0),
        .AXI_MAX_READ_TXNS(128),
        .AXI_MAX_WRITE_TXNS(128),
        .RISCV_WORD_WIDTH(64)
    ) atomics_processor (
        .clk_i(clk_i),
        .rst_ni(rstn_i),
        .mst(axi_o),
        .slv(axi_to_core)
    );

endmodule
