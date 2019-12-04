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
package riscv_pkg;

parameter XLEN = 64; 
parameter OPCODE_WIDTH = 6;
parameter REG_WIDTH = 5;
parameter INST_SIZE = 32;


// Common for RISCV types
typedef struct packed {
    logic [31:25] void2;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] func3;
    logic [11:7]  rd;
    logic [6:0]   opcode;
} instruction_common_t;

typedef struct packed {
    logic [31:25] func7;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] func3;
    logic [11:7]  rd;
    logic [6:0]   opcode;
} instruction_rtype_t;

typedef struct packed {
    logic [31:20] imm;
    logic [19:15] rs1;
    logic [14:12] func3;
    logic [11:7]  rd;
    logic [6:0]   opcode;
} instruction_itype_t;

typedef struct packed {
    logic [31:25] imm5;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] func3;
    logic [11:7]  imm0;
    logic [6:0]  opcode;
} instruction_stype_t;

typedef struct packed {
    logic [31:31] imm12;
    logic [30:25] imm5;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] func3;
    logic [11:8]  imm1;
    logic [7:7]   imm11;
    logic [6:0]   opcode;
} instruction_btype_t;

typedef struct packed {
    logic [31:12] imm;
    logic [11:7]  rd;
    logic [6:0]   opcode;
} instruction_utype_t;

typedef struct packed {
    logic [31:31] imm20;
    logic [30:21] imm1;
    logic [20:20] imm11;
    logic [19:12] imm12;
    logic [11:7]  rd;
    logic [6:0]   opcode;
} instruction_jtype_t;

// RISCV Instruction types
typedef union packed {
    logic [INST_SIZE-1:0] bits;
    instruction_common_t  common;
    instruction_rtype_t   rtype;
    instruction_itype_t   itype;
    instruction_stype_t   stype;
    instruction_btype_t   btype;
    instruction_utype_t   utype;
    instruction_jtype_t   jtype;
} instruction_t;



// Inside the system includes ecall and ebreak
typedef enum logic [6:0] {
    OP_LUI       = 7'b0110111,
    OP_AUIPC     = 7'b0010111,
    OP_JAL       = 7'b1101111,
    OP_JALR      = 7'b1100111,
    OP_BRANCH    = 7'b1100011,
    OP_LOAD      = 7'b0000011,
    OP_STORE     = 7'b0100011,
    OP_ALU_I     = 7'b0010011,
    OP_ALU       = 7'b0110011,
    OP_ALU_I_W   = 7'b0011011,
    OP_ALU_W     = 7'b0111011,
    OP_FENCE     = 7'b0001111,
    OP_SYSTEM    = 7'b1110011,
    OP_ATOMICS   = 7'b0101111
} op_inst_t;

typedef enum logic [2:0] {
    F3_BEQ  = 3'b000,
    F3_BNE  = 3'b001,
    F3_BLT  = 3'b100,
    F3_BGE  = 3'b101,
    F3_BLTU = 3'b110,
    F3_BGEU = 3'b111
} op_funct3_branch_t;

typedef enum logic [2:0] {
    F3_LB   = 3'b000,
    F3_LH   = 3'b001,
    F3_LW   = 3'b010,
    F3_LD   = 3'b011,
    F3_LBU  = 3'b100,
    F3_LHU  = 3'b101,
    F3_LWU  = 3'b110
} op_func3_load_t;

typedef enum logic [2:0] {
    STORE_SB   = 3'b000,
    STORE_SH   = 3'b001,
    STORE_SW   = 3'b010,
    STORE_SD   = 3'b011
} op_func3_store_t;


typedef enum logic [2:0] {
    F3_ADDI  = 3'b000,
    F3_SLTI  = 3'b010,
    F3_SLTIU = 3'b011,
    F3_XORI  = 3'b100,
    F3_ORI   = 3'b110,
    F3_ANDI  = 3'b111,
    F3_SLLI  = 3'b001,
    F3_SRLAI = 3'b101
} op_func3_alu_imm_t;


typedef enum logic [2:0] {
    F3_ADD_SUB = 3'b000,
    F3_SLL     = 3'b001,
    F3_SLT     = 3'b010,
    F3_SLTU    = 3'b011,
    F3_XOR     = 3'b100,
    F3_SRL_SRA = 3'b101,
    F3_OR      = 3'b110,
    F3_AND     = 3'b111
} op_func3_alu_t;

typedef enum logic [2:0] {
    F3_ECALL_EBREAK_ERET = 3'b000,
    F3_CSRRW             = 3'b001,
    F3_CSRRS             = 3'b010,
    F3_CSRRC             = 3'b011,
    F3_CSRRWI            = 3'b101,
    F3_CSRRSI            = 3'b110,
    F3_CSRRCI            = 3'b111
} op_func3_system_t;


