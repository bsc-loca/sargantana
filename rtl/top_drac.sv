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

module top_drac
    import drac_pkg::*, sargantana_icache_pkg::*, mmu_pkg::*;
(
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
// I-CANCHE INPUT INTERFACE
//------------------------------------------------------------------------------------
    
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
    input logic                 DMEM_ORDERED, // TODO: remove if we dont used

//-----------------------------------------------------------------------------------
// I-CACHE OUTPUT INTERFACE
//-----------------------------------------------------------------------------------

    //- To L2
    output logic         io_mem_acquire_valid               ,
    output logic [BLOCK_ADDR_SIZE-1:0] io_mem_acquire_bits_addr_block,
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
    output logic                io_core_pmu_itlb_access,
    output logic                io_core_pmu_itlb_miss,
    output logic                io_core_pmu_dtlb_access,
    output logic                io_core_pmu_dtlb_miss,
    output logic                io_core_pmu_ptw_hit,
    output logic                io_core_pmu_ptw_miss,
    output logic                io_core_pmu_itlb_miss_cycle,

//-----------------------------------------------------------------------------
// BOOTROM CONTROLER INTERFACE
//-----------------------------------------------------------------------------
    input  logic                brom_ready_i        ,
    input  logic [31:0]         brom_resp_data_i    ,
    input  logic                brom_resp_valid_i   ,
    output logic [23:0]         brom_req_address_o  ,
    output logic                brom_req_valid_o    ,
   
    input logic                 csr_spi_config_i,

//-----------------------------------------------------------------------------
// INTERRUPTS
//-----------------------------------------------------------------------------
    input logic                 time_irq_i, // timer interrupt
    input logic                 irq_i,      // external interrupt in
    input  logic [63:0]         time_i,     // time passed since the core is reset

//-----------------------------------------------------------------------------
// PCR
//-----------------------------------------------------------------------------
    //PCR req inputs
    input  logic                pcr_req_ready_i,    // ready bit of the pcr

    //PCR resp inputs
    input  logic                pcr_resp_valid_i,   // ready bit of the pcr
    input  logic [63:0]         pcr_resp_data_i,    // read data from performance counter module
    input  logic                pcr_resp_core_id_i, // core id of the tile that the date is sended

    //PCR outputs request
    output logic                pcr_req_valid_o,    // valid bit to make a pcr request
    output logic  [11:0]        pcr_req_addr_o,     // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    output logic  [63:0]        pcr_req_data_o,     // write data to performance counter module
    output logic  [2:0]         pcr_req_we_o,       // Cmd of the petition
    output logic                pcr_req_core_id_o   // core id of the tile

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
logic [1:0] csr_priv_lvl;
logic [2:0] fcsr_rm;
logic [1:0] fcsr_fs;
logic en_ld_st_translation;
logic en_translation;
logic [39:0] vpu_csr;

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
 
// Request Datapath to CSR
req_cpu_csr_t req_datapath_csr_interface;

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

// *** Memory Management Unit ***

// Page Table Walker - iTLB/dTLB - dCache Connections
tlb_ptw_comm_t itlb_ptw_comm, dtlb_ptw_comm;
ptw_tlb_comm_t ptw_itlb_comm, ptw_dtlb_comm;
ptw_dmem_comm_t ptw_dmem_comm;
dmem_ptw_comm_t dmem_ptw_comm;

csr_ptw_comm_t csr_ptw_comm;
logic [31:0] csr_satp;
assign csr_ptw_comm.satp = {32'b0, csr_satp}; // PTW expects 64 bits

// Page Table Walker - iCache/dCache Connections

cache_tlb_comm_t icache_itlb_comm, core_dtlb_comm;
tlb_cache_comm_t itlb_icache_comm, dtlb_core_comm;

assign icache_itlb_comm.req.valid = itlb_treq.valid;
assign icache_itlb_comm.req.asid = 1'b0;
assign icache_itlb_comm.req.vpn = itlb_treq.vpn;
assign icache_itlb_comm.req.passthrough = 1'b0;
assign icache_itlb_comm.req.instruction = 1'b1;
assign icache_itlb_comm.req.store = 1'b0;
assign icache_itlb_comm.priv_lvl = csr_priv_lvl;
assign icache_itlb_comm.vm_enable = en_translation;

assign itlb_tresp.miss   = itlb_icache_comm.resp.miss;
assign itlb_tresp.ptw_v  = ptw_itlb_comm.resp.valid;
assign itlb_tresp.ppn    = itlb_icache_comm.resp.ppn;
assign itlb_tresp.xcpt   = itlb_icache_comm.resp.xcpt.fetch;

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
assign io_core_pmu_itlb_miss_cycle = itlb_icache_comm.resp.miss && !itlb_icache_comm.tlb_ready;

sew_t sew;
assign sew = sew_t'(vpu_csr[37:36]);

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
    .en_translation_i( en_translation ), 
    .debug_i(debug_in),
    .req_icache_ready_i(req_icache_ready),
    .dtlb_comm_i(dtlb_core_comm),
    // Output datapath
    .req_cpu_dcache_o(req_datapath_dcache_interface),
    .req_cpu_icache_o(req_datapath_icache_interface),
    .req_cpu_csr_o(req_datapath_csr_interface),
    .debug_o(debug_out),
    .csr_priv_lvl_i(csr_priv_lvl),
    .csr_frm_i(fcsr_rm),
    .csr_fs_i(fcsr_fs),
    .en_ld_st_translation_i(en_ld_st_translation),
    .dtlb_comm_o(core_dtlb_comm),
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
    .en_translation_i           ( en_translation ), 
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

// DCACHE Answer
logic        datapath_resp_replay;  // Miss ready
bus_simd_t   datapath_resp_data;    // Readed data from Cache
logic        datapath_req_ready;    // Dcache ready to accept request
logic        datapath_resp_valid;   // Response is valid
logic [7:0]  datapath_resp_tag;     // Tag 
logic        datapath_resp_nack;    // Cache request not accepted
logic        datapath_resp_has_data;// Dcache response contains data
logic        datapath_ordered;

// Request TO DCACHE

logic        datapath_req_valid;    // Sending valid request
logic [4:0]  datapath_req_cmd;      // Type of memory access
addr_t       datapath_req_addr;     // Address of memory access
logic [3:0]  datapath_op_type;      // Granularity of memory access
bus_simd_t   datapath_req_data;     // Data to store
logic [7:0]  datapath_req_tag;      // Tag for the MSHR
logic        datapath_req_invalidate_lr; // Reset load-reserved/store-conditional
logic        datapath_req_kill;     // Kill actual memory access

dcache_interface dcache_interface_inst(
    .clk_i(CLK),
    .rstn_i(RST),

    .req_cpu_dcache_i(req_datapath_dcache_interface),
    .en_ld_st_translation_i(en_ld_st_translation_i),

    // DCACHE Answer
    .dmem_resp_replay_i(datapath_resp_replay),  // Miss ready
    .dmem_resp_data_i(datapath_resp_data),    // Readed data from Cache
    .dmem_req_ready_i(datapath_req_ready),    // Dcache ready to accept request
    .dmem_resp_valid_i(datapath_resp_valid),   // Response is valid
    .dmem_resp_tag_i(datapath_resp_tag),     // Tag 
    .dmem_resp_nack_i(datapath_resp_nack),    // Cache request not accepted
    .dmem_resp_has_data_i(datapath_resp_has_data),// Dcache response contains data
    .dmem_ordered_i(datapath_ordered),

    // Request TO DCACHE

    .dmem_req_valid_o(datapath_req_valid),    // Sending valid request
    .dmem_req_cmd_o(datapath_req_cmd),      // Type of memory access
    .dmem_req_addr_o(datapath_req_addr),     // Address of memory access
    .dmem_op_type_o(datapath_op_type),      // Granularity of memory access
    .dmem_req_data_o(datapath_req_data),     // Data to store
    .dmem_req_tag_o(datapath_req_tag),      // Tag for the MSHR
    .dmem_req_invalidate_lr_o(datapath_req_invalidate_lr), // Reset load-reserved/store-conditional
    .dmem_req_kill_o(datapath_req_kill),     // Kill actual memory access

    // PMU
    .dmem_is_store_o ( io_core_pmu_EXE_STORE ),
    .dmem_is_load_o  ( io_core_pmu_EXE_LOAD  ),
    
    // DCACHE Answer to cpu
    .resp_dcache_cpu_o(resp_dcache_interface_datapath) 
);


sargantana_top_icache icache (
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

// NOTE:resp_csr_interface_datapath.csr_replay is a "ready" signal that indicate
// that the CSR are not blocked. In the implementation, since we only have one 
// inorder core any access to the CSR/PCR will be available. In multicore
// scenarios or higher performance cores you may need csr_replay.

bus64_t csr_evec;
assign resp_csr_interface_datapath.csr_evec = {{25{csr_evec[39]}},csr_evec[38:0]};

csr_bsc csr_inst (
    .clk_i(CLK),
    .rstn_i(RST),
    .rw_addr_i(req_datapath_csr_interface.csr_rw_addr),                  //read and write address form the core
    .rw_cmd_i(req_datapath_csr_interface.csr_rw_cmd),                   //specific operation to execute from the core 
    .w_data_core_i(req_datapath_csr_interface.csr_rw_data),              //write data from the core
    .r_data_core_o(resp_csr_interface_datapath.csr_rw_rdata),              // read data to the core, address specified with the rw_addr_i

    .ex_i(req_datapath_csr_interface.csr_exception),                       // exception produced in the core
    .ex_cause_i(req_datapath_csr_interface.csr_xcpt_cause),                 //cause of the exception
    .pc_i(req_datapath_csr_interface.csr_pc[39:0]),                       //pc were the exception is produced

    .retire_i(req_datapath_csr_interface.csr_retire),                   // shows if a instruction is retired from the core.
    .time_irq_i(time_irq_i),                 // timer interrupt
    .irq_i(irq_i),                      // external interrupt in
    .interrupt_o(resp_csr_interface_datapath.csr_interrupt),                // Inerruption wire to the core
    .interrupt_cause_o(resp_csr_interface_datapath.csr_interrupt_cause),          // Interruption cause

    .time_i(time_i),                    // time passed since the core is reset

    .pcr_req_ready_i(pcr_req_ready_i),            // ready bit of the pcr
    .pcr_resp_valid_i(pcr_resp_valid_i),           // ready bit of the pcr
    .pcr_resp_data_i(pcr_resp_data_i),            // read data from performance counter module
    .pcr_resp_core_id_i(pcr_resp_core_id_i),         // core id of the tile that the date is sended
    .pcr_req_valid_o(pcr_req_valid_o),            // valid bit to make a pcr request
    .pcr_req_addr_o(pcr_req_addr_o),             // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    .pcr_req_data_o(pcr_req_data_o),             // write data to performance counter module
    .pcr_req_we_o(pcr_req_we_o),               // Cmd of the petition
    .pcr_req_core_id_o(pcr_req_core_id_o),          // core id of the tile

    .fcsr_flags_valid_i(req_datapath_csr_interface.csr_retire),
    .fcsr_flags_bits_i(req_datapath_csr_interface.fp_status),
    .fcsr_rm_o(fcsr_rm),
    .fcsr_fs_o(fcsr_fs),

    .csr_replay_o(resp_csr_interface_datapath.csr_replay),               // replay send to the core because there are some parts that are bussy
    .csr_stall_o(resp_csr_interface_datapath.csr_stall),                // The csr are waiting a resp and de core is stalled
    .csr_xcpt_o(resp_csr_interface_datapath.csr_exception),                 // Exeption pproduced by the csr   
    .csr_xcpt_cause_o(resp_csr_interface_datapath.csr_exception_cause),           // Exception cause
    .csr_tval_o(resp_csr_interface_datapath.csr_tval),                 // Value written to the tval registers
    .eret_o(resp_csr_interface_datapath.csr_eret),

    .status_o(csr_ptw_comm.mstatus),                   //actual mstatus of the core
    .priv_lvl_o(csr_priv_lvl),                 // actual privialge level of the core
    //.ld_st_priv_lvl_o(),
    .en_ld_st_translation_o(en_ld_st_translation),
    .en_translation_o(en_translation),

    .satp_ppn_o(csr_satp),                 // Page table base pointer for the PTW

    .evec_o(csr_evec),                      // virtual address of the PC to execute after a Interrupt or exception

    .flush_o(csr_ptw_comm.flush),                    // the core is executing a sfence.vm instruction and a tlb flush is needed
    .vpu_csr_o(vpu_csr)
);

tlb itlb (
    .clk_i(CLK),
    .rstn_i(RST),
    .cache_tlb_comm_i(icache_itlb_comm),
    .tlb_cache_comm_o(itlb_icache_comm),
    .ptw_tlb_comm_i(ptw_itlb_comm),
    .tlb_ptw_comm_o(itlb_ptw_comm),
    .pmu_tlb_access_o(pmu_itlb_access),
    .pmu_tlb_miss_o(pmu_itlb_miss)
);

tlb dtlb (
    .clk_i(CLK),
    .rstn_i(RST),
    .cache_tlb_comm_i(core_dtlb_comm),
    .tlb_cache_comm_o(dtlb_core_comm),
    .ptw_tlb_comm_i(ptw_dtlb_comm),
    .tlb_ptw_comm_o(dtlb_ptw_comm),
    .pmu_tlb_access_o(pmu_dtlb_access),
    .pmu_tlb_miss_o(pmu_dtlb_miss)
);

ptw ptw_inst (
    .clk_i(CLK),
    .rstn_i(RST),

    // iTLB request-response
    .itlb_ptw_comm_i(itlb_ptw_comm), 
    .ptw_itlb_comm_o(ptw_itlb_comm),

    // dTLB request-response
    .dtlb_ptw_comm_i(dtlb_ptw_comm),
    .ptw_dtlb_comm_o(ptw_dtlb_comm),

    // dmem request-response
    .dmem_ptw_comm_i(dmem_ptw_comm),
    .ptw_dmem_comm_o(ptw_dmem_comm),

    // csr interface
    .csr_ptw_comm_i(csr_ptw_comm),

    // pmu interface
    .pmu_ptw_hit_o(pmu_ptw_hit),
    .pmu_ptw_miss_o(pmu_ptw_miss)
);

dmem_arbiter arbiter (
    .clk_i(CLK),
    .rstn_i(RST),
    
    // DCACHE Answer
    .datapath_resp_replay_o(datapath_resp_replay),  // Miss ready
    .datapath_resp_data_o(datapath_resp_data),    // Readed data from Cache
    .datapath_req_ready_o(datapath_req_ready),    // Dcache ready to accept request
    .datapath_resp_valid_o(datapath_resp_valid),   // Response is valid
    .datapath_resp_tag_o(datapath_resp_tag),     // Tag 
    .datapath_resp_nack_o(datapath_resp_nack),    // Cache request not accepted
    .datapath_resp_has_data_o(datapath_resp_has_data),// Dcache response contains data
    .datapath_ordered_o(datapath_ordered),

    // Request TO DCACHE

    .datapath_req_valid_i(datapath_req_valid),    // Sending valid request
    .datapath_req_cmd_i(datapath_req_cmd),      // Type of memory access
    .datapath_req_addr_i(datapath_req_addr),     // Address of memory access
    .datapath_op_type_i(datapath_op_type),      // Granularity of memory access
    .datapath_req_data_i(datapath_req_data),     // Data to store
    .datapath_req_tag_i(datapath_req_tag),      // Tag for the MSHR
    .datapath_req_invalidate_lr_i(datapath_req_invalidate_lr), // Reset load-reserved/store-conditional
    .datapath_req_kill_i(datapath_req_kill),     // Kill actual memory access

    // PTW interface
    .ptw_req_i(ptw_dmem_comm),
    .ptw_resp_o(dmem_ptw_comm),

    // DCACHE Answer
    .dmem_resp_replay_i(DMEM_RESP_BITS_REPLAY),
    .dmem_resp_data_i(DMEM_RESP_BITS_DATA_SUBW),
    .dmem_req_ready_i(DMEM_REQ_READY),
    .dmem_resp_valid_i(DMEM_RESP_VALID),
    .dmem_resp_tag_i(DMEM_RESP_TAG),
    .dmem_resp_nack_i(DMEM_RESP_BITS_NACK),
    .dmem_resp_has_data_i(DMEM_RESP_BITS_HAS_DATA),
    .dmem_ordered_i(DMEM_ORDERED),

    // Interface request
    .dmem_req_valid_o(DMEM_REQ_VALID),
    .dmem_req_cmd_o(DMEM_REQ_CMD),
    .dmem_req_addr_o(DMEM_REQ_BITS_ADDR),
    .dmem_op_type_o(DMEM_OP_TYPE),
    .dmem_req_data_o(DMEM_REQ_BITS_DATA),
    .dmem_req_tag_o(DMEM_REQ_BITS_TAG),
    .dmem_req_invalidate_lr_o(DMEM_REQ_INVALIDATE_LR),
    .dmem_req_kill_o(DMEM_REQ_BITS_KILL)
);

//PMU  
assign imiss_l2_hit = ifill_resp.ack & io_core_pmu_l2_hit_i; 


endmodule
