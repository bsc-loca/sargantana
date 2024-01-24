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
    import drac_pkg::*;
#(
    parameter drac_pkg::drac_cfg_t DracCfg     = drac_pkg::DracDefaultConfig
)(
//------------------------------------------------------------------------------------
// ORIGINAL INPUTS OF LAGARTO 
//------------------------------------------------------------------------------------
    input logic                 clk_i,
    input logic                 rstn_i,
    input logic                 soft_rstn_i,
    input addr_t                reset_addr_i,
    input logic [63:0]          core_id_i,

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
    input  [5:0]	            IO_REG_PADDR,
    input                       IO_REG_PREAD,

//------------------------------------------------------------------------------------
// I-CACHE INTERFACE
//------------------------------------------------------------------------------------
    
    input logic req_icache_ready_i,
    output req_cpu_icache_t req_cpu_icache_o,
    output logic en_translation_o,
    output logic [1:0] priv_lvl_o,
    input resp_icache_cpu_t resp_icache_cpu_i,

//----------------------------------------------------------------------------------
// D-CACHE INTERFACE
//----------------------------------------------------------------------------------

    input resp_dcache_cpu_t resp_dcache_cpu_i,
    output req_cpu_dcache_t req_cpu_dcache_o, 

//----------------------------------------------------------------------------------
// MMU INTERFACE
//----------------------------------------------------------------------------------

    output csr_ptw_comm_t csr_ptw_comm_o,
    output cache_tlb_comm_t dtlb_comm_o,
    input tlb_cache_comm_t dtlb_comm_i,

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
    input  pmu_interface_t pmu_interface_i,

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
    input  logic [63:0]         pcr_resp_core_id_i, // core id of the tile that the date is sended

    //PCR outputs request
    output logic                pcr_req_valid_o,    // valid bit to make a pcr request
    output logic  [11:0]        pcr_req_addr_o,     // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    output logic  [63:0]        pcr_req_data_o,     // write data to performance counter module
    output logic  [2:0]         pcr_req_we_o,       // Cmd of the petition
    output logic  [63:0]        pcr_req_core_id_o   // core id of the tile

);

// Response CSR Interface to datapath
resp_csr_cpu_t resp_csr_interface_datapath;
logic [1:0] csr_priv_lvl, ld_st_priv_lvl;
logic [2:0] fcsr_rm;
logic [1:0] fcsr_fs;
logic [1:0] vcsr_vs;
logic en_ld_st_translation;
logic en_translation;
logic [39:0] vpu_csr;
assign en_translation_o = en_translation;
assign priv_lvl_o = csr_priv_lvl;

addr_t dcache_addr;

// struct debug input/output
debug_in_t debug_in;
debug_out_t debug_out;

//--PMU
to_PMU_t       pmu_flags    ;

logic [CSR_ADDR_SIZE-1:0] addr_csr_hpm;
logic [63:0]              data_csr_hpm, data_hpm_csr;
logic                     we_csr_hpm;
logic [31:0]              mcountinhibit_hpm;

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
always @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
        dcache_addr <= 0;
    else
        dcache_addr <= req_cpu_dcache_o.data_rs1;
end

assign IO_WB_BITS_ADDR = {24'b0,dcache_addr};
 
// Request Datapath to CSR
req_cpu_csr_t req_datapath_csr_interface;

phy_addr_t csr_satp;
assign csr_ptw_comm_o.satp = {{(XLEN-PHY_ADDR_SIZE){1'b0}}, csr_satp}; // PTW expects 64 bits

//-- HPM conection
logic count_ovf_int_req;
logic [HPM_NUM_COUNTERS+3-1:3] mhpm_ovf_bits;
logic [HPM_NUM_EVENTS:1] hpm_events;

assign hpm_events[1]  = pmu_flags.branch_miss;
assign hpm_events[2]  = pmu_flags.is_branch;
assign hpm_events[3]  = pmu_flags.branch_taken;
assign hpm_events[4]  = pmu_interface_i.exe_store;
assign hpm_events[5]  = pmu_interface_i.exe_load;
assign hpm_events[6]  = pmu_interface_i.icache_req;
assign hpm_events[7]  = pmu_interface_i.icache_kill;
assign hpm_events[8]  = pmu_flags.stall_if;
assign hpm_events[9]  = pmu_flags.stall_id;
assign hpm_events[10] = pmu_flags.stall_rr;
assign hpm_events[11] = pmu_flags.stall_exe;
assign hpm_events[12] = pmu_flags.stall_wb;
assign hpm_events[13] = pmu_interface_i.icache_miss_l2_hit;
assign hpm_events[14] = pmu_interface_i.icache_miss_kill;
assign hpm_events[15] = pmu_interface_i.icache_busy;
assign hpm_events[16] = pmu_interface_i.icache_miss_time;
assign hpm_events[17] = pmu_flags.load_store;
assign hpm_events[18] = pmu_flags.data_depend;
assign hpm_events[19] = pmu_flags.struct_depend;
assign hpm_events[20] = pmu_flags.grad_list_full;
assign hpm_events[21] = pmu_flags.free_list_empty;
assign hpm_events[22] = pmu_interface_i.itlb_access;
assign hpm_events[23] = pmu_interface_i.itlb_miss;
assign hpm_events[24] = pmu_interface_i.dtlb_access;
assign hpm_events[25] = pmu_interface_i.dtlb_miss;
assign hpm_events[26] = pmu_interface_i.ptw_buffer_hit;
assign hpm_events[27] = pmu_interface_i.ptw_buffer_miss;
assign hpm_events[28] = pmu_interface_i.itlb_stall;
                
hpm_counters #(
    .HPM_NUM_EVENTS(HPM_NUM_EVENTS),
    .HPM_NUM_COUNTERS(HPM_NUM_COUNTERS)
) hpm_counters_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    // Access interface
    .addr_i(addr_csr_hpm),
    .we_i(we_csr_hpm),
    .data_i(data_csr_hpm),
    .data_o(data_hpm_csr),
    
    .mcountinhibit_i(mcountinhibit_hpm),
    .priv_lvl_i(csr_priv_lvl),

    // Events
    .events_i(hpm_events),
    
    .count_ovf_int_req_o(count_ovf_int_req),
    .mhpm_ovf_bits_o(mhpm_ovf_bits)
);

sew_t sew;
assign sew = sew_t'(vpu_csr[37:36]);

datapath #(
    .DracCfg(DracCfg)
) datapath_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .reset_addr_i(reset_addr_i),
    // Input datapath
    .soft_rstn_i(soft_rstn_i),
    .resp_icache_cpu_i(resp_icache_cpu_i), 
    .resp_dcache_cpu_i(resp_dcache_cpu_i), 
    .resp_csr_cpu_i(resp_csr_interface_datapath),
    .sew_i(sew),//.sew_i(CSR_SEW),
    .en_translation_i( en_translation ), 
    .debug_i(debug_in),
    .req_icache_ready_i(req_icache_ready_i),
    .dtlb_comm_i(dtlb_comm_i),
    // Output datapath
    .req_cpu_dcache_o(req_cpu_dcache_o),
    .req_cpu_icache_o(req_cpu_icache_o),
    .req_cpu_csr_o(req_datapath_csr_interface),
    .debug_o(debug_out),
    .csr_priv_lvl_i(ld_st_priv_lvl),
    .csr_frm_i(fcsr_rm),
    .csr_fs_i(fcsr_fs),
    .csr_vs_i(vcsr_vs),
    .en_ld_st_translation_i(en_ld_st_translation),
    .dtlb_comm_o(dtlb_comm_o),
    //PMU                                                   
    .pmu_flags_o        (pmu_flags)
);

