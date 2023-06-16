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
    import drac_pkg::*, sargantana_icache_pkg::*, mmu_pkg::*, hpdcache_pkg::*;
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

    // *** Miss-read Interface ***

    input logic                   mem_req_miss_read_ready_i,
    input hpdcache_mem_id_t       mem_req_miss_read_base_id_i,
    output logic                  mem_req_miss_read_valid_o,
    output hpdcache_mem_addr_t    mem_req_addr_o,
    output hpdcache_mem_len_t     mem_req_len_o,
    output hpdcache_mem_size_t    mem_req_size_o,
    output hpdcache_mem_id_t      mem_req_id_o,

    input logic                   mem_resp_miss_read_valid_i,
    input hpdcache_mem_error_e    mem_resp_r_error_i,
    input hpdcache_mem_id_t       mem_resp_r_id_i,
    input hpdcache_mem_data_t     mem_resp_r_data_i,
    input logic                   mem_resp_r_last_i,
    output logic                  mem_resp_miss_read_ready_o,

    // *** Writeback Interface ***

    input  logic                  mem_req_wbuf_write_ready_i,
    output logic                  mem_req_wbuf_write_valid_o,
    output hpdcache_mem_addr_t    mem_req_wbuf_write_addr_o,
    output hpdcache_mem_len_t     mem_req_wbuf_write_len_o,
    output hpdcache_mem_size_t    mem_req_wbuf_write_size_o,
    output hpdcache_mem_id_t      mem_req_wbuf_write_id_o,
    input  hpdcache_mem_id_t      mem_req_wbuf_write_base_id_i,

    input  logic                  mem_req_wbuf_write_data_ready_i,
    output logic                  mem_req_wbuf_write_data_valid_o,
    output hpdcache_mem_data_t    mem_req_wbuf_write_data_o,
    output hpdcache_mem_be_t      mem_req_wbuf_write_be_o,
    output logic                  mem_req_wbuf_write_last_o,

    output logic                  mem_resp_wbuf_write_ready_o,
    input  logic                  mem_resp_wbuf_write_valid_i,
    input  hpdcache_mem_error_e   mem_resp_wbuf_write_error_i,
    input  hpdcache_mem_id_t      mem_resp_wbuf_write_id_i,

    // *** Uncacheable Writeback Interface ***

    input  logic                  mem_req_uc_write_ready_i,
    output logic                  mem_req_uc_write_valid_o,
    output hpdcache_mem_addr_t    mem_req_uc_write_addr_o,
    output hpdcache_mem_len_t     mem_req_uc_write_len_o,
    output hpdcache_mem_size_t    mem_req_uc_write_size_o,
    output hpdcache_mem_id_t      mem_req_uc_write_id_o,
    output hpdcache_mem_command_e mem_req_uc_write_command_o,
    output hpdcache_mem_atomic_e  mem_req_uc_write_atomic_o,
    input  hpdcache_mem_id_t      mem_req_uc_write_base_id_i,

    input  logic                  mem_req_uc_write_data_ready_i,
    output logic                  mem_req_uc_write_data_valid_o,
    output hpdcache_mem_data_t    mem_req_uc_write_data_o,
    output hpdcache_mem_be_t      mem_req_uc_write_be_o,
    output logic                  mem_req_uc_write_last_o,

    output logic                  mem_resp_uc_write_ready_o,
    input  logic                  mem_resp_uc_write_valid_i,
    input  logic                  mem_resp_uc_write_is_atomic_i,
    input  hpdcache_mem_error_e   mem_resp_uc_write_error_i,
    input  hpdcache_mem_id_t      mem_resp_uc_write_id_i,

    // *** Uncacheable Read Interface ***

    input  logic                  mem_req_uc_read_ready_i,
    output logic                  mem_req_uc_read_valid_o,
    output hpdcache_mem_addr_t    mem_req_uc_read_addr_o,
    output hpdcache_mem_len_t     mem_req_uc_read_len_o,
    output hpdcache_mem_size_t    mem_req_uc_read_size_o,
    output hpdcache_mem_id_t      mem_req_uc_read_id_o,
    output hpdcache_mem_command_e mem_req_uc_read_command_o,
    output hpdcache_mem_atomic_e  mem_req_uc_read_atomic_o,
    input  hpdcache_mem_id_t      mem_req_uc_read_base_id_i,

    input logic                   mem_resp_uc_read_valid_i,
    input hpdcache_mem_error_e    mem_resp_uc_read_error_i,
    input hpdcache_mem_id_t       mem_resp_uc_read_id_i,
    input hpdcache_mem_data_t     mem_resp_uc_read_data_i,
    input logic                   mem_resp_uc_read_last_i,
    output logic                  mem_resp_uc_read_ready_o,


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

