module conv_zvfhmin(
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

fpnew_pkg::status_t fp32_to_fp16_flags [3:0];
fpnew_pkg::status_t fp16_to_fp32_flags [3:0];

fpnew_pkg::status_t fp32_to_fp16_merged_flags;
fpnew_pkg::status_t fp16_to_fp32_merged_flags;

generate
    for (i = 0; i < 4; i = i + 1) begin
        fp32_to_fp16 fp32_to_fp16_inst (
            .f32(src_i[(i * 32) +: 32]),
            .frm(frm_i),
            .f16(fp32_to_fp16_o[(i * 16) +: 16]),
            .status_o(fp32_to_fp16_flags[i])
        );
    end
endgenerate

always_comb begin
    integer j;
    for (j = 0; j < 4; j = j + 1) begin
        fp16_to_fp32_flags[j] = '0;
        {fp16_to_fp32_flags[j].NV, fp16_to_fp32_o[(j * 32) +: 32]} = fp16_to_fp32(src_i[(j * 16) +: 16]);
    end
end

always_comb begin
    fp32_to_fp16_merged_flags = '0;
    fp32_to_fp16_merged_flags.NV = fp32_to_fp16_flags[0].NV | fp32_to_fp16_flags[1].NV | fp32_to_fp16_flags[2].NV | fp32_to_fp16_flags[3].NV;
    fp32_to_fp16_merged_flags.NX = fp32_to_fp16_flags[0].NX | fp32_to_fp16_flags[1].NX | fp32_to_fp16_flags[2].NX | fp32_to_fp16_flags[3].NX;
    fp32_to_fp16_merged_flags.OF = fp32_to_fp16_flags[0].OF | fp32_to_fp16_flags[1].OF | fp32_to_fp16_flags[2].OF | fp32_to_fp16_flags[3].OF;
    fp32_to_fp16_merged_flags.UF = fp32_to_fp16_flags[0].UF | fp32_to_fp16_flags[1].UF | fp32_to_fp16_flags[2].UF | fp32_to_fp16_flags[3].UF;

    fp16_to_fp32_merged_flags = '0;
    fp16_to_fp32_merged_flags.NV = fp16_to_fp32_flags[0].NV | fp16_to_fp32_flags[1].NV | fp16_to_fp32_flags[2].NV | fp16_to_fp32_flags[3].NV;
end

assign fp32_to_fp16_o[127:64] = 64'b0;

assign res_o = (operation_i == 1'b0) ? fp16_to_fp32_o : fp32_to_fp16_o;
assign status_o = (operation_i == 1'b0) ? fp16_to_fp32_merged_flags : fp32_to_fp16_merged_flags;

endmodule