// NOTE:resp_csr_interface_datapath.csr_replay is a "ready" signal that indicate
// that the CSR are not blocked. In the implementation, since we only have one 
// inorder core any access to the CSR/PCR will be available. In multicore
// scenarios or higher performance cores you may need csr_replay.

csr_bsc #(
    .paddr_width(drac_pkg::PHY_ADDR_SIZE)
) csr_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .core_id_i(core_id_i),

    .rw_addr_i(req_datapath_csr_interface.csr_rw_addr),                  //read and write address form the core
    .rw_cmd_i(req_datapath_csr_interface.csr_rw_cmd),                   //specific operation to execute from the core 
    .w_data_core_i(req_datapath_csr_interface.csr_rw_data),              //write data from the core
    .r_data_core_o(resp_csr_interface_datapath.csr_rw_rdata),              // read data to the core, address specified with the rw_addr_i

    .ex_i(req_datapath_csr_interface.csr_exception),                       // exception produced in the core
    .ex_cause_i(req_datapath_csr_interface.csr_xcpt_cause),                 //cause of the exception
    .pc_i(req_datapath_csr_interface.csr_pc),                       //pc were the exception is produced

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

    .fcsr_flags_valid_i(|req_datapath_csr_interface.csr_retire),
    .fcsr_flags_bits_i(req_datapath_csr_interface.fp_status),
    .fcsr_rm_o(fcsr_rm),
    .fcsr_fs_o(fcsr_fs),
    .vcsr_vs_o(vcsr_vs),

    .csr_replay_o(resp_csr_interface_datapath.csr_replay),               // replay send to the core because there are some parts that are bussy
    .csr_stall_o(resp_csr_interface_datapath.csr_stall),                // The csr are waiting a resp and de core is stalled
    .csr_xcpt_o(resp_csr_interface_datapath.csr_exception),                 // Exeption pproduced by the csr   
    .csr_xcpt_cause_o(resp_csr_interface_datapath.csr_exception_cause),           // Exception cause
    .csr_tval_o(resp_csr_interface_datapath.csr_tval),                 // Value written to the tval registers
    .eret_o(resp_csr_interface_datapath.csr_eret),

    .status_o(csr_ptw_comm_o.mstatus),                   //actual mstatus of the core
    .priv_lvl_o(csr_priv_lvl),                 // actual privialge level of the core
    .ld_st_priv_lvl_o(ld_st_priv_lvl),
    .en_ld_st_translation_o(en_ld_st_translation),
    .en_translation_o(en_translation),

    .satp_ppn_o(csr_satp),                 // Page table base pointer for the PTW

    .evec_o(resp_csr_interface_datapath.csr_evec),                      // virtual address of the PC to execute after a Interrupt or exception

    .flush_o(csr_ptw_comm_o.flush),                    // the core is executing a sfence.vm instruction and a tlb flush is needed
    .vpu_csr_o(vpu_csr),

    // Unused interfaces
    .pcr_update_data_i(64'b0),
    .pcr_update_addr_i(12'b0),
    .pcr_update_core_id_i(64'b0),
    .pcr_update_broadcast_i(1'b0),
    .pcr_update_valid_i(1'b0),
    .m_soft_irq_i(1'b0),
    .rocc_interrupt_i(1'b0),

    .perf_addr_o(addr_csr_hpm),                // read/write address to performance counter module
    .perf_data_o(data_csr_hpm),                // write data to performance counter module
    .perf_data_i(data_hpm_csr),                // read data from performance counter module
    .perf_we_o(we_csr_hpm),
    .perf_mcountinhibit_o(mcountinhibit_hpm),
    .perf_count_ovf_int_req_i(count_ovf_int_req),
    .perf_mhpm_ovf_bits_i(mhpm_ovf_bits)
);


endmodule
