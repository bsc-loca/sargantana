import fpga_pkg::*;

module axi_behav (
    input logic                     clk_i,
    input logic                     rstn_i,

    // AXI Write Address Channel Signals
    input   [`AXI4_ID_WIDTH     -1:0]    s_axi_mem_awid,
    input   [`AXI4_ADDR_WIDTH   -1:0]    s_axi_mem_awaddr,
    input   [`AXI4_LEN_WIDTH    -1:0]    s_axi_mem_awlen,
    input   [`AXI4_SIZE_WIDTH   -1:0]    s_axi_mem_awsize,
    input   [`AXI4_BURST_WIDTH  -1:0]    s_axi_mem_awburst,
    input                                s_axi_mem_awlock,
    input   [`AXI4_CACHE_WIDTH  -1:0]    s_axi_mem_awcache,
    input   [`AXI4_PROT_WIDTH   -1:0]    s_axi_mem_awprot,
    input   [`AXI4_QOS_WIDTH    -1:0]    s_axi_mem_awqos,
    input   [`AXI4_REGION_WIDTH -1:0]    s_axi_mem_awregion,
    input   [`AXI4_USER_WIDTH   -1:0]    s_axi_mem_awuser,
    input                                s_axi_mem_awvalid,
    output                               s_axi_mem_awready,

    // AXI Write Data Channel Signals
    input   [`AXI4_ID_WIDTH     -1:0]    s_axi_mem_wid,
    input   [`AXI4_DATA_WIDTH   -1:0]    s_axi_mem_wdata,
    input   [`AXI4_STRB_WIDTH   -1:0]    s_axi_mem_wstrb,
    input                                s_axi_mem_wlast,
    input   [`AXI4_USER_WIDTH   -1:0]    s_axi_mem_wuser,
    input                                s_axi_mem_wvalid,
    output                                 s_axi_mem_wready,

    // AXI Read Address Channel Signals
    input   [`AXI4_ID_WIDTH     -1:0]    s_axi_mem_arid,
    input   [`AXI4_ADDR_WIDTH   -1:0]    s_axi_mem_araddr,
    input   [`AXI4_LEN_WIDTH    -1:0]    s_axi_mem_arlen,
    input   [`AXI4_SIZE_WIDTH   -1:0]    s_axi_mem_arsize,
    input   [`AXI4_BURST_WIDTH  -1:0]    s_axi_mem_arburst,
    input                                s_axi_mem_arlock,
    input   [`AXI4_CACHE_WIDTH  -1:0]    s_axi_mem_arcache,
    input   [`AXI4_PROT_WIDTH   -1:0]    s_axi_mem_arprot,
    input   [`AXI4_QOS_WIDTH    -1:0]    s_axi_mem_arqos,
    input   [`AXI4_REGION_WIDTH -1:0]    s_axi_mem_arregion,
    input   [`AXI4_USER_WIDTH   -1:0]    s_axi_mem_aruser,
    input                                s_axi_mem_arvalid,
    output                               s_axi_mem_arready,

    // AXI Read Data Channel Signals
    output    [`AXI4_ID_WIDTH     -1:0]    s_axi_mem_rid,
    output    [`AXI4_DATA_WIDTH   -1:0]    s_axi_mem_rdata,
    output    [`AXI4_RESP_WIDTH   -1:0]    s_axi_mem_rresp,
    output                                 s_axi_mem_rlast,
    output    [`AXI4_USER_WIDTH   -1:0]    s_axi_mem_ruser,
    output                                 s_axi_mem_rvalid,
    input                                  s_axi_mem_rready,

    // AXI Write Response Channel Signals
    output    [`AXI4_ID_WIDTH     -1:0]    s_axi_mem_bid,
    output    [`AXI4_RESP_WIDTH   -1:0]    s_axi_mem_bresp,
    output    [`AXI4_USER_WIDTH   -1:0]    s_axi_mem_buser,
    output                                 s_axi_mem_bvalid,
    input                                  s_axi_mem_bready
);

    import "DPI-C" function void memory_read (input bit [31:0] addr, output bit [512-1:0] data);
    import "DPI-C" function void memory_write (input bit [31:0] addr, input bit [(512/8)-1:0] byte_enable, input bit [512-1:0] data);

    fpga_pkg::slv_req_t  axi_req;
    fpga_pkg::slv_resp_t axi_resp;

    `AXI_ASSIGN_SLAVE_TO_FLAT(mem, axi_req, axi_resp)

    localparam type addr_t     = logic [`AXI4_ADDR_WIDTH-1:0];
    localparam type mem_data_t = logic [`AXI4_DATA_WIDTH-1:0];
    localparam type mem_strb_t = logic [`AXI4_DATA_WIDTH/8-1:0];

    logic      mem_req;
    logic      mem_gnt;
    addr_t     mem_addr;
    mem_data_t mem_wdata;
    mem_strb_t mem_strb;
    logic      mem_we;
    logic      mem_rvalid;
    mem_data_t mem_rdata;

    axi_to_mem #(
        .AddrWidth(`AXI4_ADDR_WIDTH),
        .DataWidth(`AXI4_DATA_WIDTH),
        .IdWidth(`AXI4_ID_WIDTH),
        .NumBanks(1)
    ) translator_inst (
        .clk_i(clk_i),
        .rst_ni(rstn_i),

        .axi_req_i(axi_req),
        .axi_resp_o(axi_resp),

        .mem_req_o(mem_req),
        .mem_gnt_i(mem_gnt),
        .mem_addr_o(mem_addr),
        .mem_wdata_o(mem_wdata),
        .mem_strb_o(mem_strb),
        .mem_we_o(mem_we),
        .mem_rvalid_i(mem_rvalid),
        .mem_rdata_i(mem_rdata)
    );

    always_ff @(posedge clk_i) begin
        if (mem_req) begin
            mem_rvalid = 1;
            if (mem_we != 0) begin
                memory_write(mem_addr, mem_we, mem_wdata);
            end else begin
                memory_read(mem_addr, mem_rdata);
            end
        end else begin
            mem_gnt = 0;
            mem_rvalid = 0;
            mem_rdata = 0;
        end
    end

endmodule
