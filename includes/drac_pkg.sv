/*
APPENDIX

Copyright 2023 BSC*
*Barcelona Supercomputing Center (BSC)

SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
may not use this file except in compliance with the License, or, at your
option, the Apache License version 2.0. You may obtain a copy of the
License at

https://solderpad.org/licenses/SHL-2.1/

Unless required by applicable law or agreed to in writing, any work
distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.
*/

package drac_pkg;

import riscv_pkg::*;

//parameter XLEN = 64; 
//parameter VLEN = 256;
parameter ICACHELINE_SIZE = 127;
parameter ADDR_SIZE = 40;
parameter DATA_SIZE = 64;
//parameter INST_SIZE = 32;
parameter REGFILE_WIDTH = 5;
parameter ICACHE_IDX_BITS_SIZE = 12;
parameter ICACHE_VPN_BITS_SIZE = 28;
parameter CSR_ADDR_SIZE = 12;
parameter CSR_CMD_SIZE = 3;
parameter NUM_SCALAR_WB = 4;
parameter NUM_FP_WB = 2;

parameter UNMAPPED_ADDR_LOWER = 64'h0; 
parameter UNMAPPED_ADDR_UPPER = 64'h0; 
`ifdef PADDR_39
parameter PHISIC_MEM_LIMIT = 64'h07fffffffff; 
`else
parameter PHISIC_MEM_LIMIT = 64'h0ffffffff; 
`endif
parameter BROM_SIZE = 20'b000010000000000000000000;

// RISCV
//parameter OPCODE_WIDTH = 6;
//parameter REG_WIDTH = 5;

typedef reg   [63:0]  reg64_t;
typedef logic [63:0]  bus_simd_t;
typedef logic [127:0] bus128_t;
typedef logic [63:0]  bus64_t;
typedef logic [31:0]  bus32_t;

typedef logic [REGFILE_WIDTH-1:0] reg_t;
typedef reg   [riscv_pkg::XLEN-1:0] regPC_t;
typedef logic [riscv_pkg::XLEN-1:0] addrPC_t;
typedef logic [ADDR_SIZE-1:0] addr_t;
typedef reg   [ADDR_SIZE-1:0] reg_addr_t;
typedef logic [CSR_ADDR_SIZE-1:0] csr_addr_t;
typedef reg   [CSR_ADDR_SIZE-1:0] reg_csr_addr_t;
//typedef logic [CSR_CMD_SIZE-1:0] csr_cmd_t;
//typedef reg   [CSR_CMD_SIZE-1:0] reg_csr_cmd_t;

typedef logic [riscv_pkg::INST_SIZE-1:0] inst_t;
typedef logic [ICACHELINE_SIZE:0] icache_line_t;
typedef reg   [ICACHELINE_SIZE:0] icache_line_reg_t;
typedef logic [ICACHE_IDX_BITS_SIZE-1:0] icache_idx_t;
typedef logic [ICACHE_VPN_BITS_SIZE-1:0] icache_vpn_t;


// Instruction Queue
parameter INSTRUCTION_QUEUE_NUM_ENTRIES = 16;

// Physical registers 
parameter NUM_PHISICAL_REGISTERS = 64;
parameter PHISICAL_REGFILE_WIDTH = 6;
typedef logic [PHISICAL_REGFILE_WIDTH-1:0] phreg_t;

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

typedef enum logic [2:0]{
    UNIT_ALU,                   // Select ALU
    UNIT_DIV,                   // Select DIVISION
    UNIT_MUL,                   // Select MULTIPLICATION
    UNIT_BRANCH,                // Select Branch computation
    UNIT_MEM,                   // Select Memory unit
    UNIT_FPU,                   // Select FPU
    UNIT_CONTROL,               // Select CONTROL
    UNIT_SYSTEM                 // Select CSR
} functional_unit_t;   // Selection of funtional unit in exe stage 

typedef enum logic [1:0]{
    SEL_FROM_MEM,               // Select source from Memory
    SEL_FROM_ALU,               // Select source from ALU
    SEL_FROM_BRANCH,            // Select source from Branch computation
    SEL_FROM_CONTROL            // Select source from control
} reg_sel_t;          // Selection of the result from functional unit 

typedef enum logic {
    SCALAR_RF,     // Select scalar regfile
    FPU_RF        // Select fpu regfile
} regfile_sel_t;

typedef enum logic [7:0] { 
    // basic ALU op
   ADD, SUB, ADDW, SUBW,
   // logic operations
   XOR, OR, AND,
   // shifts
   SRA, SRL, SLL, SRLW, SLLW, SRAW,
   // comparisons
   BLT, BLTU, BGE, BGEU, BEQ, BNE,
   // jumps
   JALR, JAL,
   // set lower than operations
   SLT, SLTU,
   // CSR functions
   MRET, SRET, URET, ECALL, EBREAK, WFI, FENCE, FENCE_I, SFENCE_VMA, VSETVL, VSETVLI,
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
   FCLASS
} instr_type_t;

typedef enum logic[CSR_CMD_SIZE-1:0] {
    CSR_CMD_NOPE    = 3'b000,
    CSR_CMD_WRITE   = 3'b001,
    CSR_CMD_SET     = 3'b010,
    CSR_CMD_CLEAR   = 3'b011,
    CSR_CMD_SYS     = 3'b100,
    CSR_CMD_READ    = 3'b101,
    CSR_CMD_VSELVL  = 3'b110,
    CSR_CMD_N2      = 3'b111
} csr_cmd_t;                // Comands to lowrisc CSR


// Response coming from Dcache
typedef struct packed {
    logic       valid;      // Response valid
    logic       ready;      // Ready to accept requests
    bus_simd_t   data;      // Data from load
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
    addr_t        io_base_addr;        // Address Base Pointer of INPUT/OUPUT
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
    logic change_pc_ena;                // Change PC 
    logic regfile_we;                   // Write to register file
    logic fregfile_we;                  // Write to fregister file
    //logic regfile_fp_we;               // Write to register file FPU
    instr_type_t instr_type;            // Type of instruction
    logic signed_op;                    // Signed Operation
    logic [3:0] mem_size;               // Memory operation size (Byte, Word, etc)
    logic stall_csr_fence;              // CSR or fence
    mem_type_t mem_type;                // Mem instruction type
    `ifdef SIM_COMMIT_LOG
    riscv_pkg::instruction_t inst;
    `endif
    `ifdef SIM_KONATA_DUMP
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

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch  
} ir_rr_stage_t;

