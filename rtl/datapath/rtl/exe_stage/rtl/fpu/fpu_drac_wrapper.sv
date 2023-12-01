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
   input  logic                     flush_i,
   input  logic                     stall_wb_i,
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
fp_format_e  dst_fmt;
int_format_e int_fmt;
logic ready_fpu;
fpuv_pkg::status_t result_fp_status_int,finish_fp_status_int;
reg_t tag_current_instr_int, result_tag_int;

logic sign_extend_int, sign_extend_q;
logic result_valid_int, stall_pending_fp_ops;
bus64_t result_int;
logic enable_fp_op_int;

rr_exe_fpu_instr_t finish_fp_op_int;

always_comb begin : decide_FMT
   if (instruction_i.instr.fmt) begin
      dst_fmt = FP64;
   end else begin
      dst_fmt = FP32;
   end
end
// Operation decoding
always_comb begin
   rnd_mode_sel    = 0;
   opcode_rnd_mode = RNE;
   src_fmt         = dst_fmt;
   int_fmt         = dst_fmt == FP32 ? INT32 : INT64;
   sign_extend_int = 0;
   op_mod = 0;

   operands[0] = instruction_i.data_rs1;
   operands[1] = instruction_i.data_rs2;
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
      // Documentation: https://github.com/pulp-platform/fpnew/tree/79f75e0a0fdab6ebc3840a14077c39f4934321fe/docs#parameters

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
         operands[0] = instruction_i.data_rs1;
         operands[1] = instruction_i.data_rs2;
         operands[2] = '0;//instruction_i.data_rs3;
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
         operands[0] = instruction_i.data_rs1;
         operands[1] = instruction_i.data_rs2;
         operands[2] = '0;//instruction_i.data_rs3;
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
      drac_pkg::FMIN_MAX: begin 
         op          = fpuv_pkg::MINMAX;
         op_mod      = 0;
      end 
      drac_pkg::FCMP: begin
         op          = fpuv_pkg::CMP;
         op_mod      = 0;
      end
      drac_pkg::FCLASS: begin
         op          = fpuv_pkg::CLASSIFY;
         op_mod      = 0;
      end   
      drac_pkg::FSGNJ: begin
         op          = fpuv_pkg::SGNJ;
         op_mod      = 0;
      end
      // FCVT_F2I, FCVT_I2F, FCVT_F2F, FSGNJ, FMV_F2X, FMV_X2F,
      // FP to I
      drac_pkg::FCVT_F2I: begin
         op          = fpuv_pkg::F2I;
         op_mod      = instruction_i.instr.rs2[0]; // 1 --> Unsigned
         int_fmt     = instruction_i.instr.rs2[1] ? INT64 : INT32;
         sign_extend_int = (int_fmt == INT32);
      end
      // I to FP
      drac_pkg::FCVT_I2F: begin
         op          = fpuv_pkg::I2F;
         op_mod      = instruction_i.instr.rs2[0]; // 1 --> Unsigned
         int_fmt     = instruction_i.instr.rs2[1] ? INT64 : INT32;
      end
      // FP to FP
      drac_pkg::FCVT_F2F: begin
         op              = fpuv_pkg::F2F;
         op_mod          = 0;
         src_fmt         = instruction_i.instr.rs2[0] ? FP64 : FP32;
      end
      // FP to FP
      drac_pkg::FMV_X2F: begin
         op              = fpuv_pkg::SGNJ;
         op_mod          = 1;
         rnd_mode_sel    = 1'b1;
         opcode_rnd_mode = fpuv_pkg::RUP;
      end
      default: begin 
         op     = operation_e'('1); // don't care
         op_mod = DONT_CARE;        // don't care
      end
   endcase

end

assign enable_fp_op_int = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_FPU) & !stall_pending_fp_ops;

pending_fp_ops_queue pending_fp_ops_queue_inst (
    .clk_i(clk_i),              // Clock Singal
    .rstn_i(rstn_i),           // Negated Reset Signal
    .flush_i(flush_i),          // Flush all entries
    .valid_i(enable_fp_op_int & ready_fpu),                // Valid instruction 
    .instruction_i(instruction_i),          // All instruction input signals
    .result_valid_i(result_valid_int),         // Result valid
    .result_tag_i(result_tag_int),           // Instruction that finishes
    .result_data_i(result_int),          // Result asociated data
    .result_fp_status_i(result_fp_status_int),
    .advance_head_i(finish_fp_op_int.instr.valid & !stall_wb_i),         // Advance head pointer one position
    .finish_instr_fp_o(finish_fp_op_int),      // Next Instruction to Write Back FP
    .finish_fp_status_o(finish_fp_status_int),  // FP_STATUS
    .tag_o(tag_current_instr_int),                  // Tag given to the incoming instruction
    .full_o(stall_pending_fp_ops)                  // fifo full
);

typedef logic [3:0]W4_logic;
typedef logic [2:0]W3_logic;
typedef logic [1:0]W2_logic;

