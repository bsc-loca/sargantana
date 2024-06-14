/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_icache_interface.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/
package drac_pkg;

import riscv_pkg::*;

// Address size
`ifdef MEEP_SHELL
    `include "cincoranch_proto_config.v"
`endif

`ifndef CONF_SARGANTANA_PHY_ADDR_SIZE
    `define CONF_SARGANTANA_PHY_ADDR_SIZE 32
`endif
parameter PHY_ADDR_SIZE = `CONF_SARGANTANA_PHY_ADDR_SIZE;

parameter VIRT_ADDR_SIZE = 39;
parameter PHY_VIRT_MAX_ADDR_SIZE = (PHY_ADDR_SIZE < VIRT_ADDR_SIZE) ? VIRT_ADDR_SIZE : PHY_ADDR_SIZE;

parameter PHISIC_MEM_LIMIT = (64'h01 << PHY_ADDR_SIZE) - 64'h01; 

parameter ICACHE_IDX_BITS_SIZE = 12;
parameter ICACHE_VPN_BITS_SIZE = PHY_VIRT_MAX_ADDR_SIZE - ICACHE_IDX_BITS_SIZE;

parameter ICACHELINE_SIZE = 512;
parameter DATA_SIZE = 64;
parameter VELEMENTS = riscv_pkg::VLEN/DATA_SIZE;
parameter logic [6:0] VMAXELEM = riscv_pkg::VLEN/8;
parameter VMAXELEM_LOG = $clog2(VMAXELEM);
// TODO (Arnau): I don't think this is the best way of implementing this, but
//               making it fully parametrizable would introduce a *lot* of changes...
//               But at least it's better than having it hardcoded.
`ifdef CONF_SARGANTANA_DCACHE_BUS_WIDTH
parameter DCACHE_BUS_WIDTH = `CONF_SARGANTANA_DCACHE_BUS_WIDTH;
`elsif CONF_HPDCACHE_REQ_WORDS
parameter DCACHE_BUS_WIDTH = `CONF_HPDCACHE_REQ_WORDS * 64;
`else
parameter DCACHE_BUS_WIDTH = 10'd512;
`endif
parameter logic [6:0] DCACHE_MAXELEM = DCACHE_BUS_WIDTH/8;
parameter DCACHE_MAXELEM_LOG = $clog2(DCACHE_MAXELEM);
parameter REGFILE_WIDTH = 5;
parameter VREGFILE_WIDTH = 5;
parameter CSR_ADDR_SIZE = 12;
parameter CSR_CMD_SIZE = 4;
parameter NUM_SCALAR_WB = 4;
parameter NUM_FP_WB = 2;
parameter NUM_SIMD_WB = 2;
parameter HPM_NUM_EVENTS = 40;
parameter HPM_NUM_COUNTERS = 29;

// RISCV
//parameter OPCODE_WIDTH = 6;
//parameter REG_WIDTH = 5;

typedef reg   [riscv_pkg::VLEN-1:0] reg_simd_t;
typedef reg   [63:0]  reg64_t;
typedef logic [riscv_pkg::VLEN-1:0] bus_simd_t;
typedef logic [(riscv_pkg::VLEN/8)-1:0] bus_mask_t;
typedef logic [DCACHE_BUS_WIDTH-1:0] bus_dcache_data_t;
typedef logic [127:0] bus128_t;
typedef logic [63:0]  bus64_t;
typedef logic [31:0]  bus32_t;

typedef logic [REGFILE_WIDTH-1:0] reg_t;
typedef logic [VREGFILE_WIDTH-1:0] vreg_t;
typedef reg   [riscv_pkg::XLEN-1:0] regPC_t;
typedef logic [riscv_pkg::XLEN-1:0] addrPC_t;
typedef logic [PHY_VIRT_MAX_ADDR_SIZE-1:0] addr_t;
typedef logic [PHY_ADDR_SIZE-1:0] phy_addr_t;
typedef reg   [PHY_VIRT_MAX_ADDR_SIZE-1:0] reg_addr_t;
typedef logic [CSR_ADDR_SIZE-1:0] csr_addr_t;
typedef reg   [CSR_ADDR_SIZE-1:0] reg_csr_addr_t;
//typedef logic [CSR_CMD_SIZE-1:0] csr_cmd_t;
//typedef reg   [CSR_CMD_SIZE-1:0] reg_csr_cmd_t;

typedef logic [riscv_pkg::INST_SIZE-1:0] inst_t;
typedef logic [ICACHELINE_SIZE-1:0] icache_line_t;
typedef reg   [ICACHELINE_SIZE-1:0] icache_line_reg_t;
typedef logic [ICACHE_IDX_BITS_SIZE-1:0] icache_idx_t;
typedef logic [ICACHE_VPN_BITS_SIZE-1:0] icache_vpn_t;


// Instruction Queue
parameter INSTRUCTION_QUEUE_NUM_ENTRIES = 16;

// Physical registers 
parameter NUM_PHISICAL_REGISTERS = 64;
parameter PHISICAL_REGFILE_WIDTH = 6;
typedef logic [PHISICAL_REGFILE_WIDTH-1:0] phreg_t;

// Physical vector registers
parameter NUM_PHISICAL_VREGISTERS = 64;
parameter PHISICAL_VREGFILE_WIDTH = 6;
typedef logic [PHISICAL_VREGFILE_WIDTH-1:0] phvreg_t;

// Physical fp registers 
parameter NUM_PHYSICAL_FREGISTERS = 64;
parameter PHYSICAL_FREGFILE_WIDTH = 6;
typedef logic [PHYSICAL_FREGFILE_WIDTH-1:0] phfreg_t;

// Register checkpointing
parameter NUM_CHECKPOINTS = 4;
typedef logic [$clog2(NUM_CHECKPOINTS)-1:0] checkpoint_ptr;

// Graduation List
typedef logic [4:0] gl_index_t;

// Branch predictor
// Least significative bit from address used to index
parameter LEAST_SIGNIFICATIVE_INDEX_BIT_BP = 2;

// Most significative bit from address used to index
parameter MOST_SIGNIFICATIVE_INDEX_BIT_BP = 8;

// Load Store Queue
parameter LSQ_NUM_ENTRIES = 8;

// Pending Mem Request Queue
parameter PMRQ_NUM_ENTRIES = 16;
parameter PFPQ_NUM_ENTRIES = 8;

// Store buffer size 
parameter ST_BUF_NUM_ENTRIES = 8;

// SIMD
typedef logic [$clog2(VELEMENTS)-1:0] fu_id_t;

localparam NrMaxRules = 16;

typedef struct packed {  
    int                                   NIOSections;
    logic [NrMaxRules-1:0][PHY_ADDR_SIZE-1:0] InitIOBase;
    logic [NrMaxRules-1:0][PHY_ADDR_SIZE-1:0] InitIOEnd;
  
    int                                   NMappedSections;
    logic [NrMaxRules-1:0][PHY_ADDR_SIZE-1:0] InitMappedBase;
    logic [NrMaxRules-1:0][PHY_ADDR_SIZE-1:0] InitMappedEnd;

    logic [PHY_ADDR_SIZE-1:0] InitBROMBase;
    logic [PHY_ADDR_SIZE-1:0] InitBROMEnd;

    logic [PHY_ADDR_SIZE-1:0] DebugProgramBufferBase;
    logic [PHY_ADDR_SIZE-1:0] DebugProgramBufferEnd;
} drac_cfg_t;

function automatic logic range_check(addr_t start_region, addr_t end_region, bus64_t address);
    // if len is a power of two, and base is properly aligned, this check could be simplified
    return (address >= {{{64-PHY_VIRT_MAX_ADDR_SIZE}{1'b0}}, start_region}) && (address < {{{64-PHY_VIRT_MAX_ADDR_SIZE}{1'b0}}, end_region});
endfunction : range_check

function automatic logic is_inside_IO_sections (drac_cfg_t Cfg, bus64_t address);
    // if we don't specify any region we assume everything is accessible
    logic[NrMaxRules-1:0] pass;
    pass = '0;
    for (int unsigned k = 0; k < Cfg.NIOSections; k++) begin
        pass[k] = range_check(Cfg.InitIOBase[k], Cfg.InitIOEnd[k], address);
    end
    return |pass;
endfunction : is_inside_IO_sections

function automatic logic is_inside_mapped_sections (drac_cfg_t Cfg, bus64_t address);
    // if we don't specify any region we assume everything is accessible
    logic[NrMaxRules-1:0] pass;
    pass = '0;
    for (int unsigned k = 0; k < Cfg.NMappedSections; k++) begin
        pass[k] = range_check(Cfg.InitMappedBase[k], Cfg.InitMappedEnd[k], address);
    end
    return |pass;
endfunction : is_inside_mapped_sections

typedef enum logic [1:0] {
    NEXT_PC_SEL_BP_OR_PC_4  = 2'b00,
    NEXT_PC_SEL_KEEP_PC     = 2'b01,
    NEXT_PC_SEL_JUMP        = 2'b10,
    NEXT_PC_SEL_DEBUG       = 2'b11
} next_pc_sel_t;    // Enum PC Selection


typedef enum logic [1:0] {
    NOT_MEM  = 2'b00,
    LOAD     = 2'b01,
    STORE    = 2'b10,
    AMO      = 2'b11
} mem_type_t; 

typedef enum logic [2:0] {
    SEL_JUMP_EXECUTION = 3'b000,
    SEL_JUMP_CSR       = 3'b001,
    SEL_JUMP_DECODE    = 3'b010,
    SEL_JUMP_DEBUG     = 3'b011,
    SEL_JUMP_CSR_RW    = 3'b100
} jump_addr_fetch_t;

typedef enum logic [1:0]{
    TLBMiss    = 2'b00,
    NoReq      = 2'b01,
    ReqValid   = 2'b10,
    Replay     = 2'b11
} icache_state_t;   // Enum Icache Interface Machine

typedef enum logic {
    PRED_NOT_TAKEN,
    PRED_TAKEN
} branch_pred_decision_t;   // Enum Branch Prediction resolution

typedef enum logic[1:0] {
    SEW_8  = 2'b00,
    SEW_16 = 2'b01,
    SEW_32 = 2'b10,
    SEW_64 = 2'b11
} sew_t;

typedef enum logic[1:0] {
    RNU_V = 2'b00,
    RNE_V = 2'b01,
    RDN_V = 2'b10,
    ROD_V = 2'b11
} vxrm_t;

typedef struct packed {
    logic is_branch;                    // Was predicted to be branch
    branch_pred_decision_t decision;    // Taken or not taken
    addrPC_t pred_addr;                 // Predicted Address
} branch_pred_t;            // Struct for Branch Prediction

typedef struct packed {
    riscv_pkg::exception_cause_t cause; // Cause of exception vector 64 bits
    bus64_t origin; // Addr or PC generating exception
    logic valid;    // There is an eception
} exception_t;      // Struct contains exceptions

typedef struct packed {
    addrPC_t        pc_execution;              // Program counter at Execution Stage
    addrPC_t        branch_addr_result_exe;    // Final address generated by branch in Execution Stage (for RAS push as well)
    addrPC_t        branch_addr_target_exe;    // Target address generated by branch in Execution Stage (for RAS push as well)
    logic           branch_taken_result_exe;   // Taken or not taken branch result in Execution Stage
    logic           is_branch_exe;             // The instruction in the Execution Stage is a branch
} exe_if_branch_pred_t;

// Response coming from ICache
typedef struct packed {
    logic   valid;               // Response valid
    inst_t  data;                // Word of 32 bits from Icache
    logic   instr_page_fault;    // Page Fault from TLB
} resp_icache_cpu_t;

// Request send to ICache
typedef struct packed {
    logic   valid;               // Request valid
    addr_t  vaddr;               // Virtual Addr requested
    logic   invalidate_icache;   // Petition to invalidate cache content
    logic   invalidate_buffer;   // Petition to invalidate buffer, which also serves as repeat the req
    logic   inval_fetch;         //
} req_cpu_icache_t;

typedef enum logic [2:0] {
    SEL_SRC1_REGFILE,           // Source one from register file
    SEL_SRC2_REGFILE,           // Source two from register file
    SEL_IMM,                    // Immediate from decode
    SEL_PC,                     // Select PC
    SEL_PC_4,                   // Select PC + 4
    SEL_BYPASS                  // Select bypass from previous stage
} alu_sel_t;        // ALU Source Selection

typedef enum logic [3:0]{
    UNIT_ALU,                   // Select ALU
    UNIT_DIV,                   // Select DIVISION
    UNIT_MUL,                   // Select MULTIPLICATION
    UNIT_BRANCH,                // Select Branch computation
    UNIT_MEM,                   // Select Memory unit
    UNIT_SIMD,                  // Select SIMD
    UNIT_FPU,                   // Select FPU
    UNIT_CONTROL,               // Select CONTROL
    UNIT_SYSTEM                // Select CSR
} functional_unit_t;   // Selection of funtional unit in exe stage 

typedef enum logic [1:0]{
    SEL_FROM_MEM,               // Select source from Memory
    SEL_FROM_ALU,               // Select source from ALU
    SEL_FROM_BRANCH,            // Select source from Branch computation
    SEL_FROM_CONTROL            // Select source from control
} reg_sel_t;          // Selection of the result from functional unit 

typedef enum logic [1:0]{
    SCALAR_RF,     // Select scalar regfile
    FPU_RF,        // Select fpu regfile
    SIMD_RF        // Select simd regfile
} regfile_sel_t;

typedef enum logic [8:0] { 
    // basic ALU op
   ADD, SUB, ADDW, SUBW,
   // logic operations
   XOR_INST, OR_INST, AND_INST,
   // shifts
   SRA, SRL, SLL, SRLW, SLLW, SRAW,
   // comparisons
   BLT, BLTU, BGE, BGEU, BEQ, BNE,
   // jumps
   JALR, JAL,
   // set lower than operations
   SLT, SLTU,
   // CSR functions
   MRET, SRET, URET, ECALL, EBREAK, WFI, FENCE, FENCE_I, SFENCE_VMA, VSETVL, VSETVLI, VSETIVLI,
   // Old ISA CSR functions
   ERET, MRTS, MRTH, HRTS,
   //CSR_WRITE, CSR_READ, CSR_SET, CSR_CLEAR,
   CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI,
   // LSU functions
   LD, SD, LW, LWU, SW, LH, LHU, SH, LB, SB, LBU,
   // Atomic Memory Operations
   AMO_LRW, AMO_LRD, AMO_SCW, AMO_SCD,
   AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW, AMO_XORW, AMO_MAXW, AMO_MAXWU, AMO_MINW, AMO_MINWU,
   AMO_SWAPD, AMO_ADDD, AMO_ANDD, AMO_ORD, AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND, AMO_MINDU,
   // Multiplications
   MUL, MULH, MULHU, MULHSU, MULW,
   // Divisions
   DIV, DIVU, DIVW, DIVUW, REM, REMU, REMW, REMUW,
   // Floating-Point Load and Store Instructions
   FLD, FLW, FSD, FSW, // FLH, FLB, FSD, FSW, FSH, FSB,
   // Floating-Point Computational Instructions
   FADD, FSUB, FMUL, FDIV, FMIN_MAX, FSQRT, FMADD, FMSUB, FNMSUB, FNMADD,
   // Floating-Point Conversion and Move Instructions
   FCVT_F2I, FCVT_I2F, FCVT_F2F, FSGNJ, FMV_F2X, FMV_X2F,
   // Floating-Point Compare Instructions
   FCMP,
   // Floating-Point Classify Instruction
   FCLASS,
   // Vectorial Floating-Point Instructions that don't directly map onto the scalar ones
   VFMIN, VFMAX, VFSGNJ, VFSGNJN, VFSGNJX, VFEQ, VFNE, VFLT, VFGE, VFLE, VFGT, VFCPKAB_S, VFCPKCD_S, VFCPKAB_D, VFCPKCD_D,
   // Vectorial Instructions
   VADD, VSUB, VRSUB, VMIN, VMINU, VMAX, VMAXU, VAND, VOR, VXOR, VMSEQ, VMSNE, VMSLTU, VMSLT, VMSLEU, VMSLE, VMSGTU, VMSGT, VSADD, VSADDU, VSSUB, VSSUBU, VWADD, VWADDU, VWSUB, VWSUBU, VWADDW, VWADDUW, VWSUBW, VWSUBUW, VSLL, VSRA, VSRL, VNSRL, VNSRA, VMERGE, VMV, VMV1R, VEXT, VMV_X_S, VMV_S_X, VMUL, VMULH, VMULHU, VMULHSU,
   VMADD, VNMSUB, VMACC, VNMSAC, VADC, VMADC, VSBC, VMSBC, VWMUL, VWMULU, VWMULSU, VWMACC, VWMACCU, VWMACCUS, VWMACCSU, VAADD, VAADDU, VASUB, VASUBU,
   //Vector Integer Extension
   VZEXT_VF2, VSEXT_VF2, VZEXT_VF4, VSEXT_VF4, VZEXT_VF8, VSEXT_VF8,
   // Vector Mask Instructions
   VMAND, VMNAND, VMANDN, VMOR, VMNOR, VMORN, VMXNOR, VMXOR, VID, VPOPC, VIOTA, VFIRST, VMSBF, VMSIF, VMSOF,
   // Vectorial Reduction Instructions
   VREDSUM, VREDAND, VREDOR, VREDXOR, VREDMAX, VREDMAXU, VREDMIN, VREDMINU,
   //Vectorial Permutation Instructions
   //Forood: to add the pre implemented instructions too
   VSLIDEUP, VSLIDEDOWN, VSLIDE1UP, VSLIDE1DOWN, VRGATHER, VRGATHEREI16, VCOMPRESS,
   // Vectorial FP instructions
   VFADD, VFMV,
   // Vectorial memory operations
   VLE, VLM, VL1R, VSE, VSM, VS1R, VLSE, VSSE, VLXE, VSXE, VLEFF,
   // Vectorial custom instructions
   VCNT
} instr_type_t;

typedef enum logic[CSR_CMD_SIZE-1:0] {
    CSR_CMD_NOPE      = 4'b0000,
    CSR_CMD_RW        = 4'b0001,
    CSR_CMD_SET       = 4'b0010,
    CSR_CMD_CLEAR     = 4'b0011,
    CSR_CMD_SYS       = 4'b0100,
    CSR_CMD_READ      = 4'b0101,
    CSR_CMD_VSETVL    = 4'b0110,
    CSR_CMD_VSETVLMAX = 4'b0111,
    CSR_CMD_WRITE     = 4'b1000,
    CSR_CMD_VLEFF     = 4'b1001
} csr_cmd_t;                // Comands to lowrisc CSR


// Response coming from Dcache
typedef struct packed {
    logic       valid;      // Response valid
    logic       ready;      // Ready to accept requests
    bus_dcache_data_t data;      // Data from load
    logic[6:0]     rd;      // Tag of the mem access
    logic io_address_space; // Request in Input/Output Address Space
    logic     ordered;    
} resp_dcache_cpu_t;

// Request send to DCache
typedef struct packed {
    logic                valid;        // New memory request
    bus64_t           data_rs1;        // Data operand 1
    bus_simd_t        data_rs2;        // Data operand 2
    instr_type_t    instr_type;        // Type of instruction
    logic [3:0]       mem_size;        // Granularity of mem. access
    logic [6:0]             rd;        // Destination register. Used for identify a pending Miss
    logic      is_amo_or_store;        // Type of instruction is amo or store
    logic               is_amo;        // Type of instruction is amo
    logic             is_store;        // Type of instruction is amo
} req_cpu_dcache_t;

// Fetch 1 Stage
typedef struct packed {
    addrPC_t                 pc_inst;   // Actual PC
    logic                    valid;     // Valid instruction
    branch_pred_t            bpred;     // Branch prediction
    exception_t              ex;        // Exceptions
    `ifdef SIM_KONATA_DUMP
    bus64_t id;
    `endif
} if_1_if_2_stage_t;       // FETCH 1 STAGE TO DECODE STAGE

// Fetch 2 Stage
typedef struct packed {
    addrPC_t                 pc_inst;   // Actual PC
    riscv_pkg::instruction_t inst;      // Bits of the instruction
    logic                    valid;     // Valid instruction
    branch_pred_t            bpred;     // Branch prediction
    exception_t              ex;        // Exceptions
    `ifdef SIM_KONATA_DUMP
    bus64_t id;
    `endif
} if_id_stage_t;       // FETCH STAGE TO DECODE STAGE

// This is created by decode
typedef struct packed {
    logic valid;                        // Valid instruction
    addrPC_t pc;                        // PC of the instruction
    branch_pred_t bpred;                // Branch Prediciton
    logic ex_valid;                     // Exception valid
    reg_t rs1;                          // Register Source 1
    reg_t rs2;                          // Register Source 2
    reg_t rd;                           // Destination register
    logic use_rs1;                      // Instruction uses register source 1
    logic use_rs2;                      // Instruction uses register source 2

    vreg_t vs1;                         // VRegister Source 1
    vreg_t vs2;                         // VRegister Source 2
    vreg_t vd;                          // Destination vregister
    logic  use_vs1;                     // Instruction uses vregister source 1
    logic  use_vs2;                     // Instruction uses vregister source 2
    logic  is_opvx;                     // Instruction uses rs1 instead of vs1
    logic  is_opvi;                     // Instruciton uses imm instead of vs1

    bus64_t imm;                        // Instruction immediate
    
    // FP instructions only
    reg_t rs3;                          // Register Source 3 for fused ops
    logic fmt;                          // FMT mode (0:S, 1:D)
    logic use_fs1;                      // Instruction uses fregister source 1
    logic use_fs2;                      // Instruction uses fregister source 2
    logic use_fs3;                      // Instruction uses fregister source 2
    riscv_pkg::op_frm_fp_t frm;         // FP rounding mode

    logic use_imm;                      // Use Immediate later
    logic use_pc;                       // Use PC later
    logic op_32;                        // Operation of 32 bits
    functional_unit_t unit;             // Functional unit

    // Control bits
    logic regfile_we;                   // Write to register file
    logic vregfile_we;                  // Write to vregister file
    logic fregfile_we;                  // Write to fregister file
    logic use_mask;                     // Use vector mask
    logic use_old_vd;                   // Use previous value of vector destination register
    //logic regfile_fp_we;               // Write to register file FPU
    instr_type_t instr_type;            // Type of instruction
    logic signed_op;                    // Signed Operation
    logic [3:0] mem_size;               // Memory operation size (Byte, Word, etc)
    logic stall_csr_fence;              // CSR or fence
    mem_type_t mem_type;                // Mem instruction type
    `ifdef SIM_COMMIT_LOG
    riscv_pkg::instruction_t inst;
    bus64_t id;
    `elsif SIM_KONATA_DUMP
    bus64_t id;
    `endif
} instr_entry_t;

