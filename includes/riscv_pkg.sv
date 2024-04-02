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
    F6_VADD         = 6'b000000,
    F6_VSUB         = 6'b000010,
    F6_VRSUB        = 6'b000011,
    F6_VADC         = 6'b010000,
    F6_VSBC         = 6'b010010,
    F6_VMADC        = 6'b010001,
    F6_VMSBC        = 6'b010011,
    F6_VMINU        = 6'b000100,
    F6_VMIN         = 6'b000101,
    F6_VMAXU        = 6'b000110,
    F6_VMAX         = 6'b000111,
    F6_VAND         = 6'b001001,
    F6_VOR          = 6'b001010,
    F6_VXOR         = 6'b001011,
    F6_VMERGE_VMV   = 6'b010111,
    F6_VMSEQ        = 6'b011000,
    F6_VMSNE        = 6'b011001,
    F6_VMSLTU       = 6'b011010,
    F6_VMSLT        = 6'b011011,
    F6_VMSLEU       = 6'b011100,
    F6_VMSLE        = 6'b011101,
    F6_VMSGTU       = 6'b011110,
    F6_VMSGT        = 6'b011111,
    F6_VSADDU       = 6'b100000,
    F6_VSADD        = 6'b100001,
    F6_VSSUBU       = 6'b100010,
    F6_VSSUB        = 6'b100011,
    F6_VSLL         = 6'b100101,
    F6_VMV1R        = 6'b100111,
    F6_VSRL         = 6'b101000,
    F6_VSRA         = 6'b101001,
    F6_VNSRL        = 6'b101100,
    F6_VNSRA        = 6'b101101
} op_func6_vector_opi_t;

typedef enum logic [5:0] {
    F6_VREDSUM   = 6'b000000, 
    F6_VREDAND   = 6'b000001,
    F6_VREDOR    = 6'b000010,
    F6_VREDXOR   = 6'b000011,
    F6_VEXT      = 6'b001100, //Goes unused in v1.0, but the encoding is still available. Why??
    F6_VRWXUNARY0 = 6'b010000,
    F6_VCNT       = 6'b010001, //Custom instruction
    F6_VMAND     = 6'b011001,
    F6_VMOR      = 6'b011010,
    F6_VMXOR     = 6'b011011,
    F6_VMUNARY0  = 6'b010100,  //This encoding changes on v1.0 of specs. For now we keep it like this
    F6_VXUNARY0  = 6'b010010,
    F6_VMULHU    = 6'b100100,
    F6_VMUL      = 6'b100101,
    F6_VMULHSU   = 6'b100110,
    F6_VMULH     = 6'b100111,
    F6_VMADD     = 6'b101001,
    F6_VNMSUB    = 6'b101011,
    F6_VMACC     = 6'b101101,
    F6_VNMSAC    = 6'b101111,
    F6_VWADDU    = 6'b110000,
    F6_VWADD     = 6'b110001,
    F6_VWSUBU    = 6'b110010,
    F6_VWSUB     = 6'b110011,
    F6_VWADDUW   = 6'b110100,
    F6_VWADDW    = 6'b110101,
    F6_VWSUBUW   = 6'b110110,
    F6_VWSUBW    = 6'b110111,
    F6_VWMULU    = 6'b111000,
    F6_VWMULSU   = 6'b111010,
    F6_VWMUL     = 6'b111011
} op_func6_vector_opm_t;

typedef enum logic [5:0] {
    F6_VFADD = 6'b000000,
    F6_VFSUB = 6'b000010,
    F6_VFMIN = 6'b000100,
    F6_VFMAX = 6'b000110,
    F6_VFMV  = 6'b001101
} op_func6_vector_opf_t;

typedef enum logic [4:0] {
    VS1_ZEXT_VF8 = 5'b00010,
    VS1_SEXT_VF8 = 5'b00011,
    VS1_ZEXT_VF4 = 5'b00100,
    VS1_SEXT_VF4 = 5'b00101,
    VS1_ZEXT_VF2 = 5'b00110,
    VS1_SEXT_VF2 = 5'b00111 
} op_vxunary0_vs1_vector_t;

typedef enum logic [4:0] {
    VS1_VMV_X_S = 5'b00000
} op_vwxunary0_vs1_vector_t;

