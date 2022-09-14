/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vmul.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Xavier Carril & Lorién López 
 * Email(s)       : xavier.carril@bsc.es & lorien.lopez@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

`ifdef FPGA
(* use_dsp = "yes" *) module vmul (
`else 
module vmul (
`endif
  input wire                  clk_i,          // Clock
  input wire                  rstn_i,         // Reset 
  input instr_type_t          instr_type_i,   // Instruction type
  input sew_t                 sew_i,          // Element width
  input bus64_t               data_vs1_i,     // 64-bit source operand 1
  input bus64_t               data_vs2_i,     // 64-bit source operand 2
  output bus64_t              data_vd_o       // 64-bit result
);

////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 0                                   //
////////////////////////////////////////////////////////////////////////////////

sew_t sew_0;
assign sew_0 = sew_i;

wire is_mulh_0 = (instr_type_i != VMUL);
wire is_signed_0 = (instr_type_i != VMULHU);
wire is_mixed_signed_0 = (instr_type_i == VMULHSU);

wire src1_signed_0 = (is_signed_0);
wire src2_signed_0 = (is_signed_0 ^ is_mixed_signed_0);

logic [7:0] negative_results_0;

bus64_t src1_data_0;
bus64_t src2_data_0;

// Get the magnitude of the sources depending on the signess of the operation.
// This way we can perform a signed multiplication without extending the signs. 
always_comb begin
    negative_results_0 = 8'b0;
    unique case (sew_i)
    SEW_8 : begin
        for (int i = 0; i < 8; i++) begin
            automatic logic [7:0] src1 = data_vs1_i[i*8+:8];
            automatic logic [7:0] src2 = data_vs2_i[i*8+:8];

            automatic logic src1_negative = src1_signed_0 & src1[7];
            automatic logic src2_negative = src2_signed_0 & src2[7];

            negative_results_0[i] = src1_negative ^ src2_negative;

            src1_data_0[i*8+:8] = (src1_negative) ? ~src1 + 8'b1 : src1;
            src2_data_0[i*8+:8] = (src2_negative) ? ~src2 + 8'b1 : src2;
        end
    end
    SEW_16 : begin
        for (int i = 0; i < 4; i++) begin
            automatic logic [15:0] src1 = data_vs1_i[i*16+:16];
            automatic logic [15:0] src2 = data_vs2_i[i*16+:16];

            automatic logic src1_negative = src1_signed_0 & src1[15];
            automatic logic src2_negative = src2_signed_0 & src2[15];

            negative_results_0[i] = src1_negative ^ src2_negative; 

            src1_data_0[i*16+:16] = (src1_negative) ? ~src1 + 16'b1 : src1;
            src2_data_0[i*16+:16] = (src2_negative) ? ~src2 + 16'b1 : src2;
        end
    end
    SEW_32 : begin
        for (int i = 0; i < 2; i++) begin
            automatic logic [31:0] src1 = data_vs1_i[i*32+:32];
            automatic logic [31:0] src2 = data_vs2_i[i*32+:32];

            automatic logic src1_negative = src1_signed_0 & src1[31];
            automatic logic src2_negative = src2_signed_0 & src2[31];

            negative_results_0[i] = src1_negative ^ src2_negative;

            src1_data_0[i*32+:32] = (src1_negative) ? ~src1 + 32'b1 : src1;
            src2_data_0[i*32+:32] = (src2_negative) ? ~src2 + 32'b1 : src2;
        end
    end
    SEW_64 : begin
        automatic logic [63:0] src1 = data_vs1_i;
        automatic logic [63:0] src2 = data_vs2_i;

        automatic logic src1_negative = src1_signed_0 & src1[63];
        automatic logic src2_negative = src2_signed_0 & src2[63];

        negative_results_0[0] = src1_negative ^ src2_negative;

        src1_data_0[63:0] = (src1_negative) ? ~src1 + 64'b1 : src1;
        src2_data_0[63:0] = (src2_negative) ? ~src2 + 64'b1 : src2;
    end
    default : begin
        src1_data_0[63:0] = 64'd0;
        src2_data_0[63:0] = 64'd0;
        negative_results_0 = 8'b0;
    end
  endcase
end

////////////////////////////////////////////////////////////////////////////////
//                              STAGE 0 -> STAGE 1                            //
////////////////////////////////////////////////////////////////////////////////

sew_t sew_1;

logic is_mulh_1;

logic [7:0] negative_results_1;

bus64_t src1_data_1;
bus64_t src2_data_1;

always_ff@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        sew_1                    <= SEW_8;
        is_mulh_1                <= 1'b0;
        negative_results_1       <= 8'b0;
        src1_data_1              <= 64'd0;
        src2_data_1              <= 64'd0;
    end
    else begin
        sew_1                    <= sew_0;
        is_mulh_1                <= is_mulh_0;
        negative_results_1       <= negative_results_0;
        src1_data_1              <= src1_data_0;
        src2_data_1              <= src2_data_0;
    end
end

////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 1                                   //
////////////////////////////////////////////////////////////////////////////////

logic [15:0] products_8b_1[0:7][0:7];

// 8b products (all x all).
always_comb begin
    for(int i = 0; i < 8; i++) begin
        for(int j = 0; j < 8; j++) begin
            products_8b_1[i][j] = src1_data_1[i*8+:8] * src2_data_1[j*8+:8];
        end
    end
end

logic [31:0] products_16b_1[0:3][0:3];

// 16b products (all x all).
always_comb begin
    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            //      8b  8b
            // 16b [nhi nlo]
            //  x
            // 16b [mhi mlo]
            //      =
            //   [nhi * mhi]
            // +            [nlo * mhi + nhi * mlo]
            // +                                   [nlo * mlo]
            //
            automatic logic [15:0] nloxmlo = products_8b_1[i * 2 + 0][j * 2 + 0];
            automatic logic [15:0] nloxmhi = products_8b_1[i * 2 + 0][j * 2 + 1];
            automatic logic [15:0] nhixmlo = products_8b_1[i * 2 + 1][j * 2 + 0];
            automatic logic [15:0] nhixmhi = products_8b_1[i * 2 + 1][j * 2 + 1];

            products_16b_1[i][j] = nloxmlo + ((nloxmhi + nhixmlo) << 8) + (nhixmhi << 16);
        end
    end
end

logic [63:0] products_32b_1[0:1][0:1];

// 32b products (all x all).
always_comb begin
    for(int i = 0; i < 2; i++) begin
        for(int j = 0; j < 2; j++) begin
            //      16b 16b
            // 32b [nhi nlo]
            //  x
            // 32b [mhi mlo]
            //      =
            //   [nhi * mhi]
            // +            [nlo * mhi + nhi * mlo]
            // +                                   [nlo * mlo]
            //
            automatic logic [31:0] nloxmlo = products_16b_1[i * 2 + 0][j * 2 + 0];
            automatic logic [31:0] nloxmhi = products_16b_1[i * 2 + 0][j * 2 + 1];
            automatic logic [31:0] nhixmlo = products_16b_1[i * 2 + 1][j * 2 + 0];
            automatic logic [31:0] nhixmhi = products_16b_1[i * 2 + 1][j * 2 + 1];

            products_32b_1[i][j] = nloxmlo + ((nloxmhi + nhixmlo) << 16) + (nhixmhi << 32);
        end
    end
end

bus64_t data_vd_o1;

// Output the results (8, 16, 32 bits)
always_comb begin
    unique case (sew_1)
        SEW_8 : begin
            for (int i = 0; i < 8; i++) begin
                automatic logic [15:0] full_precision_result = (negative_results_1[i]) ? 
                                                               ~products_8b_1[i][i] + 16'b1 : 
                                                               products_8b_1[i][i];

                data_vd_o1[i*8+:8] = (is_mulh_1) ?
                                     full_precision_result[15:8] :
                                     full_precision_result[7:0];
            end
        end
        SEW_16 : begin
            for (int i = 0; i < 4; i++) begin
                automatic logic [31:0] full_precision_result = (negative_results_1[i]) ? 
                                                               ~products_16b_1[i][i] + 32'b1 : 
                                                               products_16b_1[i][i];

                data_vd_o1[i*16+:16] = (is_mulh_1) ?
                                       full_precision_result[31:16] :
                                       full_precision_result[15:0];
            end
        end
        SEW_32 : begin
            for (int i = 0; i < 2; i++) begin
                automatic logic [63:0] full_precision_result = (negative_results_1[i]) ? 
                                                               ~products_32b_1[i][i] + 64'b1 : 
                                                               products_32b_1[i][i];

                data_vd_o1[i*32+:32] = (is_mulh_1) ?
                                       full_precision_result[63:32] :
                                       full_precision_result[31:0];
            end
        end
        default : begin
            data_vd_o1 = 64'b0;
        end
    endcase
end

////////////////////////////////////////////////////////////////////////////////
//                              STAGE 1 -> STAGE 2                            //
////////////////////////////////////////////////////////////////////////////////

sew_t sew_2;

logic is_mulh_2;

logic [7:0] negative_results_2;

logic [15:0] products_8b_2[0:7][0:7];
logic [31:0] products_16b_2[0:3][0:3];
logic [63:0] products_32b_2[0:1][0:1];

always_ff@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        sew_2                    <= SEW_8;
        is_mulh_2                <= 1'b0;
        negative_results_2       <= 8'b0;
        products_8b_2            <= '{default:'{default:'0}};
        products_16b_2           <= '{default:'{default:'0}};
        products_32b_2           <= '{default:'{default:'0}};
    end
    else begin
        sew_2                    <= sew_1;
        is_mulh_2                <= is_mulh_1;
        negative_results_2       <= negative_results_1;
        products_8b_2            <= products_8b_1;
        products_16b_2           <= products_16b_1;
        products_32b_2           <= products_32b_1;
    end
end

////////////////////////////////////////////////////////////////////////////////
//                                  STAGE 2                                   //
////////////////////////////////////////////////////////////////////////////////

logic [127:0] product_64b_2;

// 64b product.
always_comb begin
    //      32b 32b
    // 64b [nhi nlo]
    //  x
    // 64b [mhi mlo]
    //      =
    //   [nhi * mhi]
    // +            [nlo * mhi + nhi * mlo]
    // +                                   [nlo * mlo]
    //
    automatic logic [63:0] nloxmlo = products_32b_2[0][0];
    automatic logic [63:0] nloxmhi = products_32b_2[0][1];
    automatic logic [63:0] nhixmlo = products_32b_2[1][0];
    automatic logic [63:0] nhixmhi = products_32b_2[1][1];

    product_64b_2 = nloxmlo + ((nloxmhi + nhixmlo) << 32) + (nhixmhi << 64);
end

bus64_t data_vd_o2;

// Output the results (64 bits)
always_comb begin
    unique case (sew_2)
        SEW_64 : begin
            automatic logic [127:0] full_precision_result = (negative_results_2[0]) ? 
                                                            ~product_64b_2 + 128'b1 : 
                                                            product_64b_2;

            data_vd_o2 = (is_mulh_2) ?
                         full_precision_result[127:64] :
                         full_precision_result[63:0];
        end
        default : begin
            data_vd_o2 = 64'b0;
        end
    endcase
end

////////////////////////////////////////////////////////////////////////////////
//                                OUTPUT MUX                                  //
////////////////////////////////////////////////////////////////////////////////

assign data_vd_o = (sew_2 == SEW_64) ? data_vd_o2 : data_vd_o1;

endmodule
