// (c) FER, 2019
// contact: mario.kovac@fer.hr
// All rights reserved
// No part of this code can be used/copied/extended/modified or used in any other way for commercial or non-commercial use without prior written agreement with FER
// Access to this source or any derivation of it should be given only to persons explicitly approved and under NDA/Confidentiality Agreement


module fpu_drac_wrapper
import drac_pkg::*;
import fpuv_pkg::*;
import fpuv_wrapper_pkg::*;

#(
   parameter fpu_features_t       Features = EPI_RV64D,
   parameter fpu_implementation_t Implementation = EPI_INIT,
   // Do not change
   localparam int unsigned WIDTH        = Features.Width,
   localparam int unsigned NUM_OPERANDS = 3
) (
   input  logic                     clk_i,
   input  logic                     rstn_i,
   input  logic                     kill_i,
   input  rr_exe_fpu_instr_t        instruction_i,
   output exe_wb_fp_instr_t         instruction_o,
   output exe_wb_scalar_instr_t     instruction_scalar_o,
   output logic                     stall_o
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
logic ready_fpu;
fpuv_pkg::status_t fp_status;

exe_wb_fp_instr_t instruction_d, instruction_q;

always_comb begin : decide_FMT
   if (instruction_i.instr.fmt) begin
      src_fmt = FP64;
   end else begin
      src_fmt = FP32;
   end
end
// Operation decoding
always_comb begin
   rnd_mode_sel    = 0;
   opcode_rnd_mode = RNE;
   add_fmt         = src_fmt;
   dst_fmt         = src_fmt;
   int_fmt         = src_fmt == FP32 ? INT32 : INT64;

   operands[0] = instruction_i.data_rs2;
   operands[1] = instruction_i.data_rs1;
   operands[2] = instruction_i.data_rs3;


   case (instruction_i.instr.instr_type)
      // -------------------------------------------
      //                 ADDMUL
      // -------------------------------------------
      // Floating-Point Computational Instructions
      //FADD, FSUB, FMUL, FDIV, FMIN_MAX, FSQRT, FMADD, FMSUB, FNMSUB, FNMADD,
      // Floating-Point Conversion and Move Instructions
      //FCVT_F2I, FCVT_I2F, FCVT_F2F, FSGNJ, FMV_F2X, FMV_X2F,
      // Floating-Point Compare Instructions
      //FCMP,
      // Floating-Point Classify Instruction
      //FCLASS,

      drac_pkg::FADD: begin // addition
         op     = fpuv_pkg::ADD;
         op_mod = 0;
         operands[0] = '0;
         operands[1] = instruction_i.data_rs1;
         operands[2] = instruction_i.data_rs2;
      end  
      drac_pkg::FSUB: begin // subtraction
         op     = fpuv_pkg::ADD; 
         op_mod = 1;
         operands[0] = '0;
         operands[1] = instruction_i.data_rs1;
         operands[2] = instruction_i.data_rs2;
      end
      drac_pkg::FMUL: begin // multiplication
         op     = fpuv_pkg::MUL;
         op_mod = 0;
         operands[0] = instruction_i.data_rs2;
         operands[1] = instruction_i.data_rs1;
         operands[2] = instruction_i.data_rs3;
      end
      drac_pkg::FMADD: begin // fused multiply-add
         op     = fpuv_pkg::FMADD;
         op_mod = 0;
         operands[0] = instruction_i.data_rs1;
         operands[1] = instruction_i.data_rs2;
         operands[2] = instruction_i.data_rs3;
      end
      drac_pkg::FMSUB: begin // fused multiply-subtract
         op     = fpuv_pkg::FMADD;
         op_mod = 1;
         operands[0] = instruction_i.data_rs1;
         operands[1] = instruction_i.data_rs2;
         operands[2] = instruction_i.data_rs3;
      end
      drac_pkg::FNMSUB: begin // negated fused multiply-subtract 
         op     = fpuv_pkg::FNMSUB;
         op_mod = 0;
         operands[0] = instruction_i.data_rs1;
         operands[1] = instruction_i.data_rs2;
         operands[2] = instruction_i.data_rs3;
      end
      drac_pkg::FNMADD: begin // negated fused multiply-add
         op     = fpuv_pkg::FNMSUB;
         op_mod = 1;
         operands[0] = instruction_i.data_rs1;
         operands[1] = instruction_i.data_rs2;
         operands[2] = instruction_i.data_rs3;
      end 
      // -------------------------------------------
      //                 DIV
      // -------------------------------------------
      drac_pkg::FDIV: begin
         op     = fpuv_pkg::DIV;
         op_mod = 0;
         operands[0] = instruction_i.data_rs2;
         operands[1] = instruction_i.data_rs1;
         operands[2] = instruction_i.data_rs3;
      end
      drac_pkg::FSQRT: begin
         op     = fpuv_pkg::SQRT;
         op_mod = 0;
         operands[0] = instruction_i.data_rs1;
         operands[1] = '0;
         operands[2] = '0;
      end
      // -------------------------------------------
      //                 NONCOMP
      // -------------------------------------------
      /*FMIN_MAX: begin 
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
      /*OP_VFUNARY1: begin 
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
      */
      default: begin 
         op     = operation_e'('1); // don't care
         op_mod = DONT_CARE;        // don't care
      end
   endcase

