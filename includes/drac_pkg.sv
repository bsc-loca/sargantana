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

typedef logic [riscv_pkg::INST_SIZE-1:0] inst_t;
typedef logic [ICACHELINE_SIZE:0] icache_line_t;
typedef reg   [ICACHELINE_SIZE:0] icache_line_reg_t;
typedef logic [ICACHE_IDX_BITS_SIZE-1:0] icache_idx_t;
typedef logic [ICACHE_VPN_BITS_SIZE-1:0] icache_vpn_t;


typedef enum {
    NEXT_PC_SEL_PC,
    NEXT_PC_SEL_PC_4,
    NEXT_PC_SEL_JUMP
} next_pc_sel_t;

typedef enum logic {
    SEL_JUMP_COMMIT,
    SEL_JUMP_DECODE
} jump_addr_fetch_t;

typedef enum {
    NoReq,
    ReqValid,
    RespReady
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
    addrPC_t origin; // this will be the addr or pc but maybe other things?
    logic valid;
} exception_t;

// Req coming from ICache
typedef struct packed {
    logic  valid;
    inst_t data;
    //addr_t req_addr; I think it is not completely necessary
    //exception_t ex;
    logic instr_addr_misaligned;
    logic instr_access_fault;
    logic instr_page_fault;
} req_icache_cpu_t;

// Req send to ICache
typedef struct packed {
    logic  valid;
    addr_t vaddr;
} req_cpu_icache_t;

// dcache response
// explain what is everything
typedef struct packed {
    logic     dmem_resp_replay_i;
    bus64_t   dmem_resp_data_i;
    logic     dmem_req_ready_i;
    logic     dmem_resp_valid_i;
    logic     dmem_resp_nack_i;
    logic     dmem_xcpt_ma_st_i;
    logic     dmem_xcpt_ma_ld_i;
    logic     dmem_xcpt_pf_st_i;
    logic     dmem_xcpt_pf_ld_i;
} req_dcache_cpu_t;

// dcache access
// TODO: explain magic numbers
typedef struct packed {
    logic        dmem_req_valid_o;
    logic [4:0]  dmem_req_cmd_o;
    addr_t       dmem_req_addr_o;
    bus64_t      dmem_op_type_o;
    bus64_t      dmem_req_data_o;
    logic [7:0]  dmem_req_tag_o;
    logic        dmem_req_invalidate_lr_o;
    logic        dmem_req_kill_o;
    logic        dmem_lock_o;
} req_cpu_dcache_t;

typedef enum {
    SEL_SRC1_REGFILE,
    SEL_SRC2_REGFILE,
    SEL_IMM,
    SEL_PC,
    SEL_PC_4,
    SEL_BYPASS
} alu_sel_t;

typedef enum {
    UNIT_ALU,
    UNIT_DIV,
    UNIT_MUL,
    UNIT_BRANCH,
    UNIT_MEM,
    UNIT_CONTROL
} functional_unit_t;

typedef enum {
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
   MRET, SRET, DRET, ECALL, WFI, FENCE, FENCE_I, SFENCE_VMA, CSR_WRITE, CSR_READ, CSR_SET, CSR_CLEAR,
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
   FLD, FLW, FLH, FLB, FSD, FSW, FSH, FSB,
   // Floating-Point Computational Instructions
   FADD, FSUB, FMUL, FDIV, FMIN_MAX, FSQRT, FMADD, FMSUB, FNMSUB, FNMADD,
   // Floating-Point Conversion and Move Instructions
   FCVT_F2I, FCVT_I2F, FCVT_F2F, FSGNJ, FMV_F2X, FMV_X2F,
   // Floating-Point Compare Instructions
   FCMP,
   // Floating-Point Classify Instruction
   FCLASS,
   // Vectorial Floating-Point Instructions that don't directly map onto the scalar ones
   VFMIN, VFMAX, VFSGNJ, VFSGNJN, VFSGNJX, VFEQ, VFNE, VFLT, VFGE, VFLE, VFGT, VFCPKAB_S, VFCPKCD_S, VFCPKAB_D, VFCPKCD_D
} instr_type_t;

typedef enum {
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

typedef enum {
    ALU_MUL,
    ALU_MULH,
    ALU_MULHSU,
    ALU_MULHS,
    ALU_DIV,
    ALU_DIVU,
    ALU_REM,
    ALU_REMU
} mul_op_t;


typedef enum {
    B_EQ,
    B_NE,
    B_LT,
    B_GE,
    B_LTU,
    B_GEU
} branch_op_t;

typedef enum {
    CT_JAL,
    CT_JALR,
    CT_BRANCH
} ctrl_xfer_op_t;

typedef enum {
    MEM_LOAD,
    MEM_STORE,
    MEM_AMO
} mem_op_t;

typedef enum {
    BYTE,
    HALFWORD,
    WORD,
    DOUBLEWORD,
    BYTE_UNSIGNED,
    HALFWORD_UNSIGNED,
    WORD_UNSIGNED
} mem_format_t;

typedef enum {
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
    logic signed_op;
    logic [2:0] funct3;
    bus64_t imm;
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
    addr_t result_pc;
    reg_t rd;
    bus64_t result_rd;
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
} id_cu_t;

// Control Unit signals
typedef struct packed {
    next_pc_sel_t next_pc;
} cu_if_t;

// Control Unit signals
typedef struct packed {
    logic valid;
    logic change_pc_ena;
    //branch_pred_t bpred;
    //exception_t ex;
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
    // whether insert in fetch from dec or commit
    jump_addr_fetch_t sel_addr_if;
} pipeline_ctrl_t;

// Pipeline control
typedef struct packed {
    logic       valid; // whether is a jal or not
    addrPC_t    jump_addr;
} jal_id_if_t;



endpackage

