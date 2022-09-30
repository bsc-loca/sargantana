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
logic [7:0] src1_8bits [0:7];
logic [7:0] src2_8bits [0:7];

logic [15:0] src1_16bits [0:3];
logic [15:0] src2_16bits [0:3];

logic [31:0] src1_32bits [0:1];
logic [31:0] src2_32bits [0:1];

logic [63:0] src1_64bits;
logic [63:0] src2_64bits;

logic src1_negative [0:7];
logic src2_negative [0:7];

always_comb begin
    negative_results_0 = 8'b0;
    unique case (sew_i)
    SEW_8 : begin
        for (int i = 0; i < 8; i++) begin
            src1_8bits[i] = data_vs1_i[i*8+:8];
            src2_8bits[i] = data_vs2_i[i*8+:8];

            src1_negative[i] = src1_signed_0 & src1_8bits[7][i];
            src2_negative[i] = src2_signed_0 & src2_8bits[7][i];

            negative_results_0[i] = src1_negative[i] ^ src2_negative[i];

            src1_data_0[i*8+:8] = (src1_negative[i]) ? ~src1_8bits[i] + 8'b1 : src1_8bits[i];
            src2_data_0[i*8+:8] = (src2_negative[i]) ? ~src2_8bits[i] + 8'b1 : src2_8bits[i];
        end
        
    end
    SEW_16 : begin
        for (int i = 0; i < 4; i++) begin
            src1_16bits[i] = data_vs1_i[i*16+:16];
            src2_16bits[i] = data_vs2_i[i*16+:16];

            src1_negative[i] = src1_signed_0 & src1_16bits[15][i];
            src2_negative[i] = src2_signed_0 & src2_16bits[15][i];

            negative_results_0[i] = src1_negative[i] ^ src2_negative[i]; 

            src1_data_0[i*16+:16] = (src1_negative[i]) ? ~src1_16bits[i] + 16'b1 : src1_16bits[i];
            src2_data_0[i*16+:16] = (src2_negative[i]) ? ~src2_16bits[i] + 16'b1 : src2_16bits[i];
        end
        
    end
    SEW_32 : begin
        for (int i = 0; i < 2; i++) begin
            src1_32bits[i] = data_vs1_i[i*32+:32];
            src2_32bits[i] = data_vs2_i[i*32+:32];

            src1_negative[i] = src1_signed_0 & src1_32bits[i][31];
            src2_negative[i] = src2_signed_0 & src2_32bits[i][31];

            negative_results_0[i] = src1_negative[i] ^ src2_negative[i];

            src1_data_0[i*32+:32] = (src1_negative[i]) ? ~src1_32bits[i] + 32'b1 : src1_32bits[i];
            src2_data_0[i*32+:32] = (src2_negative[i]) ? ~src2_32bits[i] + 32'b1 : src2_32bits[i];
        end

    end
    SEW_64 : begin
        src1_64bits = data_vs1_i;
        src2_64bits = data_vs2_i;

        src1_negative[0] = src1_signed_0 & src1_64bits[63];
        src2_negative[0] = src2_signed_0 & src2_64bits[63];

        negative_results_0[0] = src1_negative[0] ^ src2_negative[0];

        src1_data_0[63:0] = (src1_negative[0]) ? ~src1_64bits + 64'b1 : src1_64bits;
        src2_data_0[63:0] = (src2_negative[0]) ? ~src2_64bits + 64'b1 : src2_64bits;
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

logic [15:0] nloxmlo_16b [0:3] [0:3];
logic [15:0] nloxmhi_16b [0:3] [0:3];
logic [15:0] nhixmlo_16b [0:3] [0:3];
logic [15:0] nhixmhi_16b [0:3] [0:3];

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
            nloxmlo_16b[i][j] = products_8b_1[i * 2 + 0][j * 2 + 0];
            nloxmhi_16b[i][j] = products_8b_1[i * 2 + 0][j * 2 + 1];
            nhixmlo_16b[i][j] = products_8b_1[i * 2 + 1][j * 2 + 0];
            nhixmhi_16b[i][j] = products_8b_1[i * 2 + 1][j * 2 + 1];

            products_16b_1[i][j] = nloxmlo_16b[i][j] + ((nloxmhi_16b[i][j] + nhixmlo_16b[i][j]) << 8) + (nhixmhi_16b[i][j] << 16);
        end
    end
