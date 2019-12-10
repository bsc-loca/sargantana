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
import riscv_pkg::*;

package drac_pkg;

//parameter XLEN = 64; 
parameter ICACHELINE_SIZE = 127;
parameter ADDR_SIZE = 40;
//parameter INST_SIZE = 32;
parameter REGFILE_WIDTH = 5;
parameter ICACHE_IDX_BITS_SIZE = 12;
parameter ICACHE_VPN_BITS_SIZE = 28;
parameter CSR_ADDR_SIZE = 12;
parameter CSR_CMD_SIZE = 3;
// RISCV
//parameter OPCODE_WIDTH = 6;
//parameter REG_WIDTH = 5;

typedef reg   [63:0] reg64_t;
typedef logic [127:0] bus128_t;
typedef logic [63:0] bus64_t;
typedef logic [31:0] bus32_t;

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


typedef enum logic [1:0] {
    NEXT_PC_SEL_PC_4 = 2'b00,
    NEXT_PC_SEL_PC   = 2'b01,
    NEXT_PC_SEL_JUMP = 2'b10
} next_pc_sel_t;

typedef enum logic [1:0] {
    SEL_JUMP_COMMIT = 2'b00,
    SEL_JUMP_CSR    = 2'b01,
    SEL_JUMP_DECODE = 2'b10
} jump_addr_fetch_t;

typedef enum logic [1:0]{
    ResetState = 2'b00,
    NoReq      = 2'b01,
    ReqValid   = 2'b10,
    Replay     = 2'b11
} icache_state_t;

typedef enum logic {
    PRED_NOT_TAKEN,
    PRED_TAKEN
} branch_pred_decision_t;

typedef struct packed {
    branch_pred_decision_t decision;
    addrPC_t pred_addr;
} branch_pred_t;

typedef struct packed {
    riscv_pkg::exception_cause_t cause;
    bus64_t origin; // this will be the addr or pc but maybe other things?
    logic valid;
} exception_t;

// Response coming from ICache
typedef struct packed {
    logic  valid;
    inst_t data;
    logic instr_access_fault;
    logic instr_page_fault;
} resp_icache_cpu_t;

// Request send to ICache
typedef struct packed {
    logic  valid;
    addr_t vaddr;
    logic  invalidate_icache;
} req_cpu_icache_t;

typedef enum logic [2:0] {
    SEL_SRC1_REGFILE,
    SEL_SRC2_REGFILE,
    SEL_IMM,
    SEL_PC,
    SEL_PC_4,
    SEL_BYPASS
} alu_sel_t;

typedef enum logic [2:0]{
    UNIT_ALU,
    UNIT_DIV,
    UNIT_MUL,
    UNIT_BRANCH,
    UNIT_MEM,
    UNIT_CONTROL,
    UNIT_SYSTEM
} functional_unit_t;

typedef enum logic [1:0]{
    SEL_FROM_MEM,
    SEL_FROM_ALU,
    SEL_FROM_BRANCH,
    SEL_FROM_CONTROL
} reg_sel_t;

typedef enum logic [6:0] { 
    // basic ALU op
   ADD, SUB, ADDW, SUBW,
   // logic operations
   XOR, OR, AND,
   // shifts
   SRA, SRL, SLL, SRLW, SLLW, SRAW,
   // comparisons
   BLT, BLTU, BGE, BGEU, BEQ, BNE,
   // jumps
   JALR, JAL, BRANCH,
   // set lower than operations
   SLT, SLTU,
   // CSR functions
   MRET, SRET, URET, ECALL, EBREAK, WFI, FENCE, FENCE_I, SFENCE_VMA,
   // Old ISA CSR functions
   ERET, MRTS,
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
   // Vectorial Floating-Point Instructions that don't directly map onto the scalar ones
   VFMIN, VFMAX, VFSGNJ, VFSGNJN, VFSGNJX, VFEQ, VFNE, VFLT, VFGE, VFLE, VFGT, VFCPKAB_S, VFCPKCD_S, VFCPKAB_D, VFCPKCD_D
} instr_type_t;

typedef enum logic [3:0]{
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA,
    ALU_OR,
    ALU_AND
} alu_op_t;

typedef enum logic [2:0]{
    ALU_MUL,
    ALU_MULH,
    ALU_MULHSU,
    ALU_MULHS,
    ALU_DIV,
    ALU_DIVU,
    ALU_REM,
    ALU_REMU
} mul_op_t;


typedef enum logic [2:0]{
    B_EQ,
    B_NE,
    B_LT,
    B_GE,
    B_LTU,
    B_GEU
} branch_op_t;

typedef enum logic [1:0]{
    CT_JAL,
    CT_JALR,
    CT_BRANCH
} ctrl_xfer_op_t;

typedef enum logic [1:0]{
    MEM_NOP,
    MEM_LOAD,
    MEM_STORE,
    MEM_AMO
} mem_op_t;

typedef enum logic [2:0]{
    BYTE,
    HALFWORD,
    WORD,
    DOUBLEWORD,
    BYTE_UNSIGNED,
    HALFWORD_UNSIGNED,
    WORD_UNSIGNED
} mem_format_t;

typedef enum logic [3:0] {
    AMO_LR,
    AMO_SC,
    AMO_SWAP,
    AMO_ADD,
    AMO_XOR,
    AMO_AND,
    AMO_OR,
    AMO_MIN,
    AMO_MAX,
    AMO_MINU,
    AMO_MAXU
} amo_op_t;

