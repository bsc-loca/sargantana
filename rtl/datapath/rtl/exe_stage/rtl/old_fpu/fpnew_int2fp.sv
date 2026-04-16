module fpnew_int2fp #(
  parameter int unsigned AbsWidth=2, // Width of the abolute value, without sign bit
  parameter int unsigned FP_WIDTH=32,
  parameter fpnew_pkg::fmt_logic_t   fmt = '1
) (
    input logic[AbsWidth-1:0] abs_value_i,
    input logic is_nan,
    input logic sign_i,
    output logic[AbsWidth-1:0] post_in2fp
);

  function [FP_WIDTH-1:0] trunc_127_64(input [2*FP_WIDTH-1:0] val_in);
    trunc_127_64 = val_in[FP_WIDTH-1:0];
  endfunction
// Infer target format parameters
  localparam int unsigned EXP_BITS = fpnew_pkg::exp_bits(fpnew_pkg::fp_format_e'(fmt));
  localparam int unsigned MAN_BITS = fpnew_pkg::man_bits(fpnew_pkg::fp_format_e'(fmt));
  // localparam int unsigned FP_WIDTH = fpnew_pkg::fp_width(fpnew_pkg::fp_format_e'(fmt));
  localparam int unsigned EXP_BIAS = ((2**(EXP_BITS - 1)) - 1);

  // Intermediate values
  logic [FP_WIDTH-1:0] norm_val;
  logic [cf_math_pkg::idx_width(FP_WIDTH)-1:0] leading_zeros;
  logic [MAN_BITS-1:0] mantissa;
  logic [EXP_BITS-1:0] exponent;
  logic guard, round, sticky;
  logic [EXP_BITS-1:0] final_exponent;
  logic [EXP_BITS:0] temp_final_exponent;
  logic                 round_up;
  logic                 empty;
  logic of_mantissa;

  lzc #(
    .WIDTH(FP_WIDTH),
    .MODE(1)
  ) i_lzc (
    .in_i(abs_value_i[FP_WIDTH-1:0]),
    .cnt_o(leading_zeros),
    .empty_o        (empty)
  );

  // 1. Zero check
  always_comb begin
    if (empty) begin
      post_in2fp = '0;
      post_in2fp[FP_WIDTH-1] = sign_i;
    end else begin
      // 2. Normalize: count leading zeros

      norm_val = trunc_127_64({{FP_WIDTH{1'b0}}, abs_value_i[FP_WIDTH-1:0]} << leading_zeros);

      // 3. Extract mantissa and GRS bits
      mantissa = norm_val[FP_WIDTH-2 -: (MAN_BITS)]; // Extra bit for possible overflow
      guard    = norm_val[FP_WIDTH-2-MAN_BITS];
      round    = norm_val[FP_WIDTH-3-MAN_BITS];
      sticky   = |norm_val[FP_WIDTH-4-MAN_BITS:0];

      // 4. Rounding (round to nearest even)
      round_up = guard && (round || sticky || mantissa[0]);
      if (round_up)
        {of_mantissa, mantissa} = mantissa + 1;
      else
        of_mantissa = 0;

      // 5. Exponent
      exponent = FP_WIDTH[EXP_BITS-1:0] - {{(EXP_BITS-cf_math_pkg::idx_width(FP_WIDTH)-1){1'b0}},leading_zeros} - 1;
      temp_final_exponent = exponent + EXP_BIAS[EXP_BITS-1:0] + {{EXP_BITS-1{1'b0}}, of_mantissa};
      final_exponent =(temp_final_exponent[EXP_BITS] ? {EXP_BITS{1'b1}}: temp_final_exponent[EXP_BITS-1:0]);

      // 6. Pack result
      post_in2fp = is_nan ? {{AbsWidth-FP_WIDTH{1'b0}}, 1'b0, {EXP_BITS{1'b1}}, {1'b1, {MAN_BITS-1{1'b0}}}} : {{AbsWidth-FP_WIDTH{1'b0}}, sign_i, final_exponent[EXP_BITS-1:0], mantissa[MAN_BITS-1:0]};
    end
  end
endmodule
