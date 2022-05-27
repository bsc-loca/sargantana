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
parameter VLEN = 128;
parameter MLEN = VLEN/8;
parameter OPCODE_WIDTH = 6;
parameter REG_WIDTH = 5;
parameter NUM_ISA_REGISTERS = 32;
parameter NUM_ISA_VREGISTERS = 32;
parameter INST_SIZE = 32;


// Common for RISCV types
typedef struct packed {
    logic [31:25] func7;
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
    logic [31:27] rs3;
    logic [26:25] fmt;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] rm;
    logic [11:7]  rd;
    logic [6:0]   opcode;
} instruction_r4type_t;

typedef struct packed {
    logic [31:27] func5;
    logic [26:25] fmt;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] rm;
    logic [11:7]  rd;
    logic [6:0]   opcode;
} instruction_fprtype_t;

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

typedef struct packed {
    logic [31:26] func6;
    logic [25:25] vm;
    logic [24:20] vs2;
    logic [19:15] vs1;
    logic [14:12] func3;
    logic [11:7]  vd;
    logic [6:0]   opcode;
} instruction_vtype_t;

typedef struct packed {
    logic [31:29] nf;
    logic [28:28] mew;
    logic [27:26] mop;
    logic [25:25] vm;
    logic [24:20] lumop;
    logic [19:15] rs1;
    logic [14:12] width;
    logic [11:7]  vd;
    logic [6:0]   opcode;
} instruction_vltype_t;

typedef struct packed {
    logic [31:29] nf;
    logic [28:28] mew;
    logic [27:26] mop;
    logic [25:25] vm;
    logic [24:20] sumop;
    logic [19:15] rs1;
    logic [14:12] width;
    logic [11:7]  vs3;
    logic [6:0]   opcode;
} instruction_vstype_t;

// RISCV Instruction types
typedef union packed {
    logic [INST_SIZE-1:0] bits;
    instruction_common_t  common;
    instruction_rtype_t   rtype;
    instruction_r4type_t  r4type;
    instruction_fprtype_t fprtype;
    instruction_itype_t   itype;
    instruction_stype_t   stype;
    instruction_btype_t   btype;
    instruction_utype_t   utype;
    instruction_jtype_t   jtype;
    instruction_vtype_t   vtype;
    instruction_vltype_t  vltype;
    instruction_vstype_t  vstype;
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
    OP_ATOMICS   = 7'b0101111,
    OP_LOAD_FP   = 7'b0000111,
    OP_STORE_FP  = 7'b0100111,
    OP_FP        = 7'b1010011,
    OP_V         = 7'b1010111,
    OP_FMADD     = 7'b1000011,
    OP_FMSUB     = 7'b1000111,
    OP_FNMSUB    = 7'b1001011,
    OP_FNMADD    = 7'b1001111
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
    F3_SB   = 3'b000,
    F3_SH   = 3'b001,
    F3_SW   = 3'b010,
    F3_SD   = 3'b011
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
    F3_FENCE   = 3'b000,
    F3_FENCE_I = 3'b001
} op_func3_fence_t;

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

typedef enum logic [2:0] {
    F3_OPIVV = 3'b000,
    F3_OPFVV = 3'b001,
    F3_OPMVV = 3'b010,
    F3_OPIVI = 3'b011,
    F3_OPIVX = 3'b100,
    F3_OPFVF = 3'b101,
    F3_OPMVX = 3'b110,
    F3_OPCFG = 3'b111
} op_func3_vector_t;

typedef enum logic [5:0] {
    F6_VADD   = 6'b000000,
    F6_VSUB   = 6'b000010,
    F6_VMINU  = 6'b000100,
    F6_VMIN   = 6'b000101,
    F6_VMAXU  = 6'b000110,
    F6_VMAX   = 6'b000111,
    F6_VAND   = 6'b001001,
    F6_VOR    = 6'b001010,
    F6_VXOR   = 6'b001011,
    F6_VMV    = 6'b010111,
    F6_VMSEQ  = 6'b011000,
    F6_VSLL   = 6'b100101,
    F6_VSRL   = 6'b101000,
    F6_VSRA   = 6'b101001
} op_func6_vector_opi_t;

typedef enum logic [5:0] {
    F6_VREDSUM   = 6'b000000, 
    F6_VREDAND   = 6'b000001,
    F6_VREDOR    = 6'b000010,
    F6_VREDXOR   = 6'b000011,
    F6_VEXT      = 6'b001100, //Goes unused in v1.0, but the encoding is still available. Why??
    F6_VWXUNARY0 = 6'b010000,
    F6_VCNT      = 6'b000110, //Custom instruction, for now we use vredmaxu encoding
    F6_VMUNARY0  = 6'b010110,  //This encoding changes on v1.0 of specs. For now we keep it like this
    F6_VMULHU    = 6'b100100,
    F6_VMUL      = 6'b100101,
    F6_VMULHSU   = 6'b100110,
    F6_VMULH     = 6'b100111
} op_func6_vector_opm_t;

typedef enum logic [5:0] {
    F6_VFADD = 6'b000000,
    F6_VFSUB = 6'b000010,
    F6_VFMIN = 6'b000100,
    F6_VFMAX = 6'b000110,
    F6_VFMV  = 6'b001101
} op_func6_vector_opf_t;

typedef enum logic [4:0] {
    VS1_VMV_X_S = 5'b00000,
    VS1_VID     = 5'b10001
} op_vs1_vector_t;

