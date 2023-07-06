
`ifndef FPGA_PKG
`define FPGA_PKG

`include "axi/assign.svh"
`include "defines.svh"

package fpga_pkg;

typedef logic [`AXI4_ID_WIDTH-1:0]      id_mst_t;
typedef logic [`AXI4_ID_WIDTH-1:0]      id_slv_t;
typedef logic [`AXI4_ADDR_WIDTH-1:0]    addr_t;
typedef axi_pkg::xbar_rule_32_t         rule_t; // Has to be the same width as axi addr
typedef logic [`AXI4_DATA_WIDTH-1:0]    data_t;
typedef logic [`AXI4_STRB_WIDTH-1:0]    strb_t;
typedef logic [`AXI4_USER_WIDTH-1:0]    user_t;

`AXI_TYPEDEF_AW_CHAN_T(aw_chan_mst_t, addr_t, id_mst_t, user_t)
`AXI_TYPEDEF_AW_CHAN_T(aw_chan_slv_t, addr_t, id_slv_t, user_t)
`AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
`AXI_TYPEDEF_B_CHAN_T(b_chan_mst_t, id_mst_t, user_t)
`AXI_TYPEDEF_B_CHAN_T(b_chan_slv_t, id_slv_t, user_t)

`AXI_TYPEDEF_AR_CHAN_T(ar_chan_mst_t, addr_t, id_mst_t, user_t)
`AXI_TYPEDEF_AR_CHAN_T(ar_chan_slv_t, addr_t, id_slv_t, user_t)
`AXI_TYPEDEF_R_CHAN_T(r_chan_mst_t, data_t, id_mst_t, user_t)
`AXI_TYPEDEF_R_CHAN_T(r_chan_slv_t, data_t, id_slv_t, user_t)

`AXI_TYPEDEF_REQ_T(mst_req_t, aw_chan_mst_t, w_chan_t, ar_chan_mst_t)
`AXI_TYPEDEF_RESP_T(mst_resp_t, b_chan_mst_t, r_chan_mst_t)
`AXI_TYPEDEF_REQ_T(slv_req_t, aw_chan_slv_t, w_chan_t, ar_chan_slv_t)
`AXI_TYPEDEF_RESP_T(slv_resp_t, b_chan_slv_t, r_chan_slv_t)

endpackage

`endif