typedef enum logic [4:0] {
    VS1_VID     = 5'b10001
} op_vmunary0_vs1_vector_t;

typedef enum logic [4:0] {
    VS2_VMV_S_X = 5'b00000
} op_vrxunary0_vs2_vector_t;

typedef enum logic [1:0] {
    MOP_UNIT_STRIDE         = 2'b00,
    MOP_INDEXED_UNORDERED   = 2'b01,
    MOP_STRIDED             = 2'b10,
    MOP_INDEXED_ORDERED     = 2'b11
} mop_t;

typedef enum logic [4:0] {
    LUMOP_UNIT_STRIDE       = 5'b00000,
    LUMOP_UNIT_STRIDE_WREG  = 5'b01000,
    LUMOP_MASK              = 5'b01011
} lumop_t;

typedef enum logic [4:0] {
    SUMOP_UNIT_STRIDE       = 5'b00000,
    SUMOP_UNIT_STRIDE_WREG  = 5'b01000,
    SUMOP_MASK              = 5'b01011
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
    F3_UNIMP2 = 3'b001,
    F3_FLW    = 3'b010,
    F3_FLD    = 3'b011,
    F3_V8B    = 3'b000,
    F3_V16B   = 3'b101,
    F3_V32B   = 3'b110,
    F3_V64B   = 3'b111
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
    DEBUG_REQUEST           = 64'h18,
    NONE                    = 64'hFF
} exception_cause_t;

// Hack to codify Vector Element Loads and Stores
parameter __vector_element = 4'b1000;

// --------------------
// Privilege Spec
// --------------------
typedef enum logic[1:0] {
    PRIV_LVL_M = 2'b11,
    PRIV_LVL_S = 2'b01,
    PRIV_LVL_U = 2'b00
} priv_lvl_t;

// type which holds xlen
typedef enum logic [1:0] {
    XLEN_32  = 2'b01,
    XLEN_64  = 2'b10,
    XLEN_128 = 2'b11
} xlen_t;

typedef enum logic [1:0] {
    Off     = 2'b00,
    Init_xs = 2'b01,
    Clean   = 2'b10,
    Dirty   = 2'b11
} xs_t;

typedef struct packed {
    logic         sd;     // signal dirty state - read-only
    logic [62:36] wpri4;  // writes preserved reads ignored
    xlen_t        sxl;    // variable supervisor mode xlen - hardwired to zero
    xlen_t        uxl;    // variable user mode xlen - hardwired to zero
    logic [8:0]   wpri3;  // writes preserved reads ignored
    logic         tsr;    // trap sret
    logic         tw;     // time wait
    logic         tvm;    // trap virtual memory
    logic         mxr;    // make executable readable
    logic         sum;    // permit supervisor user memory access
    logic         mprv;   // modify privilege - privilege level for ld/st
    xs_t          xs;     // extension register - hardwired to zero
    xs_t          fs;     // floating point extension register
    priv_lvl_t    mpp;    // holds the previous privilege mode up to machine
    xs_t          vs;     // vector extension register
    logic         spp;    // holds the previous privilege mode up to supervisor
    logic         mpie;   // machine interrupts enable bit active prior to trap
    logic         wpri1;  // writes preserved reads ignored
    logic         spie;   // supervisor interrupts enable bit active prior to trap
    logic         upie;   // user interrupts enable bit active prior to trap - hardwired to zero
    logic         mie;    // machine interrupts enable
    logic         wpri0;  // writes preserved reads ignored
    logic         sie;    // supervisor interrupts enable
    logic         uie;    // user interrupts enable - hardwired to zero
} status_rv64_t;

typedef struct packed {
    logic         sd;     // signal dirty - read-only - hardwired zero
    logic [7:0]   wpri3;  // writes preserved reads ignored
    logic         tsr;    // trap sret
    logic         tw;     // time wait
    logic         tvm;    // trap virtual memory
    logic         mxr;    // make executable readable
    logic         sum;    // permit supervisor user memory access
    logic         mprv;   // modify privilege - privilege level for ld/st
    logic [1:0]   xs;     // extension register - hardwired to zero
    logic [1:0]   fs;     // extension register - hardwired to zero
    priv_lvl_t    mpp;    // holds the previous privilege mode up to machine
    logic [1:0]   wpri2;  // writes preserved reads ignored
    logic         spp;    // holds the previous privilege mode up to supervisor
    logic         mpie;   // machine interrupts enable bit active prior to trap
    logic         wpri1;  // writes preserved reads ignored
    logic         spie;   // supervisor interrupts enable bit active prior to trap
    logic         upie;   // user interrupts enable bit active prior to trap - hardwired to zero
    logic         mie;    // machine interrupts enable
    logic         wpri0;  // writes preserved reads ignored
    logic         sie;    // supervisor interrupts enable
    logic         uie;    // user interrupts enable - hardwired to zero
} status_rv32_t;