localparam NREQUESTERS = 2;

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
logic [1:0] csr_priv_lvl, ld_st_priv_lvl;
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
logic exe_store_pmu ;
logic exe_load_pmu  ;

logic [CSR_ADDR_SIZE-1:0] addr_csr_hpm;
logic [63:0]              data_csr_hpm, data_hpm_csr;
logic                     we_csr_hpm;

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
        dcache_addr <= mem_req_addr_o;
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

//-- HPM conection

logic pmu_itlb_access;
logic pmu_itlb_miss;
logic pmu_dtlb_access;
logic pmu_dtlb_miss;
logic pmu_ptw_hit;
logic pmu_ptw_miss;
logic pmu_itlb_miss_cycle;

hpm_counters hpm_counters_inst (
    .clk_i(CLK),
    .rstn_i(RST),

    // Access interface
    .addr_i(addr_csr_hpm),
    .we_i(we_csr_hpm),
    .data_i(data_csr_hpm),
    .data_o(data_hpm_csr),

    // Events
    .branch_miss_i(pmu_flags.branch_miss),
    .is_branch_i(pmu_flags.is_branch),
    .branch_taken_i(pmu_flags.branch_taken),
    .exe_store_i(exe_store_pmu),
    .exe_load_i(exe_load_pmu),
    .icache_req_i(lagarto_ireq.valid),
    .icache_kill_i(lagarto_ireq.kill),
    .stall_if_i(pmu_flags.stall_if),
    .stall_id_i(pmu_flags.stall_id),
    .stall_rr_i(pmu_flags.stall_rr),
    .stall_exe_i(pmu_flags.stall_exe),
    .stall_wb_i(pmu_flags.stall_wb ),
    .buffer_miss_i(imiss_l2_hit),
    .imiss_kill_i(imiss_kill_pmu),
    .icache_bussy_i(!icache_resp.ready ),
    .imiss_time_i(imiss_time_pmu),
    .load_store_i(pmu_flags.load_store ),
    .data_depend_i(pmu_flags.data_depend),
    .struct_depend_i(pmu_flags.struct_depend),
    .grad_list_full_i(pmu_flags.grad_list_full),
    .free_list_empty_i(pmu_flags.free_list_empty),
    .itlb_access_i(pmu_itlb_access),
    .itlb_miss_i(pmu_itlb_miss),
    .dtlb_access_i(pmu_dtlb_access),
    .dtlb_miss_i(pmu_dtlb_miss),
    .ptw_hit_i(pmu_ptw_hit),
    .ptw_miss_i(pmu_ptw_miss),
    .itlb_miss_cycle_i(pmu_itlb_miss_cycle)
);

assign pmu_itlb_miss_cycle = itlb_icache_comm.resp.miss && !itlb_icache_comm.tlb_ready;

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
    .csr_priv_lvl_i(ld_st_priv_lvl),
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

// Core-dCache Interface
logic          dcache_req_valid [NREQUESTERS-1:0];
logic          dcache_req_ready [NREQUESTERS-1:0];
hpdcache_req_t dcache_req       [NREQUESTERS-1:0];

