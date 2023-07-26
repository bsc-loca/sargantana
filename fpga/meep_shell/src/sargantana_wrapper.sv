import fpga_pkg::*;

module sargantana_wrapper(
    input            clk_i,
    input            rstn_i,

    // AXI Write Address Channel Signals
    output   [`MEM_ID_WIDTH     -1:0]    m_axi_mem_awid,
    output   [`MEM_ADDR_WIDTH   -1:0]    m_axi_mem_awaddr,
    output   [`MEM_LEN_WIDTH    -1:0]    m_axi_mem_awlen,
    output   [`MEM_SIZE_WIDTH   -1:0]    m_axi_mem_awsize,
    output   [`MEM_BURST_WIDTH  -1:0]    m_axi_mem_awburst,
    output                                m_axi_mem_awlock,
    output   [`MEM_CACHE_WIDTH  -1:0]    m_axi_mem_awcache,
    output   [`MEM_PROT_WIDTH   -1:0]    m_axi_mem_awprot,
    output   [`MEM_QOS_WIDTH    -1:0]    m_axi_mem_awqos,
    output   [`MEM_REGION_WIDTH -1:0]    m_axi_mem_awregion,
    output   [`MEM_USER_WIDTH   -1:0]    m_axi_mem_awuser,
    output                                m_axi_mem_awvalid,
    input                                 m_axi_mem_awready,

    // AXI Write Data Channel Signals
    output   [`MEM_ID_WIDTH     -1:0]    m_axi_mem_wid,
    output   [`MEM_DATA_WIDTH   -1:0]    m_axi_mem_wdata,
    output   [`MEM_STRB_WIDTH   -1:0]    m_axi_mem_wstrb,
    output                                m_axi_mem_wlast,
    output   [`MEM_USER_WIDTH   -1:0]    m_axi_mem_wuser,
    output                                m_axi_mem_wvalid,
    input                                 m_axi_mem_wready,

    // AXI Read Address Channel Signals
    output   [`MEM_ID_WIDTH     -1:0]    m_axi_mem_arid,
    output   [`MEM_ADDR_WIDTH   -1:0]    m_axi_mem_araddr,
    output   [`MEM_LEN_WIDTH    -1:0]    m_axi_mem_arlen,
    output   [`MEM_SIZE_WIDTH   -1:0]    m_axi_mem_arsize,
    output   [`MEM_BURST_WIDTH  -1:0]    m_axi_mem_arburst,
    output                                m_axi_mem_arlock,
    output   [`MEM_CACHE_WIDTH  -1:0]    m_axi_mem_arcache,
    output   [`MEM_PROT_WIDTH   -1:0]    m_axi_mem_arprot,
    output   [`MEM_QOS_WIDTH    -1:0]    m_axi_mem_arqos,
    output   [`MEM_REGION_WIDTH -1:0]    m_axi_mem_arregion,
    output   [`MEM_USER_WIDTH   -1:0]    m_axi_mem_aruser,
    output                                m_axi_mem_arvalid,
    input                                 m_axi_mem_arready,

    // AXI Read Data Channel Signals
    input    [`MEM_ID_WIDTH     -1:0]    m_axi_mem_rid,
    input    [`MEM_DATA_WIDTH   -1:0]    m_axi_mem_rdata,
    input    [`MEM_RESP_WIDTH   -1:0]    m_axi_mem_rresp,
    input                                 m_axi_mem_rlast,
    input    [`MEM_USER_WIDTH   -1:0]    m_axi_mem_ruser,
    input                                 m_axi_mem_rvalid,
    output                                m_axi_mem_rready,

    // AXI Write Response Channel Signals
    input    [`MEM_ID_WIDTH     -1:0]    m_axi_mem_bid,
    input    [`MEM_RESP_WIDTH   -1:0]    m_axi_mem_bresp,
    input    [`MEM_USER_WIDTH   -1:0]    m_axi_mem_buser,
    input                                 m_axi_mem_bvalid,
    output                                m_axi_mem_bready,

    input mem_calib_complete,

    // AXI UART
    output  [12:0]                       m_axi_uart_awaddr,
    output                               m_axi_uart_awvalid,
    input                                m_axi_uart_awready,
    output  [31:0]                       m_axi_uart_wdata,
    output  [3:0 ]                       m_axi_uart_wstrb,
    output                               m_axi_uart_wvalid,
    input                                m_axi_uart_wready,
    input  [1:0]                         m_axi_uart_bresp,
    input                                m_axi_uart_bvalid,
    output                               m_axi_uart_bready,
    output  [12:0]                       m_axi_uart_araddr,
    output                               m_axi_uart_arvalid,
    input                                m_axi_uart_arready,
    input  [31:0]                        m_axi_uart_rdata,
    input  [1:0]                         m_axi_uart_rresp,
    input                                m_axi_uart_rvalid,
    output                               m_axi_uart_rready,
    input                                uart_irq
);

    // *** AXI Crossbar ***

    localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
        NoSlvPorts:         1,
        NoMstPorts:         3,
        MaxMstTrans:        10,
        MaxSlvTrans:        6,
        FallThrough:        1'b0,
        LatencyMode:        axi_pkg::CUT_ALL_AX,
        PipelineStages:     1,
        AxiIdWidthSlvPorts: 32'(hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH),
        AxiIdUsedSlvPorts:  32'(hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH),
        UniqueIds:          1,
        AxiAddrWidth:       `AXI_XBAR_ADDR_WIDTH,
        AxiDataWidth:       `AXI_XBAR_DATA_WIDTH,
        NoAddrRules:        3
    };

    // Address Map

    localparam rule_t [xbar_cfg.NoAddrRules-1:0] ADDR_MAP = {
        rule_t'{
            idx: `UART_XBAR_ID,
            start_addr: `UART_BASE_ADDR,
            end_addr: `UART_END_ADDR,
            default: '0
        },
        rule_t'{
            idx: `TIMER_XBAR_ID,
            start_addr: `TIMER_BASE_ADDR,
            end_addr: `TIMER_END_ADDR,
            default: '0
        },
        rule_t'{
            idx: `MEM_XBAR_ID,
            start_addr: `MEM_BASE_ADDR,
            end_addr: `MEM_END_ADDR,
            default: '0
        }
    };
    
    // Bus connecting the core to the xbar
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( `AXI_XBAR_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( `AXI_XBAR_DATA_WIDTH     ),
        .AXI_ID_WIDTH   ( 32'(hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH) ),
        .AXI_USER_WIDTH ( `AXI_XBAR_USER_WIDTH )
    ) core2xbar_bus [xbar_cfg.NoSlvPorts-1:0] ();

    // Bus connecting the xbar to the address translators
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( `AXI_XBAR_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH ( `AXI_XBAR_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( `AXI_XBAR_PERI_ID_WIDTH ),
        .AXI_USER_WIDTH ( `AXI_XBAR_USER_WIDTH )
    ) xbar2tran_bus [xbar_cfg.NoMstPorts-1:0] ();

    // xbar instance
    axi_xbar_intf #(
        .AXI_USER_WIDTH ( `AXI_XBAR_USER_WIDTH ),
        .Cfg            ( xbar_cfg        ),
        .rule_t         ( rule_t          )
    ) xbar_inst (
        .clk_i                  ( clk_i    ),
        .rst_ni                 ( rstn_i   ),
        .test_i                 ( 1'b0    ),
        .slv_ports              ( core2xbar_bus ),
        .mst_ports              ( xbar2tran_bus  ),
        .addr_map_i             ( ADDR_MAP ),
        .en_default_mst_port_i  ( '0      ),
        .default_mst_port_i     ( '0      )
    );

    // Bus connecting the translators to the peripherals
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( `AXI_XBAR_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH ( `AXI_XBAR_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( `AXI_XBAR_PERI_ID_WIDTH ),
        .AXI_USER_WIDTH ( 32'd11 )
    ) xbar2peri_bus [xbar_cfg.NoMstPorts-1:0] ();

    // Address translators

    axi_modify_address_intf #(
        .AXI_SLV_PORT_ADDR_WIDTH(`AXI_XBAR_ADDR_WIDTH),
        .AXI_DATA_WIDTH(`AXI_XBAR_DATA_WIDTH),
        .AXI_ID_WIDTH(`AXI_XBAR_PERI_ID_WIDTH),
        .AXI_USER_WIDTH(`AXI_XBAR_USER_WIDTH)
    ) addr_trans_uart_inst (
        .slv(xbar2tran_bus[`UART_XBAR_ID]),
        .mst_aw_addr_i(xbar2tran_bus[`UART_XBAR_ID].aw_addr - `UART_BASE_ADDR),
        .mst_ar_addr_i(xbar2tran_bus[`UART_XBAR_ID].ar_addr - `UART_BASE_ADDR),
        .mst(xbar2peri_bus[`UART_XBAR_ID])
    );

    axi_modify_address_intf #(
        .AXI_SLV_PORT_ADDR_WIDTH(`AXI_XBAR_ADDR_WIDTH),
        .AXI_DATA_WIDTH(`AXI_XBAR_DATA_WIDTH),
        .AXI_ID_WIDTH(`AXI_XBAR_PERI_ID_WIDTH),
        .AXI_USER_WIDTH(`AXI_XBAR_USER_WIDTH)
    ) addr_trans_timer_inst (
        .slv(xbar2tran_bus[`TIMER_XBAR_ID]),
        .mst_aw_addr_i(xbar2tran_bus[`TIMER_XBAR_ID].aw_addr - `TIMER_BASE_ADDR),
        .mst_ar_addr_i(xbar2tran_bus[`TIMER_XBAR_ID].ar_addr - `TIMER_BASE_ADDR),
        .mst(xbar2peri_bus[`TIMER_XBAR_ID])
    );

    axi_modify_address_intf #(
        .AXI_SLV_PORT_ADDR_WIDTH(`AXI_XBAR_ADDR_WIDTH),
        .AXI_DATA_WIDTH(`AXI_XBAR_DATA_WIDTH),
        .AXI_ID_WIDTH(`AXI_XBAR_PERI_ID_WIDTH),
        .AXI_USER_WIDTH(`AXI_XBAR_USER_WIDTH)
    ) addr_trans_mem_inst (
        .slv(xbar2tran_bus[`MEM_XBAR_ID]),
        .mst_aw_addr_i(xbar2tran_bus[`MEM_XBAR_ID].aw_addr - `MEM_BASE_ADDR),
        .mst_ar_addr_i(xbar2tran_bus[`MEM_XBAR_ID].ar_addr - `MEM_BASE_ADDR),
        .mst(xbar2peri_bus[`MEM_XBAR_ID])
    );

    // Connect xbar peripheral buses to requests and responses
    fpga_pkg::peri_axi_req_t xbar2peri_req[xbar_cfg.NoMstPorts];
    fpga_pkg::peri_axi_resp_t xbar2peri_resp[xbar_cfg.NoMstPorts];

    /*for (genvar i = 0; i < xbar_cfg.NoMstPorts; i++) begin
        `AXI_ASSIGN_TO_REQ(xbar2peri_req[i], xbar2peri_bus[i])
        `AXI_ASSIGN_FROM_RESP(xbar2peri_bus[i], xbar2peri_resp[i])
    end*/
    `AXI_ASSIGN_TO_REQ(xbar2peri_req[`UART_XBAR_ID], xbar2peri_bus[`UART_XBAR_ID])
    `AXI_ASSIGN_FROM_RESP(xbar2peri_bus[`UART_XBAR_ID], xbar2peri_resp[`UART_XBAR_ID])

    `AXI_ASSIGN_TO_REQ(xbar2peri_req[`TIMER_XBAR_ID], xbar2peri_bus[`TIMER_XBAR_ID])
    `AXI_ASSIGN_FROM_RESP(xbar2peri_bus[`TIMER_XBAR_ID], xbar2peri_resp[`TIMER_XBAR_ID])


    // TIMER signals
    logic timer_irq;
    logic [63:0] time_value;

    // *** Core Instance ***

    axi_wrapper core_inst (
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .axi_o(core2xbar_bus[0]),

        .time_irq_i(time_irq),
        .time_i(time_value)
    );

    // *** Memory Connection ***

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( `MEM_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH ( `MEM_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( `MEM_ID_WIDTH ),
        .AXI_USER_WIDTH ( `MEM_USER_WIDTH )
    ) mem_bus ();

    // Id remaping from 256 -> 64
    axi_id_remap_intf #(
        .AXI_SLV_PORT_ID_WIDTH(`AXI_XBAR_PERI_ID_WIDTH),
        .AXI_SLV_PORT_MAX_UNIQ_IDS(2**`MEM_ID_WIDTH),
        .AXI_MAX_TXNS_PER_ID(1),
        .AXI_MST_PORT_ID_WIDTH(`MEM_ID_WIDTH),
        .AXI_ADDR_WIDTH(`MEM_ADDR_WIDTH),
        .AXI_DATA_WIDTH(`MEM_DATA_WIDTH),
        .AXI_USER_WIDTH(`MEM_USER_WIDTH)
    ) mem_id_remap_inst (
        .clk_i(clk_i),
        .rst_ni(rstn_i),
        .slv(xbar2peri_bus[`MEM_XBAR_ID]),
        .mst(mem_bus)
    );

    // Connect memory peripheral buses to requests and responses
    fpga_pkg::peri_axi_req_t mem_req;
    fpga_pkg::peri_axi_resp_t mem_resp;

    `AXI_ASSIGN_TO_REQ(mem_req, mem_bus)
    `AXI_ASSIGN_FROM_RESP(mem_bus, mem_resp)

    // Assign input/output pins

    `AXI_ASSIGN_MASTER_TO_FLAT(mem, mem_req, mem_resp)

    // *** UART Connection ***

    // Downsize 512b -> 32b

    fpga_pkg::axi32_req_t uart_axi32_req;
    fpga_pkg::axi32_resp_t uart_axi32_resp;

    axi_dw_downsizer #(
        .AxiSlvPortDataWidth(`AXI_XBAR_DATA_WIDTH),
        .AxiMstPortDataWidth(32),
        .AxiAddrWidth(`AXI_XBAR_ADDR_WIDTH),
        .AxiIdWidth(8),
        .aw_chan_t(peri_axi_aw_chan_t),
        .mst_w_chan_t(axi32_w_chan_t),
        .slv_w_chan_t(peri_axi_w_chan_t),
        .b_chan_t(peri_axi_b_chan_t),
        .ar_chan_t(peri_axi_ar_chan_t),
        .mst_r_chan_t(axi32_r_chan_t),
        .slv_r_chan_t(peri_axi_r_chan_t),
        .axi_mst_req_t(axi32_req_t),
        .axi_mst_resp_t(axi32_resp_t),
        .axi_slv_req_t(peri_axi_req_t),
        .axi_slv_resp_t(peri_axi_resp_t)
    ) axi_downsizer_uart_inst (
        .clk_i(clk_i),
        .rst_ni(rstn_i),
        .slv_req_i(xbar2peri_req[`UART_XBAR_ID]),
        .slv_resp_o(xbar2peri_resp[`UART_XBAR_ID]),
        .mst_req_o(uart_axi32_req),
        .mst_resp_i(uart_axi32_resp)
    );

    // Convert AXI to AXI-Lite

    fpga_pkg::axi_lite_req_t uart_req;
    fpga_pkg::axi_lite_resp_t uart_resp;

    axi_to_axi_lite #(
        .AxiAddrWidth(`AXI_XBAR_ADDR_WIDTH),
        .AxiDataWidth(32),
        .AxiIdWidth(8),
        .AxiUserWidth(`AXI_XBAR_USER_WIDTH),
        .AxiMaxReadTxns(1),
        .AxiMaxWriteTxns(1),
        .full_req_t(fpga_pkg::axi32_req_t),
        .full_resp_t(fpga_pkg::axi32_resp_t),
        .lite_req_t(fpga_pkg::axi_lite_req_t),
        .lite_resp_t(fpga_pkg::axi_lite_resp_t)
    ) axi_lite_uart_converter (
        .clk_i(clk_i),
        .rst_ni(rstn_i),
        .test_i(1'b0),
        .slv_req_i(uart_axi32_req),
        .slv_resp_o(uart_axi32_resp),
        .mst_req_o(uart_req),
        .mst_resp_i(uart_resp)
    );

    // Assign input/output pins

`define AXI_LITE_ASSIGN_MASTER_TO_FLAT(pat, req, rsp) \
  assign m_axi_``pat``_awvalid  = req.aw_valid;  \
  assign m_axi_``pat``_awaddr   = req.aw.addr;   \
                                                 \
  assign m_axi_``pat``_wvalid   = req.w_valid;   \
  assign m_axi_``pat``_wdata    = req.w.data;    \
  assign m_axi_``pat``_wstrb    = req.w.strb;    \
                                                 \
  assign m_axi_``pat``_bready   = req.b_ready;   \
                                                 \
  assign m_axi_``pat``_arvalid  = req.ar_valid;  \
  assign m_axi_``pat``_araddr   = req.ar.addr;   \
                                                 \
  assign m_axi_``pat``_rready   = req.r_ready;   \
                                                 \
  assign rsp.aw_ready = m_axi_``pat``_awready;   \
  assign rsp.ar_ready = m_axi_``pat``_arready;   \
  assign rsp.w_ready  = m_axi_``pat``_wready;    \
                                                 \
  assign rsp.b_valid  = m_axi_``pat``_bvalid;    \
  assign rsp.b.resp   = m_axi_``pat``_bresp;     \
                                                 \
  assign rsp.r_valid  = m_axi_``pat``_rvalid;    \
  assign rsp.r.data   = m_axi_``pat``_rdata;     \
  assign rsp.r.resp   = m_axi_``pat``_rresp;

    `AXI_LITE_ASSIGN_MASTER_TO_FLAT(uart, uart_req, uart_resp)


  // *** TIMER Connection ***

  // Downsize 512b -> 32b

  fpga_pkg::axi32_req_t timer_axi32_req;
  fpga_pkg::axi32_resp_t timer_axi32_resp;

  axi_dw_downsizer #(
      .AxiSlvPortDataWidth(`AXI_XBAR_DATA_WIDTH),
      .AxiMstPortDataWidth(32),
      .AxiAddrWidth(`AXI_XBAR_ADDR_WIDTH),
      .AxiIdWidth(8),
      .aw_chan_t(peri_axi_aw_chan_t),
      .mst_w_chan_t(axi32_w_chan_t),
      .slv_w_chan_t(peri_axi_w_chan_t),
      .b_chan_t(peri_axi_b_chan_t),
      .ar_chan_t(peri_axi_ar_chan_t),
      .mst_r_chan_t(axi32_r_chan_t),
      .slv_r_chan_t(peri_axi_r_chan_t),
      .axi_mst_req_t(axi32_req_t),
      .axi_mst_resp_t(axi32_resp_t),
      .axi_slv_req_t(peri_axi_req_t),
      .axi_slv_resp_t(peri_axi_resp_t)
  ) axi_downsizer_timer_inst (
      .clk_i(clk_i),
      .rst_ni(rstn_i),
      .slv_req_i(xbar2peri_req[`TIMER_XBAR_ID]),
      .slv_resp_o(xbar2peri_resp[`TIMER_XBAR_ID]),
      .mst_req_o(timer_axi32_req),
      .mst_resp_i(timer_axi32_resp)
  );

  // Convert AXI to AXI-Lite

  fpga_pkg::axi_lite_req_t timer_req;
  fpga_pkg::axi_lite_resp_t timer_resp;

  axi_to_axi_lite #(
      .AxiAddrWidth(`AXI_XBAR_ADDR_WIDTH),
      .AxiDataWidth(32),
      .AxiIdWidth(8),
      .AxiUserWidth(`AXI_XBAR_USER_WIDTH),
      .AxiMaxReadTxns(1),
      .AxiMaxWriteTxns(1),
      .full_req_t(fpga_pkg::axi32_req_t),
      .full_resp_t(fpga_pkg::axi32_resp_t),
      .lite_req_t(fpga_pkg::axi_lite_req_t),
      .lite_resp_t(fpga_pkg::axi_lite_resp_t)
  ) axi_lite_timer_converter (
      .clk_i(clk_i),
      .rst_ni(rstn_i),
      .test_i(1'b0),
      .slv_req_i(timer_axi32_req),
      .slv_resp_o(timer_axi32_resp),
      .mst_req_o(timer_req),
      .mst_resp_i(timer_resp)
  );

  axi_timer # (
    .C_S_AXI_ADDR_WIDTH  ( `AXI_XBAR_ADDR_WIDTH         ),
    .C_S_AXI_DATA_WIDTH  (32)
    ) axi_timer_inst (
      .S_AXI_ACLK     ( clk_i                           ),
      .S_AXI_ARESETN  ( rstn_i                          ),
      .S_AXI_AWADDR   (timer_req.aw.addr                ),
      .S_AXI_AWPROT   (timer_req.aw.prot                ),
      .S_AXI_AWVALID  (timer_req.aw_valid               ),
      .S_AXI_AWREADY  (timer_resp.aw_ready              ),
      .S_AXI_WDATA    (timer_req.w.data                 ),
      .S_AXI_WSTRB    (timer_req.w.strb                 ),
      .S_AXI_WVALID   (timer_req.w_valid                ),
      .S_AXI_WREADY   (timer_resp.w_ready               ),
      .S_AXI_BRESP    (timer_resp.b.resp                ),
      .S_AXI_BVALID   (timer_resp.b_valid               ),
      .S_AXI_BREADY   (timer_req.b_ready                ),
      .S_AXI_ARADDR   (timer_req.ar.addr               ),
      .S_AXI_ARPROT   (timer_req.ar.prot                ),
      .S_AXI_ARVALID  (timer_req.ar_valid               ),
      .S_AXI_ARREADY  (timer_resp.ar_ready              ),
      .S_AXI_RDATA    (timer_resp.r.data                ),
      .S_AXI_RRESP    (timer_resp.r.resp                ),
      .S_AXI_RVALID   (timer_resp.r_valid               ),
      .S_AXI_RREADY   (timer_req.r_ready                ),
      .time_o         (time_value                       ),
      .irq_o          (time_irq                         )
    );


endmodule