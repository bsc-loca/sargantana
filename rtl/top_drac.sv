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
    `ifdef INTEL_FSCAN_CTECH
    input logic                 fscan_rstbypen,//AK
    `endif // INTEL_FSCAN_CTECH
    input addr_t                reset_addr_i,
    input logic [63:0]          core_id_i,
    `ifdef PITON_CINCORANCH
    input logic [1:0]           boot_main_id_i,
    `endif  // Custom for CincoRanch
    `ifdef EXTERNAL_HPM_EVENT_NUM
     input logic [`EXTERNAL_HPM_EVENT_NUM-1: 0] external_hpm_i,
     `endif
//------------------------------------------------------------------------------------
// DEBUG RING SIGNALS INPUT
//------------------------------------------------------------------------------------    
    input debug_contr_in_t      debug_contr_i,
    input debug_reg_in_t        debug_reg_i,

//------------------------------------------------------------------------------------
// I-CACHE INTERFACE
//------------------------------------------------------------------------------------
    
    input  logic                req_icache_ready_i,
    output req_cpu_icache_t     req_cpu_icache_o,
    output logic                en_translation_o,
    output logic [1:0]          priv_lvl_o,
    input  resp_icache_cpu_t    resp_icache_cpu_i,

//----------------------------------------------------------------------------------
// D-CACHE INTERFACE
//----------------------------------------------------------------------------------

    input  resp_dcache_cpu_t    resp_dcache_cpu_i,
    output req_cpu_dcache_t     req_cpu_dcache_o, 

//----------------------------------------------------------------------------------
// MMU INTERFACE
//----------------------------------------------------------------------------------

    output csr_ptw_comm_t       csr_ptw_comm_o,
    output cache_tlb_comm_t     dtlb_comm_o,
    input  tlb_cache_comm_t     dtlb_comm_i,

//-----------------------------------------------------------------------------------
// DEBUGGING MODULE SIGNALS
//-----------------------------------------------------------------------------------
    output debug_contr_out_t    debug_contr_o,
    output debug_reg_out_t      debug_reg_o,

// VISA
    output visa_signals_t       visa_o,
    
//-----------------------------------------------------------------------------
// PMU INTERFACE
//-----------------------------------------------------------------------------
    input  pmu_interface_t      pmu_interface_i,

`ifdef CONF_SARGANTANA_ENABLE_PCR
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
`endif // CONF_SARGANTANA_ENABLE_PCR

//-----------------------------------------------------------------------------
// INTERRUPTS
//-----------------------------------------------------------------------------
    input  logic                 time_irq_i, // timer interrupt
    input  logic [1:0]           irq_i,      // external interrupt in
    input  logic                 soft_irq_i, // software interrupt
    input  logic [63:0]          time_i     // time passed since the core is reset

);

// Response CSR Interface to datapath
resp_csr_cpu_t resp_csr_interface_datapath;
logic [1:0] csr_priv_lvl, ld_st_priv_lvl;
logic [2:0] fcsr_rm;
logic [1:0] fcsr_fs;
logic [1:0] vcsr_vs;
logic en_ld_st_translation;
logic en_translation;
logic [42:0] vpu_csr;
logic debug_csr_halt_ack;

assign en_translation_o = en_translation;
assign priv_lvl_o = csr_priv_lvl;

addr_t dcache_addr;

//--PMU
to_PMU_t       pmu_flags    ;

logic [CSR_ADDR_SIZE-1:0] addr_csr_hpm;
logic [63:0]              data_csr_hpm, data_hpm_csr;
logic                     we_csr_hpm;
logic [31:0]              mcountinhibit_hpm;

logic tile_rstn;
`ifdef INTEL_FSCAN_CTECH
logic top_drac_tile_rstn;
assign top_drac_tile_rstn = soft_rstn_i & rstn_i;

ctech_lib_mux_2to1 drac_openpiton_wrapper_reset_mux (.d1(rstn_i),.d2(top_drac_tile_rstn),.s(fscan_rstbypen),.o(tile_rstn));//AK
`else
assign tile_rstn = soft_rstn_i & rstn_i;
`endif // INTEL_FSCAN_CTECH

// Register to save the last access to memory 
always_ff @(posedge clk_i, negedge tile_rstn) begin
    if(~tile_rstn)
        dcache_addr <= 0;
    else
        dcache_addr <= req_cpu_dcache_o.data_rs1[PHY_VIRT_MAX_ADDR_SIZE-1:0];
end
 
// Request Datapath to CSR
req_cpu_csr_t req_datapath_csr_interface;

