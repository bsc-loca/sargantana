// (c) FER, 2019
// contact: mario.kovac@fer.hr
// All rights reserved
// No part of this code can be used/copied/extended/modified or used in any other way for commercial or non-commercial use without prior written agreement with FER
// Access to this source or any derivation of it should be given only to persons explicitly approved and under NDA/Confidentiality Agreement


module fpuv_wrapper
import fpuv_pkg::*;
import fpuv_wrapper_pkg::*;

#(
   parameter fpu_features_t       Features = EPI_RV64D,
   parameter fpu_implementation_t Implementation = EPI_INIT,
   // Do not change
   localparam int unsigned WIDTH        = Features.Width,
   localparam int unsigned NUM_OPERANDS = 3
) (
   input logic                     clk_i,
   input logic                     rsn_i,
   input logic [WIDTH - 1 : 0]     src1_data_i,
   input logic [WIDTH - 1 : 0]     src2_data_i,
   input logic [WIDTH - 1 : 0]     src3_data_i,
   input std_element_width_e       sew_i,
   input logic                     lsw_valid_i,
   input logic                     masked_op_i,
   input logic [MASK_WORD - 1 : 0] mask_bits_i,
   input logic [1 : 0]             inactive_element_select_i, 
   input roundmode_e               rnd_mode_i,
   input opcode_e                  opcode_funct6_i,
   input opcode_unary_e            opcode_vs1_i,
   input logic                     valid_op_i,
   input logic                     kill_i,
   output logic                    in_ready_o,
   output logic                    result_valid_o,
   output logic [WIDTH - 1 : 0]    result_data_o,
   output status_t                 status_o
);

logic [NUM_OPERANDS - 1 : 0][WIDTH - 1 : 0] operands;
roundmode_e  opcode_rnd_mode;
logic        op_mod;
logic        rnd_mode_sel;
operation_e  op;
fp_format_e  src_fmt;
fp_format_e  add_fmt;
fp_format_e  dst_fmt;
int_format_e int_fmt;
logic        vectorial_op;
// verilator lint_off BLKANDNBLK
assign operands[0] = src1_data_i;
assign operands[1] = src2_data_i;
assign operands[2] = src3_data_i;

