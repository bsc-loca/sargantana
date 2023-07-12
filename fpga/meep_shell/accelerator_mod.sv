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