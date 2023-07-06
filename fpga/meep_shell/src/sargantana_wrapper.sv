import fpga_pkg::*;

module sargantana_wrapper(
    input            clk_i,
    input            mc_clk,
    input            vpu_clk,
    input   [4:0]    pcie_gpio ,
    output           ExtArstn,
    input            mc_rstn,

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

    logic rstn;

    assign rstn = pcie_gpio[0];

    // AXI Crossbar Configuration

    localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
        NoSlvPorts:         1,
        NoMstPorts:         2,
        MaxMstTrans:        10,
        MaxSlvTrans:        6,
        FallThrough:        1'b0,
        LatencyMode:        axi_pkg::CUT_ALL_AX,
        PipelineStages:     1,
        AxiIdWidthSlvPorts: 32'(hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH),
        AxiIdUsedSlvPorts:  32'(hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH),
        UniqueIds:          1,
        AxiAddrWidth:       `AXI4_ADDR_WIDTH,
        AxiDataWidth:       `AXI4_DATA_WIDTH,
        NoAddrRules:        2
    };

    // Address Map

    localparam rule_t [xbar_cfg.NoAddrRules-1:0] ADDR_MAP = {
        rule_t'{
            idx: 0,
            start_addr: 32'h4000_0000,
            end_addr: 32'h4001_0000, // TODO: Check this?
            default: '0
        },
        rule_t'{
            idx: 1,
            start_addr: 32'h8000_0000,
            end_addr: 32'ha000_0000,
            default: '0
        }
    };

    // master structs
    fpga_pkg::mst_req_t  [xbar_cfg.NoMstPorts-1:0] masters_req;
    fpga_pkg::mst_resp_t [xbar_cfg.NoMstPorts-1:0] masters_resp;

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( `AXI4_ADDR_WIDTH      ),
        .AXI_DATA_WIDTH ( `AXI4_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH + $clog2(xbar_cfg.NoMstPorts) ),
        .AXI_USER_WIDTH ( hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH + $clog2(xbar_cfg.NoMstPorts) )
    ) master_bus [xbar_cfg.NoMstPorts-1:0] ();
    
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( `AXI4_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( `AXI4_DATA_WIDTH     ),
        .AXI_ID_WIDTH   ( 32'(hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH) ),
        .AXI_USER_WIDTH ( 32'(hpdcache_pkg::HPDCACHE_MEM_ID_WIDTH) )
    ) slave_bus [xbar_cfg.NoSlvPorts-1:0] ();

    // Connect core AXI master to xbar slave
    for (genvar i = 0; i < xbar_cfg.NoMstPorts; i++) begin
        `AXI_ASSIGN_TO_REQ(masters_req[i], master_bus[i])
        `AXI_ASSIGN_TO_RESP(masters_resp[i], master_bus[i])
    end

    // AXI connections
    // TODO: Connect UART to axi-lite adapter
    `AXI_ASSIGN_MASTER_TO_FLAT(mem, masters_req[1], masters_resp[1])

    axi_xbar_intf #(
        .AXI_USER_WIDTH ( 0               ),
        .Cfg            ( xbar_cfg        ),
        .rule_t         ( rule_t          )
    ) xbar_inst (
        .clk_i                  ( clk_i    ),
        .rst_ni                 ( rstn   ),
        .test_i                 ( 1'b0    ),
        .slv_ports              ( slave_bus ),
        .mst_ports              ( master_bus  ),
        .addr_map_i             ( ADDR_MAP ),
        .en_default_mst_port_i  ( '0      ),
        .default_mst_port_i     ( '0      )
    );

    axi_wrapper core_inst (
        .clk_i(clk_i),
        .rstn_i(rstn),

        .axi_o(slave_bus[0])
    );

endmodule