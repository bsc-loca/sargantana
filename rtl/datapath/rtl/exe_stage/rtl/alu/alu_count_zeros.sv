/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : alu_count_zeros.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gámez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Raúl G.   | 
 * -----------------------------------------------
 */

//////////////////////////////////////////////////////////////////////////////////////////////
/*
   mmm         m      mmmmm  m    m mmmmmm           #"   mmmm  m    m mmmmm  mmmmmmmmmmmmm  mmmm   "m
 m"   "        #        #    #  m"  #               m"   #"   " #    #   #    #        #    #"   "   "m
 #             #        #    #m#    #mmmmm          #    "#mmm  #mmmm#   #    #mmmmm   #    "#mmm     #
 #       """   #        #    #  #m  #               #        "# #    #   #    #        #        "#    #
  "mmm"        #mmmmm mm#mm  #   "m #mmmmm           #   "mmm#" #    # mm#mm  #        #    "mmm#"   #
*/
//////////////////////////////////////////////////////////////////////////////////////////////
module alu_count_zeros_mine
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    output bus64_t result_o
);


logic[6:0] pos;

logic[31:0] data_rs1_32;
logic[15:0] data_rs1_16;
logic[7:0] data_rs1_8;
logic[3:0] data_rs1_4;
logic[1:0] data_rs1_2;
logic data_rs1_1;