typedef struct packed {
    logic [3:0]  mode;
    logic [15:0] asid;
    logic [43:0] ppn;
} satp_t;

localparam int unsigned IRQ_S_SOFT  = 1;
localparam int unsigned IRQ_M_SOFT  = 3;
localparam int unsigned IRQ_S_TIMER = 5;
localparam int unsigned IRQ_M_TIMER = 7;
localparam int unsigned IRQ_S_EXT   = 9;
localparam int unsigned IRQ_M_EXT   = 11;
localparam int unsigned IRQ_LCOF    = 13;

localparam logic [63:0] MIP_SSIP = 1 << IRQ_S_SOFT;
localparam logic [63:0] MIP_MSIP = 1 << IRQ_M_SOFT;
localparam logic [63:0] MIP_STIP = 1 << IRQ_S_TIMER;
localparam logic [63:0] MIP_MTIP = 1 << IRQ_M_TIMER;
localparam logic [63:0] MIP_SEIP = 1 << IRQ_S_EXT;
localparam logic [63:0] MIP_MEIP = 1 << IRQ_M_EXT;
localparam logic [63:0] MIP_LCOFIP = 1 << IRQ_LCOF;

localparam logic [63:0] S_SW_INTERRUPT    = (1 << 63) | IRQ_S_SOFT;
localparam logic [63:0] M_SW_INTERRUPT    = (1 << 63) | IRQ_M_SOFT;
localparam logic [63:0] S_TIMER_INTERRUPT = (1 << 63) | IRQ_S_TIMER;
localparam logic [63:0] M_TIMER_INTERRUPT = (1 << 63) | IRQ_M_TIMER;
localparam logic [63:0] S_EXT_INTERRUPT   = (1 << 63) | IRQ_S_EXT;
localparam logic [63:0] M_EXT_INTERRUPT   = (1 << 63) | IRQ_M_EXT;
localparam logic [63:0] LCOF_INTERRUPT    = (1 << 63) | IRQ_LCOF;

