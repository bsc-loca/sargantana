module conv_zvfhmin(
    input bus_simd_t src_i,
    input logic valid_i,
    input logic operation_i, // 0: widening, 1: narrowing
    output bus_simd_t res_o,
    output logic valid_o,
    output fpnew_pkg::status_t status_o
);

genvar i;

bus_simd_t fp32_to_fp16_o;
bus_simd_t fp16_to_fp32_o;

generate
    for (i = 0; i < 4; i = i + 1) begin
        fp32_to_fp16 fp32_to_fp16_inst (
            .f32(src_i[(i * 32) +: 32]),
            .frm(riscv_pkg::FRM_RNE),
            .f16(fp32_to_fp16_o[(i * 16) +: 16])
        );
    end
endgenerate

always_comb begin
    integer j;
    for (j = 0; j < 4; j = j + 1) begin
        fp16_to_fp32_o[(j * 32) +: 32] = fp16_to_fp32(src_i[(j * 16) +: 16]);
    end
end

assign res_o = (operation_i == 1'b0) ? fp16_to_fp32_o : fp32_to_fp16_o;

endmodule
