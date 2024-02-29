/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vaddsub.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Gerard Candón Arenas
 * Email(s)       : gerard.candon@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Gerard C. | 
 * -----------------------------------------------
 */

module vaddsub 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input bus64_t               data_vs1_i,     // 64-bit source operand 1
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);

//This module performs vector addition and subtraction. The strategy is to use
//the minimum number of adders while supporting 8, 16, 32 and 64 bit element
//widths.

logic is_sub;
logic [7:0] carry_in;
logic [7:0] carry_out;
bus64_t data_vs1;
logic [7:0][7:0] data_a;  // byte source vs2
logic [7:0][7:0] data_b;  // byte source vs1
logic [7:0][8:0] result;  // byte + carry_out partial results

assign is_sub = (instr_type_i == VSUB) ? 1'b1 : 1'b0;

always_comb begin
    //If a subtraction is performed, the operand is flipped and a 1'b1 is
    //selected as carry_in (vs2 - vs1 = vs2 + (-vs1))
    if (is_sub) begin
        data_vs1 = ~data_vs1_i;
        carry_in[0] = 1'b1;
    end else begin
        data_vs1 = data_vs1_i;
        carry_in[0] = 1'b0;
    end

    //The source operands are split into byte arrays
    for (int i = 0; i<8; ++i) begin
        data_a[i] = data_vs2_i[(8*i)+:8];
        data_b[i] = data_vs1[(8*i)+:8];
    end
end

//Partial sums, byte-adders
assign result[0] = data_a[0] + data_b[0] + carry_in[0];
assign result[1] = data_a[1] + data_b[1] + carry_in[1];
assign result[2] = data_a[2] + data_b[2] + carry_in[2];
assign result[3] = data_a[3] + data_b[3] + carry_in[3];
assign result[4] = data_a[4] + data_b[4] + carry_in[4];
assign result[5] = data_a[5] + data_b[5] + carry_in[5];
assign result[6] = data_a[6] + data_b[6] + carry_in[6];
assign result[7] = data_a[7] + data_b[7] + carry_in[7];

//Carry out of each byte-adder
assign carry_out[0] = result[0][8];
assign carry_out[1] = result[1][8];
assign carry_out[2] = result[2][8];
assign carry_out[3] = result[3][8];
assign carry_out[4] = result[4][8];
assign carry_out[5] = result[5][8];
assign carry_out[6] = result[6][8];
assign carry_out[7] = result[7][8];

//64-bit wide result
assign data_vd_o[7:0]   = result[0][7:0];
assign data_vd_o[15:8]  = result[1][7:0];
assign data_vd_o[23:16] = result[2][7:0];
assign data_vd_o[31:24] = result[3][7:0];
assign data_vd_o[39:32] = result[4][7:0];
assign data_vd_o[47:40] = result[5][7:0];
assign data_vd_o[55:48] = result[6][7:0];
assign data_vd_o[63:56] = result[7][7:0];

//Depending on the element width, each byte-adder selects it's carry_in
// - In case the previous sum is computing the same element, the carry_out of
//   the previous sum is selected
// - Otherwise, if the operation is a sub, a 1'b1 is selected
// - Otherwise, 1'b0 is selected
assign carry_in[1] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[0] : (is_sub) ? 1'b1 : 1'b0;
assign carry_in[2] = ((sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[1] : is_sub ? 1'b1 : 1'b0;
assign carry_in[3] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[2] : is_sub ? 1'b1 : 1'b0;
assign carry_in[4] = ((sew_i == SEW_64)) ? 
                        carry_out[3] : is_sub ? 1'b1 : 1'b0;
assign carry_in[5] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ?
                        carry_out[4] : is_sub ? 1'b1 : 1'b0;
assign carry_in[6] = ((sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[5] : is_sub ? 1'b1 : 1'b0;
assign carry_in[7] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[6] : is_sub ? 1'b1 : 1'b0;
endmodule
