module sargantana_wrapper(
    input            clk_i,
    input            rstn_i,

    // AXI Write Address Channel Signals
    output   [`AXI4_ID_WIDTH     -1:0]    m_axi_mem_awid,
    output   [`AXI4_ADDR_WIDTH   -1:0]    m_axi_mem_awaddr,
    output   [`AXI4_LEN_WIDTH    -1:0]    m_axi_mem_awlen,
    output   [`AXI4_SIZE_WIDTH   -1:0]    m_axi_mem_awsize,
    output   [`AXI4_BURST_WIDTH  -1:0]    m_axi_mem_awburst,
    output                                m_axi_mem_awlock,
    output   [`AXI4_CACHE_WIDTH  -1:0]    m_axi_mem_awcache,
    output   [`AXI4_PROT_WIDTH   -1:0]    m_axi_mem_awprot,
    output   [`AXI4_QOS_WIDTH    -1:0]    m_axi_mem_awqos,
    output   [`AXI4_REGION_WIDTH -1:0]    m_axi_mem_awregion,
    output   [`AXI4_USER_WIDTH   -1:0]    m_axi_mem_awuser,
    output                                m_axi_mem_awvalid,
    input                                 m_axi_mem_awready,

    // AXI Write Data Channel Signals
    output   [`AXI4_ID_WIDTH     -1:0]    m_axi_mem_wid,
    output   [`AXI4_DATA_WIDTH   -1:0]    m_axi_mem_wdata,
    output   [`AXI4_STRB_WIDTH   -1:0]    m_axi_mem_wstrb,
    output                                m_axi_mem_wlast,
    output   [`AXI4_USER_WIDTH   -1:0]    m_axi_mem_wuser,
    output                                m_axi_mem_wvalid,
    input                                 m_axi_mem_wready,

    // AXI Read Address Channel Signals
    output   [`AXI4_ID_WIDTH     -1:0]    m_axi_mem_arid,
    output   [`AXI4_ADDR_WIDTH   -1:0]    m_axi_mem_araddr,
    output   [`AXI4_LEN_WIDTH    -1:0]    m_axi_mem_arlen,
    output   [`AXI4_SIZE_WIDTH   -1:0]    m_axi_mem_arsize,
    output   [`AXI4_BURST_WIDTH  -1:0]    m_axi_mem_arburst,
    output                                m_axi_mem_arlock,
    output   [`AXI4_CACHE_WIDTH  -1:0]    m_axi_mem_arcache,
    output   [`AXI4_PROT_WIDTH   -1:0]    m_axi_mem_arprot,
    output   [`AXI4_QOS_WIDTH    -1:0]    m_axi_mem_arqos,
    output   [`AXI4_REGION_WIDTH -1:0]    m_axi_mem_arregion,
    output   [`AXI4_USER_WIDTH   -1:0]    m_axi_mem_aruser,
    output                                m_axi_mem_arvalid,
    input                                 m_axi_mem_arready,

    // AXI Read Data Channel Signals
    input    [`AXI4_ID_WIDTH     -1:0]    m_axi_mem_rid,
    input    [`AXI4_DATA_WIDTH   -1:0]    m_axi_mem_rdata,
    input    [`AXI4_RESP_WIDTH   -1:0]    m_axi_mem_rresp,
    input                                 m_axi_mem_rlast,
    input    [`AXI4_USER_WIDTH   -1:0]    m_axi_mem_ruser,
    input                                 m_axi_mem_rvalid,
    output                                m_axi_mem_rready,

    // AXI Write Response Channel Signals
    input    [`AXI4_ID_WIDTH     -1:0]    m_axi_mem_bid,
    input    [`AXI4_RESP_WIDTH   -1:0]    m_axi_mem_bresp,
    input    [`AXI4_USER_WIDTH   -1:0]    m_axi_mem_buser,
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