end

/*always_comb begin
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
end*/

fpuv_top #(
   .Features       ( Features ),
   .Implementation ( Implementation )
) i_fpuv_top (
   .clk_i          ( clk_i ),
   .rst_ni         ( rstn_i ),
   .flush_i        ( kill_i ),
   // Input
   .operands_i     ( operands ),
   .rnd_mode_i     ( opcode_rnd_mode ),
   .op_i           ( op ), /// ---???????
   .op_mod_i       ( op_mod ), /// ??????
   .src_fmt_i      ( src_fmt ), // FMT mode
   .add_fmt_i      ( add_fmt ),
   .dst_fmt_i      ( dst_fmt ),
   .int_fmt_i      ( int_fmt ),
   .masked_op_i    ( 'h0 ),
   .mask_bits_i    ( 'h0 ),
   .inactive_sel_i ( 2'b11 ),
   .vectorial_op_i ( 'h0 ),
   .tag_i          ( 1'b0 ),
   .in_valid_i     ( instruction_i.instr.valid && !(instruction_i.instr.instr_type == FMV_F2X) & (instruction_i.instr.unit == UNIT_FPU) && (!instruction_q.valid || instruction_o.valid)),
   .out_ready_i    ( 1'b1 ), // are we always ready???
   // Outputs
   .in_ready_o     ( ready_fpu ),
   .result_o       ( instruction_o.result ),
   .status_o       ( fp_status ),
   .tag_o          ( /* unused */ ),
   .out_valid_o    ( instruction_o.valid ),
   .busy_o         ( /* unused */ )
);


assign instruction_d.valid           = instruction_i.instr.valid && (instruction_i.instr.unit == UNIT_FPU) && !(instruction_i.instr.instr_type == FMV_F2X);
assign instruction_d.pc              = instruction_i.instr.pc;
assign instruction_d.bpred           = instruction_i.instr.bpred;
assign instruction_d.rs1             = instruction_i.instr.rs1;
assign instruction_d.rd              = instruction_i.instr.rd;
assign instruction_d.change_pc_ena   = instruction_i.instr.change_pc_ena;
assign instruction_d.regfile_we      = instruction_i.instr.regfile_fp_we;
assign instruction_d.instr_type      = instruction_i.instr.instr_type;
assign instruction_d.stall_csr_fence = instruction_i.instr.stall_csr_fence;
assign instruction_d.csr_addr        = instruction_i.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_d.fprd            = instruction_i.fprd;
assign instruction_d.checkpoint_done = instruction_i.checkpoint_done;
assign instruction_d.chkp            = instruction_i.chkp;
assign instruction_d.gl_index        = instruction_i.gl_index;
assign instruction_d.ex              = instruction_i.instr.ex;
`ifdef VERILATOR
assign instruction_d.id              = instruction_i.instr.id;
`endif
assign instruction_d.branch_taken    = 1'b0;
assign instruction_d.result_pc       = 0;
assign instruction_d.result          = 0;

// Instruction inside the FPU
always_ff @(posedge clk_i, negedge rstn_i) begin
   if (~rstn_i) begin
      instruction_q <= '0;
   end else begin
      if (instruction_d.valid) begin
         instruction_q <= instruction_d;
      end else if (instruction_o.valid) begin
         instruction_q <= instruction_d;
      end else begin
         instruction_q <= instruction_q;
      end
   end   
end

// Output of the FPU 
assign instruction_o.pc              = instruction_q.pc;
assign instruction_o.bpred           = instruction_q.bpred;
assign instruction_o.rs1             = instruction_q.rs1;
assign instruction_o.rd              = instruction_q.rd;
assign instruction_o.change_pc_ena   = instruction_q.change_pc_ena;
assign instruction_o.regfile_we      = instruction_q.regfile_we;
assign instruction_o.instr_type      = instruction_q.instr_type;
assign instruction_o.stall_csr_fence = instruction_q.stall_csr_fence;
assign instruction_o.csr_addr        = instruction_q.csr_addr;
assign instruction_o.fprd            = instruction_q.fprd;
assign instruction_o.checkpoint_done = instruction_q.checkpoint_done;
assign instruction_o.chkp            = instruction_q.chkp;
assign instruction_o.gl_index        = instruction_q.gl_index;
assign instruction_o.ex              = instruction_q.ex;
`ifdef VERILATOR
assign instruction_o.id            = instruction_q.id;
`endif
assign instruction_o.branch_taken  = 1'b0;
assign instruction_o.result_pc     = 0;
assign instruction_o.fp_status     = fp_status;

// Stall if the FPU is not ready or the is a fp instruction on flight
assign stall_o = (!ready_fpu || (instruction_q.valid && !instruction_o.valid)) && !(instruction_i.instr.instr_type == FMV_F2X);

// Output related to FP to integer
assign instruction_scalar_o.valid           = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_FPU) & (instruction_i.instr.instr_type == FMV_F2X);
assign instruction_scalar_o.pc              = instruction_i.instr.pc;
assign instruction_scalar_o.bpred           = instruction_i.instr.bpred;
assign instruction_scalar_o.rs1             = instruction_i.instr.rs1;
assign instruction_scalar_o.rd              = instruction_i.instr.rd;
assign instruction_scalar_o.change_pc_ena   = instruction_i.instr.change_pc_ena;
assign instruction_scalar_o.regfile_we      = instruction_i.instr.regfile_we;
assign instruction_scalar_o.instr_type      = instruction_i.instr.instr_type;
assign instruction_scalar_o.stall_csr_fence = instruction_i.instr.stall_csr_fence;
assign instruction_scalar_o.csr_addr        = instruction_i.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_scalar_o.prd             = instruction_i.fprd;
assign instruction_scalar_o.checkpoint_done = instruction_i.checkpoint_done;
assign instruction_scalar_o.chkp            = instruction_i.chkp;
assign instruction_scalar_o.gl_index        = instruction_i.gl_index;
assign instruction_scalar_o.ex              = instruction_i.instr.ex;
`ifdef VERILATOR
assign instruction_scalar_o.id              = instruction_i.instr.id;
`endif
assign instruction_scalar_o.branch_taken    = 1'b0;
assign instruction_scalar_o.result_pc       = 0;
assign instruction_scalar_o.result          = (instruction_i.instr.instr_type == FMV_F2X) ? {{32{instruction_i.data_rs1[31]}},instruction_i.data_rs1[31:0]} : instruction_i.data_rs1;

endmodule