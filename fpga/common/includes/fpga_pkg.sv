
`ifndef FPGA_PKG
`define FPGA_PKG

`include "axi/assign.svh"
`include "defines.svh"

package fpga_pkg;

typedef logic [7:0]             id_core_t;
typedef logic [7:0]             id_peri_t; // This can change, depending on number of core instances
typedef logic [63:0]            addr_t;
typedef axi_pkg::xbar_rule_64_t rule_t; // Has to be the same width as axi addr
typedef logic [511:0]           data512_t;
typedef logic [31:0]            data32_t;
typedef logic [63:0]            strb512_t;
typedef logic [3:0]             strb32_t;
typedef logic [10:0]            user_t;


typedef logic [12:0]  lite_addr_t;

`AXI_TYPEDEF_ALL(core_axi, addr_t, id_core_t, data512_t, strb512_t, user_t)
`AXI_TYPEDEF_ALL(peri_axi, addr_t, id_peri_t, data512_t, strb512_t, user_t)
`AXI_TYPEDEF_ALL(axi32, addr_t, id_peri_t, data32_t, strb32_t, user_t)
`AXI_LITE_TYPEDEF_ALL(axi_lite, lite_addr_t, data32_t, strb32_t)

endpackage

`endif