// Operation decoding
always_comb begin
   rnd_mode_sel    = 0;
   opcode_rnd_mode = RNE;
   add_fmt         = src_fmt;
   dst_fmt         = src_fmt;
   int_fmt         = src_fmt == FP32 ? INT32 : INT64;

   case (opcode_funct6_i)
      // -------------------------------------------
      //                 ADDMUL
      // -------------------------------------------
      OP_VFADD, OP_VFREDSUM, OP_VFREDOSUM: begin // addition
         op     = ADD;
         op_mod = 0;
      end  
      OP_VFSUB, OP_VFRSUB: begin // subtraction
         op     = ADD; 
         op_mod = 1;
      end
      OP_VFMUL: begin // multiplication
         op     = MUL;
         op_mod = 0;
      end
      OP_VFMADD, OP_VFMACC: begin // fused multiply-add
         op     = FMADD;
         op_mod = 0;
      end
      OP_VFMSUB, OP_VFMSAC: begin // fused multiply-subtract
         op     = FMADD;
         op_mod = 1;
      end
      OP_VFNMSUB, OP_VFNMSAC: begin // negated fused multiply-subtract 
         op     = FNMSUB;
         op_mod = 0;
      end
      OP_VFNMADD, OP_VFNMACC: begin // negated fused multiply-add
         op     = FNMSUB;
         op_mod = 1;
      end 
      // -------------------------------------------
      //                 DIV
      // -------------------------------------------
      OP_VFDIV, OP_VFRDIV: begin
         op     = DIV;
         op_mod = 0;
      end
      // -------------------------------------------
      //                 NONCOMP
      // -------------------------------------------
      OP_VFMIN, OP_VFREDMIN: begin 
         op              = MINMAX;
         op_mod          = 0;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RNE; 
      end 
      OP_VFMAX, OP_VFREDMAX: begin  
         op              = MINMAX;
         op_mod          = 0;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RTZ; 
      end
      OP_VFSGNJ: begin 
         op              = SGNJ;
         op_mod          = 0;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RNE; 
      end
      OP_VFSGNJN: begin 
         op              = SGNJ;
         op_mod          = 0;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RTZ; 
      end
      OP_VFSGNJX: begin 
         op              = SGNJ;
         op_mod          = 0;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RDN; 
      end
      OP_VMFEQ: begin 
         op              = CMP;
         op_mod          = 0;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RDN; 
      end
      OP_VMFLE: begin 
         op              = CMP;
         op_mod          = 0;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RNE; 
      end
      OP_VMFLT: begin 
         op              = CMP;
         op_mod          = 0;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RTZ; 
      end
      OP_VMFNE: begin 
         op              = CMP;
         op_mod          = 1;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RDN; 
      end
      OP_VMFGT: begin 
         op              = CMP;
         op_mod          = 1;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RNE; 
      end
      OP_VMFGE: begin 
         op              = CMP;
         op_mod          = 1;
         rnd_mode_sel    = 1;
         opcode_rnd_mode = RTZ; 
      end
      // -------------------------------------------
      //                 UNARY0 - CONV
      // -------------------------------------------
      OP_VFUNARY0: begin 
         case (opcode_vs1_i)
            OPVF_CVT_F2XU_SQRT: begin // float to unsigned integer
               op     = F2I;
               op_mod = 1;
            end
            OPVF_CVT_F2X: begin // float to signed integer
               op     = F2I;
               op_mod = 0;
            end
            OPVF_CVT_XU2F: begin // unsigned integer to float
               op     = I2F;
               op_mod = 1;
            end
            OPVF_CVT_X2F: begin // signed integer to float
               op     = I2F;
               op_mod = 0;
            end
            OPVF_WCVT_F2XU: begin // float to double-width unsigned integer
               op      = F2I;
               op_mod  = 1;
               int_fmt = INT64;
            end
            OPVF_WCVT_F2X: begin // float to double-width signed integer
               op      = F2I;
               op_mod  = 0;
               int_fmt = INT64;
            end
            OPVF_WCVT_XU2F: begin // unsigned integer to double-width float
               op      = I2F;
               op_mod  = 1;
               dst_fmt = FP64;
            end
            OPVF_WCVT_X2F: begin // signed integer to double-width float
               op      = I2F;
               op_mod  = 0;
               dst_fmt = FP64;
            end
            OPVF_WCVT_F2F: begin // single-width float to double-width float
               op      = F2F;
               op_mod  = 0;
               dst_fmt = FP64;
            end
            OPVF_NCVT_F2XU_CLASS: begin // double-width float to unsigned integer
               op      = F2I;
               op_mod  = 1;
               int_fmt = INT32;
            end
            OPVF_NCVT_F2X: begin // double-width float to signed integer
               op      = F2I;
               op_mod  = 0;
               int_fmt = INT32;
            end 
            OPVF_NCVT_XU2F: begin // double-width unsigned integer to float
               op      = I2F;
               op_mod  = 1;
               dst_fmt = FP32;
            end
            OPVF_NCVT_X2F: begin // double-width signed integer to float
               op      = I2F;
               op_mod  = 0;
               dst_fmt = FP32;
            end 
            OPVF_NCVT_F2F: begin // double-width float to single-width float
               op      = F2F;
               op_mod  = 0;
               dst_fmt = FP32;
            end
            default: begin 
               op     = operation_e'('1); // don't care
               op_mod = DONT_CARE;        // don't care
            end 
         endcase
      end
      // -------------------------------------------
      //                 UNARY1 - SQRT, CLASS
      // -------------------------------------------
      OP_VFUNARY1: begin 
         case (opcode_vs1_i)
            OPVF_CVT_F2XU_SQRT: begin 
               op     = SQRT;
               op_mod = 0;
            end 
            OPVF_NCVT_F2XU_CLASS: begin 
               op     = CLASSIFY;
               op_mod = 0;
            end
            default: begin 
               op     = operation_e'('1); // don't care
               op_mod = DONT_CARE;        // don't care
            end 
         endcase
      end 
      // -------------------------------------------
      //                 WIDENING ADDMUL
      // -------------------------------------------
      OP_VFWADD: begin // 2*SEW = SEW + SEW
         op      = ADD;
         op_mod  = 0;
         dst_fmt = FP64;
      end
      OP_VFWSUB: begin // 2*SEW = SEW - SEW
         op      = ADD;
         op_mod  = 1;
         dst_fmt = FP64;
      end
      OP_VFWADDW, OP_VFWREDSUM, OP_VFWREDOSUM: begin // 2*SEW = 2*SEW + SEW
         op      = ADD;
         op_mod  = 0;
         add_fmt = FP64; 
         dst_fmt = FP64;
      end
      OP_VFWSUBW: begin // 2*SEW = 2*SEW - SEW
         op      = ADD;
         op_mod  = 1;
         add_fmt = FP64; 
         dst_fmt = FP64;
      end
      OP_VFWMUL: begin // 2*SEW = SEW * SEW
         op      = MUL;
         op_mod  = 0;
         dst_fmt = FP64;
      end
      OP_VFWMACC: begin // 2*SEW = SEW * SEW + 2*SEW
         op      = FMADD;
         op_mod  = 0;
         add_fmt = FP64; 
         dst_fmt = FP64;
      end
      OP_VFWNMACC: begin // 2*SEW = - (SEW * SEW - 2*SEW)
         op      = FNMSUB;
         op_mod  = 1;
         add_fmt = FP64; 
         dst_fmt = FP64;
      end
      OP_VFWMSAC: begin // 2*SEW = SEW * SEW - 2*SEW
         op      = FMADD;
         op_mod  = 1;
         add_fmt = FP64; 
         dst_fmt = FP64;
      end
      OP_VFWNMSAC: begin // 2*SEW = - (SEW * SEW + 2*SEW)
         op      = FNMSUB;
         op_mod  = 0;
         add_fmt = FP64; 
         dst_fmt = FP64;
      end
      default: begin 
         op     = operation_e'('1); // don't care
         op_mod = DONT_CARE;        // don't care
      end
   endcase

   vectorial_op = (src_fmt == FP32 & dst_fmt == FP32 & int_fmt == INT32) & ~lsw_valid_i;
