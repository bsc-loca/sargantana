import fpga_pkg::*;

module axi_uart_behav (
    input logic                     clk_i,
    input logic                     rstn_i,

    // AXI UART
    input  [12:0]                       s_axi_uart_awaddr,
    input                               s_axi_uart_awvalid,
    output                                s_axi_uart_awready,
    input  [31:0]                       s_axi_uart_wdata,
    input  [3:0 ]                       s_axi_uart_wstrb,
    input                               s_axi_uart_wvalid,
    output                                s_axi_uart_wready,
    output  [1:0]                         s_axi_uart_bresp,
    output                                s_axi_uart_bvalid,
    input                               s_axi_uart_bready,
    input  [12:0]                       s_axi_uart_araddr,
    input                               s_axi_uart_arvalid,
    output                                s_axi_uart_arready,
    output  [31:0]                        s_axi_uart_rdata,
    output  [1:0]                         s_axi_uart_rresp,
    output                                s_axi_uart_rvalid,
    input                               s_axi_uart_rready,
    output                                uart_irq
);


`define AXI_LITE_ASSIGN_SLAVE_TO_FLAT(pat, req, rsp)  \
  assign req.aw_valid  = s_axi_``pat``_awvalid;  \
  assign req.aw.addr   = s_axi_``pat``_awaddr;   \
                                                 \
  assign req.w_valid   = s_axi_``pat``_wvalid;   \
  assign req.w.data    = s_axi_``pat``_wdata;    \
  assign req.w.strb    = s_axi_``pat``_wstrb;    \
                                                 \
  assign req.b_ready   = s_axi_``pat``_bready;   \
                                                 \
  assign req.ar_valid  = s_axi_``pat``_arvalid;  \
  assign req.ar.addr   = s_axi_``pat``_araddr;   \
                                                 \
  assign req.r_ready   = s_axi_``pat``_rready;   \
                                                 \
  assign s_axi_``pat``_awready = rsp.aw_ready;   \
  assign s_axi_``pat``_arready = rsp.ar_ready;   \
  assign s_axi_``pat``_wready  = rsp.w_ready;    \
                                                 \
  assign s_axi_``pat``_bvalid  = rsp.b_valid;    \
  assign s_axi_``pat``_bresp   = rsp.b.resp;     \
                                                 \
  assign s_axi_``pat``_rvalid  = rsp.r_valid;    \
  assign s_axi_``pat``_rdata   = rsp.r.data;     \
  assign s_axi_``pat``_rresp   = rsp.r.resp;

    // *** AXI interface ***

    fpga_pkg::axi_lite_req_t  axi_req;
    fpga_pkg::axi_lite_resp_t axi_resp;

    `AXI_LITE_ASSIGN_SLAVE_TO_FLAT(uart, axi_req, axi_resp)

    logic [31:0][7:0] reg_d, reg_q;
    logic [31:0] wr_active, rd_active, reg_load;

    axi_lite_regs #(
        .RegNumBytes(32),
        .AxiAddrWidth(13),
        .AxiDataWidth(32),
        .RegRstVal({8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h40, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0}),
        .AxiReadOnly(32'b0),
        .req_lite_t(fpga_pkg::axi_lite_req_t),
        .resp_lite_t(fpga_pkg::axi_lite_resp_t)
    ) axi_regs_inst (
        .clk_i(clk_i),
        .rst_ni(rstn_i),
        .axi_req_i(axi_req),
        .axi_resp_o(axi_resp),
        .wr_active_o(wr_active),
        .rd_active_o(rd_active),
        .reg_d_i(reg_d),
        .reg_load_i(reg_load),
        .reg_q_o(reg_q)
    );

    // *** UART behaviour ***

    // Port map:
    // 0: Rx FIFO
    // 1: Tx FIFO
    // 2: Status register
    // 3: Ctrl register

    assign reg_load = 16'b0;

    logic should_transmit;

    always_ff @(posedge clk_i) begin
        if (~rstn_i) should_transmit <= 1'b0;
        else should_transmit <= wr_active[0];
    end

    always_ff @(posedge clk_i) begin
        if (should_transmit) $write("%s", reg_q[0]);
    end

    /*always_ff @(posedge clk_i) begin
        if (axi_req.ar_valid) $display("Read at 0x%x (rd_active = 0x%x)", axi_req.ar.addr, reg_q[axi_req.ar.addr]);
        if (axi_req.aw_valid) $display("Write at 0x%x (wr_active = 0x%x)", axi_req.aw.addr, wr_active);
    end*/

endmodule