typedef struct packed {
    instr_entry_t instr;                // Instruction
    bus64_t data_rs1;                   // Data operand 1
    bus64_t data_rs2;                   // Data operand 2
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

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    gl_index_t gl_index;                // Graduation List entry
} rr_exe_arith_instr_t;       //  Read Regfile to Execution stage for arithmetic pipeline

typedef struct packed {
    instr_entry_t instr;                // Instruction
    bus64_t data_rs1;                   // Data operand 1
    bus_simd_t data_rs2;                // Data operand 2
    sew_t      sew;                     // Element width
    bus64_t imm;                        // Immediate
    phreg_t prs1;                       // Physical register source 1
    logic   rdy1;                       // Ready register source 1
    phreg_t prs2;                       // Physical register source 2
    logic   rdy2;                       // Ready register source 2    
    phreg_t prd;                        // Physical register destination 
    phreg_t old_prd;                    // Old Physical register destination
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
} rr_exe_mem_instr_t;       //  Read Regfile to Execution stage for memory pipeline

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
    logic change_pc_ena;                // Change PC
    logic stall_csr_fence;              // CSR or fence
    reg_csr_addr_t csr_addr;            // CSR Address
    `ifdef SIM_KONATA_DUMP
    bus64_t id;
    `endif
    `ifdef SIM_COMMIT_LOG
    riscv_pkg::instruction_t inst;
    addr_t addr;
    `endif
    phreg_t prd;                        // Physical register destination

    logic checkpoint_done;              // It has a checkpoint
    checkpoint_ptr chkp;                // Checkpoint of branch

    fpuv_pkg::status_t fp_status;       // FP status of the executed instruction

    gl_index_t gl_index;                // Graduation List entry
    mem_type_t mem_type;                // Mem instruction type
} exe_wb_scalar_instr_t;       //  Execution Stage to scalar Write Back

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
    logic change_pc_ena;                // Change PC
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
    fpuv_pkg::status_t fp_status;       // FP status of the executed instruction

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
    logic fp_out_of_checkpoints;        // FP Rename out of checkpoints
    logic empty_free_list;              // Free list out of registers
    logic fp_empty_free_list;           // FP Free list out of registers
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
    logic [1:0] fp_enable_commit_update;         // Enable update of FP Free List and Rename from commit
} cu_ir_t;      // Control Unit to Rename

typedef struct packed {
    logic [NUM_SCALAR_WB-1:0] write_enable; // Enable write on register file
    logic [NUM_FP_WB-1:0]    fwrite_enable; // Enable write on register file FP
    logic [NUM_SCALAR_WB-1:0] snoop_enable; // Enable snoop to rr and exe stage
    logic [NUM_FP_WB-1:0]    fsnoop_enable; // Enable snoop to rr and exe stage
    logic write_enable_dbg;                 // Enable write on register file dbg usage
} cu_rr_t;      // Control unit to Register File

// Control Unit signals
typedef struct packed {
    logic valid_1;                // Valid Intruction ALU, MUL, DIV
    logic valid_2;                // Valid Intruction MEM
    logic valid_fp;               // Valid Intruction FP
    logic valid_fp_mem;           // Valid Intruction FP MEM
    logic change_pc_ena_1;        // Enable PC write
    logic is_branch;              // There is a branch in the ALU
    logic branch_taken;           // Branch taken
    logic stall;                  // Execution unit stalled
} exe_cu_t;

