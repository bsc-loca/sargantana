import fpga_pkg::*;

module axi_mem_behav (
    input logic                     clk_i,
    input logic                     rstn_i,

    // AXI Write Address Channel Signals
    input   [`MEM_ID_WIDTH     -1:0]    s_axi_mem_awid,
    input   [`MEM_ADDR_WIDTH   -1:0]    s_axi_mem_awaddr,
    input   [`MEM_LEN_WIDTH    -1:0]    s_axi_mem_awlen,
    input   [`MEM_SIZE_WIDTH   -1:0]    s_axi_mem_awsize,
    input   [`MEM_BURST_WIDTH  -1:0]    s_axi_mem_awburst,
    input                                s_axi_mem_awlock,
    input   [`MEM_CACHE_WIDTH  -1:0]    s_axi_mem_awcache,
    input   [`MEM_PROT_WIDTH   -1:0]    s_axi_mem_awprot,
    input   [`MEM_QOS_WIDTH    -1:0]    s_axi_mem_awqos,
    input   [`MEM_REGION_WIDTH -1:0]    s_axi_mem_awregion,
    input   [`MEM_USER_WIDTH   -1:0]    s_axi_mem_awuser,
    input                                s_axi_mem_awvalid,
    output                               s_axi_mem_awready,

    // AXI Write Data Channel Signals
    input   [`MEM_ID_WIDTH     -1:0]    s_axi_mem_wid,
    input   [`MEM_DATA_WIDTH   -1:0]    s_axi_mem_wdata,
    input   [`MEM_STRB_WIDTH   -1:0]    s_axi_mem_wstrb,
    input                                s_axi_mem_wlast,
    input   [`MEM_USER_WIDTH   -1:0]    s_axi_mem_wuser,
    input                                s_axi_mem_wvalid,
    output                                 s_axi_mem_wready,

    // AXI Read Address Channel Signals
    input   [`MEM_ID_WIDTH     -1:0]    s_axi_mem_arid,
    input   [`MEM_ADDR_WIDTH   -1:0]    s_axi_mem_araddr,
    input   [`MEM_LEN_WIDTH    -1:0]    s_axi_mem_arlen,
    input   [`MEM_SIZE_WIDTH   -1:0]    s_axi_mem_arsize,
    input   [`MEM_BURST_WIDTH  -1:0]    s_axi_mem_arburst,
    input                                s_axi_mem_arlock,
    input   [`MEM_CACHE_WIDTH  -1:0]    s_axi_mem_arcache,
    input   [`MEM_PROT_WIDTH   -1:0]    s_axi_mem_arprot,
    input   [`MEM_QOS_WIDTH    -1:0]    s_axi_mem_arqos,
    input   [`MEM_REGION_WIDTH -1:0]    s_axi_mem_arregion,
    input   [`MEM_USER_WIDTH   -1:0]    s_axi_mem_aruser,
    input                                s_axi_mem_arvalid,
    output                               s_axi_mem_arready,

    // AXI Read Data Channel Signals
    output    [`MEM_ID_WIDTH     -1:0]    s_axi_mem_rid,
    output    [`MEM_DATA_WIDTH   -1:0]    s_axi_mem_rdata,
    output    [`MEM_RESP_WIDTH   -1:0]    s_axi_mem_rresp,
    output                                 s_axi_mem_rlast,
    output    [`MEM_USER_WIDTH   -1:0]    s_axi_mem_ruser,
    output                                 s_axi_mem_rvalid,
    input                                  s_axi_mem_rready,

    // AXI Write Response Channel Signals
    output    [`MEM_ID_WIDTH     -1:0]    s_axi_mem_bid,
    output    [`MEM_RESP_WIDTH   -1:0]    s_axi_mem_bresp,
    output    [`MEM_USER_WIDTH   -1:0]    s_axi_mem_buser,
    output                                 s_axi_mem_bvalid,
    input                                  s_axi_mem_bready
);

    import "DPI-C" function void memory_init (input string path);
    import "DPI-C" function void memory_read (input bit [31:0] addr, output bit [512-1:0] data);
    import "DPI-C" function void memory_write (input bit [31:0] addr, input bit [(512/8)-1:0] byte_enable, input bit [512-1:0] data);

    initial begin
        string path;
        if ($value$plusargs("load=%s", path)) begin
            memory_init(path);
        end else begin
            $fatal(1, "No path provided for ELF to be loaded into the simulator's memory. Please provide one using +load=<path>");
        end
    end

    fpga_pkg::mem_axi_req_t  axi_req;
    fpga_pkg::mem_axi_resp_t axi_resp;

    `AXI_ASSIGN_SLAVE_TO_FLAT(mem, axi_req, axi_resp)

    localparam type addr_t     = logic [`MEM_ADDR_WIDTH-1:0];
    localparam type mem_data_t = logic [`MEM_DATA_WIDTH-1:0];
    localparam type mem_strb_t = logic [`MEM_DATA_WIDTH/8-1:0];

    logic      mem_req;
    logic      mem_gnt;
    addr_t     mem_addr;
    mem_data_t mem_wdata;
    mem_strb_t mem_strb;
    logic      mem_we;
    logic      mem_rvalid;
    mem_data_t mem_rdata;

    axi_to_mem #(
        .AddrWidth(`MEM_ADDR_WIDTH),
        .DataWidth(`MEM_DATA_WIDTH),
        .IdWidth(`MEM_ID_WIDTH),
        .NumBanks(1),
        .axi_req_t(fpga_pkg::mem_axi_req_t),
        .axi_resp_t(fpga_pkg::mem_axi_resp_t)
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

    assign mem_gnt = mem_rvalid;

    always_ff @(posedge clk_i) begin
        if (mem_req) begin
            mem_rvalid = 1;
            if (mem_we) begin
                memory_write(mem_addr + 32'h8000_0000, mem_strb, mem_wdata);
            end else begin
                memory_read(mem_addr + 32'h8000_0000, mem_rdata);
            end
        end else begin
            mem_rvalid = 0;
            mem_rdata = 0;
        end
    end

endmodule
