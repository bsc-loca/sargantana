
import drac_pkg::*; 
import fpnew_pkg::*; 
import riscv_pkg::*;

// Vector FPU wrapper for FPNEW
module vfpu_drac_wrapper #(
    parameter fpu_features_t       Features = SARG_RV64DV,
    parameter fpu_implementation_t Implementation = SARG_SIMD_INIT,
    parameter int unsigned NumLanes = fpnew_pkg::max_num_lanes(Features.Width, Features.FpFmtMask, Features.EnableVectors),
    parameter type         MaskType = logic [NumLanes-1:0],
    // Do not change
    localparam int unsigned WIDTH        = Features.Width,
    localparam int unsigned NUM_OPERANDS = 3
) (
    input  logic    clk_i,
    input  logic    rstn_i,
    input  logic    flush_i,
    // inputs
    input  instr_type_t             instr_type_i,   // instruction type
    input  logic                    instr_valid_i,  // instruction type
    input  op_frm_fp_t              frm_i,          // rouding mode
    input  sew_t                    sew_i,          // sew (FP32 or FP64)
    input  bus_simd_t               data_vs1_i,     // data vector source 1
    input  bus_simd_t               data_vs2_i,     // data vector source 2
    input  MaskType                 data_vm_i,      // data vector mask input
    // outputs
    output bus_simd_t               data_vd_o,      // raw result, to be masked and filtered
    output fpnew_pkg::status_t      status_o        // resultant status flags
);


localparam logic [31:0] FP32_ONE  = 32'h3F800000;
localparam logic [31:0] FP32_ZERO = 32'h00000000;
localparam logic [63:0] FP64_ONE  = 64'h3FF0000000000000;
localparam logic [63:0] FP64_ZERO = 64'h0000000000000000;

localparam logic [31:0] FP32_QNAN = 32'h7FC00000;
localparam logic [63:0] FP64_QNAN = 64'h7FF8000000000000;
localparam logic [31:0] FP32_SNAN = 32'h7FA00000;
localparam logic [63:0] FP64_SNAN = 64'h7FF4000000000000;


/* Main floting-point parallel FPNEW unit
 *
 * The FPNEW floating-point unit needs to be passed all the operands and
 * operation type and selector bit depending on the incoming instruction
 * type. This will be done combinationally in the instruction type "case".
 *
 * FP Operations
 *
 * Enumerator    Modifier    Operation
 * ------------------------------------------------------------------------------------
 * FMADD         0           Fused multiply-add ((op[0] * op[1]) + op[2])
 * FMADD         1           Fused multiply-subtract ((op[0] * op[1]) - op[2])
 * FNMSUB        0           Negated fused multiply-subtract (-(op[0] * op[1]) + op[2])
 * FNMSUB        1           Negated fused multiply-add (-(op[0] * op[1]) - op[2])
 * ADD           0           Addition (op[1] + op[2])
 * ADD           1           Subtraction (op[1] - op[2])
 * MUL           0           Multiplication (op[0] * op[1])
 * DIV           0           Division (op[0] / op[1])
 * SQRT          0           Square root
 * SGNJ          0           Sign injection, operation encoded in rounding mode
 *                              RNE: op[0] with sign(op[1])
 *                              RTZ: op[0] with ~sign(op[1])
 *                              RDN: op[0] with sign(op[0]) ^ sign(op[1])
 *                              RUP: op[0] (passthrough)
 * SGNJ          1           As above, but result is sign-extended instead of NaN-Boxed
 * MINMAX        0           Minimum / maximum, operation encoded in rounding mode
 *                              RNE: minimumNumber(op[0], op[1])
 *                              RTZ: maximumNumber(op[0], op[1])
 * CMP           0           Comparison, operation encoded in rounding mode
 *                              RNE: op[0] <= op[1]
 *                              RTZ: op[0] < op[1]
 *                              RDN: op[0] == op[1]
 * CLASSIFY      0           Classification, returns RISC-V classification block
 * F2F           0           FP to FP cast, formats given by src_fmt_i and dst_fmt_i
 * F2I           0           FP to signed integer cast, formats given by src_fmt_i and int_fmt_i
 * F2I           1           FP to unsigned integer cast, formats given by src_fmt_i and int_fmt_i
 * I2F           0           Signed integer to FP cast, formats given by int_fmt_i and dst_fmt_i
 * I2F           1           Unsigned integer to FP cast, formats given by int_fmt_i and dst_fmt_i
 * CPKAB         0           Cast-and-pack op[0] and op[1] to entries 0,1 of vector op[2]
 * CPKAB         1           Cast-and-pack op[0] and op[1] to entries 2,3 of vector op[2]
 * CPKCD         0           Cast-and-pack op[0] and op[1] to entries 4,5 of vector op[2]
 * CPKCD         1           Cast-and-pack op[0] and op[1] to entries 6,7 of vector op[2]
 */

