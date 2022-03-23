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
import drac_icache_pkg::*;

module top_drac(
//------------------------------------------------------------------------------------
// ORIGINAL INPUTS OF LAGARTO 
//------------------------------------------------------------------------------------
    input logic                 CLK,
    input logic                 RST,
    input logic                 SOFT_RST,
    input addr_t                RESET_ADDRESS,

//------------------------------------------------------------------------------------
// DEBUG RING SIGNALS INPUT
// debug_halt_i is istall_test 
//------------------------------------------------------------------------------------    
    input                       debug_halt_i,

    input addr_t                IO_FETCH_PC_VALUE,
    input                       IO_FETCH_PC_UPDATE,
    
    input                       IO_REG_READ,
    input  [4:0]                IO_REG_ADDR,
    input                       IO_REG_WRITE,
    input bus64_t               IO_REG_WRITE_DATA,
    input  [5:0]		IO_REG_PADDR,
    input			IO_REG_PREAD,

//------------------------------------------------------------------------------------
// CSR INPUT INTERFACE
//------------------------------------------------------------------------------------
    input bus64_t               CSR_RW_RDATA,
    input logic                 CSR_CSR_STALL,
    input logic                 CSR_XCPT,
    input [63:0]                CSR_XCPT_CAUSE,
    input [63:0]                CSR_TVAL,
    input logic                 CSR_ERET,
    input addr_t                CSR_EVEC,
    input logic                 CSR_INTERRUPT,
    input bus64_t               CSR_INTERRUPT_CAUSE,
    input logic                 io_csr_csr_replay,
    input [1:0]                 csr_priv_lvl_i,
    input [39:0]                csr_vpu_data_i,
    input logic [2:0]           csr_frm_i,
    input logic                 en_ld_st_translation_i,

//------------------------------------------------------------------------------------
// I-CANCHE INPUT INTERFACE
//------------------------------------------------------------------------------------
    
    input logic                 PTWINVALIDATE     ,
    input logic                 TLB_RESP_MISS     ,
    input logic                 TLB_RESP_XCPT_IF  ,
    input logic  [19:0]         itlb_resp_ppn_i   ,   
    input logic                 iptw_resp_valid_i ,
    //==============================================================
    
    //- From L2
    input  logic         io_mem_grant_valid                 ,
    input  logic [127:0] io_mem_grant_bits_data             ,
    input  logic   [1:0] io_mem_grant_bits_addr_beat        ,
    

//----------------------------------------------------------------------------------
// D-CACHE  INTERFACE
//----------------------------------------------------------------------------------
    input logic                 DMEM_REQ_READY,
    input bus_simd_t            DMEM_RESP_BITS_DATA_SUBW,
    input logic                 DMEM_RESP_BITS_NACK,
    input logic                 DMEM_RESP_BITS_REPLAY,
    input logic                 DMEM_RESP_VALID,
    input logic  [7:0]          DMEM_RESP_TAG,
    input logic                 DMEM_RESP_BITS_HAS_DATA,
    input logic                 DMEM_XCPT_MA_ST,
    input logic                 DMEM_XCPT_MA_LD,
    input logic                 DMEM_XCPT_PF_ST,
    input logic                 DMEM_XCPT_PF_LD,
    input logic                 DMEM_ORDERED, // TODO: remove if we dont used

//-----------------------------------------------------------------------------------
// CSR OUTPUT INTERFACE
//-----------------------------------------------------------------------------------
    output logic   [11:0]       CSR_RW_ADDR,
    output logic   [2:0]        CSR_RW_CMD,
    output bus64_t              CSR_RW_WDATA,
    output logic                CSR_EXCEPTION,
    output logic  [1:0]         CSR_RETIRE,
    output bus64_t              CSR_CAUSE,
    output addr_t               CSR_PC,
    output logic [4:0]          csr_fp_status_o,
    output logic                csr_fp_status_valid_o,

//-----------------------------------------------------------------------------------
// I-CACHE OUTPUT INTERFACE
//-----------------------------------------------------------------------------------
    
    output logic [27:0]         TLB_REQ_BITS_VPN,
    output logic                TLB_REQ_VALID,

    //- To L2
    output logic         io_mem_acquire_valid               ,
    output logic  [25:0] io_mem_acquire_bits_addr_block     ,
    output logic         io_mem_acquire_bits_client_xact_id ,
    output logic   [1:0] io_mem_acquire_bits_addr_beat      ,
    output logic [127:0] io_mem_acquire_bits_data           ,
    output logic         io_mem_acquire_bits_is_builtin_type,
    output logic   [2:0] io_mem_acquire_bits_a_type         ,
    output logic  [16:0] io_mem_acquire_bits_union          ,
    output logic         io_mem_grant_ready                 ,

//-----------------------------------------------------------------------------------
// D-CACHE  OUTPUT INTERFACE
//-----------------------------------------------------------------------------------
    output logic                DMEM_REQ_VALID,  
    output logic   [3:0]        DMEM_OP_TYPE,
    output logic   [4:0]        DMEM_REQ_CMD,
    output bus_simd_t           DMEM_REQ_BITS_DATA,
    output addr_t               DMEM_REQ_BITS_ADDR,
    output logic   [7:0]        DMEM_REQ_BITS_TAG,
    output logic                DMEM_REQ_INVALIDATE_LR,
    output logic                DMEM_REQ_BITS_KILL,

//-----------------------------------------------------------------------------------
// DEBUGGING MODULE SIGNALS
//-----------------------------------------------------------------------------------

// PC
    output addr_t               IO_FETCH_PC,
    output addr_t               IO_DEC_PC,
    output addr_t               IO_RR_PC,
    output addr_t               IO_EXE_PC,
    output addr_t               IO_WB_PC,
// WB
    output logic                IO_WB_PC_VALID,
    output logic  [4:0]         IO_WB_ADDR,
    output logic                IO_WB_WE,
    output bus64_t              IO_WB_BITS_ADDR,

    output logic		IO_REG_BACKEND_EMPTY,
    output logic  [5:0]		IO_REG_LIST_PADDR,
    output bus64_t              IO_REG_READ_DATA,


//-----------------------------------------------------------------------------
// PMU INTERFACE
//-----------------------------------------------------------------------------
    input  logic                io_core_pmu_l2_hit_i        ,
    output logic                io_core_pmu_branch_miss     ,
    output logic                io_core_pmu_is_branch       ,
    output logic                io_core_pmu_branch_taken    , 
    output logic                io_core_pmu_EXE_STORE       ,
    output logic                io_core_pmu_EXE_LOAD        ,
    output logic  [1:0]         io_core_pmu_new_instruction ,
    output logic                io_core_pmu_icache_req      ,
    output logic                io_core_pmu_icache_kill     ,
    output logic                io_core_pmu_stall_if        ,
    output logic                io_core_pmu_stall_id        ,
    output logic                io_core_pmu_stall_rr        ,
    output logic                io_core_pmu_stall_exe       ,
    output logic                io_core_pmu_stall_wb        ,           
    output logic                io_core_pmu_buffer_miss     ,           
    output logic                io_core_pmu_imiss_kill      ,           
    output logic                io_core_pmu_icache_bussy    ,
    output logic                io_core_pmu_imiss_time      ,
    output logic                io_core_pmu_load_store      ,
    output logic                io_core_pmu_data_depend     ,
    output logic                io_core_pmu_struct_depend   ,
    output logic                io_core_pmu_grad_list_full  ,
    output logic                io_core_pmu_free_list_empty ,

//-----------------------------------------------------------------------------
// BOOTROM CONTROLER INTERFACE
//-----------------------------------------------------------------------------
    input  logic                brom_ready_i        ,
    input  logic [31:0]         brom_resp_data_i    ,
    input  logic                brom_resp_valid_i   ,
    output logic [23:0]         brom_req_address_o  ,
    output logic                brom_req_valid_o    ,
   
    input logic                 csr_spi_config_i, 
    input logic                 en_translation_i  

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

addr_t dcache_addr;

// struct debug input/output
debug_in_t debug_in;
debug_out_t debug_out;

//iCache
iresp_o_t      icache_resp  ;
ireq_i_t       lagarto_ireq ;
tresp_i_t      itlb_tresp   ;
treq_o_t       itlb_treq    ;
ifill_resp_i_t ifill_resp   ;
ifill_req_o_t  ifill_req    ;
logic          iflush       ;
logic          req_icache_ready;

//--PMU
to_PMU_t       pmu_flags    ;
logic          buffer_miss  ;
logic imiss_time_pmu  ;
logic imiss_kill_pmu ;
logic imiss_l2_hit ;

assign debug_in.halt_valid=debug_halt_i;
assign debug_in.change_pc_addr={24'b0,IO_FETCH_PC_VALUE};
assign debug_in.change_pc_valid=IO_FETCH_PC_UPDATE;
assign debug_in.reg_read_valid=IO_REG_READ;
assign debug_in.reg_read_write_addr=IO_REG_ADDR;
assign debug_in.reg_write_valid=IO_REG_WRITE;
assign debug_in.reg_write_data=IO_REG_WRITE_DATA;
assign debug_in.reg_p_read_valid=IO_REG_PREAD;
assign debug_in.reg_read_write_paddr=IO_REG_PADDR;
    
assign IO_FETCH_PC=debug_out.pc_fetch;
assign IO_DEC_PC=debug_out.pc_dec;
assign IO_RR_PC=debug_out.pc_rr;
assign IO_EXE_PC=debug_out.pc_exe;
assign IO_WB_PC=debug_out.pc_wb;
assign IO_WB_PC_VALID=debug_out.wb_valid_1;
assign IO_WB_ADDR=debug_out.wb_reg_addr_1;
assign IO_WB_WE=debug_out.wb_reg_we_1;
assign IO_REG_READ_DATA=debug_out.reg_read_data;
assign IO_REG_LIST_PADDR=debug_out.reg_list_paddr;
assign IO_REG_BACKEND_EMPTY=debug_out.reg_backend_empty;

// Register to save the last access to memory 
always @(posedge CLK, negedge RST) begin
    if(~RST)
        dcache_addr <= 0;
    else
        dcache_addr <= DMEM_REQ_BITS_ADDR;
end

assign IO_WB_BITS_ADDR = {24'b0,dcache_addr};

assign resp_csr_interface_datapath.csr_rw_rdata = CSR_RW_RDATA;
// NOTE:resp_csr_interface_datapath.csr_replay is a "ready" signal that indicate
// that the CSR are not blocked. In the implementation, since we only have one 
// inorder core any access to the CSR/PCR will be available. In multicore
// scenarios or higher performance cores you may need csr_replay.
assign resp_csr_interface_datapath.csr_replay = 1'b0; 
assign resp_csr_interface_datapath.csr_stall = CSR_CSR_STALL;
assign resp_csr_interface_datapath.csr_exception = CSR_XCPT;
assign resp_csr_interface_datapath.csr_exception_cause = CSR_XCPT_CAUSE;
assign resp_csr_interface_datapath.csr_tval = CSR_TVAL;
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
assign csr_fp_status_o  = req_datapath_csr_interface.fp_status;
assign csr_fp_status_valid_o  = req_datapath_csr_interface.csr_retire;


//L2 Network conection - response
assign ifill_resp.data  = io_mem_grant_bits_data             ;  
assign ifill_resp.beat  = io_mem_grant_bits_addr_beat        ;
assign ifill_resp.valid = io_mem_grant_valid                 ;
assign ifill_resp.ack   = io_mem_grant_bits_addr_beat[0] &
                          io_mem_grant_bits_addr_beat[1] ;

//L2 Network conection - request
assign io_mem_acquire_valid                = ifill_req.valid        ;
assign io_mem_acquire_bits_addr_block      = ifill_req.paddr        ;
assign io_mem_acquire_bits_client_xact_id  =   1'b0                 ;
assign io_mem_acquire_bits_addr_beat       =   2'b0                 ;
assign io_mem_acquire_bits_data            = 127'b0                 ;
assign io_mem_acquire_bits_is_builtin_type =   1'b1                 ;
assign io_mem_acquire_bits_a_type          =   3'b001               ;
assign io_mem_acquire_bits_union           =  17'b00000000111000001 ;
assign io_mem_grant_ready                  =   1'b1                 ;

//TLB conection
assign itlb_tresp.miss   = TLB_RESP_MISS     ;
assign itlb_tresp.ptw_v  = iptw_resp_valid_i ;
assign itlb_tresp.ppn    = itlb_resp_ppn_i   ;
assign itlb_tresp.xcpt   = TLB_RESP_XCPT_IF  ;
assign TLB_REQ_BITS_VPN  = itlb_treq.vpn     ;
assign TLB_REQ_VALID     = itlb_treq.valid   ;

//-- PMU conection
assign io_core_pmu_icache_req       = lagarto_ireq.valid                    ; 
assign io_core_pmu_icache_kill      = lagarto_ireq.kill                     ;
assign io_core_pmu_stall_if         = pmu_flags.stall_if                    ;  
assign io_core_pmu_stall_id         = pmu_flags.stall_id                    ; 
assign io_core_pmu_stall_rr         = pmu_flags.stall_rr                    ; 
assign io_core_pmu_stall_exe        = pmu_flags.stall_exe                   ; 
assign io_core_pmu_stall_wb         = pmu_flags.stall_wb                    ; 
assign io_core_pmu_branch_miss      = pmu_flags.branch_miss                 ; 
assign io_core_pmu_is_branch        = pmu_flags.is_branch                   ; 
assign io_core_pmu_branch_taken     = pmu_flags.branch_taken                ; 
assign io_core_pmu_load_store       = pmu_flags.load_store                  ;
assign io_core_pmu_data_depend      = pmu_flags.data_depend                 ;
assign io_core_pmu_struct_depend    = pmu_flags.struct_depend               ;
assign io_core_pmu_grad_list_full   = pmu_flags.grad_list_full              ;
assign io_core_pmu_free_list_empty  = pmu_flags.free_list_empty             ;
assign io_core_pmu_new_instruction  = req_datapath_csr_interface.csr_retire ;
assign io_core_pmu_buffer_miss      = imiss_l2_hit                          ;
assign io_core_pmu_imiss_time       = imiss_time_pmu                        ;
assign io_core_pmu_imiss_kill       = imiss_kill_pmu                        ;
assign io_core_pmu_icache_bussy     = !icache_resp.ready                    ;

sew_t sew;
assign sew = sew_t'(csr_vpu_data_i[37:36]);

datapath datapath_inst(
    .clk_i(CLK),
    .rstn_i(RST),
    .reset_addr_i(RESET_ADDRESS),
    // Input datapath
    .soft_rstn_i(SOFT_RST),
    .resp_icache_cpu_i(resp_icache_interface_datapath), 
    .resp_dcache_cpu_i(resp_dcache_interface_datapath), 
    .resp_csr_cpu_i(resp_csr_interface_datapath),
    .sew_i(sew),//.sew_i(CSR_SEW),
    .en_translation_i( en_translation_i ), 
    .debug_i(debug_in),
    .req_icache_ready_i(req_icache_ready),
    // Output datapath
    .req_cpu_dcache_o(req_datapath_dcache_interface),
    .req_cpu_icache_o(req_datapath_icache_interface),
    .req_cpu_csr_o(req_datapath_csr_interface),
    .debug_o(debug_out),
    .csr_priv_lvl_i(csr_priv_lvl_i),
    .csr_frm_i(csr_frm_i),
    .en_ld_st_translation_i(en_ld_st_translation_i),
    //PMU                                                   
    .pmu_flags_o        (pmu_flags)
);

icache_interface icache_interface_inst(
    .clk_i(CLK),
    .rstn_i(RST),

    // Inputs ICache
    .icache_resp_datablock_i    ( icache_resp.data  ),
    .icache_resp_vaddr_i        ( icache_resp.vaddr ), 
    .icache_resp_valid_i        ( icache_resp.valid ),
    .icache_req_ready_i         ( icache_resp.ready ), 
    .tlb_resp_xcp_if_i          ( icache_resp.xcpt  ),
    .en_translation_i           ( en_translation_i ), 
    .csr_spi_config_i           ( csr_spi_config_i  ), 
   
    // Outputs ICache
    .icache_invalidate_o    ( iflush             ), 
    .icache_req_bits_idx_o  ( lagarto_ireq.idx   ), 
    .icache_req_kill_o      ( lagarto_ireq.kill  ), 
    .icache_req_valid_o     ( lagarto_ireq.valid ),
    .icache_req_bits_vpn_o  ( lagarto_ireq.vpn   ), 

    // Inputs Bootrom
    .brom_ready_i           ( brom_ready_i      ),
    .brom_resp_data_i       ( brom_resp_data_i  ), 
    .brom_resp_valid_i      ( brom_resp_valid_i ),

    // Outputs Bootrom
    .brom_req_address_o     ( brom_req_address_o ),
    .brom_req_valid_o       ( brom_req_valid_o   ),

    // Fetch stage interface - Request packet from fetch_stage
    .req_fetch_icache_i(req_datapath_icache_interface),
    
    // Fetch stage interface - Response packet icache to fetch
    .resp_icache_fetch_o(resp_icache_interface_datapath),
    .req_fetch_ready_o(req_icache_ready),
    //PMU
    .buffer_miss_o (buffer_miss )
);

dcache_interface dcache_interface_inst(
    .clk_i(CLK),
    .rstn_i(RST),

    .req_cpu_dcache_i(req_datapath_dcache_interface),
    .en_ld_st_translation_i(en_ld_st_translation_i),

    // DCACHE Answer
    .dmem_resp_replay_i(DMEM_RESP_BITS_REPLAY),
    .dmem_resp_data_i(DMEM_RESP_BITS_DATA_SUBW),
    .dmem_req_ready_i(DMEM_REQ_READY),
    .dmem_resp_valid_i(DMEM_RESP_VALID),
    .dmem_resp_tag_i(DMEM_RESP_TAG),
    .dmem_resp_nack_i(DMEM_RESP_BITS_NACK),
    .dmem_resp_has_data_i(DMEM_RESP_BITS_HAS_DATA),
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

    // PMU
    .dmem_is_store_o ( io_core_pmu_EXE_STORE ),
    .dmem_is_load_o  ( io_core_pmu_EXE_LOAD  ),
    
    // DCACHE Answer to cpu
    .resp_dcache_cpu_o(resp_dcache_interface_datapath) 
);


top_icache icache (
    .clk_i              ( CLK           ) ,
    .rstn_i             ( RST           ) ,
    .flush_i            ( iflush        ) , 
    .lagarto_ireq_i     ( lagarto_ireq  ) , //- From Lagarto.
    .icache_resp_o      ( icache_resp   ) , //- To Lagarto.
    .mmu_tresp_i        ( itlb_tresp    ) , //- From MMU.
    .icache_treq_o      ( itlb_treq     ) , //- To MMU.
    .ifill_resp_i       ( ifill_resp    ) , //- From upper levels.
    .icache_ifill_req_o ( ifill_req     ) ,  //- To upper levels. 
    .imiss_time_pmu_o    ( imiss_time_pmu ) ,
    .imiss_kill_pmu_o    ( imiss_kill_pmu )
);

//PMU  
assign imiss_l2_hit = ifill_resp.ack & io_core_pmu_l2_hit_i; 


endmodule
