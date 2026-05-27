module conv_zvfhmin
import drac_pkg::*;
import riscv_pkg::*;
import mmu_pkg::*;
(
    input bus_simd_t src_i,
    input logic valid_i,
    input logic operation_i, // 0: widening, 1: narrowing
    input  op_frm_fp_t frm_i,
    output bus_simd_t res_o,
    output fpnew_pkg::status_t status_o
);

genvar i;

bus_simd_t fp32_to_fp16_o;
bus_simd_t fp16_to_fp32_o;

fpnew_pkg::status_t fp32_to_fp16_flags [(VLEN/32):0];
logic fp16_to_fp32_nv_flag [(VLEN/32):0];

fpnew_pkg::status_t fp32_to_fp16_merged_flags;
fpnew_pkg::status_t fp16_to_fp32_merged_flags;

generate
    for (i = 0; i < (VLEN/32); i = i + 1) begin
        fp32_to_fp16 fp32_to_fp16_inst (
            .f32(src_i[(i * 32) +: 32]),
            .frm(fpnew_pkg::roundmode_e'(frm_i)),
            .f16(fp32_to_fp16_o[(i * 16) +: 16]),
            .status_o(fp32_to_fp16_flags[i])
        );

        fp16_to_fp32 fp16_to_fp32_inst (
            .fp16_i(src_i[(i * 16) +: 16]),
            .fp32_o(fp16_to_fp32_o[(i * 32) +: 32]),
            .nv_o(fp16_to_fp32_nv_flag[i])
        );
    end
endgenerate

always_comb begin
    fp32_to_fp16_merged_flags = '0;
    fp16_to_fp32_merged_flags = '0;

    for (int k = 0; k < (VLEN/32); k = k + 1) begin
        fp32_to_fp16_merged_flags.NV = fp32_to_fp16_flags[k].NV | fp32_to_fp16_merged_flags.NV;
        fp32_to_fp16_merged_flags.NX = fp32_to_fp16_flags[k].NX | fp32_to_fp16_merged_flags.NX;
        fp32_to_fp16_merged_flags.OF = fp32_to_fp16_flags[k].OF | fp32_to_fp16_merged_flags.OF;
        fp32_to_fp16_merged_flags.UF = fp32_to_fp16_flags[k].UF | fp32_to_fp16_merged_flags.UF;

        fp16_to_fp32_merged_flags = fp16_to_fp32_nv_flag[k] | fp16_to_fp32_merged_flags;
    end


end

assign fp32_to_fp16_o[VLEN-1:(VLEN/2)] = '0;

assign res_o = (operation_i == 1'b0) ? fp16_to_fp32_o : fp32_to_fp16_o;
assign status_o = (operation_i == 1'b0) ? fp16_to_fp32_merged_flags : fp32_to_fp16_merged_flags;

endmodule