typedef struct packed {
    instr_entry_t instr;                // Instruction
    exception_t ex;                     // Exceptions
} id_ir_stage_t;

typedef struct packed {
    instr_entry_t instr;                // Instruction
    exception_t ex;                     // Exceptions
    phreg_t prs1;                       // Physical register source 1
    logic   rdy1;                       // Ready register source 1
    phreg_t prs2;                       // Physical register source 2
    logic   rdy2;                       // Ready register source 2 
    phreg_t fprs1;                      // FP Physical register source 1
    logic   frdy1;                      // FP Ready register source 1
    phreg_t fprs2;                      // FP Physical register source 2
    logic   frdy2;                      // FP Ready register source 2
    phreg_t fprs3;                      // FP Physical register source 3
    logic   frdy3;                      // FP Ready register source 3    
    phreg_t prd;                        // Physical register destination
    phreg_t old_prd;                    // Old Physical register destination
    phreg_t fprd;                       // Physical register destination
    phreg_t old_fprd;                   // Old Physical register destination

    phvreg_t pvs1;                      // Physical vregister source 1
    logic    vrdy1;                     // Ready vregister source 1
    phvreg_t pvs2;                      // Physical vregister source 2
    logic    vrdy2;                     // Ready vregister source 2
    phvreg_t pvm;                       // Physical vregister source mask
    logic    vrdym;                     // Ready vregister source mask
    phvreg_t pvd;                       // Physical vregister destination
    phvreg_t old_pvd;                   // Old Physical vregister destination
    logic    vrdy_old_vd;               // Ready vregister old vd

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch  
} ir_rr_stage_t;

