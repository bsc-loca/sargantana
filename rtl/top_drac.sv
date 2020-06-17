/* -----------------------------------------------
* Project Name   : DRAC
* File           : datapath.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Cabo Pitarch 
* Email(s)       : guillem.cabo@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.CP | 
* -----------------------------------------------
*/

import drac_pkg::*;

module top_drac(
//--------------------------------------------------------------------------------------------------------------------------
// ORIGINAL INPUTS OF LAGARTO 
//--------------------------------------------------------------------------------------------------------------------------
    input logic                 CLK,
    input logic                 RST,
    input logic                 SOFT_RST,
    input addr_t                RESET_ADDRESS,

//--------------------------------------------------------------------------------------------------------------------------
// CSR INPUT INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
    input bus64_t               CSR_RW_RDATA,
    input logic                 CSR_CSR_STALL,
    input logic                 CSR_XCPT,
    input logic                 CSR_ERET,
    input bus64_t               CSR_EVEC,
    input logic                 CSR_INTERRUPT,
    input bus64_t               CSR_INTERRUPT_CAUSE,

//--------------------------------------------------------------------------------------------------------------------------
// I-CANCHE INPUT INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
    input icache_line_t         ICACHE_RESP_BITS_DATABLOCK,
    input addr_t                ICACHE_RESP_BITS_VADDR,
    input logic                 ICACHE_RESP_VALID,
    input logic                 ICACHE_REQ_READY,
    input logic                 PTWINVALIDATE,
    input logic                 TLB_RESP_MISS,
    input logic                 TLB_RESP_XCPT_IF,
    input logic                 iptw_resp_valid_i,

//--------------------------------------------------------------------------------------------------------------------------
// D-CACHE  INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
    input logic                 DMEM_ORDERED,
    input logic                 DMEM_REQ_READY,
    input bus64_t               DMEM_RESP_BITS_DATA_SUBW,
    input logic                 DMEM_RESP_BITS_NACK,
    input logic                 DMEM_RESP_BITS_REPLAY,
    input logic                 DMEM_RESP_VALID,
    input logic                 DMEM_XCPT_MA_ST,
    input logic                 DMEM_XCPT_MA_LD,
    input logic                 DMEM_XCPT_PF_ST,
    input logic                 DMEM_XCPT_PF_LD,

//--------------------------------------------------------------------------------------------------------------------------
// FETCH  INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
    input addr_t                IO_FETCH_PC_VALUE,
    input logic                 IO_FETCH_PC_UPDATE,

//--------------------------------------------------------------------------------------------------------------------------
// DEBUGGING MODULE SIGNALS
//--------------------------------------------------------------------------------------------------------------------------
    input logic                 IO_REG_READ,
    input logic [4:0]           IO_REG_ADDR,  // Address used for both read and write operations    
    input logic                 IO_REG_WRITE,
    input logic [63:0]          IO_REG_WRITE_DATA,
    input logic                 istall_test, 

//--------------------------------------------------------------------------------------------------------------------------
// CSR OUTPUT INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
    output logic   [11:0]       CSR_RW_ADDR,
    output logic   [2:0]        CSR_RW_CMD,
    output bus64_t              CSR_RW_WDATA,
    output logic                CSR_EXCEPTION,
    output logic                CSR_RETIRE,
    output bus64_t              CSR_CAUSE,
    output addr_t               CSR_PC,

//--------------------------------------------------------------------------------------------------------------------------
// I-CANCHE OUTPUT INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
    output logic                ICACHE_INVALIDATE,
    output logic [11:0]         ICACHE_REQ_BITS_IDX,
    output logic                ICACHE_REQ_BITS_KILL,
    output logic                ICACHE_REQ_VALID,
    output logic                ICACHE_RESP_READY,
    output logic [27:0]         ICACHE_REQ_BITS_VPN,
    output logic [27:0]         TLB_REQ_BITS_VPN,
    output logic                TLB_REQ_VALID,

//--------------------------------------------------------------------------------------------------------------------------
// D-CACHE  OUTPUT INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
    output logic                DMEM_REQ_VALID,  
    output logic   [3:0]        DMEM_OP_TYPE,
    output logic   [4:0]        DMEM_REQ_CMD,
    output bus64_t              DMEM_REQ_BITS_DATA,
    output addr_t               DMEM_REQ_BITS_ADDR,
    output logic   [7:0]        DMEM_REQ_BITS_TAG,
    output logic                DMEM_REQ_INVALIDATE_LR,
    output logic                DMEM_REQ_BITS_KILL,

//--------------------------------------------------------------------------------------------------------------------------
// DEBUGGING MODULE SIGNALS
//--------------------------------------------------------------------------------------------------------------------------

// PC
    output addr_t               IO_FETCH_PC,
    output addr_t               IO_DEC_PC,
    output addr_t               IO_RR_PC,
    output addr_t               IO_EXE_PC,
    output addr_t               IO_WB_PC,

    output logic                IO_WB_PC_VALID,
    output logic  [4:0]         IO_WB_ADDR,
    output logic                IO_WB_WE,
    output bus64_t              IO_WB_BITS_ADDR,

    output bus64_t              IO_REG_READ_DATA,

//--------------------------------------------------------------------------------------------------------------------------
// PMU INTERFACE
//--------------------------------------------------------------------------------------------------------------------------
    output logic                io_core_pmu_branch_miss,
    output logic                io_core_pmu_EXE_STORE,
    output logic                io_core_pmu_EXE_LOAD,
    //output logic  [39:0]           io_core_pmu_EXE_PC,
    output logic                io_core_pmu_new_instruction

);