typedef enum logic[CSR_CMD_SIZE-1:0] {
    CSR_CMD_NOPE    = 3'b000,
    CSR_CMD_WRITE   = 3'b001,
    CSR_CMD_SET     = 3'b010,
    CSR_CMD_CLEAR   = 3'b011,
    CSR_CMD_SYS     = 3'b100,
    CSR_CMD_READ    = 3'b101,
    CSR_CMD_N1      = 3'b110,
    CSR_CMD_N2      = 3'b111
} csr_cmd_t;

// Response coming from ICache
typedef struct packed {
    logic        ready; // Dcache_interface ready to accept mem. access
    bus64_t      data;  // Data from load
    logic        lock;   // Dcache cannot accept more mem. accesses
    logic xcpt_ma_st;
    logic xcpt_ma_ld;
    logic xcpt_pf_st;
    logic xcpt_pf_ld;
    bus64_t addr;
} resp_dcache_cpu_t;

// Request send to ICache
typedef struct packed {
    logic         valid;             // New memory request
    logic         kill;              // Exception detected at Commit
    //logic         csr_eret;          // Exception from CSR Register File //TODO:not needed
    bus64_t       data_rs1;          // Data operand 1
    bus64_t       data_rs2;          // Data operand 2
    instr_type_t  instr_type;        // Type of instruction
    mem_op_t      mem_op;            // Type of memory access
    logic [2:0]   funct3;            // Granularity of mem. access
    reg_t         rd;                // Destination register. Used for identify a pending Miss
    bus64_t       imm;               // Inmmediate 
    addr_t        io_base_addr;      // Address Base Pointer of INPUT/OUPUT
} req_cpu_dcache_t;

// Fetch Stage
typedef struct packed {
    addrPC_t pc_inst;
    riscv_pkg::instruction_t inst;
    logic valid;
    branch_pred_t bpred;
    exception_t ex;
} if_id_stage_t;

// This is created by decode
//
typedef struct packed {
    logic valid;
    addrPC_t pc;
    branch_pred_t bpred;
    exception_t ex;
    reg_t rs1;
    reg_t rs2;
    reg_t rd;
    
    logic use_imm;
    logic use_pc;
    logic op_32;
    alu_op_t alu_op;
    functional_unit_t unit;
    // control bits
    logic change_pc_ena;
    logic regfile_we;
    reg_sel_t regfile_w_sel;
    // future
    instr_type_t instr_type;
    bus64_t result; // it can be used as the immediate

    // Added by Ruben
    mem_op_t mem_op;
    logic signed_op;
    logic [2:0] funct3;
    bus64_t imm;
    logic aq;
    logic rl;
    // TODO remove
    logic stall_csr_fence;
} instr_entry_t;

typedef struct packed {
    functional_unit_t functional_unit;
    logic int_32;

    // ALU signals
    alu_op_t alu_op;
    mul_op_t mul_op;
    logic use_imm;
    bus64_t imm;

    // Branch unit signals
    ctrl_xfer_op_t ctrl_xfer_op;
    branch_op_t branch_op;
    addrPC_t pc;

    // Memory unit signals
    mem_op_t mem_op;
    // BAD NAMING FUNCT3
    logic [2:0] funct3;
    mem_format_t mem_format;
    amo_op_t amo_op;
    reg_t rd;
} dec_exe_instr_t;

typedef struct packed {
    logic regfile_we;
    logic change_pc_ena;
} dec_wb_instr_t;

typedef struct packed {
    instr_entry_t instr;
    bus64_t data_rs1;
    bus64_t data_rs2;
} rr_exe_instr_t;

typedef struct packed {
    instr_entry_t instr;
    addrPC_t result_pc;
    reg_t rd;
    bus64_t result_rd;
    logic branch_taken;
} exe_wb_instr_t;

// For bypass
typedef struct packed {
    logic valid;
    reg_t rd;
    bus64_t data;
} wb_exe_instr_t;

// Control Unit signals
typedef struct packed {
    logic valid_fetch;
} if_cu_t;

typedef struct packed {
    logic valid_jal;
    logic stall_csr_fence;
} id_cu_t;

typedef struct packed {
    logic stall_csr_fence;
} rr_cu_t;


typedef struct packed {
    next_pc_sel_t next_pc;
    logic invalidate_icache;
} cu_if_t;

typedef struct packed {
    logic write_enable;
} cu_rr_t;

// Control Unit signals
typedef struct packed {
    logic stall;
    logic stall_csr_fence;
} exe_cu_t;

// Control Unit signals
typedef struct packed {
    logic valid;
    logic change_pc_ena;
    logic branch_taken;
    logic csr_enable_wb;
    logic write_enable;
    logic stall_csr_fence;
    logic xcpt;
    logic ecall_taken;
    logic fence;
    //branch_pred_t bpred;
} wb_cu_t;


// Control Unit signals
typedef struct packed {
    logic enable_commit;
} cu_wb_t;

// Pipeline control
typedef struct packed {
    logic stall_if;
    logic stall_id;
    logic stall_rr;
    logic stall_exe;
    logic stall_wb;

    logic flush_if;
    logic flush_id;
    logic flush_rr;
    logic flush_exe;
    logic flush_wb;
    // whether insert in fetch from dec or commit
    jump_addr_fetch_t sel_addr_if;
} pipeline_ctrl_t;

// Pipeline control
typedef struct packed {
    logic       valid; // whether is a jal or not
    addrPC_t    jump_addr;
} jal_id_if_t;

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
    logic       csr_retire;
    // exception cause
    bus64_t     csr_xcpt_cause;
    // xcpt pc 
    bus64_t     csr_pc; 
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
    // or WFIdrac
    logic       csr_stall;
    // CSR exception
    // read CSR without enough privilege
    // or eret/ecall
    // CSR handles all the usual logic
    // don't care about cause and do the typical
    // flush and charge evec? 
    logic       csr_exception;
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
} resp_csr_cpu_t;



endpackage