always_comb begin
    pos = 0;
    if (data_rs1_i[63:32] == '0) begin
        pos[5] = 1'b1;
        data_rs1_32 = data_rs1_i[31:0];
    end else begin
        data_rs1_32 = data_rs1_i[63:32];
    end

    if (data_rs1_32[31:16] == '0) begin
        pos[4] = 1'b1;
        data_rs1_16 = data_rs1_32[15:0];
    end else begin
        data_rs1_16 = data_rs1_32[31:16];
    end

    if (data_rs1_16[15:8] == '0) begin
        pos[3] = 1'b1;
        data_rs1_8 = data_rs1_16[7:0];
    end else begin
        data_rs1_8 = data_rs1_16[15:8];
    end

    if (data_rs1_8[7:4] == '0) begin
        pos[2] = 1'b1;
        data_rs1_4 = data_rs1_8[3:0];
    end else begin
        data_rs1_4 = data_rs1_8[7:4];
    end

    if (data_rs1_4[3:2] == '0) begin
        pos[1] = 1'b1;
        data_rs1_2 = data_rs1_4[1:0];
    end else begin
        data_rs1_2 = data_rs1_4[3:2];
    end

    if (data_rs1_2[1] == '0) begin
        pos[0] = 1'b1;
        data_rs1_1 = data_rs1_2[0];
    end else begin
        data_rs1_1 = data_rs1_2[1];
    end

end

assign result_o = (data_rs1_i == '0) ? XLEN : pos;

endmodule

//////////////////////////////////////////////////////////////////////////////////////////////
/*
 m    m                mmmm  m    m m       mmmm  mmmmm  mmmm   mmmmmm mmmmm    mmm    mm
 "m  m"               m"  "m #  m"  #      m"  "m #    # #   "m     #"   #        #    ##
  #  #                #    # #m#    #      #    # #mmmm" #    #   m#     #        #   #  #
  "mm"                #    # #  #m  #      #    # #    # #    #  m"      #        #   #mm#
   ##     #            #mm#  #   "m #mmmmm  #mm#  #mmmm" #mmm"  ##mmmm mm#mm  "mmm"  #    #
*/
//////////////////////////////////////////////////////////////////////////////////////////////
/* Implementation of:
 * V. Oklobdzija, "An implementation algorithm and design of a novel
 * leading zero detector circuit," in Conference Record of the
 * Twenty-Sixth Asilomar Conference on Signals, Systems \& Computers,
 * Pacific Grove, CA, USA, 1992, pp. 391,392,393,394,395,
 * doi: 10.1109/ACSSC.1992.269243.
 * url: https://doi.ieeecomputersociety.org/10.1109/ACSSC.1992.269243
 */
module bits_pair_checker_Oklobdzija
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic left_i,
    input logic right_i,
    output logic invalid_o,
    output logic position_o
);

assign invalid_o = ~(left_i | right_i);
assign position_o = (~left_i & right_i);
endmodule



module tree_Oklobdzija
    import drac_pkg::*;
    import riscv_pkg::*;
#(
    parameter DATA_SIZE = 4
) (
    input logic[DATA_SIZE-1:0] data_i,
    output logic invalid_o,
    output logic[$clog2(DATA_SIZE)-1:0] position_o
);

logic left_invalid;
logic right_invalid;

logic[$clog2(DATA_SIZE)-2:0] left_res;
logic[$clog2(DATA_SIZE)-2:0] right_res;

initial begin
    $display("%d", DATA_SIZE);
end

generate
    if (DATA_SIZE == 4) begin
        bits_pair_checker_Oklobdzija bits_pair_checker_Oklobdzija_left(
            .left_i(data_i[3]),
            .right_i(data_i[2]),
            .invalid_o(left_invalid),
            .position_o(left_res)
        );

        bits_pair_checker_Oklobdzija bits_pair_checker_Oklobdzija_right(
            .left_i(data_i[1]),
            .right_i(data_i[0]),
            .invalid_o(right_invalid),
            .position_o(right_res)
        );

    end else begin
        tree_Oklobdzija #(.DATA_SIZE(DATA_SIZE/2)) tree_Oklobdzija_left(
            .data_i(data_i[DATA_SIZE-1:DATA_SIZE/2]),
            .invalid_o(left_invalid),
            .position_o(left_res)
        );

        tree_Oklobdzija #(.DATA_SIZE(DATA_SIZE/2)) tree_Oklobdzija_right(
            .data_i(data_i[DATA_SIZE/2-1:0]),
            .invalid_o(right_invalid),
            .position_o(right_res)
        );

    end
endgenerate

assign invalid_o = left_invalid & right_invalid;
assign position_o[$clog2(DATA_SIZE)-1] = (invalid_o == 1'b0) ? left_invalid : 0;
assign position_o[$clog2(DATA_SIZE)-2:0] = (invalid_o == 1'b0) ? (left_invalid == 1'b0) ? left_res : right_res : 0;

endmodule


module alu_count_zeros_Oklobdzija
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    output bus64_t result_o
);

tree_Oklobdzija #(.DATA_SIZE(64)) tree_Oklobdzija_base(
    .data_i(data_rs1_i),
    .invalid_o(result_o[6]),
    .position_o(result_o[5:0])
);

endmodule
//////////////////////////////////////////////////////////////////////////////////////////////
/*
 mm   m               m    m mmmmm  m      mmmmmm mm   m m    m  mmmm  m    m mmmmm    mmm
 #"m  #               ##  ##   #    #      #      #"m  # #  m"  m"  "m "m  m"   #    m"   "
 # #m #               # ## #   #    #      #mmmmm # #m # #m#    #    #  #  #    #    #
 #  # #               # "" #   #    #      #      #  # # #  #m  #    #  "mm"    #    #
 #   ##   #           #    # mm#mm  #mmmmm #mmmmm #   ## #   "m  #mm#    ##   mm#mm   "mmm"
*/
//////////////////////////////////////////////////////////////////////////////////////////////
/* Implementation of
 * Milenković, N. Z., Stanković, V. V., & Milić, M. L. (2015). Modular design
 * of fast leading zeros counting circuit. Journal of Electrical Engineering,
 * 66(6), 329-333.
 */
module NLC_Milenkovic (
    input logic[3:0] data_i,
    output logic a_o,
    output logic[1:0] z_o
);

assign a_o = ~(data_i[3] | data_i[2] | data_i[1] | data_i[0]);
assign z_o[0] = ~((~data_i[2] & data_i[1]) | data_i[3]);
assign z_o[1] = ~(data_i[2] | data_i[3]);
endmodule

module BNE_Milenkovic (
    input logic[7:0] data_i,
    output logic q_o,
    output logic[2:0] y_o
);

assign q_o = data_i[0] & data_i[1] & data_i[2] & data_i[3] & data_i[4] & data_i[5] & data_i[6] & data_i[7];
assign y_o[2] = data_i[0] & data_i[1] & data_i[2] & data_i[3];
assign y_o[1] = data_i[0] & data_i[1] & (~data_i[2] | ~data_i[3] | (data_i[4] & data_i[5]));
assign y_o[0] = (data_i[0] & (~data_i[1] | (data_i[2] & ~data_i[3]))) | (data_i[0] & data_i[2] & data_i[4] & (~data_i[5] | data_i[6]));
endmodule

module LZC_32_bits_Milenkovic (
    input logic[31:0] data_i,
    output logic q_o,
    output logic[4:0] y_o
);

logic[7:0] a;
logic[1:0] z[7:0];

genvar i;
generate
    for (i = 0; i < 8; ++i) begin
        NLC_Milenkovic NLC_Milenkovic_inst (
            .data_i(data_i[4*i +: 4]),
            .a_o(a[7-i]),
            .z_o(z[7-i])
        );
    end
endgenerate

logic[2:0] y;

BNE_Milenkovic BNE_Milenkovic_inst (
    .data_i(a),
    .q_o(q_o),
    .y_o(y)
);

assign y_o[4:2] = y;
assign y_o[1:0] = z[y];

endmodule

module alu_count_zeros_Milenkovic
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    output bus64_t result_o
);

logic q_high;
logic q_low;

logic[4:0] y_high;
logic[4:0] y_low;

LZC_32_bits_Milenkovic LZC_32_bits_Milenkovic_high (
    .data_i(data_rs1_i[63:32]),
    .q_o(q_high),
    .y_o(y_high)
);

LZC_32_bits_Milenkovic LZC_32_bits_Milenkovic_low (
    .data_i(data_rs1_i[31:0]),
    .q_o(q_low),
    .y_o(y_low)
);

logic invalid;

always_comb begin
    result_o = '0;

    invalid = q_high & q_low;
    result_o[6] = invalid;
    result_o[5] = (invalid == 1'b0) ? q_high : 1'b0;
    result_o[4:0] = (invalid == 1'b0) ? (q_high == 1'b1) ? y_low : y_high : 5'b0;
end

endmodule


//////////////////////////////////////////////////////////////////////////////////////////////
/*
   mmm  mmmmm   mmmm  mmmmm         m    m  mmmm    mm     mmm  mmmmmm
 m"   " #   "# m"  "m #   "#        #    # #"   "   ##   m"   " #
 #      #mmm#" #    # #mmm#"        #    # "#mmm   #  #  #   mm #mmmmm
 #      #      #    # #             #    #     "#  #mm#  #    # #
  "mmm" #       #mm#  #             "mmmm" "mmm#" #    #  "mmm" #mmmmm
*/
//////////////////////////////////////////////////////////////////////////////////////////////

// TODO








//////////////////////////////////////////////////////////////////////////////////////////////
/*
   mmm  mmmmmm mm   m mmmmmm mmmmm    mm   m
 m"   " #      #"m  # #      #   "#   ##   #
 #   mm #mmmmm # #m # #mmmmm #mmmm"  #  #  #
 #    # #      #  # # #      #   "m  #mm#  #
  "mmm" #mmmmm #   ## #mmmmm #    " #    # #mmmmm
*/
//////////////////////////////////////////////////////////////////////////////////////////////

module alu_count_zeros
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    instr_type_t instr_type_i,
    output bus64_t result_o
);

bus64_t data_to_calc;

always_comb begin
    case (instr_type_i)
        CTZ: begin
            for (int i = 0; i < 64; ++i) begin
                data_to_calc[i] = data_rs1_i[63-i];
            end
        end
        CTZW: begin
            for (int i = 0; i < 32; ++i) begin
                data_to_calc[i] = data_rs1_i[31-i];
            end

            data_to_calc[63:32] = '0;
        end
        CLZ: begin
            data_to_calc = data_rs1_i;
        end
        CLZW: begin
            data_to_calc[31:0] = data_rs1_i[31:0];
            data_to_calc[63:32] = '0;
        end
        default: begin
            data_to_calc = data_rs1_i;
        end
    endcase
end

bus64_t res_module;

alu_count_zeros_Milenkovic alu_count_zeros_inst (
    .data_rs1_i(data_to_calc),
    .result_o(res_module)
);

always_comb begin
    case (instr_type_i)
        CTZW, CLZW: begin
            if (res_module == 64) begin
                result_o = 32;
            end else if (res_module[5] == 1'b1) begin
                result_o = res_module;
                result_o[5] = 1'b0;
            end else begin
                result_o = res_module;
            end
        end
        default: begin
            result_o = res_module;
        end
    endcase
end

endmodule