// -----
// CSRs
// -----
typedef enum logic [11:0] {
    // Floating-Point CSRs
    CSR_FFLAGS         = 12'h001,
    CSR_FRM            = 12'h002,
    CSR_FCSR           = 12'h003,
    CSR_FTRAN          = 12'h800,
    // Vector CSRs
    CSR_VSTART         = 12'h008, // RVV-0.7,1.0
    CSR_VXSAT          = 12'h009, // RVV-1.0
    CSR_VXRM           = 12'h00A, // RVV-1.0
    CSR_VCSR           = 12'h00F, // RVV-1.0 
    CSR_VL             = 12'hC20,
    CSR_VTYPE          = 12'hC21,
    CSR_VLENB          = 12'hC22, // RVV-1.0 
    // Supervisor Mode CSRs
    CSR_SSTATUS        = 12'h100,
    CSR_SIE            = 12'h104,
    CSR_STVEC          = 12'h105,
    CSR_SCOUNTEREN     = 12'h106,
    CSR_SSCRATCH       = 12'h140,
    CSR_SEPC           = 12'h141,
    CSR_SCAUSE         = 12'h142,
    CSR_STVAL          = 12'h143,
    CSR_SIP            = 12'h144,
    CSR_SATP           = 12'h180,
    CSR_SCOUNTOVF      = 12'hDA0,
    // Machine Mode CSRs
    CSR_MSTATUS        = 12'h300,
    CSR_MISA           = 12'h301,
    CSR_MEDELEG        = 12'h302,
    CSR_MIDELEG        = 12'h303,
    CSR_MIE            = 12'h304,
    CSR_MTVEC          = 12'h305,
    CSR_MCOUNTEREN     = 12'h306,
    CSR_MCOUNTINHIBIT  = 12'h320,
    CSR_MHPM_EVENT_3   = 12'h323,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_4   = 12'h324,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_5   = 12'h325,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_6   = 12'h326,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_7   = 12'h327,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_8   = 12'h328,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_9   = 12'h329,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_10  = 12'h32a,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_11  = 12'h32b,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_12  = 12'h32c,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_13  = 12'h32d,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_14  = 12'h32e,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_15  = 12'h32f,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_16  = 12'h330,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_17  = 12'h331,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_18  = 12'h332,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_19  = 12'h333,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_20  = 12'h334,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_21  = 12'h335,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_22  = 12'h336,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_23  = 12'h337,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_24  = 12'h338,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_25  = 12'h339,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_26  = 12'h33a,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_27  = 12'h33b,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_28  = 12'h33c,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_29  = 12'h33d,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_30  = 12'h33e,  //Machine performance monitoring Event Selector
    CSR_MHPM_EVENT_31  = 12'h33f,  //Machine performance monitoring Event Selector
    CSR_MSCRATCH       = 12'h340,
    CSR_MEPC           = 12'h341,
    CSR_MCAUSE         = 12'h342,
    CSR_MTVAL          = 12'h343,
    CSR_MIP            = 12'h344,
    CSR_MVENDORID      = 12'hF11,
    CSR_MARCHID        = 12'hF12,
    CSR_MIMPID         = 12'hF13,
    CSR_MHARTID        = 12'hF14,
    `ifdef PITON_CINCORANCH
    CSR_MBOOT_MAIN_ID  = 12'hFC0,
    `endif
    CSR_MCYCLE         = 12'hB00,
    CSR_MINSTRET       = 12'hB02,
    // Performance counters (Machine Mode)
    CSR_MHPM_COUNTER_3  = 12'hB03,
    CSR_MHPM_COUNTER_4  = 12'hB04,
    CSR_MHPM_COUNTER_5  = 12'hB05,
    CSR_MHPM_COUNTER_6  = 12'hB06,
    CSR_MHPM_COUNTER_7  = 12'hB07,
    CSR_MHPM_COUNTER_8  = 12'hB08,
    CSR_MHPM_COUNTER_9  = 12'hB09,
    CSR_MHPM_COUNTER_10 = 12'hB0A,
    CSR_MHPM_COUNTER_11 = 12'hB0B,
    CSR_MHPM_COUNTER_12 = 12'hB0C,
    CSR_MHPM_COUNTER_13 = 12'hB0D,
    CSR_MHPM_COUNTER_14 = 12'hB0E,
    CSR_MHPM_COUNTER_15 = 12'hB0F,
    CSR_MHPM_COUNTER_16 = 12'hB10,
    CSR_MHPM_COUNTER_17 = 12'hB11,
    CSR_MHPM_COUNTER_18 = 12'hB12,
    CSR_MHPM_COUNTER_19 = 12'hB13,
    CSR_MHPM_COUNTER_20 = 12'hB14,
    CSR_MHPM_COUNTER_21 = 12'hB15,
    CSR_MHPM_COUNTER_22 = 12'hB16,
    CSR_MHPM_COUNTER_23 = 12'hB17,
    CSR_MHPM_COUNTER_24 = 12'hB18,
    CSR_MHPM_COUNTER_25 = 12'hB19,
    CSR_MHPM_COUNTER_26 = 12'hB1A,
    CSR_MHPM_COUNTER_27 = 12'hB1B,
    CSR_MHPM_COUNTER_28 = 12'hB1C,
    CSR_MHPM_COUNTER_29 = 12'hB1D,
    CSR_MHPM_COUNTER_30 = 12'hB1E,
    CSR_MHPM_COUNTER_31 = 12'hB1F,
    // Cache Control (platform specifc)
    CSR_DCACHE         = 12'h701,
    CSR_ICACHE         = 12'h700,
    // Triggers
    CSR_TSELECT        = 12'h7A0,
    CSR_TDATA1         = 12'h7A1,
    CSR_TDATA2         = 12'h7A2,
    CSR_TDATA3         = 12'h7A3,
    CSR_TINFO          = 12'h7A4,
    // Debug CSR
    CSR_DCSR           = 12'h7b0,
    CSR_DPC            = 12'h7b1,
    CSR_DSCRATCH0      = 12'h7b2, // optional
    CSR_DSCRATCH1      = 12'h7b3, // optional
    // Counters and Timers (User Mode - R/O Shadows)
    CSR_CYCLE          = 12'hC00,
    CSR_TIME           = 12'hC01,
    CSR_INSTRET        = 12'hC02,
    // Performance counters (User Mode - R/O Shadows)
    CSR_HPM_COUNTER_3  = 12'hC03,
    CSR_HPM_COUNTER_4  = 12'hC04,
    CSR_HPM_COUNTER_5  = 12'hC05,
    CSR_HPM_COUNTER_6  = 12'hC06,
    CSR_HPM_COUNTER_7  = 12'hC07,
    CSR_HPM_COUNTER_8  = 12'hC08,
    CSR_HPM_COUNTER_9  = 12'hC09,
    CSR_HPM_COUNTER_10 = 12'hC0A,
    CSR_HPM_COUNTER_11 = 12'hC0B,
    CSR_HPM_COUNTER_12 = 12'hC0C,
    CSR_HPM_COUNTER_13 = 12'hC0D,
    CSR_HPM_COUNTER_14 = 12'hC0E,
    CSR_HPM_COUNTER_15 = 12'hC0F,
    CSR_HPM_COUNTER_16 = 12'hC10,
    CSR_HPM_COUNTER_17 = 12'hC11,
    CSR_HPM_COUNTER_18 = 12'hC12,
    CSR_HPM_COUNTER_19 = 12'hC13,
    CSR_HPM_COUNTER_20 = 12'hC14,
    CSR_HPM_COUNTER_21 = 12'hC15,
    CSR_HPM_COUNTER_22 = 12'hC16,
    CSR_HPM_COUNTER_23 = 12'hC17,
    CSR_HPM_COUNTER_24 = 12'hC18,
    CSR_HPM_COUNTER_25 = 12'hC19,
    CSR_HPM_COUNTER_26 = 12'hC1A,
    CSR_HPM_COUNTER_27 = 12'hC1B,
    CSR_HPM_COUNTER_28 = 12'hC1C,
    CSR_HPM_COUNTER_29 = 12'hC1D,
    CSR_HPM_COUNTER_30 = 12'hC1E,
    CSR_HPM_COUNTER_31 = 12'hC1F,

    CSR_MEM_MAP_0   = 12'h7C0,  // MEM space
    CSR_MEM_MAP_1   = 12'h7C1,  // MEM space
    CSR_MEM_MAP_2   = 12'h7C2,  // MEM space
    CSR_MEM_MAP_3   = 12'h7C3,  // MEM space
    CSR_MEM_MAP_4   = 12'h7C4,  // MEM space
    CSR_MEM_MAP_5   = 12'h7C5,  // MEM space
    CSR_MEM_MAP_6   = 12'h7C6,  // MEM space
    CSR_MEM_MAP_7   = 12'h7C7,  // MEM space
    CSR_MEM_MAP_8   = 12'h7C8,  // MEM space
    CSR_MEM_MAP_9   = 12'h7C9,  // MEM space
    CSR_MEM_MAP_10  = 12'h7CA,  // MEM space
    CSR_MEM_MAP_11  = 12'h7CB,  // MEM space
    CSR_MEM_MAP_12  = 12'h7CC,  // MEM space
    CSR_MEM_MAP_13  = 12'h7CD,  // MEM space
    CSR_MEM_MAP_14  = 12'h7CE,  // MEM space
    CSR_MEM_MAP_15  = 12'h7CF,  // MEM space

    CSR_IO_MAP_0    = 12'h7D0,  // IO space
    CSR_IO_MAP_1    = 12'h7D1,  // IO space
    CSR_IO_MAP_2    = 12'h7D2,  // IO space
    CSR_IO_MAP_3    = 12'h7D3,  // IO space
    CSR_IO_MAP_4    = 12'h7D4,  // IO space
    CSR_IO_MAP_5    = 12'h7D5,  // IO space
    CSR_IO_MAP_6    = 12'h7D6,  // IO space
    CSR_IO_MAP_7    = 12'h7D7,  // IO space
    CSR_IO_MAP_8    = 12'h7D8,  // IO space
    CSR_IO_MAP_9    = 12'h7D9,  // IO space
    CSR_IO_MAP_10   = 12'h7DA,  // IO space
    CSR_IO_MAP_11   = 12'h7DB,  // IO space
    CSR_IO_MAP_12   = 12'h7DC,  // IO space
    CSR_IO_MAP_13   = 12'h7DD,  // IO space
    CSR_IO_MAP_14   = 12'h7DE,  // IO space
    CSR_IO_MAP_15   = 12'h7DF,  // IO space

    CSR_IRQ_MAP_0   = 12'h7E0,  // IRQ space
    CSR_IRQ_MAP_1   = 12'h7E1,  // IRQ space
    CSR_IRQ_MAP_2   = 12'h7E2,  // IRQ space
    CSR_IRQ_MAP_3   = 12'h7E3,  // IRQ space
    CSR_IRQ_MAP_4   = 12'h7E4,  // IRQ space
    CSR_IRQ_MAP_5   = 12'h7E5,  // IRQ space
    CSR_IRQ_MAP_6   = 12'h7E6,  // IRQ space
    CSR_IRQ_MAP_7   = 12'h7E7,  // IRQ space
    CSR_IRQ_MAP_8   = 12'h7E8,  // IRQ space
    CSR_IRQ_MAP_9   = 12'h7E9,  // IRQ space
    CSR_IRQ_MAP_10  = 12'h7EA,  // IRQ space
    CSR_IRQ_MAP_11  = 12'h7EB,  // IRQ space
    CSR_IRQ_MAP_12  = 12'h7EC,  // IRQ space
    CSR_IRQ_MAP_13  = 12'h7ED,  // IRQ space
    CSR_IRQ_MAP_14  = 12'h7EE,  // IRQ space
    CSR_IRQ_MAP_15  = 12'h7EF,  // IRQ space

    CSR_PMPCFG_0    = 12'h3A0,  //Physical memory protection config
    CSR_PMPCFG_1    = 12'h3A1,  //Physical memory protection config
    CSR_PMPCFG_2    = 12'h3A2,  //Physical memory protection config
    CSR_PMPCFG_3    = 12'h3A3,  //Physical memory protection config

    CSR_PMPADDR_0   = 12'h3B0,  //Physical memory protection addr
    CSR_PMPADDR_1   = 12'h3B1,  //Physical memory protection addr
    CSR_PMPADDR_2   = 12'h3B2,  //Physical memory protection addr
    CSR_PMPADDR_3   = 12'h3B3,  //Physical memory protection addr
    CSR_PMPADDR_4   = 12'h3B4,  //Physical memory protection addr
    CSR_PMPADDR_5   = 12'h3B5,  //Physical memory protection addr
    CSR_PMPADDR_6   = 12'h3B6,  //Physical memory protection addr
    CSR_PMPADDR_7   = 12'h3B7,  //Physical memory protection addr
    CSR_PMPADDR_8   = 12'h3B8,  //Physical memory protection addr
    CSR_PMPADDR_9   = 12'h3B9,  //Physical memory protection addr
    CSR_PMPADDR_10  = 12'h3BA,  //Physical memory protection addr
    CSR_PMPADDR_11  = 12'h3BB,  //Physical memory protection addr
    CSR_PMPADDR_12  = 12'h3BC,  //Physical memory protection addr
    CSR_PMPADDR_13  = 12'h3BD,  //Physical memory protection addr
    CSR_PMPADDR_14  = 12'h3BE,  //Physical memory protection addr
    CSR_PMPADDR_15  = 12'h3BF,  //Physical memory protection addr

    TO_HOST         = 12'h9F0,  // to host csr used for simulation
    FROM_HOST       = 12'h9F1,  // from host csr used for simulation

    CSR_HYPERRAM_CONFIG = 12'h7F0,  // HyperRAM Configuration CSR
    CSR_CNM_CONFIG = 12'h7F1, 	// CNM Peripherals Configuration CSR 
    CSR_SPI_CONFIG = 12'h7F2  // SPI Configuration CSR
    
} csr_reg_t;

