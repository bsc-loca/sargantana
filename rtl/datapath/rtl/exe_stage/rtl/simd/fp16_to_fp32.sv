module fp16_to_fp32(
    input logic [15:0] fp16_i,
    output logic [31:0] fp32_o,
    output logic nv_o
);

logic       sign;
logic [4:0]  exp16;
logic [9:0]  frac16;
logic [3:0]  shift_amount;

logic [9:0] frac16_shifted;
logic [38:0] frac16_shifted_ext;

logic [7:0]  exp32;
logic [22:0] frac32;

logic       nv_flag;
logic [31:0] converted_val;

logic empty_lzc_denormals;

lzc #(
    .WIDTH (10),
    .MODE  (1)
) i_lzc (
    .in_i    (frac16),
    .cnt_o   (shift_amount),
    .empty_o (empty_lzc_denormals)
);

always_comb begin
    sign   = fp16_i[15];
    exp16  = fp16_i[14:10];
    frac16 = fp16_i[9:0];

    nv_flag = (exp16 == 5'h1F) && (frac16[9] == 1'b0) && (frac16[8:0] != 0);

    if (exp16 == 5'h00) begin
        if (frac16 == 10'h000) begin
            exp32  = 8'h00;
            frac32 = 23'h000000;
        end
        else begin
            exp32 = (8'd112 - shift_amount);

            frac16_shifted_ext = {13'b0, frac16} << (shift_amount + 1);
            frac16_shifted = frac16_shifted_ext[9:0];

            frac32 = {frac16_shifted, 13'b0};
        end
    end

    else if (exp16 == 5'h1F) begin
        exp32  = 8'hFF;
        frac32 = {frac16, {13{1'b0}}};
    end
    else begin
        exp32  = (exp16 - 5'd15) + 8'd127;
        frac32 = {frac16, {13{1'b0}}};
    end

    if (drac_pkg::is_qnan_f16(fp16_i)) begin
        converted_val = drac_pkg::FP32_QNAN;
    end else if (drac_pkg::is_snan_f16(fp16_i)) begin
        converted_val = drac_pkg::FP32_QNAN;
    end else begin
        converted_val = {sign, exp32, frac32};
    end

    fp32_o = converted_val;
    nv_o = nv_flag;
end
endmodule;
