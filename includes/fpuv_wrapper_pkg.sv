// (c) FER, 2019
// contact: mario.kovac@fer.hr
// All rights reserved
// No part of this code can be used/copied/extended/modified or used in any other way for commercial or non-commercial use without prior written agreement with FER
// Access to this source or any derivation of it should be given only to persons explicitly approved and under NDA/Confidentiality Agreement
//import fpuv_pkg::*;
package fpuv_wrapper_pkg;

  /* localparam fpuv_pkg::fpu_features_t EPI_RV64D = '{
      Width:         64,
      EnableVectors: 1'b0, // guillemlp do not do vectors i guess?
      EnableNanBox:  1'b0,
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

   localparam int unsigned DIVSQRT_ITER = 1; //This parameter configure the number of iterations per cycle of the divsqrt unit.
   localparam int unsigned SEW_WIDTH = 3;
   typedef enum logic [SEW_WIDTH - 1 : 0] {
      BINARY32 = 'b010,
      BINARY64 = 'b011
   } std_element_width_e;

   localparam int unsigned FUNCT_WIDTH = 6;
   typedef enum logic [FUNCT_WIDTH - 1 : 0] {
      //
      //                            Vector Single-Width Floating-Point Add/Subtract Instructions
      //
      OP_VFADD       = 'b000000, // FP add; vector-vector, vector-scalar;
      OP_VFSUB       = 'b000010, // FP sub; vector-vector, vector-scalar;
      OP_VFRSUB      = 'b100111, // FP reverse sub; scalar-vector;
      //
      //                            Vector Floating-Point MIN/MAX Instructions
      //
      OP_VFMIN       = 'b000100, // FP minimum; vector-vector, vector-scalar;
      OP_VFMAX       = 'b000110, // FP maximum; vector-vector, vector-scalar;
      //
      //                            Vector Floating-Point Sign-Injection Instructions                         
      //
      OP_VFSGNJ      = 'b001000, 
      OP_VFSGNJN     = 'b001001,
      OP_VFSGNJX     = 'b001010,
      //
      //                            Floating-Point Scalar Move Instructions
      //
      // OP_VFMVFS      = 'b001100,
      // OP_VFMVSF      = 'b001101,
      //
      //                            Vector Floating-Point Merge Instruction
      //
      // OP_VFMERGE     = 'b010111,
      //
      //                            Vector Floating-Point Compare Instructions
      //
      OP_VMFEQ       = 'b011000, // Compare equal
      OP_VMFLE       = 'b011001, // Compare less than or equal
      // OP_VMFORD      = 'b011010, // vmford instruction is added that sets amask register if the arguments are ordered (i.e., neither argument is NaN).
      OP_VMFLT       = 'b011011, // Compare less than
      OP_VMFNE       = 'b011100, // Compare not equal
      OP_VMFGT       = 'b011101, // Compare greater than
      OP_VMFGE       = 'b011111, // Compare greater than or equal
      //
      //                            UNARY0 encoding space
      //
      OP_VFUNARY0    = 'b100010, 
      //
      //                            UNARY1 encoding space
      //
      OP_VFUNARY1    = 'b100011,
      //
      //                            Vector Single-Width Floating-Point Multiply/Divide Instructions
      //
      OP_VFDIV       = 'b100000, // Floating-point divide; vector-vector, vector-scalar;
      OP_VFRDIV      = 'b100001, // Reverse floating-point divide vector = scalar / vector
      OP_VFMUL       = 'b100100, // Floating-point multiply; vector-vector, vector-scalar;
      //
      //                            Vector Single-Width Floating-Point Fused Multiply-Add Instructions
      //
      OP_VFMADD      = 'b101000, // FP multiply-add, overwrites multiplicand; vd[i] = +(vs1[i] * vd[i]) + vs2[i], vd[i] = +(f[rs1] * vd[i]) + vs2[i];
      OP_VFNMADD     = 'b101001, // FP negate-(multiply-add), overwrites multiplicand; vd[i] = -(vs1[i] * vd[i]) - vs2[i], vd[i] = -(f[rs1] * vd[i]) - vs2[i];
      OP_VFMSUB      = 'b101010, // FP multiply-sub, overwrites multiplicand; vd[i] = +(vs1[i] * vd[i]) - vs2[i], vd[i] = +(f[rs1] * vd[i]) - vs2[i];
      OP_VFNMSUB     = 'b101011, // FP negate-(multiply-sub), overwrites multiplicand; vd[i] = -(vs1[i] * vd[i]) + vs2[i], vd[i] = -(f[rs1] * vd[i]) + vs2[i];
      OP_VFMACC      = 'b101100, // FP multiply-accumulate, overwrites addend; vd[i] = +(vs1[i] * vs2[i]) + vd[i], vd[i] = +(f[rs1] * vs2[i]) + vd[i];
      OP_VFNMACC     = 'b101101, // FP negate-(multiply-accumulate), overwrites subtrahend; vd[i] = -(vs1[i] * vs2[i]) - vd[i], vd[i] = -(f[rs1] * vs2[i]) - vd[i];
      OP_VFMSAC      = 'b101110, // FP multiply-subtract-accumulator, overwrites subtrahend; vd[i] = +(vs1[i] * vs2[i]) - vd[i], vd[i] = +(f[rs1] * vs2[i]) - vd[i];
      OP_VFNMSAC     = 'b101111, // FP negate-(multiply-subtract-accumulator), overwrites minuend; vd[i] = -(vs1[i] * vs2[i]) + vd[i], vd[i] = -(f[rs1] * vs2[i]) + vd[i];
      //
      //                            Vector Widening Floating-Point Fused Multiply-Add Instructions
      //
      OP_VFWADD      = 'b110000, // Widening FP add/subtract; vector-vector, vector-scalar; 2*SEW = SEW +/- SEW;
      OP_VFWSUB      = 'b110010, // Widening FP add/subtract; vector-vector, vector-scalar; 2*SEW = SEW +/- SEW;    
      OP_VFWADDW     = 'b110100, // Widening FP add/subtract; 2*SEW = 2*SEW +/- SEW;
      OP_VFWSUBW     = 'b110110, // Widening FP add/subtract; 2*SEW = 2*SEW +/- SEW
      //
      //                            Vector Widening Floating-Point Multiply
      //
      OP_VFWMUL      = 'b111000, // Widening floating-point multiply; vector-vector, vector-scalar;
      //
      //                            Vector Floating-Point Dot Product Instruction
      //
      OP_VFDOT       = 'b111001, // Dot product
      //
      //                            Vector Widening Floating-Point Fused Multiply-Add Instructions
      //
      OP_VFWMACC     = 'b111100, // FP widening multiply-accumulate, overwrites addend
      OP_VFWNMACC    = 'b111101, // FP widening negate-(multiply-accumulate), overwrites addend
      OP_VFWMSAC     = 'b111110, // FP widening multiply-subtract-accumulator, overwrites addend
      OP_VFWNMSAC    = 'b111111, // FP widening negate-(multiply-subtract-accumulator), overwrites addend
      //
      //                            Vector reduction operations
      //
      OP_VFREDSUM    = 'b000001, // Unordered single-width sum reduction
      OP_VFREDOSUM   = 'b000011, // Ordered single-width sum reduction
      OP_VFREDMIN    = 'b000101, // Single-width min reduction
      OP_VFREDMAX    = 'b000111, // Single-width max reduction
      OP_VFWREDSUM   = 'b110001, // Widening unordered sum reduction
      OP_VFWREDOSUM  = 'b110011  // Widening ordered sum reduction
   } opcode_e;

   localparam int unsigned VS1_ADDR_WIDTH = 5;
   typedef enum logic [VS1_ADDR_WIDTH - 1 : 0] {
      //
      //                           UNARY0 and UNARY1 encoding space
      //
      //                           UNARY0: Single-Width Floating-Point/Integer Type-Convert Instructions 
      //                           UNARY1: Square-Root
      //
      OPVF_CVT_F2XU_SQRT   = 'b00000,    // Convert float to unsigned integer (unary0), square-root (unary1).
      OPVF_CVT_F2X         = 'b00001,    // Convert float to signed integer.
      OPVF_CVT_XU2F        = 'b00010,    // Convert unsigned integer to float.
      OPVF_CVT_X2F         = 'b00011,    // Convert signed integer to float.
      //
      //                           UNARY0: Widening Floating-Point/Integer Type-Convert Instructions
      //
      OPVF_WCVT_F2XU       = 'b01000,    // Convert float to double-width unsigned integer.
      OPVF_WCVT_F2X        = 'b01001,    // Convert float to double-width signed integer.
      OPVF_WCVT_XU2F       = 'b01010,    // Convert unsigned integer to double-width float.
      OPVF_WCVT_X2F        = 'b01011,    // Convert signed integer to double-width float.
      OPVF_WCVT_F2F        = 'b01100,    // Convert single-width float to double-width float.
      //
      //                           UNARY0: Narrowing Floating-Point/Integer Type-Convert Instructions
      //                           UNARY1: Classify Instruction
      //
      OPVF_NCVT_F2XU_CLASS = 'b10000,     // Convert double-width float to unsigned integer (unary0), classify instruction (unary1)
      OPVF_NCVT_F2X        = 'b10001,     // Convert double-width float to signed integer.
      OPVF_NCVT_XU2F       = 'b10010,     // Convert double-width unsigned integer to float.
      OPVF_NCVT_X2F        = 'b10011,     // Convert double-width signed integer to float.
      OPVF_NCVT_F2F        = 'b10100      // Convert double-width float to single-width float.
   } opcode_unary_e;*/

endpackage