end

logic [63:0] products_32b_1[0:1][0:1];

logic [31:0] nloxmlo_32b [0:1] [0:1];
logic [31:0] nloxmhi_32b [0:1] [0:1];
logic [31:0] nhixmlo_32b [0:1] [0:1];
logic [31:0] nhixmhi_32b [0:1] [0:1];

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
            nloxmlo_32b[i][j] = products_16b_1[i * 2 + 0][j * 2 + 0];
            nloxmhi_32b[i][j] = products_16b_1[i * 2 + 0][j * 2 + 1];
            nhixmlo_32b[i][j] = products_16b_1[i * 2 + 1][j * 2 + 0];
            nhixmhi_32b[i][j] = products_16b_1[i * 2 + 1][j * 2 + 1];

            products_32b_1[i][j] = nloxmlo_32b[i][j] + ((nloxmhi_32b[i][j] + nhixmlo_32b[i][j]) << 16) + (nhixmhi_32b[i][j] << 32);
        end
    end
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

logic [63:0] nloxmlo_64b;
logic [63:0] nloxmhi_64b;
logic [63:0] nhixmlo_64b;
logic [63:0] nhixmhi_64b;

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
    nloxmlo_64b = products_32b_2[0][0];
    nloxmhi_64b = products_32b_2[0][1];
    nhixmlo_64b = products_32b_2[1][0];
    nhixmhi_64b = products_32b_2[1][1];

    product_64b_2 = nloxmlo_64b + ((nloxmhi_64b + nhixmlo_64b) << 32) + (nhixmhi_64b << 64);
end

////////////////////////////////////////////////////////////////////////////////
//                                OUTPUT MUX                                  //
////////////////////////////////////////////////////////////////////////////////

bus64_t data_vd_o1;
bus64_t data_vd_o2;
logic [63:0] full_precision_result_64b;

// Output the results (8, 16, 32 bits)
always_comb begin
    full_precision_result_64b = 'b0;
    unique case (sew_1)
        SEW_8 : begin
            for (int i = 0; i < 8; i++) begin
                full_precision_result_64b[15:0] = (negative_results_1[i]) ? 
                                                               ~products_8b_1[i][i] + 16'b1 : 
                                                               products_8b_1[i][i];

                data_vd_o1[i*8+:8] = (is_mulh_1) ?
                                     full_precision_result_64b[15:8] :
                                     full_precision_result_64b[7:0];
            end
        end
        SEW_16 : begin
            for (int i = 0; i < 4; i++) begin
                full_precision_result_64b[31:0] = (negative_results_1[i]) ? 
                                                               ~products_16b_1[i][i] + 32'b1 : 
                                                               products_16b_1[i][i];

                data_vd_o1[i*16+:16] = (is_mulh_1) ?
                                       full_precision_result_64b[31:16] :
                                       full_precision_result_64b[15:0];
            end
        end
        SEW_32 : begin
            for (int i = 0; i < 2; i++) begin
                full_precision_result_64b[63:0] = (negative_results_1[i]) ? 
                                                               ~products_32b_1[i][i] + 64'b1 : 
                                                               products_32b_1[i][i];

                data_vd_o1[i*32+:32] = (is_mulh_1) ?
                                       full_precision_result_64b[63:32] :
                                       full_precision_result_64b[31:0];
            end
        end
        default : begin
            data_vd_o1 = 64'b0;
        end
    endcase
end

// Output the results (64 bits)
logic [127:0] full_precision_result_128b;
always_comb begin
    unique case (sew_2)
        SEW_64 : begin
            full_precision_result_128b[127:0] = (negative_results_2[0]) ? 
                                                            ~product_64b_2 + 128'b1 : 
                                                            product_64b_2;

            data_vd_o2 = (is_mulh_2) ?
                         full_precision_result_128b[127:64] :
                         full_precision_result_128b[63:0];
        end
        default : begin
            data_vd_o2 = 64'b0;
        end
    endcase
end

assign data_vd_o = (sew_2 == SEW_64) ? data_vd_o2 : data_vd_o1;

endmodule