localparam logic [63:0] SSTATUS_UIE    = 64'h00000001;
localparam logic [63:0] SSTATUS_SIE    = 64'h00000002;
localparam logic [63:0] SSTATUS_SPIE   = 64'h00000020;
localparam logic [63:0] SSTATUS_SPP    = 64'h00000100;
localparam logic [63:0] SSTATUS_VS     = 64'h00000600;
localparam logic [63:0] SSTATUS_FS     = 64'h00006000;
localparam logic [63:0] SSTATUS_XS     = 64'h00018000;
localparam logic [63:0] SSTATUS_SUM    = 64'h00040000;
localparam logic [63:0] SSTATUS_MXR    = 64'h00080000;
localparam logic [63:0] SSTATUS_UPIE   = 64'h00000010;
localparam logic [63:0] SSTATUS_UXL    = 64'h0000000300000000;
localparam logic [63:0] SSTATUS64_SD   = 64'h8000000000000000;
localparam logic [63:0] SSTATUS32_SD   = 64'h80000000;
localparam logic [63:0] SSTATUS64_WPRI = 64'h7ffffffdfff398cc;

localparam logic [63:0] MSTATUS_UIE    = 64'h00000001;
localparam logic [63:0] MSTATUS_SIE    = 64'h00000002;
localparam logic [63:0] MSTATUS_HIE    = 64'h00000004;
localparam logic [63:0] MSTATUS_MIE    = 64'h00000008;
localparam logic [63:0] MSTATUS_UPIE   = 64'h00000010;
localparam logic [63:0] MSTATUS_SPIE   = 64'h00000020;
localparam logic [63:0] MSTATUS_HPIE   = 64'h00000040;
localparam logic [63:0] MSTATUS_MPIE   = 64'h00000080;
localparam logic [63:0] MSTATUS_SPP    = 64'h00000100;
localparam logic [63:0] MSTATUS_HPP    = 64'h00000600;
localparam logic [63:0] MSTATUS_MPP    = 64'h00001800;
localparam logic [63:0] MSTATUS_FS     = 64'h00006000;
localparam logic [63:0] MSTATUS_XS     = 64'h00018000;
localparam logic [63:0] MSTATUS_MPRV   = 64'h00020000;
localparam logic [63:0] MSTATUS_SUM    = 64'h00040000;
localparam logic [63:0] MSTATUS_MXR    = 64'h00080000;
localparam logic [63:0] MSTATUS_TVM    = 64'h00100000;
localparam logic [63:0] MSTATUS_TW     = 64'h00200000;
localparam logic [63:0] MSTATUS_TSR    = 64'h00400000;
localparam logic [63:0] MSTATUS32_SD   = 64'h80000000;
localparam logic [64:0] MSTATUS32_WPRI = 64'h7f800044;
localparam logic [63:0] MSTATUS_UXL    = 64'h0000000300000000;
localparam logic [63:0] MSTATUS_SXL    = 64'h0000000C00000000;
localparam logic [63:0] MSTATUS64_SD   = 64'h8000000000000000;
localparam logic [63:0] MSTATUS64_WPRI = 64'h7ffffff5ff800044;