logic [drac_pkg::PPN_SIZE-1:0] csr_satp;
assign csr_ptw_comm_o.satp = {{(riscv_pkg::XLEN-PHY_ADDR_SIZE){1'b0}}, csr_satp}; // PTW expects 64 bits

`ifdef EXTERNAL_HPM_EVENT_NUM
localparam HPM_EXT_NUM_EVENT = `EXTERNAL_HPM_EVENT_NUM;
`else 
localparam HPM_EXT_NUM_EVENT = 0;
`endif

//-- HPM conection
logic count_ovf_int_req;
logic [HPM_NUM_COUNTERS+3-1:3] mhpm_ovf_bits;
logic [HPM_NUM_EVENTS+HPM_EXT_NUM_EVENT:1] hpm_events_d, hpm_events_q;

assign hpm_events_d[1]  = pmu_flags.branch_miss;
assign hpm_events_d[2]  = pmu_flags.is_branch;
assign hpm_events_d[3]  = pmu_flags.branch_taken;
assign hpm_events_d[4]  = pmu_interface_i.exe_store;
assign hpm_events_d[5]  = pmu_interface_i.exe_load;
assign hpm_events_d[6]  = pmu_interface_i.icache_req;
assign hpm_events_d[7]  = pmu_interface_i.icache_kill;
assign hpm_events_d[8]  = pmu_flags.stall_if;
assign hpm_events_d[9]  = pmu_flags.stall_id;
assign hpm_events_d[10] = pmu_flags.stall_rr;
assign hpm_events_d[11] = pmu_flags.stall_exe;
assign hpm_events_d[12] = pmu_flags.stall_wb;
assign hpm_events_d[13] = pmu_interface_i.icache_miss_l2_hit;
assign hpm_events_d[14] = pmu_interface_i.icache_miss_kill;
assign hpm_events_d[15] = pmu_interface_i.icache_busy;
assign hpm_events_d[16] = pmu_interface_i.icache_miss_time;
assign hpm_events_d[17] = pmu_flags.load_store;
assign hpm_events_d[18] = pmu_flags.data_depend;
assign hpm_events_d[19] = pmu_flags.struct_depend;
assign hpm_events_d[20] = pmu_flags.grad_list_full;
assign hpm_events_d[21] = pmu_flags.free_list_empty;
assign hpm_events_d[22] = pmu_interface_i.itlb_access;
assign hpm_events_d[23] = pmu_interface_i.itlb_miss;
assign hpm_events_d[24] = pmu_interface_i.dtlb_access;
assign hpm_events_d[25] = pmu_interface_i.dtlb_miss;
assign hpm_events_d[26] = pmu_interface_i.ptw_buffer_hit;
assign hpm_events_d[27] = pmu_interface_i.ptw_buffer_miss;
assign hpm_events_d[28] = pmu_interface_i.itlb_stall;
assign hpm_events_d[29] = pmu_interface_i.dcache_stall;
assign hpm_events_d[30] = pmu_interface_i.dcache_stall_refill;
assign hpm_events_d[31] = pmu_interface_i.dcache_rtab_rollback;
assign hpm_events_d[32] = pmu_interface_i.dcache_req_onhold;
assign hpm_events_d[33] = pmu_interface_i.dcache_prefetch_req;
assign hpm_events_d[34] = pmu_interface_i.dcache_read_req;
assign hpm_events_d[35] = pmu_interface_i.dcache_write_req;
assign hpm_events_d[36] = pmu_interface_i.dcache_cmo_req;
assign hpm_events_d[37] = pmu_interface_i.dcache_uncached_req;
assign hpm_events_d[38] = pmu_interface_i.dcache_miss_read_req;
assign hpm_events_d[39] = pmu_interface_i.dcache_miss_write_req;
assign hpm_events_d[40] = pmu_flags.stall_ir;

`ifdef EXTERNAL_HPM_EVENT_NUM //can be 4,6,10

wire hpm_l2_access, hpm_l2_miss;
wire hpm_l15_access, hpm_l15_miss;
assign {hpm_l2_access, hpm_l2_miss, hpm_l15_access, hpm_l15_miss}= external_hpm_i[3:0];

assign hpm_events_d[HPM_NUM_EVENTS+1] =  hpm_l2_miss;            //41
assign hpm_events_d[HPM_NUM_EVENTS+2] =  hpm_l2_access;          //42
assign hpm_events_d[HPM_NUM_EVENTS+3] =  hpm_l15_miss;           //43
assign hpm_events_d[HPM_NUM_EVENTS+4] =  hpm_l15_access;         //44

generate 
if(HPM_EXT_NUM_EVENT == 10) begin 
    logic [2:0]hpm_noc_stall, hpm_noc_flit_val;
    assign {hpm_noc_stall, hpm_noc_flit_val}= external_hpm_i[9:4];
    assign hpm_events_d[HPM_NUM_EVENTS+5] =  hpm_noc_flit_val[0]; //45
    assign hpm_events_d[HPM_NUM_EVENTS+6] =  hpm_noc_flit_val[1]; //46 
    assign hpm_events_d[HPM_NUM_EVENTS+7] =  hpm_noc_flit_val[2]; //47
    assign hpm_events_d[HPM_NUM_EVENTS+8] =  hpm_noc_stall[0];    //48
    assign hpm_events_d[HPM_NUM_EVENTS+9] =  hpm_noc_stall[1];    //49
    assign hpm_events_d[HPM_NUM_EVENTS+10] =  hpm_noc_stall[2];    //50
end else if (HPM_EXT_NUM_EVENT == 6 )begin 
    logic hpm_nocs_stall, hpm_nocs_flit_val;
    assign {hpm_nocs_stall, hpm_nocs_flit_val}= external_hpm_i[5:4];
    assign hpm_events_d[HPM_NUM_EVENTS+5] = hpm_nocs_flit_val;    //45
    assign hpm_events_d[HPM_NUM_EVENTS+6] = hpm_nocs_stall;       //46
end
endgenerate

`endif
// Register HPM events to fix critical paths
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
        hpm_events_q <= 'h0;
    else
        hpm_events_q <= hpm_events_d;
end
             
hpm_counters #(
    .HPM_NUM_EVENTS(HPM_NUM_EVENTS+HPM_EXT_NUM_EVENT),
    .HPM_NUM_COUNTERS(HPM_NUM_COUNTERS)
) hpm_counters_inst (
    .clk_i(clk_i),
    .rstn_i(tile_rstn),

    // Access interface
    .addr_i(addr_csr_hpm),
    .we_i(we_csr_hpm),
    .data_i(data_csr_hpm),
    .data_o(data_hpm_csr),
    
    .mcountinhibit_i(mcountinhibit_hpm),
    .priv_lvl_i(csr_priv_lvl),

    // Events
    .events_i(hpm_events_q),
    
    .count_ovf_int_req_o(count_ovf_int_req),
    .mhpm_ovf_bits_o(mhpm_ovf_bits)
);

vxrm_t vxrm;
assign vxrm = vxrm_t'(vpu_csr[30:29]);          //Vector Fixed-Point rounding mode


datapath #(
    .DracCfg(DracCfg)
) datapath_inst (
    .clk_i(clk_i),
    .rstn_i(tile_rstn),
    .reset_addr_i(reset_addr_i),
    // Input datapath
    .resp_icache_cpu_i(resp_icache_cpu_i), 
    .resp_dcache_cpu_i(resp_dcache_cpu_i), 
    .resp_csr_cpu_i(resp_csr_interface_datapath),
    .vxrm_i(vxrm),
    .en_translation_i( en_translation ), 
    .req_icache_ready_i(req_icache_ready_i),
    .dtlb_comm_i(dtlb_comm_i),
    .debug_contr_i(debug_contr_i),
    .debug_reg_i(debug_reg_i),
    // Output datapath
    .req_cpu_dcache_o(req_cpu_dcache_o),
    .req_cpu_icache_o(req_cpu_icache_o),
    .req_cpu_csr_o(req_datapath_csr_interface),
    .visa_o(visa_o),
    .csr_priv_lvl_i(ld_st_priv_lvl),
    .csr_frm_i(fcsr_rm),
    .csr_fs_i(fcsr_fs),
    .csr_vs_i(vcsr_vs),
    .en_ld_st_translation_i(en_ld_st_translation),
    .dtlb_comm_o(dtlb_comm_o),
    .debug_contr_o(debug_contr_o),
    .debug_reg_o(debug_reg_o),
    .debug_csr_halt_ack_o(debug_csr_halt_ack),
    //PMU                                                   
    .pmu_flags_o        (pmu_flags)
);

// NOTE:resp_csr_interface_datapath.csr_replay is a "ready" signal that indicate
// that the CSR are not blocked. In the implementation, since we only have one 
// inorder core any access to the CSR/PCR will be available. In multicore
// scenarios or higher performance cores you may need csr_replay.

// Trap vector is defined to be at an offset of 0x40 from whichever address the core boots from
logic [63:0] trap_vector_addr;
assign trap_vector_addr = {{{64-PHY_VIRT_MAX_ADDR_SIZE}{1'b0}}, reset_addr_i + 8'h40};

logic fcsr_flags_valid;
assign fcsr_flags_valid = |req_datapath_csr_interface.csr_retire;

csr_bsc #(
    .PPN_WIDTH(drac_pkg::PPN_SIZE),
    .PROGRAM_BUFFER_ADDR(DracCfg.DebugProgramBufferBase)
) csr_inst (
    .clk_i(clk_i),
    .rstn_i(tile_rstn),

    .core_id_i(core_id_i),
    `ifdef PITON_CINCORANCH
    .boot_main_id_i(boot_main_id_i),
    `endif  // Custom for CincoRanch
    .trap_vector_addr_i(trap_vector_addr), // Address of the exception vector

    .rw_addr_i(req_datapath_csr_interface.csr_rw_addr),                               // read and write address form the core
    .rw_cmd_i(req_datapath_csr_interface.csr_rw_cmd),                                 // specific operation to execute from the core 
    .w_data_core_i(req_datapath_csr_interface.csr_rw_data),                           // write data from the core
    .r_data_core_o(resp_csr_interface_datapath.csr_rw_rdata),                         // read data to the core, address specified with the rw_addr_i

    .ex_i(req_datapath_csr_interface.csr_exception),                                  // exception produced in the core
    .ex_cause_i(req_datapath_csr_interface.csr_xcpt_cause),                           // cause of the exception
    .ex_origin_i(req_datapath_csr_interface.csr_xcpt_origin),                         // origin of the exception
    .pc_i(req_datapath_csr_interface.csr_pc),                                         // pc were the exception is produced

    .retire_i(req_datapath_csr_interface.csr_retire),                                 // shows if a instruction is retired from the core.
    .time_irq_i(time_irq_i),                                                          // timer interrupt
    .irq_i(irq_i),                                                                    // external interrupt in
    .m_soft_irq_i(soft_irq_i),
    .interrupt_o(resp_csr_interface_datapath.csr_interrupt),                          // Inerruption wire to the core
    .interrupt_cause_o(resp_csr_interface_datapath.csr_interrupt_cause),              // Interruption cause

    .time_i(time_i),                    // time passed since the core is reset

`ifdef CONF_SARGANTANA_ENABLE_PCR
    .pcr_req_ready_i(pcr_req_ready_i),            // ready bit of the pcr
    .pcr_resp_valid_i(pcr_resp_valid_i),           // ready bit of the pcr
    .pcr_resp_data_i(pcr_resp_data_i),            // read data from performance counter module
    .pcr_resp_core_id_i(pcr_resp_core_id_i),         // core id of the tile that the date is sended
    .pcr_req_valid_o(pcr_req_valid_o),            // valid bit to make a pcr request
    .pcr_req_addr_o(pcr_req_addr_o),             // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    .pcr_req_data_o(pcr_req_data_o),             // write data to performance counter module
    .pcr_req_we_o(pcr_req_we_o),               // Cmd of the petition
    .pcr_req_core_id_o(pcr_req_core_id_o),          // core id of the tile
`endif // CONF_SARGANTANA_ENABLE_PCR

    .freg_modified_i(req_datapath_csr_interface.freg_modified),
    .fcsr_flags_valid_i(fcsr_flags_valid),
    .fcsr_flags_bits_i(req_datapath_csr_interface.fp_status),
    .fcsr_rm_o(fcsr_rm),
    .fcsr_fs_o(fcsr_fs),
    .vcsr_vs_o(vcsr_vs),
    .vreg_modified_i(req_datapath_csr_interface.vreg_modified),
    .vxsat_i(req_datapath_csr_interface.csr_vxsat),

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

    .debug_halt_req_i(debug_contr_i.halt_req),
    .debug_halt_ack_i(debug_csr_halt_ack),
    .debug_resume_ack_i(debug_contr_o.resume_ack),
    .debug_ebreak_o(resp_csr_interface_datapath.debug_ebreak),
    .debug_step_o(resp_csr_interface_datapath.debug_step),
    .perf_addr_o(addr_csr_hpm),                // read/write address to performance counter module
    .perf_data_o(data_csr_hpm),                // write data to performance counter module
    .perf_data_i(data_hpm_csr),                // read data from performance counter module
    .perf_we_o(we_csr_hpm),
    .perf_mcountinhibit_o(mcountinhibit_hpm),
    .perf_count_ovf_int_req_i(count_ovf_int_req),
    .perf_mhpm_ovf_bits_i(mhpm_ovf_bits)
);


endmodule
