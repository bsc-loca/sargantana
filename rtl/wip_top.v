//TODO: add DRAC header
//TODO: replace definitions with package drac
`include "definitions.vh" 

module top_drac(
    //original inputs of lagarto
    input                         CLK,
    input                         RST,
    input                         SOFT_RST,
    input    `ADDR                RESET_ADDRESS,
    //CSR inputs
    input    `DATA              CSR_RW_RDATA,
    input                       CSR_CSR_STALL,
    input                       CSR_XCPT,
    input                       CSR_ERET,
    input    `ADDR              CSR_EVEC,
    input                       CSR_INTERRUPT,
    input    `DATA              CSR_INTERRUPT_CAUSE,
    //ICache
    input     `CBLOCK           ICACHE_RESP_BITS_DATABLOCK,
    input                       ICACHE_RESP_VALID,
    input                       PTWINVALIDATE,
    input                       TLB_RESP_MISS,
    input                       TLB_RESP_XCPT_IF,
    //DMEM
    input                       DMEM_ORDERED,
    input                       DMEM_REQ_READY,
    input    `DATA              DMEM_RESP_BITS_DATA_SUBW,
    input                       DMEM_RESP_BITS_NACK,
    input                       DMEM_RESP_BITS_REPLAY,
    input                       DMEM_RESP_VALID,
    input                       DMEM_XCPT_MA_ST,
    input                       DMEM_XCPT_MA_LD,
    input                       DMEM_XCPT_PF_ST,
    input                       DMEM_XCPT_PF_LD,
    //fetch
    input `ADDR                 IO_FETCH_PC_VALUE,
    input                       IO_FETCH_PC_UPDATE,
    //debug register file?
    input                       IO_REG_READ,
    input [4:0]                 IO_REG_ADDR,     
    input                       IO_REG_WRITE,
    input [63:0]                IO_REG_WRITE_DATA
    //TODO:add outputs later
);

//instance of the struct  for interface icache and cpu
req_icache_cpu_t req_icache_cpu_i;
//translate from SoC signals to struct
assign req_icache_cpu_i.valid = ICACHE_RESP_VALID;
assign req_icache_cpu_i.data =  ICACHE_RESP_BITS_DATABLOCK;
//TODO: If not needed remove them from struct
//req_icache_cpu_i.instr_addr_misaligned = ;
//req_icache_cpu_i.instr_access_fault = ;
assign req_icache_cpu_i.instr_page_fault = PTWINVALIDATE ;

//instance of the struct for interface dcache and cpu
assign req_dcache_cpu_t req_icache_cpu_i;
//translate from SoC signals to struct
assign req_icache_cpu_i.dmem_resp_replay_i = DMEM_RESP_BITS_REPLAY;
assign req_icache_cpu_i.dmem_resp_data_i = DMEM_RESP_BITS_DATA_SUBW;
assign req_icache_cpu_i.dmem_req_ready_i = DMEM_REQ_READY;
assign req_icache_cpu_i.dmem_resp_valid_i = DMEM_RESP_VALID ;
assign req_icache_cpu_i.dmem_resp_nack_i = DMEM_RESP_BITS_NACK;
assign req_icache_cpu_i.dmem_xcpt_ma_st_i = DMEM_XCPT_MA_ST;
assign req_icache_cpu_i.dmem_xcpt_ma_ld_i = DMEM_XCPT_MA_LD;
assign req_icache_cpu_i.dmem_xcpt_pf_st_i = DMEM_XCPT_PF_ST;
assign req_icache_cpu_i.dmem_xcpt_pf_ld_i = DMEM_XCPT_PF_LD;

datapath datapath_inst(
    .clk_i(CLK),
    .rstn_i(RST),
    .soft_rstn_i(SOFT_RST),
    .req_icache_cpu_i(req_icache_cpu_i),//req_icache_cpu_t
    .req_dcache_cpu_i(req_dcache_cpu_i),//req_dcache_cpu_t
//TODO:connect outputs later
    .req_cpu_dcache_o(), //req_cpu_dcache_t
    .req_cpu_icache_o() //req_cpu_icache_t

);
/*
icache_interface icache_interface_inst(
    clk_i(CLK),
    rstn_i(RST),
    icache_resp_valid_i(ICACHE_RESP_VALID), // ICACHE_RESP_VALID,
    ptw_invalidate_i(PTWINVALIDATE), // PTWINVALIDATE,
    tlb_resp_miss_i(TLB_RESP_MISS), // TLB_RESP_MISS,
    tlb_resp_xcp_if_i(TLB_RESP_XCPT_IF), // TLB_RESP_XCPT_IF,
    icache_invalidate_o(), // ICACHE_INVALIDATE
    icache_req_kill_o(), // ICACHE_REQ_BITS_KILL,
    icache_req_valid_o(), // ICACHE_REQ_VALID,
    icache_resp_ready_o(), // ICACHE_RESP_READY,
    tlb_req_valid_o(), // TLB_REQ_VALID
//TODO:
    icache_idx_t         icache_req_bits_idx_o(), // ICACHE_REQ_BITS_IDX,
    // Fetch stage interface - Request packet from fetch_stage
    req_cpu_icache_t   req_fetch_icache_i(),
    // Request  signals from ICache
    icache_line_t      icache_resp_datablock_i(), // ICACHE_RESP_BITS_DATABLOCK
    icache_vpn_t         tlb_req_bits_vpn_o(), // TLB_REQ_BITS_VPN,
    // Fetch stage interface - Request packet icache to fetch
    req_icache_cpu_t  req_icache_fetch_o
);

dcache_interface dcache_interface_inst(
);
*/
endmodule
