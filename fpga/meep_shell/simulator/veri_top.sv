
module veri_top
    (
    // debugring disable
    input       i_dr_dis,
    input         clk_p,
    input         clk_n,
    input         rst_top
    );

    logic clk_i;
    logic rstn_i;

    assign clk_i = clk_p;
    assign rstn_i = ~rst_top;

    // AXI Write Address Channel Signals
    logic   [`AXI4_ID_WIDTH     -1:0]    mem_awid;
    logic   [`AXI4_ADDR_WIDTH   -1:0]    mem_awaddr;
    logic   [`AXI4_LEN_WIDTH    -1:0]    mem_awlen;
    logic   [`AXI4_SIZE_WIDTH   -1:0]    mem_awsize;
    logic   [`AXI4_BURST_WIDTH  -1:0]    mem_awburst;
    logic                                mem_awlock;
    logic   [`AXI4_CACHE_WIDTH  -1:0]    mem_awcache;
    logic   [`AXI4_PROT_WIDTH   -1:0]    mem_awprot;
    logic   [`AXI4_QOS_WIDTH    -1:0]    mem_awqos;
    logic   [`AXI4_REGION_WIDTH -1:0]    mem_awregion;
    logic   [`AXI4_USER_WIDTH   -1:0]    mem_awuser;
    logic                                mem_awvalid;
    logic                                mem_awready;

    // AXI Write Data Channel Signals
    logic   [`AXI4_ID_WIDTH     -1:0]    mem_wid;
    logic   [`AXI4_DATA_WIDTH   -1:0]    mem_wdata;
    logic   [`AXI4_STRB_WIDTH   -1:0]    mem_wstrb;
    logic                                mem_wlast;
    logic   [`AXI4_USER_WIDTH   -1:0]    mem_wuser;
    logic                                mem_wvalid;
    logic                                mem_wready;

    // AXI Read Address Channel Signals
    logic   [`AXI4_ID_WIDTH     -1:0]    mem_arid;
    logic   [`AXI4_ADDR_WIDTH   -1:0]    mem_araddr;
    logic   [`AXI4_LEN_WIDTH    -1:0]    mem_arlen;
    logic   [`AXI4_SIZE_WIDTH   -1:0]    mem_arsize;
    logic   [`AXI4_BURST_WIDTH  -1:0]    mem_arburst;
    logic                                mem_arlock;
    logic   [`AXI4_CACHE_WIDTH  -1:0]    mem_arcache;
    logic   [`AXI4_PROT_WIDTH   -1:0]    mem_arprot;
    logic   [`AXI4_QOS_WIDTH    -1:0]    mem_arqos;
    logic   [`AXI4_REGION_WIDTH -1:0]    mem_arregion;
    logic   [`AXI4_USER_WIDTH   -1:0]    mem_aruser;
    logic                                mem_arvalid;
    logic                                mem_arready;

    // AXI Read Data Channel Signals
    logic   [`AXI4_ID_WIDTH     -1:0]    mem_rid;
    logic   [`AXI4_DATA_WIDTH   -1:0]    mem_rdata;
    logic   [`AXI4_RESP_WIDTH   -1:0]    mem_rresp;
    logic                                mem_rlast;
    logic   [`AXI4_USER_WIDTH   -1:0]    mem_ruser;
    logic                                mem_rvalid;
    logic                                mem_rready;

    // AXI Write Response Channel Signals
    logic   [`AXI4_ID_WIDTH     -1:0]    mem_bid;
    logic   [`AXI4_RESP_WIDTH   -1:0]    mem_bresp;
    logic   [`AXI4_USER_WIDTH   -1:0]    mem_buser;
    logic                                mem_bvalid;
    logic                                mem_bready;

    logic mem_calib_complete;

    // AXI UART
    logic  [12:0]                        uart_awaddr;
    logic                                uart_awvalid;
    logic                                uart_awready;
    logic  [31:0]                        uart_wdata;
    logic  [3:0 ]                        uart_wstrb;
    logic                                uart_wvalid;
    logic                                uart_wready;
    logic [1:0]                          uart_bresp;
    logic                                uart_bvalid;
    logic                                uart_bready;
    logic  [12:0]                        uart_araddr;
    logic                                uart_arvalid;
    logic                                uart_arready;
    logic [31:0]                         uart_rdata;
    logic [1:0]                          uart_rresp;
    logic                                uart_rvalid;
    logic                                uart_rready;
    logic                                uart_irq;

    sargantana_wrapper DUT(
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .m_axi_mem_awid(mem_awid),
        .m_axi_mem_awaddr(mem_awaddr),
        .m_axi_mem_awlen(mem_awlen),
        .m_axi_mem_awsize(mem_awsize),
        .m_axi_mem_awburst(mem_awburst),
        .m_axi_mem_awlock(mem_awlock),
        .m_axi_mem_awcache(mem_awcache),
        .m_axi_mem_awprot(mem_awprot),
        .m_axi_mem_awqos(mem_awqos),
        .m_axi_mem_awregion(mem_awregion),
        .m_axi_mem_awuser(mem_awuser),
        .m_axi_mem_awvalid(mem_awvalid),
        .m_axi_mem_awready(mem_awready),
        .m_axi_mem_wid(mem_wid),
        .m_axi_mem_wdata(mem_wdata),
        .m_axi_mem_wstrb(mem_wstrb),
        .m_axi_mem_wlast(mem_wlast),
        .m_axi_mem_wuser(mem_wuser),
        .m_axi_mem_wvalid(mem_wvalid),
        .m_axi_mem_wready(mem_wready),
        .m_axi_mem_arid(mem_arid),
        .m_axi_mem_araddr(mem_araddr),
        .m_axi_mem_arlen(mem_arlen),
        .m_axi_mem_arsize(mem_arsize),
        .m_axi_mem_arburst(mem_arburst),
        .m_axi_mem_arlock(mem_arlock),
        .m_axi_mem_arcache(mem_arcache),
        .m_axi_mem_arprot(mem_arprot),
        .m_axi_mem_arqos(mem_arqos),
        .m_axi_mem_arregion(mem_arregion),
        .m_axi_mem_aruser(mem_aruser),
        .m_axi_mem_arvalid(mem_arvalid),
        .m_axi_mem_arready(mem_arready),
        .m_axi_mem_rid(mem_rid),
        .m_axi_mem_rdata(mem_rdata),
        .m_axi_mem_rresp(mem_rresp),
        .m_axi_mem_rlast(mem_rlast),
        .m_axi_mem_ruser(mem_ruser),
        .m_axi_mem_rvalid(mem_rvalid),
        .m_axi_mem_rready(mem_rready),
        .m_axi_mem_bid(mem_bid),
        .m_axi_mem_bresp(mem_bresp),
        .m_axi_mem_buser(mem_buser),
        .m_axi_mem_bvalid(mem_bvalid),
        .m_axi_mem_bready(mem_bready),

        .m_axi_uart_awaddr(uart_awaddr),
        .m_axi_uart_awvalid(uart_awvalid),
        .m_axi_uart_awready(uart_awready),
        .m_axi_uart_wdata(uart_wdata),
        .m_axi_uart_wstrb(uart_wstrb),
        .m_axi_uart_wvalid(uart_wvalid),
        .m_axi_uart_wready(uart_wready),
        .m_axi_uart_bresp(uart_bresp),
        .m_axi_uart_bvalid(uart_bvalid),
        .m_axi_uart_bready(uart_bready),
        .m_axi_uart_araddr(uart_araddr),
        .m_axi_uart_arvalid(uart_arvalid),
        .m_axi_uart_arready(uart_arready),
        .m_axi_uart_rdata(uart_rdata),
        .m_axi_uart_rresp(uart_rresp),
        .m_axi_uart_rvalid(uart_rvalid),
        .m_axi_uart_rready(uart_rready),
        .uart_irq(uart_irq)
    );

    axi_mem_behav axi_mem_inst (
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .s_axi_mem_awid(mem_awid),
        .s_axi_mem_awaddr(mem_awaddr),
        .s_axi_mem_awlen(mem_awlen),
        .s_axi_mem_awsize(mem_awsize),
        .s_axi_mem_awburst(mem_awburst),
        .s_axi_mem_awlock(mem_awlock),
        .s_axi_mem_awcache(mem_awcache),
        .s_axi_mem_awprot(mem_awprot),
        .s_axi_mem_awqos(mem_awqos),
        .s_axi_mem_awregion(mem_awregion),
        .s_axi_mem_awuser(mem_awuser),
        .s_axi_mem_awvalid(mem_awvalid),
        .s_axi_mem_awready(mem_awready),
        .s_axi_mem_wid(mem_wid),
        .s_axi_mem_wdata(mem_wdata),
        .s_axi_mem_wstrb(mem_wstrb),
        .s_axi_mem_wlast(mem_wlast),
        .s_axi_mem_wuser(mem_wuser),
        .s_axi_mem_wvalid(mem_wvalid),
        .s_axi_mem_wready(mem_wready),
        .s_axi_mem_arid(mem_arid),
        .s_axi_mem_araddr(mem_araddr),
        .s_axi_mem_arlen(mem_arlen),
        .s_axi_mem_arsize(mem_arsize),
        .s_axi_mem_arburst(mem_arburst),
        .s_axi_mem_arlock(mem_arlock),
        .s_axi_mem_arcache(mem_arcache),
        .s_axi_mem_arprot(mem_arprot),
        .s_axi_mem_arqos(mem_arqos),
        .s_axi_mem_arregion(mem_arregion),
        .s_axi_mem_aruser(mem_aruser),
        .s_axi_mem_arvalid(mem_arvalid),
        .s_axi_mem_arready(mem_arready),
        .s_axi_mem_rid(mem_rid),
        .s_axi_mem_rdata(mem_rdata),
        .s_axi_mem_rresp(mem_rresp),
        .s_axi_mem_rlast(mem_rlast),
        .s_axi_mem_ruser(mem_ruser),
        .s_axi_mem_rvalid(mem_rvalid),
        .s_axi_mem_rready(mem_rready),
        .s_axi_mem_bid(mem_bid),
        .s_axi_mem_bresp(mem_bresp),
        .s_axi_mem_buser(mem_buser),
        .s_axi_mem_bvalid(mem_bvalid),
        .s_axi_mem_bready(mem_bready)
    );


    axi_uart_behav axi_uart_inst (
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .s_axi_uart_awaddr(uart_awaddr),
        .s_axi_uart_awvalid(uart_awvalid),
        .s_axi_uart_awready(uart_awready),
        .s_axi_uart_wdata(uart_wdata),
        .s_axi_uart_wstrb(uart_wstrb),
        .s_axi_uart_wvalid(uart_wvalid),
        .s_axi_uart_wready(uart_wready),
        .s_axi_uart_bresp(uart_bresp),
        .s_axi_uart_bvalid(uart_bvalid),
        .s_axi_uart_bready(uart_bready),
        .s_axi_uart_araddr(uart_araddr),
        .s_axi_uart_arvalid(uart_arvalid),
        .s_axi_uart_arready(uart_arready),
        .s_axi_uart_rdata(uart_rdata),
        .s_axi_uart_rresp(uart_rresp),
        .s_axi_uart_rvalid(uart_rvalid),
        .s_axi_uart_rready(uart_rready),
        .uart_irq(uart_irq)
    );

endmodule // veri_top