fpnew_top #(
   .Features       ( Features ),
   .Implementation ( Implementation )
) i_fpuv_top (
   .clk_i          ( clk_i ),
   .rst_ni         ( rstn_i ),
   .flush_i        ( flush_i ),
   // Input
   .operands_i     ( operands ),
   .rnd_mode_i     ( rnd_mode_sel ? fpnew_pkg::roundmode_e'(W3_logic'(opcode_rnd_mode)) : 
    fpnew_pkg::roundmode_e'(W3_logic'(instruction_i.instr.frm))),
   .op_i           ( fpnew_pkg::operation_e'(W4_logic'(op ))),
   .op_mod_i       ( op_mod ),
   .src_fmt_i      ( fpnew_pkg::fp_format_e'(W3_logic'(src_fmt ))),
   .dst_fmt_i      ( fpnew_pkg::fp_format_e'(W3_logic'(dst_fmt ))),
   .int_fmt_i      ( fpnew_pkg::int_format_e'(W2_logic'(int_fmt ))),
   .simd_mask_i    ( '0 ),
   //.inactive_sel_i ( 2'b11 ),
   .vectorial_op_i ( '0 ),
   .tag_i          ( tag_current_instr_int ),
   .in_valid_i     ( enable_fp_op_int),
   .out_ready_i    ( 1'b1 ),
   // Outputs
   .in_ready_o     ( ready_fpu ),
   .result_o       ( result_int ),
   .status_o       ( result_fp_status_int ),
   .tag_o          ( result_tag_int ),
   .out_valid_o    ( result_valid_int ),
   .busy_o         ( /* unused */ )
);

// Output FPU
assign instruction_o.valid           = finish_fp_op_int.instr.valid & finish_fp_op_int.instr.fregfile_we;
assign instruction_o.result          = finish_fp_op_int.instr.op_32 ? {{32{1'b1}},finish_fp_op_int.data_rs3[31:0]} : finish_fp_op_int.data_rs3;
assign instruction_o.pc              = finish_fp_op_int.instr.pc;
assign instruction_o.bpred           = finish_fp_op_int.instr.bpred;
assign instruction_o.rs1             = finish_fp_op_int.instr.rs1;
assign instruction_o.rd              = finish_fp_op_int.instr.rd;
assign instruction_o.change_pc_ena   = finish_fp_op_int.instr.change_pc_ena;
assign instruction_o.regfile_we      = finish_fp_op_int.instr.fregfile_we;
assign instruction_o.instr_type      = finish_fp_op_int.instr.instr_type;
assign instruction_o.stall_csr_fence = finish_fp_op_int.instr.stall_csr_fence;
assign instruction_o.csr_addr        = finish_fp_op_int.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_o.fprd            = finish_fp_op_int.fprd;
assign instruction_o.checkpoint_done = finish_fp_op_int.checkpoint_done;
assign instruction_o.chkp            = finish_fp_op_int.chkp;
assign instruction_o.gl_index        = finish_fp_op_int.gl_index;
assign instruction_o.branch_taken    = 1'b0;
assign instruction_o.result_pc       = 0;
assign instruction_o.fp_status       = finish_fp_status_int;
assign instruction_o.ex              = '0;
`ifdef SIM_KONATA_DUMP
   assign instruction_o.id           = finish_fp_op_int.instr.id;
`endif 


// Stall if the FPU is not ready or there is a fp instruction on flight
assign stall_o = (!ready_fpu | stall_pending_fp_ops);


// Output FPU scalar
assign instruction_scalar_o.valid           = finish_fp_op_int.instr.valid && finish_fp_op_int.instr.regfile_we && !stall_wb_i;
assign instruction_scalar_o.result          = finish_fp_op_int.instr.op_32 ? {{32{finish_fp_op_int.data_rs3[31]}},finish_fp_op_int.data_rs3[31:0]} : finish_fp_op_int.data_rs3;
assign instruction_scalar_o.pc              = finish_fp_op_int.instr.pc;
assign instruction_scalar_o.bpred           = finish_fp_op_int.instr.bpred;
assign instruction_scalar_o.rs1             = finish_fp_op_int.instr.rs1;
assign instruction_scalar_o.rd              = finish_fp_op_int.instr.rd;
assign instruction_scalar_o.change_pc_ena   = finish_fp_op_int.instr.change_pc_ena;
assign instruction_scalar_o.regfile_we      = finish_fp_op_int.instr.regfile_we;
assign instruction_scalar_o.instr_type      = finish_fp_op_int.instr.instr_type;
assign instruction_scalar_o.stall_csr_fence = finish_fp_op_int.instr.stall_csr_fence;
assign instruction_scalar_o.csr_addr        = finish_fp_op_int.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_scalar_o.prd             = finish_fp_op_int.fprd;
assign instruction_scalar_o.checkpoint_done = finish_fp_op_int.checkpoint_done;
assign instruction_scalar_o.chkp            = finish_fp_op_int.chkp;
assign instruction_scalar_o.gl_index        = finish_fp_op_int.gl_index;
`ifdef SIM_KONATA_DUMP
assign instruction_scalar_o.id              = finish_fp_op_int.instr.id;
`endif
assign instruction_scalar_o.branch_taken    = 1'b0;
assign instruction_scalar_o.result_pc       = 0;
assign instruction_scalar_o.fp_status       = finish_fp_status_int;
assign instruction_scalar_o.ex              = '0;
assign instruction_scalar_o.mem_type        = NOT_MEM;


endmodule