// Response Interface icache to datapath
resp_icache_cpu_t resp_icache_interface_datapath;

// Request Datapath to Icache interface
req_cpu_icache_t req_datapath_icache_interface;

// Response Interface dcache to datapath
resp_dcache_cpu_t resp_dcache_interface_datapath;

// Request Datapath to Dcache interface
req_cpu_dcache_t req_datapath_dcache_interface;

// Response CSR Interface to datapath
resp_csr_cpu_t resp_csr_interface_datapath;

assign resp_csr_interface_datapath.csr_rw_rdata = CSR_RW_RDATA;
// NOTE:resp_csr_interface_datapath.csr_replay is a "ready" signal that indicate
// that the CSR are not blocked. In the implementation, since we only have one 
// inorder core any access to the CSR/PCR will be available. In multicore
// scenarios or higher performance cores you may need csr_replay.
assign resp_csr_interface_datapath.csr_replay = 1'b0; 
assign resp_csr_interface_datapath.csr_stall = CSR_CSR_STALL;
assign resp_csr_interface_datapath.csr_exception = CSR_XCPT;
assign resp_csr_interface_datapath.csr_eret = CSR_ERET;
assign resp_csr_interface_datapath.csr_evec = {{25{CSR_EVEC[39]}},CSR_EVEC[38:0]};
assign resp_csr_interface_datapath.csr_interrupt = CSR_INTERRUPT;
assign resp_csr_interface_datapath.csr_interrupt_cause = CSR_INTERRUPT_CAUSE;
 
// Request Datapath to CSR
req_cpu_csr_t req_datapath_csr_interface;

assign CSR_RW_ADDR      = req_datapath_csr_interface.csr_rw_addr;
assign CSR_RW_CMD       = req_datapath_csr_interface.csr_rw_cmd;
assign CSR_RW_WDATA     = req_datapath_csr_interface.csr_rw_data;
assign CSR_EXCEPTION    = req_datapath_csr_interface.csr_exception;
assign CSR_RETIRE       = req_datapath_csr_interface.csr_retire;
assign CSR_CAUSE        = req_datapath_csr_interface.csr_xcpt_cause;
assign CSR_PC           = req_datapath_csr_interface.csr_pc[39:0];