typedef struct packed {
    instr_entry_t instr;                // Instruction
    bus64_t data_rs1;                   // Data operand 1
    bus64_t data_rs2;                   // Data operand 2
    bus_simd_t data_vs1;                // Data vector operand 1
    bus_simd_t data_vs2;                // Data vector operand 2
    bus_simd_t data_old_vd;             // Data vector old destination
    bus_mask_t data_vm;                 // Data vector mask
    bus64_t data_rs3;                   // Data operand 3 FP
    phreg_t prs1;                       // Physical register source 1
    logic   rdy1;                       // Ready register source 1
    phreg_t prs2;                       // Physical register source 2
    logic   rdy2;                       // Ready register source 2
    phreg_t fprs1;                       // Physical register source 1
    logic   frdy1;                       // Ready register source 1
    phreg_t fprs2;                       // Physical register source 2
    logic   frdy2;                       // Ready register source 2
    phreg_t fprs3;                       // Physical register source 2
    logic   frdy3;                       // Ready register source 3
    phreg_t prd;                        // Physical register destination 
    phreg_t old_prd;                    // Old Physical register destination
    phreg_t fprd;                        // Physical register destination
    phreg_t old_fprd;                    // Old Physical register destination

    phvreg_t pvs1;                      // Physical vregister source 1
    logic    vrdy1;                     // Ready vregister source 1
    phvreg_t pvs2;                      // Physical vregister source 2
    logic    vrdy2;                     // Ready vregister source 2
    phvreg_t pvm;                       // Physical vregister mask
    logic    vrdym;                     // Ready vregister mask
    //logic    use_mask;                  // Does the instruction use a mask?
    phvreg_t pvd;                       // Physical vregister destination
    phvreg_t old_pvd;                   // Old Physical vregister destination
    logic    vrdy_old_vd;               // Ready vregister old vd

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    gl_index_t gl_index;                // Graduation List entry
} rr_exe_instr_t;       //  Read Regfile to Execution stage for arithmetic pipeline