logic          dcache_rsp_valid [NREQUESTERS-1:0];
hpdcache_rsp_t dcache_rsp       [NREQUESTERS-1:0];
logic wbuf_empty;

dcache_interface dcache_interface_inst(
    .clk_i(CLK),
    .rstn_i(RST),

    .en_ld_st_translation_i(en_ld_st_translation_i),

    // CPU Interface
    .req_cpu_dcache_i(req_datapath_dcache_interface),
    .resp_dcache_cpu_o(resp_dcache_interface_datapath),

    // dCache Interface
    .dcache_ready_i(dcache_req_ready[1]),
    .dcache_valid_i(dcache_rsp_valid[1]),
    .core_req_valid_o(dcache_req_valid[1]),
    .req_dcache_o(dcache_req[1]),
    .rsp_dcache_i(dcache_rsp[1]),
    .wbuf_empty_i(wbuf_empty),

    // PMU
    .dmem_is_store_o ( exe_store_pmu ),
    .dmem_is_load_o  ( exe_load_pmu  )
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

// *** dCache-memory interface ***

//      Miss read interface
hpdcache_mem_req_t             mem_req_miss_read;

assign mem_req_addr_o = mem_req_miss_read.mem_req_addr;
assign mem_req_len_o  = mem_req_miss_read.mem_req_len;
assign mem_req_size_o = mem_req_miss_read.mem_req_size;
assign mem_req_id_o   = mem_req_miss_read.mem_req_id;

hpdcache_mem_resp_r_t          mem_resp_miss_read;

assign mem_resp_miss_read.mem_resp_r_error = mem_resp_r_error_i;
assign mem_resp_miss_read.mem_resp_r_id = mem_resp_r_id_i;
assign mem_resp_miss_read.mem_resp_r_data = mem_resp_r_data_i;
assign mem_resp_miss_read.mem_resp_r_last = mem_resp_r_last_i;

//      Write-buffer write interface
hpdcache_mem_req_t    mem_req_wbuf_write;

assign mem_req_wbuf_write_addr_o = mem_req_wbuf_write.mem_req_addr;
assign mem_req_wbuf_write_len_o  = mem_req_wbuf_write.mem_req_len;
assign mem_req_wbuf_write_size_o = mem_req_wbuf_write.mem_req_size;
assign mem_req_wbuf_write_id_o   = mem_req_wbuf_write.mem_req_id;

hpdcache_mem_req_w_t  mem_req_wbuf_write_data;

assign mem_req_wbuf_write_data_o = mem_req_wbuf_write_data.mem_req_w_data;
assign mem_req_wbuf_write_be_o   = mem_req_wbuf_write_data.mem_req_w_be;
assign mem_req_wbuf_write_last_o = mem_req_wbuf_write_data.mem_req_w_last;

hpdcache_mem_resp_w_t mem_resp_wbuf_write;

assign mem_resp_wbuf_write.mem_resp_w_error = mem_resp_wbuf_write_error_i;
assign mem_resp_wbuf_write.mem_resp_w_id = mem_resp_wbuf_write_id_i;
assign mem_resp_wbuf_write.mem_resp_w_is_atomic = 1'b0;

//      Uncacheable write interface
hpdcache_mem_req_t    mem_req_uc_write;

assign mem_req_uc_write_addr_o    = mem_req_uc_write.mem_req_addr;
assign mem_req_uc_write_len_o     = mem_req_uc_write.mem_req_len;
assign mem_req_uc_write_size_o    = mem_req_uc_write.mem_req_size;
assign mem_req_uc_write_id_o      = mem_req_uc_write.mem_req_id;
assign mem_req_uc_write_command_o = mem_req_uc_write.mem_req_command;
assign mem_req_uc_write_atomic_o  = mem_req_uc_write.mem_req_atomic;

hpdcache_mem_req_w_t  mem_req_uc_write_data;

assign mem_req_uc_write_data_o = mem_req_uc_write_data.mem_req_w_data;
assign mem_req_uc_write_be_o   = mem_req_uc_write_data.mem_req_w_be;
assign mem_req_uc_write_last_o = mem_req_uc_write_data.mem_req_w_last;

hpdcache_mem_resp_w_t mem_resp_uc_write;

assign mem_resp_uc_write.mem_resp_w_error = mem_resp_uc_write_error_i;
assign mem_resp_uc_write.mem_resp_w_id = mem_resp_uc_write_id_i;
assign mem_resp_uc_write.mem_resp_w_is_atomic = mem_resp_uc_write_is_atomic_i;

//      Uncacheable read interface
hpdcache_mem_req_t mem_req_uc_read;

assign mem_req_uc_read_addr_o    = mem_req_uc_read.mem_req_addr;
assign mem_req_uc_read_len_o     = mem_req_uc_read.mem_req_len;
assign mem_req_uc_read_size_o    = mem_req_uc_read.mem_req_size;
assign mem_req_uc_read_id_o      = mem_req_uc_read.mem_req_id;
assign mem_req_uc_read_command_o = mem_req_uc_read.mem_req_command;
assign mem_req_uc_read_atomic_o  = mem_req_uc_read.mem_req_atomic;

hpdcache_mem_resp_r_t mem_resp_uc_read;

assign mem_resp_uc_read.mem_resp_r_error = mem_resp_uc_read_error_i;
assign mem_resp_uc_read.mem_resp_r_id    = mem_resp_uc_read_id_i;
assign mem_resp_uc_read.mem_resp_r_data  = mem_resp_uc_read_data_i;
assign mem_resp_uc_read.mem_resp_r_last  = mem_resp_uc_read_last_i;

hpdcache #(.NREQUESTERS(NREQUESTERS)) dcache (
    .clk_i(CLK),
    .rst_ni(RST),

    // Core interface
    .core_req_valid_i(dcache_req_valid),
    .core_req_ready_o(dcache_req_ready),
    .core_req_i(dcache_req),
    .core_rsp_valid_o(dcache_rsp_valid),
    .core_rsp_o(dcache_rsp),

    // dMem miss-read interface
    .mem_req_miss_read_ready_i(mem_req_miss_read_ready_i),
    .mem_req_miss_read_valid_o(mem_req_miss_read_valid_o),
    .mem_req_miss_read_o(mem_req_miss_read),
    .mem_req_miss_read_base_id_i(mem_req_miss_read_base_id_i),

    .mem_resp_miss_read_ready_o(mem_resp_miss_read_ready_o),
    .mem_resp_miss_read_valid_i(mem_resp_miss_read_valid_i),
    .mem_resp_miss_read_i(mem_resp_miss_read),

    // dMem writeback interface
    .mem_req_wbuf_write_ready_i(mem_req_wbuf_write_ready_i),
    .mem_req_wbuf_write_valid_o(mem_req_wbuf_write_valid_o),
    .mem_req_wbuf_write_o(mem_req_wbuf_write),
    .mem_req_wbuf_write_base_id_i(mem_req_wbuf_write_base_id_i),

    .mem_req_wbuf_write_data_ready_i(mem_req_wbuf_write_data_ready_i),
    .mem_req_wbuf_write_data_valid_o(mem_req_wbuf_write_data_valid_o),
    .mem_req_wbuf_write_data_o(mem_req_wbuf_write_data),

    .mem_resp_wbuf_write_ready_o(mem_resp_wbuf_write_ready_o),
    .mem_resp_wbuf_write_valid_i(mem_resp_wbuf_write_valid_i),
    .mem_resp_wbuf_write_i(mem_resp_wbuf_write),

    // dMem uncacheable write interface
    .mem_req_uc_write_ready_i(mem_req_uc_write_ready_i),
    .mem_req_uc_write_valid_o(mem_req_uc_write_valid_o),
    .mem_req_uc_write_o(mem_req_uc_write),
    .mem_req_uc_write_base_id_i(mem_req_uc_write_base_id_i),

    .mem_req_uc_write_data_ready_i(mem_req_uc_write_data_ready_i),
    .mem_req_uc_write_data_valid_o(mem_req_uc_write_data_valid_o),
    .mem_req_uc_write_data_o(mem_req_uc_write_data),

    .mem_resp_uc_write_ready_o(mem_resp_uc_write_ready_o),
    .mem_resp_uc_write_valid_i(mem_resp_uc_write_valid_i),
    .mem_resp_uc_write_i(mem_resp_uc_write),

    // dMem uncacheable read interface
    .mem_req_uc_read_ready_i(mem_req_uc_read_ready_i),
    .mem_req_uc_read_valid_o(mem_req_uc_read_valid_o),
    .mem_req_uc_read_o(mem_req_uc_read),
    .mem_req_uc_read_base_id_i(mem_req_uc_read_base_id_i),

    .mem_resp_uc_read_ready_o(mem_resp_uc_read_ready_o),
    .mem_resp_uc_read_valid_i(mem_resp_uc_read_valid_i),
    .mem_resp_uc_read_i(mem_resp_uc_read),

    // misc
    .wbuf_empty_o(wbuf_empty),

    // Config
    .cfg_enable_i(1'b1),
    .cfg_wbuf_threshold_i(4'd2),
    .cfg_wbuf_reset_timecnt_on_write_i(1'b1),
    .cfg_wbuf_sequential_waw_i(1'b0),
    .cfg_prefetch_updt_plru_i(1'b1),
    .cfg_error_on_cacheable_amo_i(1'b0),
    .cfg_rtab_single_entry_i(1'b0)
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
    .ld_st_priv_lvl_o(ld_st_priv_lvl),
    .en_ld_st_translation_o(en_ld_st_translation),
    .en_translation_o(en_translation),

    .satp_ppn_o(csr_satp),                 // Page table base pointer for the PTW

    .evec_o(csr_evec),                      // virtual address of the PC to execute after a Interrupt or exception

    .flush_o(tlb_flush),                    // the core is executing a sfence.vm instruction and a tlb flush is needed
    .vpu_csr_o(vpu_csr),

    .perf_addr_o(addr_csr_hpm),                // read/write address to performance counter module
    .perf_data_o(data_csr_hpm),                // write data to performance counter module
    .perf_data_i(data_hpm_csr),                // read data from performance counter module
    .perf_we_o(we_csr_hpm)
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

// Connect PTW to dcache
assign dcache_req_valid[0] = ptw_dmem_comm.req.valid;
assign dmem_ptw_comm.dmem_ready = dcache_req_ready[0];
assign dcache_req[0].addr = ptw_dmem_comm.req.addr;
assign dcache_req[0].wdata = ptw_dmem_comm.req.data;
assign dcache_req[0].op = ptw_dmem_comm.req.cmd == 5'b01010 ? HPDCACHE_REQ_AMO_OR : HPDCACHE_REQ_LOAD;
assign dcache_req[0].be = ptw_dmem_comm.req.cmd == 5'b01010 ? 8'hff : 8'h00;
assign dcache_req[0].size = ptw_dmem_comm.req.typ;
assign dcache_req[0].uncacheable = 1'b0;
assign dcache_req[0].sid = 0;
assign dcache_req[0].tid = 0;
assign dcache_req[0].need_rsp = 1'b1;

assign dmem_ptw_comm.resp.valid = dcache_rsp_valid[0];
assign dmem_ptw_comm.resp.data = dcache_rsp[0].rdata; //TODO: Shift

//PMU  
assign imiss_l2_hit = ifill_resp.ack & io_core_pmu_l2_hit_i; 


endmodule
