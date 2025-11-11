module fp32_to_fp16 (
    input  logic [31:0] f32,
    input  riscv_pkg::op_frm_fp_t frm,
    output logic [15:0] f16,
    output fpnew_pkg::status_t status_o
);

    logic sign;
    logic [7:0]  exp32;
    logic [22:0] frac32;
    logic [4:0]  exp16;
    logic [5:0]  exp16_ext;
    logic [9:0]  frac16;

    logic [10:0] frac_ext;
    logic [5:0]  exp_ext;

    logic guard;
    logic round;
    logic sticky;
    logic round_up;

    logic [7:0] exp_unbiased;
    logic [8:0] shift_amt;

    logic [26:0] frac_denorm;
    logic [22:0] frac_shifted;

    logic inexact;
    logic nv;

    localparam logic [4:0] EXP_BIAS_16  = 4'd15;

    always_comb begin
        nv = 1'b0;
        sign   = f32[31];
        exp32  = f32[30:23];
        frac32 = f32[22:0];

        round_up = 1'b0;
        guard    = 1'b0;
        round    = 1'b0;
        sticky   = 1'b0;

        if (exp32 == 8'hFF) begin
            // Infinity or NaN
            exp16  = 5'h1F;
            frac16 = (frac32 != 0) ? {1'b1, frac32[21:13]} : 10'h0;
            nv = 1'b1;
        end else begin
            if ((exp32 == 0) && (frac32 == 0)) begin
                // Zero
                exp16  = 5'h00;
                frac16 = 10'h0;
            end else begin
                if (exp32 == 0) begin // Subnormal
                    frac_shifted = frac32;
                    exp_unbiased = 8'h82; // -126
                end else begin // Normal
                    frac_shifted = frac32;
                    exp_unbiased = exp32 - 8'd127;
                end

                if (exp32 < EXP_BIAS_16) begin
                    shift_amt   = ((-8'sd13) - signed'(exp_unbiased));
                    frac_denorm = {1'b1, frac_shifted, 3'b000} >> shift_amt;

                    exp16  = 5'h00;
                    frac16 = frac_denorm[26:17];
                    guard  = frac_denorm[16];
                    round  = frac_denorm[15];
                    sticky = |frac_denorm[14:0];
                end else if (signed'(exp_unbiased) > 15) begin
                    exp16 = 5'h1F;
                    frac16 = 10'b0;
                    guard = 1'b0;
                    round = 1'b0;
                    sticky = 1'b0;
                    nv = 1'b1;
                end else begin
                    // Normal conversion
                    exp16_ext  = exp_unbiased[4:0] + 5'd15;
                    exp16 = exp16_ext[4:0];

                    frac16 = frac32[22:13];

                    guard  = frac32[12];
                    round  = frac32[11];
                    sticky = |frac32[10:0];
                end
            end
        end

        case (frm)
            riscv_pkg::FRM_RNE: round_up = guard && (round || sticky || frac16[0]);
            riscv_pkg::FRM_RTZ: round_up = 1'b0;
            riscv_pkg::FRM_RDN: round_up = sign && (guard || round || sticky);
            riscv_pkg::FRM_RUP: round_up = !sign && (guard || round || sticky);
            riscv_pkg::FRM_RMM: round_up = guard && (round || sticky || !sign);
            default: round_up = 1'b0;
        endcase

        inexact = (guard || round || sticky);

        frac_ext = {1'b0, frac16} + {{10{1'b0}}, round_up};

        if (frac_ext[10]) begin
            exp_ext = {1'b0, exp16} + 6'b1;
            exp16 = exp_ext[4:0];

            frac16 = 10'h0;
        end else begin
            frac16 = frac_ext[9:0];
        end

        f16 = {sign, exp16, frac16};

        status_o = '0;
        status_o.NX = inexact;
        status_o.NV = nv;
    end
endmodule