typedef struct packed {
    instr_entry_t instr;                // Instruction
    bus64_t data_rs1;                   // Data operand 1
    bus64_t data_rs2;                   // Data operand 2
    phreg_t prs1;                       // Physical register source 1
    logic   rdy1;                       // Ready register source 1
    phreg_t prs2;                       // Physical register source 2
    logic   rdy2;                       // Ready register source 2    
    phreg_t prd;                        // Physical register destination 
    phreg_t old_prd;                    // Old Physical register destination
    phvreg_t old_pvd;                   // Old Physical register destination

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    gl_index_t gl_index;                // Graduation List entry
} rr_exe_arith_instr_t;       //  Read Regfile to Execution stage for arithmetic pipeline

typedef struct packed {
    instr_entry_t instr;                // Instruction
    bus64_t data_rs1;                   // Data operand 1
    bus_simd_t data_rs2;                // Data operand 2
    bus_simd_t data_old_vd;             // Data simd old destination
    bus_mask_t data_vm;                 // Data simd mask
    sew_t      sew;                     // Element width
    phreg_t prs1;                       // Physical register source 1
    logic   rdy1;                       // Ready register source 1
    phreg_t prs2;                       // Physical register source 2
    logic   rdy2;                       // Ready register source 2    
    phreg_t prd;                        // Physical register destination 
    phvreg_t pvd;                       // Physical vregister destination
    phreg_t old_prd;                    // Old Physical register destination
    phvreg_t old_pvd;                   // Old Physical register destination
    phreg_t fprd;                       // Physical register destination
    phreg_t old_fprd;                   // Old Physical register destination
    
    logic is_amo_or_store;              // Encodes if type instruction is amo or store
    logic is_amo;                       // Encodes if type instruction is amo
    logic is_store;                     // Encodes if type instruction is store

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    logic translated;                   // Has been translated to a physical address
    exception_t ex;

    `ifdef SIM_COMMIT_LOG
    bus64_t vaddr;
    `endif

    gl_index_t gl_index;                // Graduation List entry

    logic [VMAXELEM_LOG-1:0] agu_req_tag;// Tag for the microoperation generated by the AGU
    logic vmisalign_xcpt;               // Vector memory instruction has a misaligned access
    logic [VMAXELEM_LOG-1:0] velem_id;  // Id of the lowest vector element in a request
    logic [VMAXELEM-1:0] load_mask;     // Mask of valid elements in a vector load request
    logic [DCACHE_MAXELEM_LOG-1:0] velem_off; // Offset in number of elements until the first valid one in a request
    logic [VMAXELEM_LOG:0] velem_incr;  // Number of valid elements in a request
    logic neg_stride;                   // Vector load with negative stride

} rr_exe_mem_instr_t;       //  Read Regfile to Execution stage for memory pipeline