// decoded CSR address
typedef struct packed {
    logic [1:0]  rw;
    priv_lvl_t   priv_lvl;
    logic  [7:0] address;
} csr_addr_t;

typedef union packed {
    csr_reg_t   address;
    csr_addr_t  csr_decode;
} csr_t;

// Floating-Point control and status register (32-bit!)
typedef struct packed {
    logic [31:8]  reserved;  // reserved for L extension, return 0 otherwise

    logic [2:0]   frm;       // float rounding mode
    logic [4:0]   fflags;    // float exception flags
} fcsr_t;

// Vector control and status register (RVV 1.0)
typedef struct packed {
    logic [1:0]   vxrm;      // vector fixed-point rounding mode
    logic         vxsat;     // vector fixed-point accrued saturation flag
} vcsr_t;

// -----
// Debug
// -----
typedef struct packed {
    logic [31:28]     xdebugver;
    logic [27:16]     zero2;
    logic             ebreakm;
    logic             zero1;
    logic             ebreaks;
    logic             ebreaku;
    logic             stepie;
    logic             stopcount;
    logic             stoptime;
    logic [8:6]       cause;
    logic             zero0;
    logic             mprven;
    logic             nmip;
    logic             step;
    priv_lvl_t        prv;
} dcsr_t;

endpackage