datapath datapath_inst(
    .clk_i(CLK),
    .rstn_i(RST),
    .reset_addr_i(RESET_ADDRESS),

    // INPUT DATAPATH
    .soft_rstn_i(SOFT_RST),
    .resp_icache_cpu_i(resp_icache_interface_datapath), 
    .resp_dcache_cpu_i(resp_dcache_interface_datapath), 
    .resp_csr_cpu_i(resp_csr_interface_datapath),

    // OUTPUT DATAPATH
    .req_cpu_dcache_o(req_datapath_dcache_interface),
    .req_cpu_icache_o(req_datapath_icache_interface),
    .req_cpu_csr_o(req_datapath_csr_interface)
);

icache_interface icache_interface_inst(
    .clk_i(CLK),
    .rstn_i(RST),

    // Inputs ICache
    .icache_resp_datablock_i(ICACHE_RESP_BITS_DATABLOCK),
    .icache_resp_vaddr_i(ICACHE_RESP_BITS_VADDR), 
    .icache_resp_valid_i(ICACHE_RESP_VALID),
    .icache_req_ready_i(ICACHE_REQ_READY), 
    .iptw_resp_valid_i(iptw_resp_valid_i),
    .ptw_invalidate_i(PTWINVALIDATE),
    .tlb_resp_miss_i(TLB_RESP_MISS),
    .tlb_resp_xcp_if_i(TLB_RESP_XCPT_IF),

    // Fetch stage interface - Request packet from fetch_stage
    .req_fetch_icache_i(req_datapath_icache_interface),

    // Outputs ICache
    .icache_invalidate_o(ICACHE_INVALIDATE), 
    .icache_req_bits_idx_o(ICACHE_REQ_BITS_IDX), 
    .icache_req_kill_o(ICACHE_REQ_BITS_KILL), 
    .icache_req_valid_o(ICACHE_REQ_VALID),
    .icache_resp_ready_o(ICACHE_RESP_READY),
    .icache_req_bits_vpn_o(ICACHE_REQ_BITS_VPN), 
    .tlb_req_bits_vpn_o(TLB_REQ_BITS_VPN), 
    .tlb_req_valid_o(TLB_REQ_VALID),

    // Fetch stage interface - Response packet icache to fetch
    .resp_icache_fetch_o(resp_icache_interface_datapath)
);

dcache_interface dcache_interface_inst(
    .clk_i(CLK),
    .rstn_i(RST),

    .req_cpu_dcache_i(req_datapath_dcache_interface),

    // DCACHE Answer
    .dmem_resp_replay_i(DMEM_RESP_BITS_REPLAY),
    .dmem_resp_data_i(DMEM_RESP_BITS_DATA_SUBW),
    .dmem_req_ready_i(DMEM_REQ_READY),
    .dmem_resp_valid_i(DMEM_RESP_VALID), 
    .dmem_resp_nack_i(DMEM_RESP_BITS_NACK),
    .dmem_xcpt_ma_st_i(DMEM_XCPT_MA_ST),
    .dmem_xcpt_ma_ld_i(DMEM_XCPT_MA_LD),
    .dmem_xcpt_pf_st_i(DMEM_XCPT_PF_ST),
    .dmem_xcpt_pf_ld_i(DMEM_XCPT_PF_LD),

    // Interface request
    .dmem_req_valid_o(DMEM_REQ_VALID),
    .dmem_req_cmd_o(DMEM_REQ_CMD),
    .dmem_req_addr_o(DMEM_REQ_BITS_ADDR),
    .dmem_op_type_o(DMEM_OP_TYPE),
    .dmem_req_data_o(DMEM_REQ_BITS_DATA),
    .dmem_req_tag_o(DMEM_REQ_BITS_TAG),
    .dmem_req_invalidate_lr_o(DMEM_REQ_INVALIDATE_LR),
    .dmem_req_kill_o(DMEM_REQ_BITS_KILL),

    // DCACHE Answer to cpu
    .resp_dcache_cpu_o(resp_dcache_interface_datapath) 
);

endmodule