typedef struct packed {
    instr_entry_t instr;                // Instruction
    bus64_t data_rs1;                   // Data operand 1
    bus_dcache_data_t data_rs2;          // Data operand 2
    bus_simd_t data_old_vd;             // Data simd old destination
    bus_mask_t data_vm;                 // Data simd mask
    sew_t      sew;                     // Element width
    phreg_t prs1;                       // Physical register source 1
    logic   rdy1;                       // Ready register source 1
    phreg_t prs2;                       // Physical register source 2
    logic   rdy2;                       // Ready register source 2    
    phreg_t prd;                        // Physical register destination 
    phvreg_t pvd;                       // Physical vregister destination
    phreg_t old_prd;                    // Old Physical register destination
    phvreg_t old_pvd;                   // Old Physical register destination
    phreg_t fprd;                       // Physical register destination
    phreg_t old_fprd;                   // Old Physical register destination
    
    logic is_amo_or_store;              // Encodes if type instruction is amo or store
    logic is_amo;                       // Encodes if type instruction is amo
    logic is_store;                     // Encodes if type instruction is store

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    logic translated;                   // Has been translated to a physical address
    exception_t ex;

    `ifdef SIM_COMMIT_LOG
    bus64_t vaddr;
    `endif

    gl_index_t gl_index;                // Graduation List entry

    logic [VMAXELEM_LOG-1:0] agu_req_tag;// Tag for the microoperation generated by the AGU
    logic vmisalign_xcpt;               // Vector memory instruction has a misaligned access
    logic [VMAXELEM_LOG-1:0] velem_id;  // Id of the lowest vector element in a request
    logic [VMAXELEM-1:0] load_mask;     // Mask of valid elements in a vector load request
    logic [DCACHE_MAXELEM_LOG-1:0] velem_off; // Offset in number of elements until the first valid one in a request
    logic [VMAXELEM_LOG:0] velem_incr;  // Number of valid elements in a request
    logic neg_stride;                   // Vector load with negative stride

} pmrq_instr_t;       //  Read Regfile to Execution stage for memory pipeline

typedef struct packed {
    instr_entry_t instr;                // Instruction
    bus64_t data_rs1;                   // Data scalar operand 1
    bus_simd_t data_vs1;                // Data simd operand 1
    bus_simd_t data_vs2;                // Data simd operand 2
    bus_simd_t data_old_vd;             // Data simd old destination
    bus_mask_t data_vm;                 // Data simd mask
    sew_t      sew;                     // Element width    
    phvreg_t pvs1;                      // Physical register source 1
    logic   vrdy1;                      // Ready register source 1
    phvreg_t pvs2;                      // Physical register source 2
    logic   vrdy2;                      // Ready register source 2    
    
    phreg_t prd;                         // Physical register destination
    phvreg_t pvd;                       // Physical register destination 
    phreg_t old_prd;                    // Old Physical register destination
    phvreg_t old_pvd;                   // Old Physical register destination
    logic vrdy_old_vd;                  // Ready register old vd

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    gl_index_t gl_index;                // Graduation List entry

    logic [3:0] exe_stages;              // Number of executuion stages
} rr_exe_simd_instr_t;


typedef struct packed {
    instr_entry_t instr;                // Instruction
    bus64_t data_rs1;                   // Data operand 1
    bus64_t data_rs2;                   // Data operand 2
    bus64_t data_rs3;                   // Data operand 2
    phreg_t fprs1;                       // Physical register source 1
    logic   frdy1;                       // Ready register source 1
    phreg_t fprs2;                       // Physical register source 2
    logic   frdy2;                       // Ready register source 2
    phreg_t fprs3;                       // Physical register source 3
    logic   frdy3;                       // Ready register source 3
    //phreg_t prd;                       // Physical register destination 
    phreg_t old_fprd;                    // Old Physical register destination
    phreg_t fprd;                        // Physical register destination
    //phreg_t old_prd;                   // Old Physical register destination
    logic checkpoint_done;               // It has a checkpoint
    checkpoint_ptr chkp;                 // Checkpoint of branch

    gl_index_t gl_index;                // Graduation List entry
} rr_exe_fpu_instr_t;       //  Read Regfile to Execution stage for arithmetic pipeline