typedef enum logic [1:0] {
    MOP_UNIT_STRIDE = 2'b00
} mop_t;

typedef enum logic [4:0] {
    LUMOP_UNIT_STRIDE = 5'b00000
} lumop_t;

typedef enum logic [4:0] {
    SUMOP_UNIT_STRIDE = 5'b00000
} sumop_t;

typedef enum logic [2:0] {
    WIDTH_VECTOR_BYTE = 3'b000,
    WIDTH_VECTOR_HALF = 3'b101,
    WIDTH_VECTOR_WORD = 3'b110,
    WIDTH_VECTOR_ELEM = 3'b111
} width_t;

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

typedef enum logic [6:0] {
    F7_ECALL_EBREAK_URET    = 7'b0000000,
    F7_SRET_WFI_ERET_SFENCE = 7'b0001000,
    F7_SFENCE_VM            = 7'b0001001,
    F7_MRET_MRTS            = 7'b0011000
} op_func7_system_t; // The first 7 bits of func7

typedef enum logic [4:0] {
    RS2_ECALL_ERET      = 5'b00000,
    RS2_EBREAK_SFENCEVM = 5'b00001,
    RS2_URET_SRET_MRET  = 5'b00010,
    RS2_WFI             = 5'b00101
    //RS2_MRTS            = 5'b00101 //Old ISA
} op_rs2_system_t; // the next 5 bits after func7

typedef enum logic [6:0] {
    F7_MUL_DIV  = 7'b0000001
} op_func7_mul_t;

typedef enum logic [4:0] {
    F5_FP_FADD              = 5'b00000,
    F5_FP_FSUB              = 5'b00001,
    F5_FP_FMUL              = 5'b00010,
    F5_FP_FDIV              = 5'b00011,
    F5_FP_FSQRT             = 5'b01011,
    F5_FP_FSGNJ             = 5'b00100,
    F5_FP_FMIN_MAX          = 5'b00101,
    F5_FP_FCVT_F2I          = 5'b11000,
    F5_FP_FMV_F2I_FCLASS    = 5'b11100,
    F5_FP_FCMP              = 5'b10100,
    F5_FP_FCVT_I2F          = 5'b11010,
    F5_FP_FMV_I2F           = 5'b11110,
    F5_FP_FCVT_SD           = 5'b01000
} op_func7_fp_t;

typedef enum logic [1:0] {
    FMT_FP_S  = 2'b00,
    FMT_FP_D  = 2'b01,
    FMT_FP_Q  = 2'b10,
    FMT_FP_H  = 2'b11
} op_fmt_fp_t;

typedef enum logic [2:0] {
    F3_UNIMP1 = 3'b000,
    F3_UNIMP2 = 3'b001,
    F3_FLW    = 3'b010,
    F3_FLD    = 3'b011,
    F3_VSEW   = 3'b111
} op_func3_fp_t;

// Rounding modes FP
typedef enum logic [2:0] {
    FRM_RNE    = 3'b000, // Round to Nearest, ties to Even
    FRM_RTZ    = 3'b001, // Round towards Zero
    FRM_RDN    = 3'b010, // Round Down (towards −∞)
    FRM_RUP    = 3'b011, // Round Up (towards +∞)
    FRM_RMM    = 3'b100, // Round to Nearest, ties to Max Magnitude
    FRM_INV_1  = 3'b101, // Invalid. Reserved for future use.
    FRM_INV_2  = 3'b110, // Invalid. Reserved for future use.
    FRM_DYN    = 3'b111  // In instruction’s rm field, selects dynamic rounding mode;
} op_frm_fp_t;           // In Rounding Mode register, Invalid.

// Rounding modes FP
typedef enum logic [1:0] {
    FMT_S = 2'b00, // 32-bit single-precision
    FMT_D = 2'b01, // 64-bit double-precision
    FMT_H = 2'b10, // 16-bit half-precision
    FMT_Q = 2'b11  // 128-bit quad-precision
} op_riscv_fmt_t; 

// Rounding modes FP
/*typedef enum logic [0:0] {
    FMT_S = 1'b0, // 32-bit single-precision
    FMT_D = 1'b1  // 64-bit double-precision
} op_fmt_fp_drac_t; */

// Status flags
typedef struct packed {
    logic NV; // Invalid
    logic DZ; // Divide by zero
    logic OF; // Overflow
    logic UF; // Underflow
    logic NX; // Inexact
} fp_status_t;

// By RISCV ISA, exceptions are 64 bits
typedef enum logic[XLEN-1:0] {
    INSTR_ADDR_MISALIGNED   = 64'h00,
    INSTR_ACCESS_FAULT      = 64'h01,
    ILLEGAL_INSTR           = 64'h02,
    BREAKPOINT              = 64'h03,
    LD_ADDR_MISALIGNED      = 64'h04,
    LD_ACCESS_FAULT         = 64'h05,
    ST_AMO_ADDR_MISALIGNED  = 64'h06,
    ST_AMO_ACCESS_FAULT     = 64'h07,
    USER_ECALL              = 64'h08,
    SUPERVISOR_ECALL        = 64'h09,
    INSTR_PAGE_FAULT        = 64'h0C,
    LD_PAGE_FAULT           = 64'h0D,
    ST_AMO_PAGE_FAULT       = 64'h0F,
    NONE                    = 64'hFF
} exception_cause_t;

// Hack to codify Vector Element Loads and Stores
parameter __vector_element = 4'b0111;

endpackage
