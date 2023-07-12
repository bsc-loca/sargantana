`define MEM_DATA_WIDTH  512
`define MEM_ID_WIDTH    6
`define MEM_ADDR_WIDTH  64
`define MEM_LEN_WIDTH   8
`define MEM_SIZE_WIDTH  3
`define MEM_STRB_WIDTH  64
`define MEM_BURST_WIDTH 2
`define MEM_RESP_WIDTH  2
`define MEM_CACHE_WIDTH 4
`define MEM_PROT_WIDTH 3
`define MEM_QOS_WIDTH 4
`define MEM_REGION_WIDTH 4
`define MEM_USER_WIDTH 11

`define AXI_XBAR_DATA_WIDTH 512
`define AXI_XBAR_ADDR_WIDTH 64
`define AXI_XBAR_USER_WIDTH 32'd11
// hpdcache id width + clog2(core count)
// This is 8 because there is only 1 master/core
`define AXI_XBAR_PERI_ID_WIDTH 9

`define UART_XBAR_ID 0
`define UART_BASE_ADDR 64'h0000_0000_4000_1000
`define UART_END_ADDR  64'h0000_0000_4000_1020

`define MEM_XBAR_ID 1
`define MEM_BASE_ADDR 64'h0000_0000_8000_0000
`define MEM_END_ADDR  64'h0000_0000_d000_0000