// Control Unit signals
typedef struct packed {
    logic [NUM_SCALAR_WB-1:0] valid;         // Valid Intruction
    logic [NUM_FP_WB-1:0]    fvalid;         // Valid FP Intruction
    logic change_pc_ena;                     // Enable PC write
    logic checkpoint_done;        // It has a checkpoint
    checkpoint_ptr  chkp;         // Label of the checkpoint
    gl_index_t gl_index;          // Graduation List entry of ALU
    logic [NUM_SCALAR_WB-1:0] write_enable;  // Write Enable to Register File
    logic [NUM_SCALAR_WB-1:0] snoop_enable;  // Snoop Enable to rr and exe
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
    logic [1:0] fwrite_enable;      // Write Enable to Register File
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
    // xcpt pc 
    bus64_t     csr_pc;
    logic [4:0] fp_status;       // FP status of the executed instruction 
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
} resp_csr_cpu_t;

typedef struct packed {
    // Triggers a halt on the pipeline 
    logic           halt_valid;
    // New PC addr
    addrPC_t        change_pc_addr;
    // change new pc valid
    logic           change_pc_valid;
    // Read from register file valid
    logic           reg_read_valid;
    // Read/Write addr from register file addr
    logic  [4:0]    reg_read_write_addr;
    // Write to register file valid
    logic           reg_write_valid;
    // Write to register file data
    bus64_t         reg_write_data;
    // Input register paddr
    logic  [5:0]    reg_read_write_paddr;
    // Read register file with paddr
    logic           reg_p_read_valid;
} debug_in_t;

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
    `ifdef SIM_COMMIT_LOG
    reg_csr_addr_t  csr_addr;               // CSR Address
    exception_t     exception;              // Exceptions
    bus_simd_t      result;                 // Result or immediate
    addr_t          addr;                   // Virtual address of memory op.
    `endif
    logic           ex_valid;
    logic           stall_csr_fence;        // CSR or fence
    logic           regfile_we;             // Write to register file
    logic           fregfile_we;            // Write to fregister file
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
    fpuv_pkg::status_t fp_status;           // FP status of the executed instruction
    mem_type_t mem_type;                // Mem instruction type
} gl_instruction_t;


typedef struct packed {
    reg_csr_addr_t  csr_addr;               // CSR Address
    exception_t     exception;              // Exceptions
    bus_simd_t      result;                 // Result or immediate
    `ifdef SIM_COMMIT_LOG
    addr_t addr;                            // Virtual address of memory op.
    `endif
    fpuv_pkg::status_t fp_status;           // FP status of the executed instruction
} gl_wb_data_t;


typedef struct packed {
    // current pc in fetch stage
    addr_t          pc_fetch;
    // current pc in decode stage
    addr_t          pc_dec;
    // current pc in read register stage
    addr_t          pc_rr;
    // current pc in execution stage
    addr_t          pc_exe;
    // current pc in write-back stage
    addr_t          pc_wb;
    // valid write-back
    logic           wb_valid_1;
    // write-back register file addr
    logic  [4:0]    wb_reg_addr_1;
    // write-back register file we
    logic           wb_reg_we_1;
        // valid write-back
    logic           wb_valid_2;
    // write-back register file addr
    logic  [4:0]    wb_reg_addr_2;
    // write-back register file we
    logic           wb_reg_we_2;
    // write-back register file read data
    bus64_t         reg_read_data;
    // Signal to ensure the debug ring only interacts when the
    // pipeline is empty
    logic	    reg_backend_empty;
    // physical register addres from the list
    logic  [5:0]    reg_list_paddr;
} debug_out_t;



localparam fpuv_pkg::fpu_features_t EPI_RV64D = '{
      Width:         64,
      EnableVectors: 1'b0,
      EnableNanBox:  1'b1,
      FpFmtMask:     5'b11000,
      IntFmtMask:    4'b0011
   };

localparam fpuv_pkg::fpu_implementation_t EPI_INIT = '{
    PipeRegs:   '{'{default: 5}, // ADDMUL
                '{default: 5},   // DIVSQRT
                '{default: 5},   // NONCOMP
                '{default: 5}},  // CONV
    UnitTypes:  '{'{default: fpuv_pkg::MERGED}, // ADDMUL
                '{default: fpuv_pkg::MERGED},   // DIVSQRT
                '{default: fpuv_pkg::PARALLEL}, // NONCOMP
                '{default: fpuv_pkg::MERGED}},  // CONV
    PipeConfig: fpuv_pkg::DISTRIBUTED
};

localparam int unsigned DIVSQRT_ITER = 3; //This parameter configure the number of iterations per cycle of the divsqrt unit.
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
} pmu_interface_t;

`ifdef SIM_COMMIT_LOG
typedef struct packed {
    longint unsigned pc;
    longint unsigned inst;
    longint unsigned dst;
    longint unsigned fdst;
    longint unsigned vdst;
    longint unsigned reg_wr_valid;
    longint unsigned freg_wr_valid;
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
