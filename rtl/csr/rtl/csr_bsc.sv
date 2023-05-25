//////////////////////////////////////////////////////////////////////////////////
// Company: Barcelona Supercomputing Center
// Engineer: Max Doblas Font max.doblas@bsc.es
// 
// Create Date: 29/08/2019 17:06:00 PM
// Design Name: 
// Module Name: csr_bsc
// Project Name: DRAC
// Target Devices: 
// Tool Versions: Privileged ISA 1.11
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module csr_bsc#(
    parameter word_width = 64,
    parameter addr_width_extended = 40,
    parameter paddr_width = 32,
    parameter csr_addr_width = 12,
    parameter mtvec_par = 'h104,
    parameter start_addr_par = 'h100,
    parameter core_id = 1'b0,
    parameter rocc_instance = 1'b0,
    parameter boot_addr = 'h100,
    parameter AsidWidth = 13
)(
    input logic                             clk_i,
    input logic                             rstn_i,

    // RW interface with the core
    input logic [csr_addr_width-1:0]        rw_addr_i,                  //read and write address form the core
    input logic [2:0]                       rw_cmd_i,                   //specific operation to execute from the core 
    input logic [word_width-1:0]            w_data_core_i,              //write data from the core
    output logic [word_width-1:0]           r_data_core_o,              // read data to the core, address specified with the rw_addr_i

    //Exceptions 
    input logic                             ex_i,                       // exception produced in the core
    input logic [word_width-1:0]            ex_cause_i,                 //cause of the exception
    input logic [addr_width_extended-1:0]   pc_i,                       //pc were the exception is produced

    input logic [1:0]                       retire_i,                   // shows if a instruction is retired from the core.
    
    //Interruptions
    input logic                             rocc_interrupt_i,           // interrupt from the Rocc module
    input logic                             time_irq_i,                 // timer interrupt
    input logic                             irq_i,                      // external interrupt in
    input logic                             m_soft_irq_i,               // Machine software interrupt form the axi module
    output logic                            interrupt_o,                // Inerruption wire to the core
    output logic [word_width-1:0]           interrupt_cause_o,          // Interruption cause

    input  logic [word_width-1:0]           time_i,                    // time passed since the core is reset

    //PCR req inputs
    input  logic                            pcr_req_ready_i,            // ready bit of the pcr

    //PCR resp inputs
    input  logic                            pcr_resp_valid_i,           // ready bit of the pcr
    input  logic [word_width-1:0]           pcr_resp_data_i,            // read data from performance counter module
    input  logic                            pcr_resp_core_id_i,         // core id of the tile that the date is sended

    //PCR outputs request
    output logic                            pcr_req_valid_o,            // valid bit to make a pcr request
    output logic  [csr_addr_width-1:0]      pcr_req_addr_o,             // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    output logic  [63:0]                    pcr_req_data_o,             // write data to performance counter module
    output logic  [2:0]                     pcr_req_we_o,               // Cmd of the petition
    output logic                            pcr_req_core_id_o,          // core id of the tile

    //PCR update inputs
    input  logic                            pcr_update_valid_i,
    input  logic                            pcr_update_broadcast_i,
    input  logic                            pcr_update_core_id_i,
    input  logic [csr_addr_width-1:0]       pcr_update_addr_i,
    input  logic [word_width-1:0]           pcr_update_data_i,

    // floating point flags
    input logic                             fcsr_flags_valid_i,
    input logic [4:0]                       fcsr_flags_bits_i,
    output logic [2:0]                      fcsr_rm_o,
    output logic [1:0]                      fcsr_fs_o,

    

    output logic                            csr_replay_o,               // replay send to the core because there are some parts that are bussy
    output logic                            csr_stall_o,                // The csr are waiting a resp and de core is stalled
    output logic                            csr_xcpt_o,                 // Exeption pproduced by the csr   
    output logic [63:0]                     csr_xcpt_cause_o,           // Exception cause
    output logic [63:0]                     csr_tval_o,                 // Value written to the tval registers
    output logic                            eret_o,

    output logic [word_width-1:0]           status_o,                   //actual mstatus of the core
    output logic [1:0]                      priv_lvl_o,                 // actual privialge level of the core
    output logic [1:0]                      ld_st_priv_lvl_o,
    output logic                            en_ld_st_translation_o,
    output logic                            en_translation_o,

    output logic [paddr_width-1:0]          satp_ppn_o,                 // Page table base pointer for the PTW

    output logic [addr_width_extended-1:0]  evec_o,                      // virtual address of the PC to execute after a Interrupt or exception

    output logic                            flush_o,                    // the core is executing a sfence.vm instruction and a tlb flush is needed
    output logic [39:0]                     vpu_csr_o,

    output logic [csr_addr_width-1:0]       perf_addr_o,                // read/write address to performance counter module
    output logic [63:0]                     perf_data_o,                // write data to performance counter module
    input  logic [63:0]                     perf_data_i,                // read data from performance counter module
    output logic                            perf_we_o
);

    localparam int MHPM_TO_HPM_DIST = CSR_HPM_COUNTER_3 - CSR_MHPM_COUNTER_3;

    //////////////////////////////////////////////
    // Registers declaration
    //////////////////////////////////////////////
    
    riscv_pkg::status_rv64_t  mstatus_q,  mstatus_d;
    riscv_pkg::satp_t         satp_q, satp_d;
    riscv_pkg::csr_t  csr_addr;
    // privilege level register
    riscv_pkg::priv_lvl_t   priv_lvl_d, priv_lvl_q;

    logic        mtvec_rst_load_q;// used to determine whether we came out of reset
    logic [63:0] mtvec_q,     mtvec_d;
    logic [63:0] medeleg_q,   medeleg_d;
    logic [63:0] mideleg_q,   mideleg_d;
    logic [63:0] mip_q,       mip_d;
    logic [63:0] mie_q,       mie_d;
    logic [63:0] mcounteren_q,mcounteren_d;
    logic [63:0] mscratch_q,  mscratch_d;
    logic [63:0] mepc_q,      mepc_d;
    logic [63:0] mcause_q,    mcause_d;
    logic [63:0] mtval_q,     mtval_d;

    logic [63:0] stvec_q,     stvec_d;
    logic [63:0] scounteren_q,scounteren_d;
    logic [63:0] sscratch_q,  sscratch_d;
    logic [63:0] sepc_q,      sepc_d;
    logic [63:0] scause_q,    scause_d;
    logic [63:0] stval_q,     stval_d;

    // Vector extension registers
    logic [63:0] vl_q,        vl_d;
    logic [63:0] vtype_q,     vtype_d;

    logic [63:0] cycle_q,     cycle_d;
    logic [63:0] instret_q,   instret_d;

    riscv_pkg::fcsr_t fcsr_q, fcsr_d;

    //////////////////////////////////////////////
    // Intermidiet wires and regs declaration
    //////////////////////////////////////////////

    // internal signal to keep track of access exceptions
    logic        read_access_exception, update_access_exception, privilege_violation;
    logic        csr_we, csr_read;
    logic        csr_xcpt;          // Internal csr exception bit.
    logic [63:0] csr_xcpt_cause;    // cause of the internal csr exception
    logic [63:0] ex_tval;
    logic [63:0] csr_wdata, csr_rdata;
    logic [63:0] trap_vector_base;
    riscv_pkg::priv_lvl_t   trap_to_priv_lvl;
    // register for enabling load store address translation, this is critical, hence the register
    logic        en_ld_st_translation_d, en_ld_st_translation_q;
    logic  mprv;
    logic  mret;  // return from M-mode exception
    logic  sret;  // return from S-mode exception
    // CSR write causes us to mark the FPU state as dirty
    logic  dirty_fp_state_csr;

    // actual state wires
    logic system_insn;
    logic priv_sufficient;
    logic wfi_d, wfi_q;

    // instruction wires
    logic insn_call;
    logic insn_break; 
    logic insn_ret;
    logic insn_sfence_vm; 
    logic insn_wfi;

    // vector instruction wires
    logic vsetvl_insn;
    logic [10:0] vtype_new;
    logic [63:0] vlmax;

    // pcr wires
    logic pcr_wait_resp_d, pcr_wait_resp_q; // the csr regfile is waiting the response of the PCR
    logic pcr_req_valid; // the csr regfile requests data to the PCR
    logic [63:0] reg_time_d, reg_time_q; // time value from de PCR
    logic cpu_ren; // is needed a read to the csr (write, read, set and clear)
    logic pcr_addr_valid; // the address requested is a pcr address.

    //interruption wires
    logic cond_m_int, cond_s_int;
    logic [63:0] interrupt_cause_q, interrupt_cause_d, interrupt_cause;
    logic interrupt_d, interrupt_q;
    logic global_enable;

    // flush caused by a sfence instruction
    logic flush_sfence;


    //////////////////////////////////////////////
    // System Instructions Decode
    //////////////////////////////////////////////
    // indicates if the request is a system instuction
    assign system_insn = (rw_cmd_i == 3'b100) ? 1'b1 : 1'b0;
    assign priv_sufficient = priv_lvl_q >= rw_addr_i[9:8];
    // the instructions are codified using the rw_addr_i
    assign insn_call = (10'b0000000000 == rw_addr_i[9:0] && system_insn) ? 1'b1 : 1'b0;
    assign insn_break = (10'b0000000001 == rw_addr_i[9:0] && system_insn) ? 1'b1 : 1'b0;
    assign insn_mret =  (10'b1100000010 == rw_addr_i[9:0] && system_insn && priv_sufficient) ? 1'b1 : 1'b0;
    assign insn_sret =  (10'b0100000010 == rw_addr_i[9:0] && system_insn && priv_sufficient) ? 1'b1 : 1'b0;
    assign insn_sfence_vm = (5'b01001 == rw_addr_i[9:5] && system_insn && priv_sufficient) ? 1'b1 : 1'b0;
    assign insn_wfi = (10'b0100000101 == rw_addr_i[9:0] && system_insn && priv_sufficient) ? 1'b1 : 1'b0;

    //////////////////////////////////////////////
    // Vector Instructions Decode
    //////////////////////////////////////////////
    assign vsetvl_insn = (rw_cmd_i == 3'b110 || rw_cmd_i == 3'b111) ? 1'b1 : 1'b0;

    //////////////////////////////////////////////
    // VPU Instructions Decode
    //////////////////////////////////////////////
    // indicates if the request is a system instuction

    // ----------------
    // Assignments
    // ----------------
    assign csr_addr = riscv_pkg::csr_t'(rw_addr_i);

    // ----------------
    // CSR Read logic
    // ----------------
    always_comb begin : csr_read_process
        // a read access exception can only occur if we attempt to read a CSR which does not exist
        read_access_exception = 1'b0;
        pcr_addr_valid = 1'b0;
        csr_rdata = 64'b0;
        perf_addr_o = '0;

        if (csr_read) begin
            unique case (csr_addr.address)
                riscv_pkg::CSR_FFLAGS: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {59'b0, fcsr_q.fflags};
                    end
                end
                riscv_pkg::CSR_FRM: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {61'b0, fcsr_q.frm};
                    end
                end
                riscv_pkg::CSR_FCSR: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {56'b0, fcsr_q.frm, fcsr_q.fflags};
                    end
                end
                // debug registers
                riscv_pkg::CSR_DCSR:               csr_rdata = 64'b0; // not implemented
                riscv_pkg::CSR_DPC:                csr_rdata = 64'b0; // not implemented
                riscv_pkg::CSR_DSCRATCH0:          csr_rdata = 64'b0; // not implemented
                riscv_pkg::CSR_DSCRATCH1:          csr_rdata = 64'b0; // not implemented
                // trigger module registers
                riscv_pkg::CSR_TSELECT:; // not implemented
                riscv_pkg::CSR_TDATA1:;  // not implemented
                riscv_pkg::CSR_TDATA2:;  // not implemented
                riscv_pkg::CSR_TDATA3:;  // not implemented
                // supervisor registers
                riscv_pkg::CSR_SSTATUS: begin
                    csr_rdata = mstatus_q & def_pkg::SMODE_STATUS_READ_MASK;
                end
                riscv_pkg::CSR_SIE:                csr_rdata = mie_q & mideleg_q;
                riscv_pkg::CSR_SIP:                csr_rdata = mip_q & mideleg_q;
                riscv_pkg::CSR_STVEC:              csr_rdata = stvec_q;
                riscv_pkg::CSR_SCOUNTEREN:         csr_rdata = scounteren_q;
                riscv_pkg::CSR_SSCRATCH:           csr_rdata = sscratch_q;
                riscv_pkg::CSR_SEPC:               csr_rdata = sepc_q;
                riscv_pkg::CSR_SCAUSE:             csr_rdata = scause_q;
                riscv_pkg::CSR_STVAL:              csr_rdata = stval_q;
                riscv_pkg::CSR_SATP: begin
                    // intercept reads to SATP if in S-Mode and TVM is enabled
                    if (priv_lvl_o == riscv_pkg::PRIV_LVL_S && mstatus_q.tvm) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = satp_q;
                    end
                end
                // machine mode registers
                riscv_pkg::CSR_MSTATUS:            csr_rdata = mstatus_q;
                riscv_pkg::CSR_MISA:               csr_rdata = def_pkg::ISA_CODE; 
                riscv_pkg::CSR_MEDELEG:            csr_rdata = medeleg_q;
                riscv_pkg::CSR_MIDELEG:            csr_rdata = mideleg_q;
                riscv_pkg::CSR_MIE:                csr_rdata = mie_q;
                riscv_pkg::CSR_MTVEC:              csr_rdata = mtvec_q;
                riscv_pkg::CSR_MCOUNTEREN:         csr_rdata = mcounteren_q;
                riscv_pkg::CSR_MSCRATCH:           csr_rdata = mscratch_q;
                riscv_pkg::CSR_MEPC:               csr_rdata = mepc_q;
                riscv_pkg::CSR_MCAUSE:             csr_rdata = mcause_q;
                riscv_pkg::CSR_MTVAL:              csr_rdata = mtval_q;
                riscv_pkg::CSR_MIP:                csr_rdata = mip_q;
                riscv_pkg::CSR_MVENDORID:          csr_rdata = 64'b0; // not implemented
                riscv_pkg::CSR_MARCHID:            csr_rdata = 64'b0; // not implemented
                riscv_pkg::CSR_MIMPID:             csr_rdata = 64'b0; // not implemented
                riscv_pkg::CSR_MHARTID:            csr_rdata = core_id; 
                // Counters and Timers
                riscv_pkg::CSR_MCYCLE:             csr_rdata = cycle_q;
                riscv_pkg::CSR_MINSTRET:           csr_rdata = instret_q;
                riscv_pkg::CSR_MHPM_COUNTER_3,
                riscv_pkg::CSR_MHPM_COUNTER_4,
                riscv_pkg::CSR_MHPM_COUNTER_5,
                riscv_pkg::CSR_MHPM_COUNTER_6,
                riscv_pkg::CSR_MHPM_COUNTER_7,
                riscv_pkg::CSR_MHPM_COUNTER_8,
                riscv_pkg::CSR_MHPM_COUNTER_9,
                riscv_pkg::CSR_MHPM_COUNTER_10,
                riscv_pkg::CSR_MHPM_COUNTER_11,
                riscv_pkg::CSR_MHPM_COUNTER_12,
                riscv_pkg::CSR_MHPM_COUNTER_13,
                riscv_pkg::CSR_MHPM_COUNTER_14,
                riscv_pkg::CSR_MHPM_COUNTER_15,
                riscv_pkg::CSR_MHPM_COUNTER_16,
                riscv_pkg::CSR_MHPM_COUNTER_17,
                riscv_pkg::CSR_MHPM_COUNTER_18,
                riscv_pkg::CSR_MHPM_COUNTER_19,
                riscv_pkg::CSR_MHPM_COUNTER_20,
                riscv_pkg::CSR_MHPM_COUNTER_21,
                riscv_pkg::CSR_MHPM_COUNTER_22,
                riscv_pkg::CSR_MHPM_COUNTER_23,
                riscv_pkg::CSR_MHPM_COUNTER_24,
                riscv_pkg::CSR_MHPM_COUNTER_25,
                riscv_pkg::CSR_MHPM_COUNTER_26,
                riscv_pkg::CSR_MHPM_COUNTER_27,
                riscv_pkg::CSR_MHPM_COUNTER_28,
                riscv_pkg::CSR_MHPM_COUNTER_29,
                riscv_pkg::CSR_MHPM_COUNTER_30,
                riscv_pkg::CSR_MHPM_COUNTER_31: begin
                    perf_addr_o = csr_addr.address[11:0];
                    csr_rdata = perf_data_i;
                end

                riscv_pkg::CSR_CYCLE:              csr_rdata = cycle_q;
                riscv_pkg::CSR_TIME:               csr_rdata = reg_time_q;
                riscv_pkg::CSR_INSTRET:            csr_rdata = instret_q;
                riscv_pkg::CSR_HPM_COUNTER_3,
                riscv_pkg::CSR_HPM_COUNTER_4,
                riscv_pkg::CSR_HPM_COUNTER_5,
                riscv_pkg::CSR_HPM_COUNTER_6,
                riscv_pkg::CSR_HPM_COUNTER_7,
                riscv_pkg::CSR_HPM_COUNTER_8,
                riscv_pkg::CSR_HPM_COUNTER_9,
                riscv_pkg::CSR_HPM_COUNTER_10,
                riscv_pkg::CSR_HPM_COUNTER_11,
                riscv_pkg::CSR_HPM_COUNTER_12,
                riscv_pkg::CSR_HPM_COUNTER_13,
                riscv_pkg::CSR_HPM_COUNTER_14,
                riscv_pkg::CSR_HPM_COUNTER_15,
                riscv_pkg::CSR_HPM_COUNTER_16,
                riscv_pkg::CSR_HPM_COUNTER_17,
                riscv_pkg::CSR_HPM_COUNTER_18,
                riscv_pkg::CSR_HPM_COUNTER_19,
                riscv_pkg::CSR_HPM_COUNTER_20,
                riscv_pkg::CSR_HPM_COUNTER_21,
                riscv_pkg::CSR_HPM_COUNTER_22,
                riscv_pkg::CSR_HPM_COUNTER_23,
                riscv_pkg::CSR_HPM_COUNTER_24,
                riscv_pkg::CSR_HPM_COUNTER_25,
                riscv_pkg::CSR_HPM_COUNTER_26,
                riscv_pkg::CSR_HPM_COUNTER_27,
                riscv_pkg::CSR_HPM_COUNTER_28,
                riscv_pkg::CSR_HPM_COUNTER_29,
                riscv_pkg::CSR_HPM_COUNTER_30,
                riscv_pkg::CSR_HPM_COUNTER_31: begin
                    perf_addr_o = csr_addr.address[11:0] - MHPM_TO_HPM_DIST;
                    csr_rdata = perf_data_i;
                end

                riscv_pkg::CSR_MHPM_EVENT_3,
                riscv_pkg::CSR_MHPM_EVENT_4,
                riscv_pkg::CSR_MHPM_EVENT_5,
                riscv_pkg::CSR_MHPM_EVENT_6,
                riscv_pkg::CSR_MHPM_EVENT_7,
                riscv_pkg::CSR_MHPM_EVENT_8,
                riscv_pkg::CSR_MHPM_EVENT_9,
                riscv_pkg::CSR_MHPM_EVENT_10,
                riscv_pkg::CSR_MHPM_EVENT_11,
                riscv_pkg::CSR_MHPM_EVENT_12,
                riscv_pkg::CSR_MHPM_EVENT_13,
                riscv_pkg::CSR_MHPM_EVENT_14,
                riscv_pkg::CSR_MHPM_EVENT_15,
                riscv_pkg::CSR_MHPM_EVENT_16,
                riscv_pkg::CSR_MHPM_EVENT_17,
                riscv_pkg::CSR_MHPM_EVENT_18,
                riscv_pkg::CSR_MHPM_EVENT_19,
                riscv_pkg::CSR_MHPM_EVENT_20,
                riscv_pkg::CSR_MHPM_EVENT_21,
                riscv_pkg::CSR_MHPM_EVENT_22,
                riscv_pkg::CSR_MHPM_EVENT_23,
                riscv_pkg::CSR_MHPM_EVENT_24,
                riscv_pkg::CSR_MHPM_EVENT_25,
                riscv_pkg::CSR_MHPM_EVENT_26,
                riscv_pkg::CSR_MHPM_EVENT_27,
                riscv_pkg::CSR_MHPM_EVENT_28,
                riscv_pkg::CSR_MHPM_EVENT_29,
                riscv_pkg::CSR_MHPM_EVENT_30,
                riscv_pkg::CSR_MHPM_EVENT_31:   begin
                    perf_addr_o = csr_addr.address[11:0];
                    csr_rdata = perf_data_i;
                end

                riscv_pkg::CSR_MEM_MAP_0,
                riscv_pkg::CSR_MEM_MAP_1,
                riscv_pkg::CSR_MEM_MAP_2,
                riscv_pkg::CSR_MEM_MAP_3,
                riscv_pkg::CSR_MEM_MAP_4,
                riscv_pkg::CSR_MEM_MAP_5,
                riscv_pkg::CSR_MEM_MAP_6,
                riscv_pkg::CSR_MEM_MAP_7,
                riscv_pkg::CSR_MEM_MAP_8,
                riscv_pkg::CSR_MEM_MAP_9,
                riscv_pkg::CSR_MEM_MAP_10,                
                riscv_pkg::CSR_MEM_MAP_11,                
                riscv_pkg::CSR_MEM_MAP_12,                
                riscv_pkg::CSR_MEM_MAP_13,                
                riscv_pkg::CSR_MEM_MAP_14,                
                riscv_pkg::CSR_MEM_MAP_15,
                riscv_pkg::CSR_IO_MAP_0,
                riscv_pkg::CSR_IO_MAP_1,
                riscv_pkg::CSR_IO_MAP_2,
                riscv_pkg::CSR_IO_MAP_3,
                riscv_pkg::CSR_IO_MAP_4,
                riscv_pkg::CSR_IO_MAP_5,
                riscv_pkg::CSR_IO_MAP_6,
                riscv_pkg::CSR_IO_MAP_7,
                riscv_pkg::CSR_IO_MAP_8,
                riscv_pkg::CSR_IO_MAP_9,
                riscv_pkg::CSR_IO_MAP_10,
                riscv_pkg::CSR_IO_MAP_11,
                riscv_pkg::CSR_IO_MAP_12,
                riscv_pkg::CSR_IO_MAP_13,
                riscv_pkg::CSR_IO_MAP_14,
                riscv_pkg::CSR_IO_MAP_15,
                riscv_pkg::CSR_IRQ_MAP_0,
                riscv_pkg::CSR_IRQ_MAP_1,
                riscv_pkg::CSR_IRQ_MAP_2,
                riscv_pkg::CSR_IRQ_MAP_3,
                riscv_pkg::CSR_IRQ_MAP_4,
                riscv_pkg::CSR_IRQ_MAP_5,
                riscv_pkg::CSR_IRQ_MAP_6,
                riscv_pkg::CSR_IRQ_MAP_7,
                riscv_pkg::CSR_IRQ_MAP_8,
                riscv_pkg::CSR_IRQ_MAP_9,
                riscv_pkg::CSR_IRQ_MAP_10,
                riscv_pkg::CSR_IRQ_MAP_11,
                riscv_pkg::CSR_IRQ_MAP_12,
                riscv_pkg::CSR_IRQ_MAP_13,
                riscv_pkg::CSR_IRQ_MAP_14,
                riscv_pkg::CSR_IRQ_MAP_15,
                riscv_pkg::FROM_HOST,
                riscv_pkg::CSR_HYPERRAM_CONFIG, 
                riscv_pkg::CSR_SPI_CONFIG, 
                riscv_pkg::CSR_CNM_CONFIG,
                riscv_pkg::TO_HOST: begin            
                                        csr_rdata = pcr_resp_data_i;
                                        pcr_addr_valid = 1'b1;
                end
                
                riscv_pkg::CSR_PMPCFG_0:;
                riscv_pkg::CSR_PMPCFG_1:;
                riscv_pkg::CSR_PMPCFG_2:;
                riscv_pkg::CSR_PMPCFG_3:;

                riscv_pkg::CSR_PMPADDR_0:;
                riscv_pkg::CSR_PMPADDR_1:;
                riscv_pkg::CSR_PMPADDR_2:;
                riscv_pkg::CSR_PMPADDR_3:;
                riscv_pkg::CSR_PMPADDR_4:;
                riscv_pkg::CSR_PMPADDR_5:;
                riscv_pkg::CSR_PMPADDR_6:;
                riscv_pkg::CSR_PMPADDR_7:;
                riscv_pkg::CSR_PMPADDR_8:;
                riscv_pkg::CSR_PMPADDR_9:;
                riscv_pkg::CSR_PMPADDR_10:;
                riscv_pkg::CSR_PMPADDR_11:;
                riscv_pkg::CSR_PMPADDR_12:;
                riscv_pkg::CSR_PMPADDR_13:;
                riscv_pkg::CSR_PMPADDR_14:;
                riscv_pkg::CSR_PMPADDR_15:;
                riscv_pkg::CSR_VL: csr_rdata = vl_q;
                riscv_pkg::CSR_VTYPE: csr_rdata = vtype_q;
                //
                default: read_access_exception = 1'b1;
            endcase
        end
    end




    // ---------------------------
    // CSR Write and update logic
    // ---------------------------
    logic [63:0] mask;
    always_comb begin : csr_update
        automatic riscv_pkg::satp_t sapt,sapt_temp; // temporal values to correct the structure of the writing on the sapt reg
        automatic logic [63:0] instret;
        automatic logic [63:0] mstatus_int, mstatus_clear ,mstatus_set; //Used to set and clear some bits of the mstatus_d
        automatic logic flush; //temporal flush value befor the exceptions logic
        automatic logic [63:0] mcause_int; // temporal value of mcause
        automatic logic [63:0] scause_int; // temporal value of scause
        automatic logic [63:0] mtval_int; // temporal value of mtval
        automatic logic [63:0] stval_int; // temporal value of stval
        automatic logic [63:0] mepc_int; // temporal value of mepc
        automatic logic [63:0] sepc_int; // temporal value of sepc

        sapt = satp_q;
        instret = instret_q;

        // --------------------
        // Counters
        // --------------------
        // increase instruction retired counter
        if (!ex_i) instret = instret + retire_i[0] + retire_i[1];
        instret_d = instret;
        // increment the cycle count 
        cycle_d = cycle_q + 1'b1;

        eret_o                  = 1'b0;
        flush                  = 1'b0;
        update_access_exception = 1'b0;

        perf_we_o               = 1'b0;
        perf_data_o             = 'b0;

        fcsr_d                  = fcsr_q;

        priv_lvl_d              = priv_lvl_q;

        mstatus_clear = riscv_pkg::MSTATUS_UXL | riscv_pkg::MSTATUS_SXL | riscv_pkg::MSTATUS64_SD;
        mstatus_set =   ((mstatus_q.xs == riscv_pkg::Dirty) | (mstatus_q.fs == riscv_pkg::Dirty))<<63 |
                        riscv_pkg::XLEN_64 << 32|
                        riscv_pkg::XLEN_64 << 34;
        mstatus_int   = (mstatus_q & ~mstatus_clear)| mstatus_set;

        // hardwired extension registers

        // write the floating point status register
        if (fcsr_flags_valid_i) begin
            fcsr_d.fflags = fcsr_flags_bits_i | fcsr_q.fflags;
        end
       

        // check whether we come out of reset
        // this is a workaround. some tools have issues
        // having boot_addr_i in the asynchronous
        // reset assignment to mtvec_d, even though
        // boot_addr_i will be assigned a constant
        // on the top-level.
        if (mtvec_rst_load_q) begin
            mtvec_d             = boot_addr + 'h40;
        end else begin
            mtvec_d             = mtvec_q;
        end

        // ---------------------
        // External Interrupts
        // ---------------------
        // the IRQ_M_EXT = irq_i || rocc_interrupt_i, IRQ_M_SOFT = m_soft_irq_i and IRQ_M_TIMER = time_irq_i
        mip_d = {mip_q[63:12],irq_i || rocc_interrupt_i, mip_q[10:8], time_irq_i, mip_q[6:4], m_soft_irq_i, mip_q[2:0]};



        medeleg_d               = medeleg_q;
        mideleg_d               = mideleg_q;
        
        mie_d                   = mie_q;
        mepc_int                = mepc_q;
        mcause_int              = mcause_q;
        mcounteren_d            = mcounteren_q;
        mscratch_d              = mscratch_q;
        mtval_int               = mtval_q;

        sepc_int                = sepc_q;
        scause_int              = scause_q;
        stvec_d                 = stvec_q;
        scounteren_d            = scounteren_q;
        sscratch_d              = sscratch_q;
        stval_int               = stval_q;
        satp_d                  = satp_q;

        en_ld_st_translation_d  = en_ld_st_translation_q;
        dirty_fp_state_csr      = 1'b0;
        pcr_req_data_o          = 'b0;

        // check for correct access rights and that we are writing
        if (csr_we) begin
            unique case (csr_addr.address)
                // Floating-Point
                riscv_pkg::CSR_FFLAGS: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d.fflags = csr_wdata[4:0];
                        // this instruction has side-effects
                        flush = 1'b1;
                    end
                end
                riscv_pkg::CSR_FRM: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d.frm    = csr_wdata[2:0];
                        // this instruction has side-effects
                        flush = 1'b1;
                    end
                end
                riscv_pkg::CSR_FCSR: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d[7:0] = csr_wdata[7:0]; // ignore writes to reserved space
                        /*vxsat_d = csr_wdata[8];
                        vxrm_d = csr_wdata[10:9];*/
                        // this instruction has side-effects
                        flush = 1'b1;
                    end
                end

                // debug CSR
                riscv_pkg::CSR_DCSR:;// not implemented
                riscv_pkg::CSR_DPC:;// not implemented
                riscv_pkg::CSR_DSCRATCH0:;// not implemented
                riscv_pkg::CSR_DSCRATCH1:;// not implemented
                // trigger module CSRs
                riscv_pkg::CSR_TSELECT:; // not implemented
                riscv_pkg::CSR_TDATA1:;  // not implemented
                riscv_pkg::CSR_TDATA2:;  // not implemented
                riscv_pkg::CSR_TDATA3:;  // not implemented
                // sstatus is a subset of mstatus - mask it accordingly
                riscv_pkg::CSR_SSTATUS: begin
                    mask = def_pkg::SMODE_STATUS_WRITE_MASK;
                    mstatus_int = (mstatus_q & ~mask) | (csr_wdata & mask);
                    // this instruction has side-effects
                    flush = 1'b1;
                end
                // even machine mode interrupts can be visible and set-able to supervisor
                // if the corresponding bit in mideleg is set
                riscv_pkg::CSR_SIE: begin
                    // the mideleg makes sure only delegate-able register (and therefore also only implemented registers) are written
                    mask = riscv_pkg::MIP_SSIP | riscv_pkg::MIP_STIP | riscv_pkg::MIP_SEIP;
                    mie_d = (mie_q & ~mask) | (csr_wdata & mask);
                end

                riscv_pkg::CSR_SIP: begin
                    // only the supervisor software interrupt is write-able, iff delegated
                    mask = riscv_pkg::MIP_SSIP & mideleg_q;
                    mip_d = (mip_q & ~mask) | (csr_wdata & mask);
                end

                riscv_pkg::CSR_SCOUNTEREN:         scounteren_d = {{32{1'b0}}, csr_wdata[31:0]};
                riscv_pkg::CSR_STVEC:              stvec_d     = {csr_wdata[63:2], 1'b0, csr_wdata[0]};
                riscv_pkg::CSR_SSCRATCH:           sscratch_d  = csr_wdata;
                riscv_pkg::CSR_SEPC:               sepc_int    = {csr_wdata[63:1], 1'b0};
                riscv_pkg::CSR_SCAUSE:             scause_int  = csr_wdata;
                riscv_pkg::CSR_STVAL:              stval_int   = csr_wdata;
                // supervisor address translation and protection
                riscv_pkg::CSR_SATP: begin
                    // intercept SATP writes if in S-Mode and TVM is enabled
                    if (priv_lvl_o == riscv_pkg::PRIV_LVL_S && mstatus_q.tvm)
                        update_access_exception = 1'b1;
                    else begin
                        sapt_temp      = riscv_pkg::satp_t'(csr_wdata);
                        // only make ASID_LEN - 1 bit stick, that way software can figure out how many ASID bits are supported
                        sapt.asid = sapt_temp.asid & {{(16-AsidWidth){1'b0}}, {AsidWidth{1'b1}}};
                        sapt.mode = sapt_temp.mode;
                        sapt.ppn = sapt_temp.ppn;
                        // only update if we actually support this mode
                        if (sapt.mode == def_pkg::MODE_OFF || sapt.mode == def_pkg::MODE_SV39) satp_d = sapt;
                    end
                    // changing the mode can have side-effects on address translation (e.g.: other instructions), re-fetch
                    // the next instruction by executing a flush
                    flush = 1'b1;
                end

                riscv_pkg::CSR_MSTATUS: begin
                    // mask of the bits that are set to zero
                    mask = riscv_pkg::MSTATUS_UIE | riscv_pkg::MSTATUS_UPIE | riscv_pkg::MSTATUS_XS | riscv_pkg::MSTATUS64_WPRI;
                    mstatus_int      = csr_wdata & ~mask;
                    
                    // this register has side-effects on other registers, flush the pipeline
                    flush        = 1'b1;
                end
                // MISA is WARL (Write Any Value, Reads Legal Value)
                riscv_pkg::CSR_MISA:;
                // machine exception delegation register
                // 0 - 15 exceptions supported
                riscv_pkg::CSR_MEDELEG: begin
                    mask = (1 << riscv_pkg::INSTR_ADDR_MISALIGNED) |
                           (1 << riscv_pkg::BREAKPOINT) |
                           (1 << riscv_pkg::USER_ECALL) |
                           (1 << riscv_pkg::INSTR_PAGE_FAULT) |
                           (1 << riscv_pkg::LD_PAGE_FAULT) |
                           (1 << riscv_pkg::ST_AMO_PAGE_FAULT);
                    medeleg_d = (medeleg_q & ~mask) | (csr_wdata & mask);
                end
                // machine interrupt delegation register
                // we do not support user interrupt delegation
                riscv_pkg::CSR_MIDELEG: begin
                    mask = riscv_pkg::MIP_SSIP | riscv_pkg::MIP_STIP | riscv_pkg::MIP_SEIP;
                    mideleg_d = (mideleg_q & ~mask) | (csr_wdata & mask);
                end
                // mask the register so that unsupported interrupts can never be set
                riscv_pkg::CSR_MIE: begin
                    mask = riscv_pkg::MIP_SSIP | riscv_pkg::MIP_STIP | riscv_pkg::MIP_SEIP | riscv_pkg::MIP_MSIP | riscv_pkg::MIP_MTIP | riscv_pkg::MIP_MEIP;
                    mie_d = (mie_q & ~mask) | (csr_wdata & mask); // we only support supervisor and M-mode interrupts
                end

                riscv_pkg::CSR_MTVEC: begin
                    mtvec_d = {csr_wdata[63:2], 1'b0, csr_wdata[0]};
                    // we are in vector mode, this implementation requires the additional
                    // alignment constraint of 64 * 4 bytes
                    if (csr_wdata[0]) mtvec_d = {csr_wdata[63:8], 7'b0, csr_wdata[0]};
                end

                riscv_pkg::CSR_MCOUNTEREN:         mcounteren_d = {{32{1'b0}}, csr_wdata[31:0]};
                riscv_pkg::CSR_MSCRATCH:           mscratch_d  = csr_wdata;
                riscv_pkg::CSR_MEPC:               mepc_int    = {csr_wdata[63:1], 1'b0};
                riscv_pkg::CSR_MCAUSE:             mcause_int  = csr_wdata;
                riscv_pkg::CSR_MTVAL:              mtval_int   = csr_wdata;
                riscv_pkg::CSR_MIP: begin
                    mask = riscv_pkg::MIP_SSIP | riscv_pkg::MIP_STIP | riscv_pkg::MIP_SEIP;
                    mip_d = (mip_q & ~mask) | (csr_wdata & mask);
                end
                // performance counters
                riscv_pkg::CSR_MCYCLE:             cycle_d     = csr_wdata;
                riscv_pkg::CSR_MINSTRET:           instret_d     = csr_wdata;

                riscv_pkg::CSR_MHPM_COUNTER_3,
                riscv_pkg::CSR_MHPM_COUNTER_4,
                riscv_pkg::CSR_MHPM_COUNTER_5,
                riscv_pkg::CSR_MHPM_COUNTER_6,
                riscv_pkg::CSR_MHPM_COUNTER_7,
                riscv_pkg::CSR_MHPM_COUNTER_8,
                riscv_pkg::CSR_MHPM_COUNTER_9,
                riscv_pkg::CSR_MHPM_COUNTER_10,
                riscv_pkg::CSR_MHPM_COUNTER_11,
                riscv_pkg::CSR_MHPM_COUNTER_12,
                riscv_pkg::CSR_MHPM_COUNTER_13,
                riscv_pkg::CSR_MHPM_COUNTER_14,
                riscv_pkg::CSR_MHPM_COUNTER_15,
                riscv_pkg::CSR_MHPM_COUNTER_16,
                riscv_pkg::CSR_MHPM_COUNTER_17,
                riscv_pkg::CSR_MHPM_COUNTER_18,
                riscv_pkg::CSR_MHPM_COUNTER_19,
                riscv_pkg::CSR_MHPM_COUNTER_20,
                riscv_pkg::CSR_MHPM_COUNTER_21,
                riscv_pkg::CSR_MHPM_COUNTER_22,
                riscv_pkg::CSR_MHPM_COUNTER_23,
                riscv_pkg::CSR_MHPM_COUNTER_24,
                riscv_pkg::CSR_MHPM_COUNTER_25,
                riscv_pkg::CSR_MHPM_COUNTER_26,
                riscv_pkg::CSR_MHPM_COUNTER_27,
                riscv_pkg::CSR_MHPM_COUNTER_28,
                riscv_pkg::CSR_MHPM_COUNTER_29,
                riscv_pkg::CSR_MHPM_COUNTER_30,
                riscv_pkg::CSR_MHPM_COUNTER_31: begin
                    perf_we_o = 1'b1;
                    perf_data_o = csr_wdata;
                end

                riscv_pkg::CSR_MHPM_EVENT_3,
                riscv_pkg::CSR_MHPM_EVENT_4,
                riscv_pkg::CSR_MHPM_EVENT_5,
                riscv_pkg::CSR_MHPM_EVENT_6,
                riscv_pkg::CSR_MHPM_EVENT_7,
                riscv_pkg::CSR_MHPM_EVENT_8,
                riscv_pkg::CSR_MHPM_EVENT_9,
                riscv_pkg::CSR_MHPM_EVENT_10,
                riscv_pkg::CSR_MHPM_EVENT_11,
                riscv_pkg::CSR_MHPM_EVENT_12,
                riscv_pkg::CSR_MHPM_EVENT_13,
                riscv_pkg::CSR_MHPM_EVENT_14,
                riscv_pkg::CSR_MHPM_EVENT_15,
                riscv_pkg::CSR_MHPM_EVENT_16,
                riscv_pkg::CSR_MHPM_EVENT_17,
                riscv_pkg::CSR_MHPM_EVENT_18,
                riscv_pkg::CSR_MHPM_EVENT_19,
                riscv_pkg::CSR_MHPM_EVENT_20,
                riscv_pkg::CSR_MHPM_EVENT_21,
                riscv_pkg::CSR_MHPM_EVENT_22,
                riscv_pkg::CSR_MHPM_EVENT_23,
                riscv_pkg::CSR_MHPM_EVENT_24,
                riscv_pkg::CSR_MHPM_EVENT_25,
                riscv_pkg::CSR_MHPM_EVENT_26,
                riscv_pkg::CSR_MHPM_EVENT_27,
                riscv_pkg::CSR_MHPM_EVENT_28,
                riscv_pkg::CSR_MHPM_EVENT_29,
                riscv_pkg::CSR_MHPM_EVENT_30,
                riscv_pkg::CSR_MHPM_EVENT_31: begin
                    perf_we_o = 1'b1;
                    perf_data_o = csr_wdata;
                end

                riscv_pkg::CSR_CYCLE,
                riscv_pkg::CSR_TIME,
                riscv_pkg::CSR_INSTRET,
                riscv_pkg::CSR_HPM_COUNTER_3,
                riscv_pkg::CSR_HPM_COUNTER_4,
                riscv_pkg::CSR_HPM_COUNTER_5,
                riscv_pkg::CSR_HPM_COUNTER_6,
                riscv_pkg::CSR_HPM_COUNTER_7,
                riscv_pkg::CSR_HPM_COUNTER_8,
                riscv_pkg::CSR_HPM_COUNTER_9,
                riscv_pkg::CSR_HPM_COUNTER_10,
                riscv_pkg::CSR_HPM_COUNTER_11,
                riscv_pkg::CSR_HPM_COUNTER_12,
                riscv_pkg::CSR_HPM_COUNTER_13,
                riscv_pkg::CSR_HPM_COUNTER_14,
                riscv_pkg::CSR_HPM_COUNTER_15,
                riscv_pkg::CSR_HPM_COUNTER_16,
                riscv_pkg::CSR_HPM_COUNTER_17,
                riscv_pkg::CSR_HPM_COUNTER_18,
                riscv_pkg::CSR_HPM_COUNTER_19,
                riscv_pkg::CSR_HPM_COUNTER_20,
                riscv_pkg::CSR_HPM_COUNTER_21,
                riscv_pkg::CSR_HPM_COUNTER_22,
                riscv_pkg::CSR_HPM_COUNTER_23,
                riscv_pkg::CSR_HPM_COUNTER_24,
                riscv_pkg::CSR_HPM_COUNTER_25,
                riscv_pkg::CSR_HPM_COUNTER_26,
                riscv_pkg::CSR_HPM_COUNTER_27,
                riscv_pkg::CSR_HPM_COUNTER_28,
                riscv_pkg::CSR_HPM_COUNTER_29,
                riscv_pkg::CSR_HPM_COUNTER_30,
                riscv_pkg::CSR_HPM_COUNTER_31:
                    update_access_exception = 1'b1;

                riscv_pkg::CSR_MEM_MAP_0,
                riscv_pkg::CSR_MEM_MAP_1,
                riscv_pkg::CSR_MEM_MAP_2,
                riscv_pkg::CSR_MEM_MAP_3,
                riscv_pkg::CSR_MEM_MAP_4,
                riscv_pkg::CSR_MEM_MAP_5,
                riscv_pkg::CSR_MEM_MAP_6,
                riscv_pkg::CSR_MEM_MAP_7,
                riscv_pkg::CSR_MEM_MAP_8,
                riscv_pkg::CSR_MEM_MAP_9,
                riscv_pkg::CSR_MEM_MAP_10,                
                riscv_pkg::CSR_MEM_MAP_11,                
                riscv_pkg::CSR_MEM_MAP_12,                
                riscv_pkg::CSR_MEM_MAP_13,                
                riscv_pkg::CSR_MEM_MAP_14,                
                riscv_pkg::CSR_MEM_MAP_15,
                riscv_pkg::CSR_IO_MAP_0,
                riscv_pkg::CSR_IO_MAP_1,
                riscv_pkg::CSR_IO_MAP_2,
                riscv_pkg::CSR_IO_MAP_3,
                riscv_pkg::CSR_IO_MAP_4,
                riscv_pkg::CSR_IO_MAP_5,
                riscv_pkg::CSR_IO_MAP_6,
                riscv_pkg::CSR_IO_MAP_7,
                riscv_pkg::CSR_IO_MAP_8,
                riscv_pkg::CSR_IO_MAP_9,
                riscv_pkg::CSR_IO_MAP_10,
                riscv_pkg::CSR_IO_MAP_11,
                riscv_pkg::CSR_IO_MAP_12,
                riscv_pkg::CSR_IO_MAP_13,
                riscv_pkg::CSR_IO_MAP_14,
                riscv_pkg::CSR_IO_MAP_15,
                riscv_pkg::CSR_IRQ_MAP_0,
                riscv_pkg::CSR_IRQ_MAP_1,
                riscv_pkg::CSR_IRQ_MAP_2,
                riscv_pkg::CSR_IRQ_MAP_3,
                riscv_pkg::CSR_IRQ_MAP_4,
                riscv_pkg::CSR_IRQ_MAP_5,
                riscv_pkg::CSR_IRQ_MAP_6,
                riscv_pkg::CSR_IRQ_MAP_7,
                riscv_pkg::CSR_IRQ_MAP_8,
                riscv_pkg::CSR_IRQ_MAP_9,
                riscv_pkg::CSR_IRQ_MAP_10,
                riscv_pkg::CSR_IRQ_MAP_11,
                riscv_pkg::CSR_IRQ_MAP_12,
                riscv_pkg::CSR_IRQ_MAP_13,
                riscv_pkg::CSR_IRQ_MAP_14,
                riscv_pkg::CSR_IRQ_MAP_15,
                riscv_pkg::FROM_HOST,
                riscv_pkg::CSR_HYPERRAM_CONFIG, 
                riscv_pkg::CSR_SPI_CONFIG, 
                riscv_pkg::CSR_CNM_CONFIG,
                riscv_pkg::TO_HOST: begin
                                        pcr_req_data_o = csr_wdata;

                end

                riscv_pkg::CSR_PMPCFG_0:;
                riscv_pkg::CSR_PMPCFG_1:;
                riscv_pkg::CSR_PMPCFG_2:;
                riscv_pkg::CSR_PMPCFG_3:;

                riscv_pkg::CSR_PMPADDR_0:;
                riscv_pkg::CSR_PMPADDR_1:;
                riscv_pkg::CSR_PMPADDR_2:;
                riscv_pkg::CSR_PMPADDR_3:;
                riscv_pkg::CSR_PMPADDR_4:;
                riscv_pkg::CSR_PMPADDR_5:;
                riscv_pkg::CSR_PMPADDR_6:;
                riscv_pkg::CSR_PMPADDR_7:;
                riscv_pkg::CSR_PMPADDR_8:;
                riscv_pkg::CSR_PMPADDR_9:;
                riscv_pkg::CSR_PMPADDR_10:;
                riscv_pkg::CSR_PMPADDR_11:;
                riscv_pkg::CSR_PMPADDR_12:;
                riscv_pkg::CSR_PMPADDR_13:;
                riscv_pkg::CSR_PMPADDR_14:;
                riscv_pkg::CSR_PMPADDR_15:;
                default: update_access_exception = 1'b1;
            endcase
        end

        // assign the temporal value to _d values to avoid multiples assign in the same cicle
        mstatus_d   = mstatus_int;
        mstatus_d.wpri2 = 2'b11;
        mcause_d    = mcause_int;
        scause_d    = scause_int;
        mtval_d     = mtval_int;
        stval_d     = stval_int;
        mepc_d      = mepc_int;
        sepc_d      = sepc_int;

        // mark the floating point extension register as dirty 
        if (def_pkg::FP_PRESENT && (dirty_fp_state_csr)) begin
            mstatus_d.fs = riscv_pkg::Dirty;
        end
        // hardwire to zero if floating point extension is not present
        else if (!def_pkg::FP_PRESENT) begin
            mstatus_d.fs = riscv_pkg::Off;
        end


        // -----------------
        // Interrupt Control
        // -----------------
        // we decode an interrupt the same as an exception, hence it will be taken if the instruction did not
        // throw any previous exception.
        // we have three interrupt sources: external interrupts, software interrupts, timer interrupts (order of precedence)
        // for two privilege levels: Supervisor and Machine Mode
        
        interrupt_cause_d = interrupt_cause_q;
        interrupt_d = 1'b0;
        interrupt_cause = 64'b0;
        ex_tval = 64'b0;
        // Machine Mode External Interrupt
        if (mip_q[riscv_pkg::M_EXT_INTERRUPT[5:0]] && mie_q[riscv_pkg::M_EXT_INTERRUPT[5:0]]) begin
            interrupt_cause = riscv_pkg::M_EXT_INTERRUPT;
        end
        // Machine Mode Software Interrupt
        else if (mip_q[riscv_pkg::M_SW_INTERRUPT[5:0]] && mie_q[riscv_pkg::M_SW_INTERRUPT[5:0]]) begin
            interrupt_cause = riscv_pkg::M_SW_INTERRUPT;
        end
        // Machine Timer Interrupt
        else if (mip_q[riscv_pkg::M_TIMER_INTERRUPT[5:0]] && mie_q[riscv_pkg::M_TIMER_INTERRUPT[5:0]]) begin
            interrupt_cause = riscv_pkg::M_TIMER_INTERRUPT;
        end
        // Supervisor External Interrupt
        else if (mie_q[riscv_pkg::S_EXT_INTERRUPT[5:0]] && (mip_q[riscv_pkg::S_EXT_INTERRUPT[5:0]] || irq_i)) begin
            interrupt_cause = riscv_pkg::S_EXT_INTERRUPT;
        end
        // Supervisor Software Interrupt
        else if (mie_q[riscv_pkg::S_SW_INTERRUPT[5:0]] && mip_q[riscv_pkg::S_SW_INTERRUPT[5:0]]) begin
            interrupt_cause = riscv_pkg::S_SW_INTERRUPT;
        end
        // Supervisor Timer Interrupt
        else if (mie_q[riscv_pkg::S_TIMER_INTERRUPT[5:0]] && mip_q[riscv_pkg::S_TIMER_INTERRUPT[5:0]]) begin
            interrupt_cause = riscv_pkg::S_TIMER_INTERRUPT;
        end  
        
        // if the priv is different of M or the mie is 1, the interrups are enable
        global_enable = ((mstatus_q.mie & (priv_lvl_o == riscv_pkg::PRIV_LVL_M))
                                    | (priv_lvl_o != riscv_pkg::PRIV_LVL_M));

        if (interrupt_cause[63] && global_enable) begin
            // However, if bit i in mideleg is set, interrupts are considered to be globally enabled if the hart’s current privilege
            // mode equals the delegated privilege mode (S or U) and that mode’s interrupt enable bit
            // (SIE or UIE in mstatus) is set, or if the current privilege mode is less than the delegated privilege mode.
            if (mideleg_q[interrupt_cause[5:0]]) begin
                if ((mstatus_q.sie && priv_lvl_q == riscv_pkg::PRIV_LVL_S) || priv_lvl_q == riscv_pkg::PRIV_LVL_U) begin
                    interrupt_d = 1'b1;
                    interrupt_cause_d = interrupt_cause;
                end
            end else begin
                interrupt_d = 1'b1;
                interrupt_cause_d = interrupt_cause;
            end
        end
        
        // a sfence is executed and a flush is needed
        if (flush_sfence) begin
            flush = 1'b1;
        end
        flush_o = flush;

        //Output connection
        interrupt_o = interrupt_q;
        interrupt_cause_o = interrupt_cause_q;
        // -----------------------
        // Manage Exception Stack
        // -----------------------
        // update exception CSRs
        // we got an exception update cause, pc and stval register
        trap_to_priv_lvl = riscv_pkg::PRIV_LVL_M;
        // Exception is taken and we are not in debug mode
        // exceptions in debug mode don't update any fields
        
        if (((ex_cause_i != riscv_pkg::DEBUG_REQUEST) && ex_i) || csr_xcpt) begin
            // do not flush, flush is reserved for CSR writes with side effects
            flush_o   = 1'b0;
            ex_tval = {{24{pc_i[addr_width_extended-1]}},pc_i};
            //tval is the actual pc except for the data access exeptions
            if (ex_i && ex_cause_i inside {riscv_pkg::LD_ADDR_MISALIGNED, riscv_pkg::LD_ACCESS_FAULT, 
                                    riscv_pkg::ST_AMO_ADDR_MISALIGNED, riscv_pkg::ST_AMO_ACCESS_FAULT,
                                    riscv_pkg::LD_PAGE_FAULT, riscv_pkg::ST_AMO_PAGE_FAULT,
                                    riscv_pkg::INSTR_PAGE_FAULT}) begin
                ex_tval = w_data_core_i;
            end else if (ex_i && ex_cause_i == riscv_pkg::INSTR_ADDR_MISALIGNED) begin
                ex_tval = 64'b0; //TODO: mirar si es la seguent o la anterior
            end else if ((ex_i && ex_cause_i == riscv_pkg::ILLEGAL_INSTR) || (csr_xcpt && csr_xcpt_cause == riscv_pkg::ILLEGAL_INSTR)) begin
                ex_tval = 64'b0; //TODO: propagar instrucció
	    end else if (csr_xcpt && csr_xcpt_cause == riscv_pkg::BREAKPOINT) begin
                ex_tval = pc_i;
            end else begin
                ex_tval = 64'b0;
            end
            // figure out where to trap to
            // a m-mode trap might be delegated if we are taking it in S mode
            // first figure out if this was an exception or an interrupt e.g.: look at bit 63
            // the cause register can only be 6 bits long (as we only support 64 exceptions)
            if ((ex_i &&((ex_cause_i[63] && mideleg_q[ex_cause_i[5:0]]) ||
                (~ex_cause_i[63] && medeleg_q[ex_cause_i[5:0]]))) ||
                (csr_xcpt && ((csr_xcpt_cause[63] && mideleg_q[csr_xcpt_cause[5:0]]) ||
                (~csr_xcpt_cause[63] && medeleg_q[csr_xcpt_cause[5:0]])))) begin
                // traps never transition from a more-privileged mode to a less privileged mode
                // so if we are already in M mode, stay there
                trap_to_priv_lvl = (priv_lvl_o == riscv_pkg::PRIV_LVL_M) ? riscv_pkg::PRIV_LVL_M : riscv_pkg::PRIV_LVL_S;
            end

            // trap to supervisor mode
            if (trap_to_priv_lvl == riscv_pkg::PRIV_LVL_S) begin
                // update sstatus
                mstatus_d.sie  = 1'b0;
                mstatus_d.spie = mstatus_q.sie;
                // this can either be user or supervisor mode
                mstatus_d.spp  = priv_lvl_q[0];
                // set cause
                scause_d       = csr_xcpt ? csr_xcpt_cause : ex_cause_i;
                // set epc
                sepc_d         = {{24{pc_i[addr_width_extended-1]}},pc_i};
                // set mtval or stval
                // stval_d have a special case for a mecanisem of ariane. In DRAC stval_d = ex_i.tval.
                stval_d        = ex_tval;
            // trap to machine mode
            end else begin
                // update mstatus
                mstatus_d.mie  = 1'b0;
                mstatus_d.mpie = mstatus_q.mie;
                // save the previous privilege mode
                mstatus_d.mpp  = priv_lvl_q;
                mcause_d       = csr_xcpt ? csr_xcpt_cause : ex_cause_i;
                // set epc
                mepc_d         = {{24{pc_i[addr_width_extended-1]}},pc_i};
                // set mtval or stval
                // stval_d have a special case for a mecanisem of ariane. In DRAC stval_d = ex_i.tval.
                mtval_d        = ex_tval;
            end
            
            priv_lvl_d = trap_to_priv_lvl;
        end
        // ------------------------------
        // Return from Environment
        // ------------------------------
        // When executing an xRET instruction, supposing xPP holds the value y, xIE is set to xPIE; the privilege
        // mode is changed to y; xPIE is set to 1; and xPP is set to U
        else if (mret) begin
            // return from exception, IF doesn't care from where we are returning
            eret_o = 1'b1;
            // return to the previous privilege level and restore all enable flags
            // get the previous machine interrupt enable flag
            mstatus_d.mie  = mstatus_q.mpie;
            // restore the previous privilege level
            priv_lvl_d     = mstatus_q.mpp;
            // set mpp to user mode
            mstatus_d.mpp  = riscv_pkg::PRIV_LVL_U;
            // set mpie to 1
            mstatus_d.mpie = 1'b1;
        end else if (sret && !(priv_lvl_q == riscv_pkg::PRIV_LVL_S && mstatus_q.tsr == 1'b1)) begin
            // return from exception, IF doesn't care from where we are returning
            eret_o = 1'b1;
            // return the previous supervisor interrupt enable flag
            mstatus_d.sie  = mstatus_q.spie;
            // restore the previous privilege level
            priv_lvl_d     = riscv_pkg::priv_lvl_t'({1'b0, mstatus_q.spp});
            // set spp to user mode
            mstatus_d.spp  = 1'b0;
            // set spie to 1
            mstatus_d.spie = 1'b1;
        end

        // ------------------------------
        // MPRV - Modify Privilege Level
        // ------------------------------
        // Set the address translation at which the load and stores should occur
        // we can use the previous values since changing the address translation will always involve a pipeline flush
        if (mprv && satp_q.mode == def_pkg::MODE_SV39 && (mstatus_q.mpp != riscv_pkg::PRIV_LVL_M))
            en_ld_st_translation_d = 1'b1;
        else // otherwise we go with the regular settings
            en_ld_st_translation_d = en_translation_o; //TODO
            //ld_st_priv_lvl_o = (mprv) ? mstatus_q.mpp : priv_lvl_o;//TODO
            //en_ld_st_translation_o = en_ld_st_translation_q;//TODO
        //end
	
	ld_st_priv_lvl_o = (mprv) ? mstatus_q.mpp : priv_lvl_o;//TODO
	en_ld_st_translation_o = en_ld_st_translation_q;//TODO
        
    end

    assign csr_tval_o = ex_tval;

    // ---------------------------
    // CSR OP Select Logic
    // ---------------------------
    always_comb begin : csr_op_logic
        flush_sfence = 1'b0;
        csr_wdata = w_data_core_i;
        csr_we    = 1'b1;
        csr_read  = 1'b1;
        mret      = 1'b0;
        sret      = 1'b0;

        unique case (rw_cmd_i)
            3'b001: csr_wdata = w_data_core_i;                // Write
            3'b010: csr_wdata = w_data_core_i | csr_rdata;    // Set
            3'b011: csr_wdata = (~w_data_core_i) & csr_rdata; // Clear
            3'b101: csr_we    = 1'b0;                         // Read
            default: begin
                csr_we   = 1'b0;
                csr_read = 1'b0;
            end
        endcase
        if (insn_sret) begin
            // the return should not have any write or read side-effects
            sret     = 1'b1; // signal a return from supervisor mode
        end else if (insn_mret) begin
            // the return should not have any write or read side-effects
            mret     = 1'b1; // signal a return from machine mode
        end else if (insn_sfence_vm) begin // flush_o can not be changed here, it changes in csr_update process
            flush_sfence = 1'b1;
        end
        // if we are violating our privilges do not update the architectural state
        if (privilege_violation) begin
            csr_we = 1'b0;
            csr_read = 1'b0;
        end
    end

    // -----------------
    // Privilege Check
    // -----------------
    always_comb begin : privilege_check
        privilege_violation = 1'b0;
        // if we are reading or writing, check for the correct privilege level this has
        // precedence over interrupts
        if (rw_cmd_i inside {3'b001, 3'b010, 3'b011, 3'b101}) begin // inside of: write, set, clear, read
            if ((riscv_pkg::priv_lvl_t'(priv_lvl_o & csr_addr.csr_decode.priv_lvl) != csr_addr.csr_decode.priv_lvl)) begin
                privilege_violation = 1'b1;
            end
            // check access to debug mode only CSRs 
            if (rw_addr_i[11:4] == 8'h7b ) begin
                privilege_violation = 1'b1;
            end
            if (csr_addr.address inside {[riscv_pkg::CSR_CYCLE:riscv_pkg::CSR_HPM_COUNTER_31]}) begin
                unique case (priv_lvl_o)
                    riscv_pkg::PRIV_LVL_M: privilege_violation = 1'b0;
                    riscv_pkg::PRIV_LVL_S: privilege_violation = ~mcounteren_q[csr_addr.address[4:0]];
                    riscv_pkg::PRIV_LVL_U: privilege_violation = ~mcounteren_q[csr_addr.address[4:0]] & ~scounteren_q[csr_addr.address[4:0]];
                endcase
            end
        end
        //checks the level of the system instruction or sfence with tvm = 1 or sret and tsr = 1
        if (system_insn && !priv_sufficient || insn_sfence_vm && priv_lvl_q == riscv_pkg::PRIV_LVL_S && mstatus_q.tvm == 1'b1
            || insn_sret && priv_lvl_q == riscv_pkg::PRIV_LVL_S && mstatus_q.tsr == 1'b1) begin
             privilege_violation = 1'b1;
        end
    end

    // ----------------------
    // CSR Exception Control
    // ----------------------
    assign csr_xcpt_o = csr_xcpt;
    assign csr_xcpt_cause_o = csr_xcpt_cause;
    assign tval_o = ex_tval;

    always_comb begin : exception_ctrl
        csr_xcpt_cause = 64'b0;
        csr_xcpt = 1'b0;
        // ----------------------------------
        // Illegal Access (decode exception)
        // ----------------------------------
        // we got an exception in one of the processes above
        // throw an illegal instruction exception
        if (update_access_exception || read_access_exception) begin
            csr_xcpt_cause = riscv_pkg::ILLEGAL_INSTR;
            // we don't set the tval field as this will be set by the commit stage
            // this spares the extra wiring from commit to CSR and back to commit
            csr_xcpt = 1'b1;
        end else if (privilege_violation) begin
          csr_xcpt_cause = riscv_pkg::ILLEGAL_INSTR;
          csr_xcpt = 1'b1;
        end else if (insn_call) begin
            csr_xcpt_cause = riscv_pkg::USER_ECALL + priv_lvl_q;
            csr_xcpt = 1'b1;
        end else if (insn_break) begin
            csr_xcpt_cause = riscv_pkg::BREAKPOINT;
            csr_xcpt = 1'b1;
        end else if (insn_wfi && mstatus_q.tw) begin
            csr_xcpt_cause = riscv_pkg::ILLEGAL_INSTR;
            csr_xcpt = 1'b1;
        end
    end

    // -------------------
    // Wait for Interrupt
    // -------------------
    always_comb begin : wfi_ctrl
        // wait for interrupt register
        wfi_d = wfi_q;
        // if there is any interrupt pending un-stall the core
        if (|mip_q || irq_i) begin
            wfi_d = 1'b0;
        // or alternatively if there is no exception pending and we are not in debug mode wait here
        // for the interrupt
        end else if (insn_wfi && !ex_i) begin
            wfi_d = 1'b1;
        end
    end

    // -------------------
    // Vector instruccions excecution
    // -------------------
    always_comb begin : vsetvl_ctrl
        vtype_new = rw_addr_i[10:0];
        // new vlmax depending on the vtype config
        vlmax = ((VLEN << vtype_new[1:0]) >> 3) >> vtype_new[4:2];
        if (vsetvl_insn) begin
            // vl assignation depending on the AVL respect VLMAX
            if (rw_cmd_i == 3'b111) begin //vsetvl with x0
                if (w_data_core_i == 64'b1) begin
                    vl_d = vl_q;
                end else begin
                    vl_d = vlmax;
                end
            end else if (vlmax >= w_data_core_i) begin
                vl_d = w_data_core_i;
            end else if ((vlmax<<1) >= w_data_core_i) begin
                vl_d = w_data_core_i>>1 + w_data_core_i[0];
            end else begin
                vl_d = vlmax;
            end
            // vtype assignation
            if (vtype_new[10:4] != 6'b0) begin
                vtype_d = {1'b1,63'b0};
            end else begin
                vtype_d = {'0,vtype_new};
            end                
        end else  begin
            // default, keeps the old value
            vl_d = vl_q;
            vtype_d = vtype_q;
        end
    end

    assign vpu_csr_o = {vtype_q[63], vtype_q[4:0], fcsr_q[7:5], 2'b0, vl_q[14:0], 14'b0};

    // -------------------
    // PCR contol logic
    // -------------------

    always_comb begin : pcr_ctrl
        //whait until a response from the pcs
        cpu_ren = 1'b0;
        pcr_wait_resp_d = pcr_wait_resp_q;

        // determine if the cpu requests a read of a csr
        if (rw_cmd_i inside {3'b001, 3'b010, 3'b011, 3'b101}) begin //write, set, clear, read
            cpu_ren = 1'b1;
        end

        // requests to pcr are valid when the pcr is ready, there aren't any exceptions and the 
        pcr_req_valid = cpu_ren & pcr_addr_valid & priv_sufficient & ~csr_xcpt & ~pcr_wait_resp_d;
        

        if (pcr_req_valid && (!pcr_resp_valid_i || pcr_resp_core_id_i != core_id )) pcr_wait_resp_d = 1'b1;
        else if (pcr_resp_valid_i && pcr_resp_core_id_i == core_id) pcr_wait_resp_d = 1'b0;
        
        //pcr requests outputs connections
        pcr_req_addr_o = csr_addr;
        pcr_req_we_o = rw_cmd_i;
        pcr_req_core_id_o = core_id;
        pcr_req_valid_o = pcr_req_valid;
    end

    // -------------------
    // CPU actions induced by the csr
    // -------------------
    assign csr_replay_o = pcr_req_valid & !pcr_req_ready_i; // pcr write but not ready
    assign csr_stall_o = wfi_q | // or waiting pcr response 
                  (pcr_wait_resp_d & (~pcr_resp_valid_i | pcr_resp_core_id_i != core_id));


    // output assignments dependent on privilege mode
    always_comb begin : priv_output
        // vectorized trap addres
        trap_vector_base[63:8] = mtvec_q[63:8];
        trap_vector_base[7:2] = (mtvec_q[1:0] == 2'b0 || csr_xcpt || !ex_cause_i[63]) ? mtvec_q[7:2] : csr_xcpt ? (mtvec_q[7:2] + csr_xcpt_cause[5:0]) : (mtvec_q[7:2] + ex_cause_i[5:0]);
        trap_vector_base[1:0] = 2'b0;
        // output user mode stvec
        if (trap_to_priv_lvl == riscv_pkg::PRIV_LVL_S) begin
            // vectorized trap addres
            trap_vector_base[63:8] = stvec_q[63:8];
            trap_vector_base[7:2] = (stvec_q[1:0] == 2'b0 || csr_xcpt || !ex_cause_i[63]) ? stvec_q[7:2] : csr_xcpt ? (mtvec_q[7:2] + csr_xcpt_cause[5:0]) : (mtvec_q[7:2] + ex_cause_i[5:0]);
            trap_vector_base[1:0] = 2'b0;
        end

        evec_o = mepc_q; // we are returning from machine mode, so take the mepc register
        
        if (ex_i || csr_xcpt_o) begin // an exception is detected in the core and it is send the trap address
            evec_o = trap_vector_base;
        end else if (sret) begin // we are returning from supervisor mode, so take the sepc register
            evec_o = sepc_q;
        end
    end

    // -------------------
    // Output Assignments
    // -------------------
    always_comb begin
        // When the SEIP bit is read with a CSRRW, CSRRS, or CSRRC instruction, the value
        // returned in the rd destination register contains the logical-OR of the software-writable
        // bit and the interrupt signal from the interrupt controller.
	if (vsetvl_insn) begin
        	r_data_core_o = vl_d;
	end else begin
		r_data_core_o = csr_rdata;
        	unique case (csr_addr.address)
        	    riscv_pkg::CSR_MIP: r_data_core_o = csr_rdata | ({63'b0,irq_i} << riscv_pkg::IRQ_S_EXT);
        	    // in supervisor mode we also need to check whether we delegated this bit
        	    riscv_pkg::CSR_SIP: begin
        	        r_data_core_o = csr_rdata
        	                    | ({63'b0,(irq_i & mideleg_q[riscv_pkg::IRQ_S_EXT])} << riscv_pkg::IRQ_S_EXT);
        	    end
                default:;
                endcase
	end
    end
    // fcrs assigments
    assign status_o = mstatus_q;
    // in debug mode we execute with privilege level M
    assign priv_lvl_o       = priv_lvl_q;
    // FPU outputs

    assign fcsr_rm_o        = fcsr_q.frm;
    assign fcsr_fs_o        = mstatus_q.fs;

    // MMU outputs 
    assign satp_ppn_o       = satp_q.ppn;

    // we support bare memory addressing and SV39
    assign en_translation_o = (satp_q.mode == 4'h8 && priv_lvl_o != riscv_pkg::PRIV_LVL_M)
                              ? 1'b1
                              : 1'b0;

    // mprv assignation
    assign mprv             = mstatus_q.mprv;

    // timer output assign
    assign reg_time_d = time_i;

    // sequential process
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (!rstn_i) begin
            priv_lvl_q             <= riscv_pkg::PRIV_LVL_M;
            // floating-point registers
            fcsr_q                 <= 64'b0;
            // machine mode registers
            mstatus_q              <= 64'b011000000000;
            // set to boot address + direct mode + 4 byte offset which is the initial trap
            mtvec_rst_load_q       <= 1'b1;
            mtvec_q                <= 64'b0;
            medeleg_q              <= 64'b0;
            mideleg_q              <= 64'b0;
            mip_q                  <= 64'b0;
            mie_q                  <= 64'b0;
            mepc_q                 <= 64'b0;
            mcause_q               <= 64'b0;
            mcounteren_q           <= 64'b0;
            mscratch_q             <= 64'b0;
            mtval_q                <= 64'b0;
            // supervisor mode registers
            sepc_q                 <= 64'b0;
            scause_q               <= 64'b0;
            stvec_q                <= 64'b0;
            scounteren_q           <= 64'b0;
            sscratch_q             <= 64'b0;
            stval_q                <= 64'b0;
            satp_q                 <= 64'b0;
            // timer and counters
            cycle_q                <= 64'b0;
            instret_q              <= 64'b0;
            // aux registers
            en_ld_st_translation_q <= 1'b0;
            // wait for interrupt
            wfi_q                  <= 1'b0;
            //PCR assigments
            pcr_wait_resp_q <= 1'b0;
            reg_time_q <= 64'b0;

            //Interrupt assigments
            interrupt_q <= 1'b0;
            interrupt_cause_q <= 64'b0;

            // Vector extension
            vl_q              <= 64'b0;
            vtype_q           <= {1'b1, 63'b0};
        end else begin
            priv_lvl_q             <= priv_lvl_d;
            // floating-point registers
            fcsr_q                 <= fcsr_d;
            // machine mode registers
            mstatus_q              <= mstatus_d;
            mtvec_rst_load_q       <= 1'b0;
            mtvec_q                <= mtvec_d;
            medeleg_q              <= medeleg_d;
            mideleg_q              <= mideleg_d;
            mip_q                  <= mip_d;
            mie_q                  <= mie_d;
            mepc_q                 <= mepc_d;
            mcause_q               <= mcause_d;
            mcounteren_q           <= mcounteren_d;
            mscratch_q             <= mscratch_d;
            mtval_q                <= mtval_d;
            // supervisor mode registers
            sepc_q                 <= sepc_d;
            scause_q               <= scause_d;
            stvec_q                <= stvec_d;
            scounteren_q           <= scounteren_d;
            sscratch_q             <= sscratch_d;
            stval_q                <= stval_d;
            satp_q                 <= satp_d;
            // timer and counters
            cycle_q                <= cycle_d;
            instret_q              <= instret_d;
            // aux registers
            en_ld_st_translation_q <= en_ld_st_translation_d;
            // wait for interrupt
            wfi_q                  <= wfi_d;
            // PCR assigments
            pcr_wait_resp_q <= pcr_wait_resp_d;
            reg_time_q <= reg_time_d; 

            //Interrupt assigments
            interrupt_q <= interrupt_d;
            interrupt_cause_q <= interrupt_cause_d;

            // Vector extension
            vl_q                    <= vl_d;
            vtype_q                 <= vtype_d;
        end
    end

    //-------------
    // Assertions
    //-------------
    //pragma translate_off
    `ifndef VERILATOR
        // check that eret and ex are never valid together
        assert property (
          @(posedge clk_i) !(eret_o && ex_i))
        else begin $error("eret and exception should never be valid at the same time"); $stop(); end
    `endif
    //pragma translate_on
endmodule