typedef struct packed {
    logic valid;                        // Valid instruction
    addrPC_t pc;                        // PC of the instruction
    reg_t rs1;                          // Register Source 1
    instr_type_t instr_type;            // Type of instruction
    addrPC_t result_pc;                 // PC result
    reg_t rd;                           // Destination Register
    bus64_t result;                     // Result or immediate  
    logic branch_taken;                 // Branch taken
    branch_pred_t bpred;                // Branch Prediciton
    exception_t ex;                     // Exceptions
    logic regfile_we;                   // Write to register file
    logic stall_csr_fence;              // CSR or fence
    reg_csr_addr_t csr_addr;            // CSR Address
    `ifdef SIM_COMMIT_LOG
    riscv_pkg::instruction_t inst;
    bus64_t id;
    addr_t addr;
    `elsif SIM_KONATA_DUMP
    bus64_t id;
    `endif
    phreg_t prd;                        // Physical register destination

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    fpnew_pkg::status_t fp_status;      // FP status of the executed instruction

    gl_index_t gl_index;                // Graduation List entry
    mem_type_t mem_type;                // Mem instruction type
} exe_wb_scalar_instr_t;       //  Execution Stage to scalar Write Back

typedef struct packed {
    logic valid;                        // Valid instruction
    addrPC_t pc;                        // PC of the instruction
    reg_t rs1;                          // Register Source 1
    instr_type_t instr_type;            // Type of instruction
    addrPC_t result_pc;                 // PC result
    vreg_t vd;                          // Destination VRegister
    bus_simd_t vresult;                 // VResult    
    logic branch_taken;                 // Branch taken
    branch_pred_t bpred;                // Branch Prediciton
    exception_t ex;                     // Exceptions
    logic vregfile_we;                  // Write to vregister file
    logic stall_csr_fence;              // CSR or fence
    reg_csr_addr_t csr_addr;            // CSR Address
    `ifdef SIM_KONATA_DUMP
    bus64_t id;
    `endif
    `ifdef SIM_COMMIT_LOG
    riscv_pkg::instruction_t inst;
    addr_t addr;
    `endif
    phvreg_t pvd;                       // Physical vregister destination

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    gl_index_t gl_index;                // Graduation List entry
    logic vs_ovf;
} exe_wb_simd_instr_t;       //  Execution Stage to SIMD Write Back


typedef struct packed {
    logic valid;                        // Valid instruction
    addrPC_t pc;                        // PC of the instruction
    reg_t rs1;                          // Register Source 1
    instr_type_t instr_type;            // Type of instruction
    addrPC_t result_pc;                 // PC result
    reg_t rd;                           // Destination Register
    bus64_t result;                     // Result or immediate                  
    logic branch_taken;                 // Branch taken
    branch_pred_t bpred;                // Branch Prediciton
    exception_t ex;                     // Exceptions
    logic regfile_we;                   // Write to register file
    logic stall_csr_fence;              // CSR or fence
    reg_csr_addr_t csr_addr;            // CSR Address
    `ifdef SIM_KONATA_DUMP
    bus64_t id;
    `endif
    `ifdef SIM_COMMIT_LOG
    riscv_pkg::instruction_t inst;
    addr_t addr;
    `endif
    phreg_t fprd;                       // Physical register destination
    fpnew_pkg::status_t fp_status;      // FP status of the executed instruction

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    gl_index_t gl_index;                // Graduation List entry  
} exe_wb_fp_instr_t;       //  Execution Stage to FP Write Back

typedef struct packed {
    logic   valid;                      // Valid instruction
    bus64_t data;                       // Result data
    reg_t   rd;                         // Virtual register destination
    phreg_t prd;                        // Physical register destination
    phreg_t fprd;                        // Physical register destination
} wb_exe_instr_t;   // WB Stage to Execution

// Control Unit signals
typedef struct packed {
    logic valid_fetch;      // Fetch is valid
} if_cu_t;      // Fetch to Control Unit

typedef struct packed {
    logic valid;                        // Valid instruction
    logic valid_jal;                    // JAL is valid
    logic stall_csr_fence;              // CSR or fenceEPI_RV64D
    logic is_branch;                    // Decode instruction is a branch
    logic predicted_as_branch;          // Decode instruction was predicted as branch
} id_cu_t;      // Decode to Control Unit

typedef struct packed {
    logic valid;                        // Valid instruction
    logic full_iq;                      // Instruction Queue full
    logic out_of_checkpoints;           // Rename out of checkpoints
    logic simd_out_of_checkpoints;      // SIMD Rename out of checkpoints
    logic fp_out_of_checkpoints;        // FP Rename out of checkpoints
    logic empty_free_list;              // Free list out of registers
    logic is_branch;                    // Rename instruction is a branch
} ir_cu_t;      // Rename to Control Unit

typedef struct packed {
    logic gl_full;  // CSR or fence
} rr_cu_t;      // Read Register to Control Unit 

typedef struct packed {
    next_pc_sel_t next_pc;      // Select next PC
} cu_if_t;      // Control Unit to Fetch

typedef struct packed {
    logic do_checkpoint;                   // Invalidate ICache content
    logic delete_checkpoint;               // Delete last checkpoint
    logic do_recover;                      // Recover checkpoint
    checkpoint_ptr recover_checkpoint;     // Label of the checkpoint to recover   
    logic recover_commit;                  // Recover at Commit
    logic [1:0] enable_commit_update;            // Enable update of Free List and Rename from commit
    logic [1:0] simd_enable_commit_update;       // Enable update of SIMD Free List and Rename from commit
    logic [1:0] fp_enable_commit_update;         // Enable update of FP Free List and Rename from commit
} cu_ir_t;      // Control Unit to Rename

typedef struct packed {
    logic [NUM_SCALAR_WB-1:0] write_enable; // Enable write on register file
    logic [NUM_SIMD_WB-1:0]  vwrite_enable; // Enable write on vregister file
    logic [NUM_FP_WB-1:0]    fwrite_enable; // Enable write on register file FP
    logic [NUM_SCALAR_WB-1:0] snoop_enable; // Enable snoop to rr and exe stage
    logic [NUM_SIMD_WB-1:0]  vsnoop_enable; // Enable snoop to rr and exe stage
    logic [NUM_FP_WB-1:0]    fsnoop_enable; // Enable snoop to rr and exe stage
    logic write_enable_dbg;                 // Enable write on register file dbg usage
} cu_rr_t;      // Control unit to Register File

// Control Unit signals
typedef struct packed {
    logic valid_1;                // Valid Intruction ALU, MUL, DIV
    logic valid_2;                // Valid Intruction MEM
    logic valid_3;                // Valid Instruction SIMD
    logic valid_fp;               // Valid Intruction FP
    logic valid_fp_mem;           // Valid Intruction FP MEM
    logic is_branch;              // There is a branch in the ALU
    logic branch_taken;           // Branch taken
    logic stall;                  // Execution unit stalled
} exe_cu_t;

// Control Unit signals
typedef struct packed {
    logic [NUM_SCALAR_WB-1:0] valid;         // Valid Intruction
    logic [NUM_SIMD_WB-1:0]  vvalid;         // Valid SIMD Instruction
    logic [NUM_FP_WB-1:0]    fvalid;         // Valid FP Intruction
    logic checkpoint_done;        // It has a checkpoint
    checkpoint_ptr  chkp;         // Label of the checkpoint
    gl_index_t gl_index;          // Graduation List entry of ALU
    logic [NUM_SCALAR_WB-1:0] write_enable;  // Write Enable to Register File
    logic [NUM_SCALAR_WB-1:0] snoop_enable;  // Snoop Enable to rr and exe
    logic [NUM_SIMD_WB-1:0]  vwrite_enable;  // Write Enable to VRegister File
    logic [NUM_SIMD_WB-1:0]  vsnoop_enable;  // Snoop Enable to rr and exe
    logic [NUM_FP_WB-1:0]    fwrite_enable;   // Write Enable to Register File
    logic [NUM_FP_WB-1:0]    fsnoop_enable; // Enable snoop to rr and exe stage
} wb_cu_t;      // Write Back to Control Unit

// Control Unit signals
typedef struct packed {
    logic valid;                // Valid Intruction
    logic csr_enable;           // CSR that needs to write to register file
    logic stall_csr_fence;      // CSR or fence
    logic xcpt;                 // Exception
    logic ecall_taken;          // Ecall 
    logic fence;                // Is fence
    logic fence_i;              // Is fence i
    logic write_enable;         // Write Enable to Register File
    logic stall_commit;         // Stop commits
    logic [1:0] regfile_we;           // Commit update enable
    logic [1:0] vregfile_we;          // Commit update enable
    logic [1:0] fregfile_we;        // Commit update enable
    gl_index_t gl_index;        // Graduation List entry
    logic [1:0] retire;
} commit_cu_t;      // Write Back to Control Unit

// Control Unit signals
typedef struct packed {
    logic enable_commit;        // Enable Commit
    logic flush_gl_commit;      // Flush Graduation List
} cu_commit_t;      // Control Unit to Commit

// Control Unit signals
typedef struct packed {
    logic      flush_gl;         // Enable Commit
    gl_index_t flush_gl_index;   // Enable Commit
} cu_wb_t;      // Control Unit to Write Back

// Pipeline control
typedef struct packed {
    logic stall_if_1;       // Stop Fetch 1
    logic stall_if_2;       // Stop Fetch 2
    logic stall_id;         // Stop Decode
    logic stall_iq;         // Stop Instruction Queue
    logic stall_ir;         // Stop Rename
    logic stall_rr;         // Stop Read Register
    logic stall_exe;        // Stop Exe
    logic stall_commit;     // Stop Commit

    // whether insert in fetch from dec or commit
    jump_addr_fetch_t sel_addr_if;
} pipeline_ctrl_t;  // Control signals of the pipeline

// Pipeline control
typedef struct packed {
    logic flush_if;         // Flush Fetch
    logic flush_id;         // Flush instruction in Decode
    logic flush_ir;         // Flush instructions in Rename
    logic flush_rr;         // Flush instruction in Read Register
    logic flush_exe;        // Flush instruction in Execution Stage
    logic kill_exe;         // Kill the instruction that will be executed this cycle
    logic flush_commit;     // Flush instruction in commit
} pipeline_flush_t;

// Pipeline control
typedef struct packed {
    logic       valid; // whether is a jal or not
    addrPC_t    jump_addr;
} jal_id_if_t;

//PMU flags
typedef struct packed {
    logic stall_if   ;         // Stop Fetch
    logic stall_id   ;         // Stop Decode -
    logic stall_ir   ;         // Stop Rename
    logic stall_rr   ;         // Stop Read Register
    logic stall_exe  ;         // Stop Exe -
    logic stall_wb   ;         // Stop Write Back
    logic branch_miss;         // Stop Write Back -
    logic is_branch  ;         // Stop Write Back
    logic branch_taken;         // Stop Write Back
    logic load_store;           // load or store inst in WB
    logic data_depend;          // stall due to data dependency
    logic struct_depend;        // stall due to structural risk
    logic grad_list_full;       // stall due to graduation list full
    logic free_list_empty;      // stall due to free list empty
} to_PMU_t;  // Control signals to PMU counters

// CSR output
typedef struct packed {
    // csr addr or 12 imm bits from system instr
    csr_addr_t  csr_rw_addr;
    // internal cmd of csr
    csr_cmd_t   csr_rw_cmd;
    // if xcpt, pass misaligned addr
    // data to write in CSR 
    bus64_t     csr_rw_data;
    // exception from wb
    logic       csr_exception;
    // every time commit send this
    logic [1:0] csr_retire;
    // exception cause
    bus64_t     csr_xcpt_cause;
    // exception origin
    bus64_t     csr_xcpt_origin;
    // xcpt pc 
    bus64_t     csr_pc;
    logic [4:0] fp_status;       // FP status of the executed instruction
    logic       freg_modified;   // An FP instruction has written the FP regfile 
    logic       csr_vxsat;       // Vector saturating instruction overflow
} req_cpu_csr_t;

// CSR input
typedef struct packed {
    bus64_t     csr_rw_rdata;
    // if sending a csr command while 
    // CSR is not responding
    // EX: send a CSR petition to PCR
    // but thery are busy, at same cycle 
    // replay wil be to 1
    logic       csr_replay;
    // petition to CSR takes more than one cycle
    // when down value ready
    // while up doing req
    // or WFI
    logic       csr_stall;
    // CSR exception
    // read CSR without enough privilege
    // or eret/ecall
    // CSR handles all the usual logic
    // don't care about cause and do the typical
    // flush and charge evec? 
    logic       csr_exception;
    bus64_t     csr_exception_cause;
    // old uret, sret, mret
    // return  from system to user
    logic       csr_eret;
    // pc to go if xcpt or eret
    bus64_t     csr_evec;
    // any interrupt
    logic       csr_interrupt;
    // save until the instruction then 
    // give the interrupt cause as xcpt cause
    bus64_t     csr_interrupt_cause;
    // tval
    bus64_t     csr_tval;
    // Step_mode_enbled
    logic       debug_step;
    // Ebreak in CSR module
    logic       debug_ebreak;
} resp_csr_cpu_t;

typedef struct packed {
    // Triggers a halt on the pipeline 
    logic           halt_req;
    // Triggers a restart on the pipeline
    logic           resume_req;
    // The core starts to fetch from the debug program buffer
    logic           progbuf_req;
    // Indicates that the core should halt after exiting form a reset
    logic           halt_on_reset;
} debug_contr_in_t;

typedef struct packed {
    // Rename read request 
    logic           rnm_read_en;
    // Virtual register address that needs to be renamed 
    reg_t           rnm_read_reg;
    // Register file read request 
    logic           rf_en;
    // Physical register address that needs to be read/write
    phreg_t         rf_preg;
    // Write enable of the register file 
    logic           rf_we;
    // Data to be written 
    bus64_t         rf_wdata;
} debug_reg_in_t;

typedef struct packed {
    // ACKs the halt of the pipeline 
    logic           halt_ack;
    // The pipelines is halted
    logic           halted;
    // ACKs the restart of the pipeline
    logic           resume_ack;
    // The pipeline is running
    logic           running;
    // ACKs the probram buffer execution request
    logic           progbuf_ack;
    // The pipeline is halted and is not executing from the probram buffer (parked state)
    logic           parked;
    // Indicates if the debugging is unavailable
    logic           unavail;
} debug_contr_out_t;

typedef struct packed {
    // Response of a rename request 
    phreg_t         rnm_read_resp;
    // Response form a read request
    bus64_t         rf_rdata;
} debug_reg_out_t;

//--------------------------------
// Legacy Debug structs for Ka
typedef struct packed {
    // Triggers a halt on the pipeline 
    logic           halt_req;
    // Triggers a restart on the pipeline
    logic           resume_req;
} debug_intel_in_t;

typedef struct packed {
    // ACKs the halt of the pipeline 
    logic           halt_ack;
    // ACKs the restart of the pipeline
    logic           resume_ack;
} debug_intel_out_t;

typedef enum logic[1:0] {
    DEBUG_RESET,
    DEBUG_RUNNING, 
    DEBUG_CLEAR, 
    DEBUG_HALT
} debug_intel_state_t;
// End Legacy Debug structs for Ka
//--------------------------------

typedef enum logic[2:0] {
    DEBUG_STATE_RESET,
    DEBUG_STATE_RUNNING, 
    DEBUG_STATE_HALTING, 
    DEBUG_STATE_HALTED,
    DEBUG_STATE_PROGBUFF
} debug_contr_state_t;

// LSQ in/out of instruction signals
typedef struct packed {
    logic            valid;          // Valid bit
    regPC_t          addr;           // Address        
    bus64_t          data;           // Data 
    instr_type_t     instr_type;     // Type of instruction
    logic [3:0]      mem_size;       // Granularity of mem. access
    reg_t            rd;             // Destination register. Used for identify a pending Miss
} lsq_interface_t;

// Graduation List in/out of instruction signals
typedef struct packed {
    logic           valid;                  // Valid instruction
    addrPC_t        pc;                     // PC of the instruction
    instr_type_t    instr_type;             // Type of instruction
    reg_t           rd;                     // Destination Register
    reg_t           rs1;                    // Source register 1
    vreg_t          vd;                     // Destination VRegister
    vreg_t          vs1;                    // Source vregister 1
    `ifdef SIM_COMMIT_LOG
    reg_csr_addr_t  csr_addr;               // CSR Address
    exception_t     exception;              // Exceptions
    bus_simd_t      result;                 // Result or immediate
    addr_t          addr;                   // Virtual address of memory op.
    `endif
    logic           ex_valid;
    logic           stall_csr_fence;        // CSR or fence
    logic           regfile_we;             // Write to register file
    logic           vregfile_we;            // Write to vregister file
    logic           fregfile_we;            // Write to fregister file
    phreg_t         pvd;                    // Physical vregister destination to write      
    phreg_t         old_pvd;                // Old Physical vregister destination
    phreg_t         prd;                    // Physical register destination to write 
    phreg_t         old_prd;                // Old Physical register destination
    phreg_t         fprd;                   // Physical register destination to write
    phreg_t         old_fprd;               // Old Physical register destination
    `ifdef SIM_COMMIT_LOG
    riscv_pkg::instruction_t inst;
    `endif
    `ifdef SIM_KONATA_DUMP
    bus64_t id;
    `endif
    fpnew_pkg::status_t fp_status;          // FP status of the executed instruction
    mem_type_t mem_type;                // Mem instruction type
    logic           vs_ovf;
} gl_instruction_t;


typedef struct packed {
    reg_csr_addr_t  csr_addr;               // CSR Address
    exception_t     exception;              // Exceptions
    bus_simd_t      result;                 // Result or immediate
    `ifdef SIM_COMMIT_LOG
    addr_t addr;                            // Virtual address of memory op.
    `endif
    fpnew_pkg::status_t fp_status;          // FP status of the executed instruction
    logic vs_ovf;
} gl_wb_data_t;

localparam drac_cfg_t DracDefaultConfig = '{
    NIOSections: 1, // number of IO space sections
    InitIOBase:  {40'h40000000}, // IO base 0 address after reset
    InitIOEnd:  {40'h80000000}, // IO end 0 address after reset

    NMappedSections: 3, // number of Memory space sections
    InitMappedBase: {40'h0040000000, 40'h0000000100, 40'h0000010000}, // Memory base address after reset
    InitMappedEnd: {40'h3fffffffff, 40'h000000ffff, 40'h0000010020}, // Memory end 0 address after reset

    InitBROMBase: 40'h0000000100,
    InitBROMEnd: 40'h000000ffff,

    DebugProgramBufferBase: 40'h0000010000,
    DebugProgramBufferEnd:  40'h0000010020
};

localparam fpnew_pkg::fpu_features_t EPI_RV64D = '{
    Width:         64,
    EnableVectors: 1'b0,
    EnableNanBox:  1'b1,
    FpFmtMask:     5'b11000,
    IntFmtMask:    4'b0011
};

localparam fpnew_pkg::fpu_implementation_t EPI_INIT = '{
    PipeRegs:   '{'{default: 5}, // ADDMUL
                '{default: 5},   // DIVSQRT
                '{default: 5},   // NONCOMP
                '{default: 5}},  // CONV
    UnitTypes:  '{'{default: fpnew_pkg::MERGED}, // ADDMUL
                '{default: fpnew_pkg::MERGED},   // DIVSQRT
                '{default: fpnew_pkg::PARALLEL}, // NONCOMP
                '{default: fpnew_pkg::MERGED}},  // CONV
    PipeConfig: fpnew_pkg::DISTRIBUTED
};

localparam int unsigned SEW_WIDTH = 3;
typedef enum logic [SEW_WIDTH - 1 : 0] {
    BINARY32 = 'b010,
    BINARY64 = 'b011
} std_element_width_e;


////////////////////////////////      
//
//  Cache-TLB communication
//
///////////////////////////////   

parameter VPN_SIZE = 27;
parameter PPN_SIZE = 44;
parameter ASID_SIZE = 7;

// Cache-TLB request
typedef struct packed {
    logic valid;   
    logic [ASID_SIZE-1:0] asid;
    logic [VPN_SIZE:0] vpn;
    logic passthrough;
    logic instruction;
    logic store;
} cache_tlb_req_t;

typedef struct packed {
    cache_tlb_req_t req;
    logic [1:0] priv_lvl;   
    logic vm_enable; 
} cache_tlb_comm_t;

typedef struct packed {
    logic load;
    logic store;
    logic fetch;
} tlb_ex_t;

// TLB-Cache response
typedef struct packed { 
    logic miss;
    logic [PPN_SIZE-1:0] ppn; 
    tlb_ex_t xcpt;
    logic [7:0] hit_idx;
} tlb_cache_resp_t;

typedef struct packed {
    logic tlb_ready;  
    tlb_cache_resp_t resp;
} tlb_cache_comm_t;

typedef struct packed {
    logic [63:0] satp;
    logic flush;
    logic [63:0] mstatus;
} csr_ptw_comm_t;

typedef struct packed {
    logic exe_load;
    logic exe_store;
    logic icache_req;
    logic icache_kill;
    logic icache_miss_l2_hit;
    logic icache_miss_kill;
    logic icache_busy;
    logic icache_miss_time;
    logic itlb_access;
    logic itlb_miss;
    logic dtlb_access;
    logic dtlb_miss;
    logic ptw_buffer_hit;
    logic ptw_buffer_miss;
    logic itlb_stall;
    logic dcache_stall;
    logic dcache_stall_refill;
    logic dcache_rtab_rollback;
    logic dcache_req_onhold;
    logic dcache_prefetch_req;
    logic dcache_read_req;
    logic dcache_write_req;
    logic dcache_cmo_req;
    logic dcache_uncached_req;
    logic dcache_miss_read_req;
    logic dcache_miss_write_req;
} pmu_interface_t;

typedef struct packed {
    logic commit_valid0;
    logic commit_xcpt;
    logic [4:0] commit_xcpt_cause;
    logic stall_if_1;       
    logic stall_if_2;      
    logic stall_id;         
    logic stall_iq;             
    logic stall_rr;       
    logic stall_exe;       
    logic stall_commit;   
    logic flush_if;
    logic flush_rr;
} visa_signals_t;

`ifdef SIM_COMMIT_LOG
typedef struct packed {
    longint unsigned pc;
    longint unsigned inst;
    longint unsigned dst;
    longint unsigned fdst;
    longint unsigned vdst;
    longint unsigned reg_wr_valid;
    longint unsigned freg_wr_valid;
    longint unsigned vreg_wr_valid;
    bit[riscv_pkg::VLEN-1:0] data;
    longint unsigned csr_wr_valid;
    longint unsigned csr_dst;
    longint unsigned csr_data;
    longint unsigned sew;
    longint unsigned xcpt;
    longint unsigned xcpt_cause;
    longint unsigned csr_priv_lvl;
    longint unsigned csr_rw_data;
    longint unsigned csr_xcpt;
    longint unsigned csr_xcpt_cause;
    longint unsigned csr_tval;
    longint unsigned mem_type;
    longint unsigned mem_addr;
    longint unsigned fflags_wr_valid;
} commit_data_t;
`endif

endpackage