logic                   [SARG_RV64DV.Width-1:0][2:0] vector_operands;
fpnew_pkg::operation_e  vector_operation; // to be setted in decode always_comb
logic                   vector_operation_modifier;
fpnew_pkg::fp_format_e  vector_src_format;
fpnew_pkg::fp_format_e  vector_dst_format;

always_comb begin
    case (instr_type_i)
        VFADD: begin
            vector_operands[0]          = '0; // ignored in ADD mode 
            vector_operands[1]          = data_vs1_i;
            vector_operands[2]          = data_vs2_i;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b0;
            case (sew_i)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFSUB: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = data_vs2_i; // VS2 - VS1 or VS2 - f (if vfsub.vf)
            vector_operands[2]          = data_vs1_i;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b1; // SUB mode
            case (sew_i)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFRSUB: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = data_vs1_i; // reverse order (f - VS2)
            vector_operands[2]          = data_vs2_i;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b1;
            case (sew_i)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP32);
                end
                default: begin // FP64 mode
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFWADD: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = data_vs1_i;
            vector_operands[2]          = data_vs2_i;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b0;
            case (sew_i)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
                default: begin // in FP64 will be illegal instruction 
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        VFWSUB: begin
            vector_operands[0]          = '0;
            vector_operands[1]          = data_vs2_i; // vs2 - vs1, vs2 - f
            vector_operands[2]          = data_vs1_i;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = 1'b1;
            case (sew_i)
                SEW_32: begin
                    vector_src_format = fpnew_pkg::fp_format_e'(FP32);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
                default: begin // in FP64 will be illegal instruction 
                    vector_src_format = fpnew_pkg::fp_format_e'(FP64);
                    vector_dst_format = fpnew_pkg::fp_format_e'(FP64);
                end
            endcase
        end
        default: begin
            vector_operands             = '0;
            vector_operation            = fpnew_pkg::operation_e'(fpnew_pkg::ADD);
            vector_operation_modifier   = '0;
        end
    endcase
end

// instanciation of main FPNEW module
fpnew_top #(
    .Features       (SARG_RV64DV),
    .Implementation (SARG_SIMD_INIT)
) vector_fpnew (
    .clk_i          (clk_i),
    .rst_ni         (rstn_i),
    .flush_i        (flush_i),
    // inputs
    .operands_i     (vector_operands),
    .rnd_mode_i     (frm_i),
    .op_i           (vector_operation),
    .op_mod_i       (vector_operation_modifier),
    .src_fmt_i      (vector_src_format),
    .dst_fmt_i      (vector_dst_format),
    .int_fmt_i      (fpnew_pkg::int_format_e'(INT32)), // no INT use
    .vectorial_op_i (1'b1),
    .tag_i          ('0), // no tag, control over simd scoreboard
    .simd_mask_i    (data_vm_i), // MaskType logic [NumLanes-1:0]
    // ouputs
    .result_o       (data_vd_o),
    .status_o       (status_o),
    .tag_o          (), // no tag nor handshake needed
    .busy_o         (),
    // handshake signals, unused
    .in_valid_i     (instr_valid_i),
    .out_ready_i    (1'b1),
    .in_ready_o     (),
    .out_valid_o    ()
);

endmodule