typedef enum logic [2:0] {
    //F3_64_SLLI         = 3'b001,
    //F3_64_SRLI_SRAI    = 3'b101,
    F3_64_ADDIW        = 3'b000,
    F3_64_SLLIW        = 3'b001,
    F3_64_SRLIW_SRAIW  = 3'b101
} op_func3_alu_imm_64_t;


typedef enum logic [2:0] {
    F3_64_ADDW_SUBW = 3'b000,
    F3_64_SLLW      = 3'b001,
    F3_64_SRLW_SRAW = 3'b101
} op_func3_alu_64_t;

typedef enum logic [2:0] {
    F3_MUL    = 3'b000,
    F3_MULH   = 3'b001,
    F3_MULHSU = 3'b010,
    F3_MULHU  = 3'b011,
    F3_DIV    = 3'b100,
    F3_DIVU   = 3'b101,
    F3_REM    = 3'b110,
    F3_REMU   = 3'b111
} op_func3_mul_t;


typedef enum logic [2:0] {
    F3_MULW   = 3'b000,
    F3_DIVW   = 3'b100,
    F3_DIVUW  = 3'b101,
    F3_REMW   = 3'b110,
    F3_REMUW  = 3'b111
} op_func3_mul64_t;

typedef enum logic [2:0] {
    F3_ATOMICS      = 3'b010,
    F3_ATOMICS_64   = 3'b011
} op_func3_atomics_t;

typedef enum logic [4:0] {
    LR_W        = 5'b00010,
    SC_W        = 5'b00011,
    AMOSWAP_W   = 5'b00001,
    AMOADD_W    = 5'b00000,
    AMOXOR_W    = 5'b00100,
    AMOAND_W    = 5'b01100,
    AMOOR_W     = 5'b01000,
    AMOMIN_W    = 5'b10000,
    AMOMAX_W    = 5'b10100,
    AMOMINU_W   = 5'b11000,
    AMOMAXU_W   = 5'b11100
} op_func7_atomics_t;

typedef enum logic [4:0] {
    LR_D        = 5'b00010,
    SC_D        = 5'b00011,
    AMOSWAP_D   = 5'b00001,
    AMOADD_D    = 5'b00000,
    AMOXOR_D    = 5'b00100,
    AMOAND_D    = 5'b01100,
    AMOOR_D     = 5'b01000,
    AMOMIN_D    = 5'b10000,
    AMOMAX_D    = 5'b10100,
    AMOMINU_D   = 5'b11000,
    AMOMAXU_D   = 5'b11100
} op_func7_atomics_64_t;


typedef enum logic [6:0] {
    F7_SRAI_SUB_SRA   = 7'b0100000,
    F7_NORMAL         = 7'b0000000
} op_func7_alu_t;

typedef enum logic [6:0] {
    F7_64_SRAIW_SUBW_SRAW  = 7'b0100000,
    F7_64_NORMAL           = 7'b0000000
} op_func7_alu_64_t;

typedef enum logic [11:0] {
    F12_ECALL   = 12'b000000000000,
    F12_EBREAK  = 12'b000000000001,
    F12_URET    = 12'b000000000010,
    F12_SRET    = 12'b000100000010,
    F12_MRET    = 12'b001100000010,
    F12_WFI     = 12'b000100000011,
    F12_ERET    = 12'b000100000000, //Old ISA
    F12_MRTS    = 12'b001100000101 //Old ISA
} op_func12_system_t;

typedef enum logic [6:0] {
    F7_MUL_DIV  = 7'b0000001
} op_func7_mul_t;

// By RISCV ISA, exceptions are 64 bits
typedef enum logic[XLEN-1:0] {
    INSTR_ADDR_MISALIGNED   = 64'h00,
    INSTR_ACCESS_FAULT      = 64'h01,
    ILLEGAL_INSTR           = 64'h02,
    BREAKPOINT              = 64'h03,
    LD_ADDR_MISALIGNED      = 64'h04,
    LD_ACCESS_FAULT         = 64'h05,
    ST_AMO_ADDR_MISALIGNED  = 64'h06,
    ST_AMO_ACCES_FAULT      = 64'h07,
    USER_ECALL              = 64'h08,
    SUPERVISOR_ECALL        = 64'h09,
    INSTR_PAGE_FAULT        = 64'h0C,
    LD_PAGE_FAULT           = 64'h0D,
    ST_AMO_PAGE_FAULT       = 64'h0F,
    NONE                    = 64'hFF
} exception_cause_t;

endpackage
