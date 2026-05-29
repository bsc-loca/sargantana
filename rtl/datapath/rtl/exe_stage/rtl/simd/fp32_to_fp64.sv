module fp32_to_fp64(
    input logic [31:0] fp32_i,
    output logic [63:0] fp64_o
);
    logic        sign;
    logic [7:0]  exp32;
    logic [22:0] frac32;
    logic [22:0] frac32_shifted;
    logic [54:0] frac32_shifted_ext;

    logic [10:0] exp64;
    logic [51:0] frac64;

    logic [63:0] fp64_s;

    logic [4:0] shift_amt;

    logic empty_lzc_denormals;

    lzc #(
        .WIDTH (23),
        .MODE  (1) // MODE = 1 counts leading zeroes
    ) i_lzc (
        .in_i    (frac32),
        .cnt_o   (shift_amt),
        .empty_o(empty_lzc_denormals)
    );

    always_comb begin
        sign   = fp32_i[31];
        exp32  = fp32_i[30:23];
        frac32 = fp32_i[22:0];

        if (exp32 == 8'h00) begin
            if (frac32 == 0) begin
                exp64 = 11'h000;
                frac64 = 52'd0;
            end else begin
                exp64  = 11'h000;
                exp64  = 11'd896 - {6'h0, shift_amt};

                frac32_shifted_ext = {32'b0, frac32} << (shift_amt + 1);
                frac32_shifted = frac32_shifted_ext[22:0];

                frac64 = {frac32_shifted, {29'b0}};  // left-align mantissa
            end
        end
        else if (exp32 == 8'hFF) begin
            exp64  = 11'h7FF;
            frac64 = {frac32, {29{1'b0}}};
        end
        else begin
            exp64  = {3'b0, exp32} + 11'd896; // 896 = (1023 - 127) = (BIAS64 - BIAS32)
            frac64 = {frac32, {29{1'b0}}};
        end

        // canonicalize both QNAN and SNAN
        if (drac_pkg::is_qnan_f32(fp32_i)) begin
            fp64_s = drac_pkg::FP64_QNAN;
        end else if (drac_pkg::is_snan_f32(fp32_i)) begin
            fp64_s = drac_pkg::FP64_SNAN;
        end else begin
            fp64_s = {sign, exp64, frac64};
        end
    end

    assign fp64_o = fp64_s;

endmodule