end

always_comb begin
   case (sew_i)
      BINARY32: begin
         src_fmt      = FP32;
      end
      BINARY64: begin
         src_fmt      = FP64;
      end
      default: begin
         src_fmt      = FP64;
      end
   endcase
end

fpuv_top #(
   .Features       ( Features ),
   .Implementation ( Implementation )
) i_fpuv_top (
   .clk_i          ( clk_i ),
   .rst_ni         ( rsn_i ),
   .operands_i     ( operands ),
   .rnd_mode_i     ( rnd_mode_sel ? opcode_rnd_mode : rnd_mode_i ),
   .op_i           ( op ),
   .op_mod_i       ( op_mod ),
   .src_fmt_i      ( src_fmt ),
   .add_fmt_i      ( add_fmt ),
   .dst_fmt_i      ( dst_fmt ),
   .int_fmt_i      ( int_fmt ),
   .masked_op_i    ( masked_op_i ),
   .mask_bits_i    ( mask_bits_i ),
   .inactive_sel_i ( inactive_element_select_i ),
   .vectorial_op_i ( vectorial_op ),
   .tag_i          ( 1'b0 ),
   .in_valid_i     ( valid_op_i ),
   .in_ready_o     ( in_ready_o ),
   .flush_i        ( kill_i ),
   .result_o       ( result_data_o ),
   .status_o       ( status_o ),
   .tag_o          ( /* unused */ ),
   .out_valid_o    ( result_valid_o ),
   .out_ready_i    ( 1'b1 ),
   .busy_o         ( /* unused */ )
);

endmodule